# Report — QEMU-Test: die Firewall in einer Debian-VM (2026-09-16)

Auftrag: Full verdict-test lokal in QEMU. Ergebnis: **kein einziges Urteil auf
dem Draht** — und der Grund ist ein neuer Befund auf Emitter-Ebene (Q-1),
den kein Harness bisher sehen konnte, weil er erst gegen einen echten Kernel
sichtbar wird.

## 1. Aufbau (alles lokal, alles wiederholbar)

- Host: EndeavourOS, `qemu-system-x86_64` 11.1.1, `/dev/kvm` benutzbar.
- Gast: **Debian 13.7.0 amd64 netinst** (`debian-13.7.0-amd64-netinst.iso`,
  per `bsdtar` geprüft), 8-GB-qcow2, 2 vCPU, 2 GB RAM, User-Netzwerk.
- Unattended-Install per Preseed in der Initrd (zweite cpio-Archive angehängt,
  Verfahren aus den Debian-Docs): Hostname `verdict-test`, root-Passwort
  `verdict` (nur Test-VM hinter NAT), Pakete u.a. `nftables`, `strace`,
  `python3`, `openssh-server`, serielle Konsole (`console=ttyS0`,
  `GRUB_TERMINAL="console serial"`).
- Zwei Installations-Anläufe: Anlauf 1+2 mit `reboot_in_progress` booteten per
  `-kernel` nach Fertigstellung in den Installer zurück und partitionierten
  erneut (SeaBIOS hing danach bei `Booting from Hard Disk...`, per
  `screendump` belegt). Anlauf 3 mit zusätzlich
  `d-i debian-installer/exit/poweroff boolean true` schaltete sauber ab
  (`Installing GRUB boot loader ... 100%`, `reboot: Power down`, QEMU-Exit 0).
  Lehre: `-kernel`-Boot + Installer-Reboot = Schleife; Poweroff-Preseed bricht
  sie (QEMU beendet sich beim Gast-Poweroff von selbst).
- Bedienung: `tmux`-Sitzung (`-serial stdio`), Login root über serielle
  Konsole, Datei-Transfer per Host-HTTP (`python3 -m http.server`, Gast holt
  per `wget` über `10.0.2.2`). QEMU-Monitor über Unix-Socket für
  `info status`/`screendump`.
- Firewall-Binary: `bau/*.c` aus `make` (9/9 `pruefen` grün) + Scratch-Stub
  **nur** für die 4 divergierenden Exits
  (`zaehler_streit`, `netz_streit`, `lauf_aufgegeben`, `treffer_aufgegeben`
  als `abort()`; `VSPERRE_nimm`/`gib` kommen aus `gab/sperre.gab`). Stub liegt
  in `/tmp/opencode/verdict-stub.c`, nie im Baum (Makefile-NOTE). Binary braucht
  nur `GLIBC_2.2.5`/`2.34` — läuft auf Debian 13 (glibc 2.41).
- Test-Regel (SSH bleibt frei, nur Test-Traffic geht in die Queue):
  `nft add rule inet filter input tcp dport { 80, 81 } queue num 0`
  (Hook `input`, Policy `accept`). Server: `python3 -m http.server` auf :80
  und :81 an 127.0.0.1. Client: `curl` auf 127.0.0.1 (lokal erzeugte Pakete
  an lokale Adressen durchlaufen die INPUT-Chain — belegt durch Zähler unten).

## 2. Messungen

### M1 — ohne Rechte: fail-closed, auch in der VM

```
timeout 10 setpriv --reuid=nobody --regid=nogroup --clear-groups ./verdict
nobody-exit=112
```

Wie auf dem Host: EPERM auf die Config-Nachrichten, `einrichten` gibt 1
zurück, Exit 112. Fail-closed gilt.

### M2 — als root: kein Urteil, Blockade im ersten `empfange`

```
timeout 8 strace -f -o v2.log -e trace=network ./verdict   # root-exit=124
wc -l v2.log        # 9 Zeilen
grep -c sendto      # 4   (28/32/28/36, wie auf dem Host)
grep -c recvfrom    # 1   (ein einziges, nie beantwortetes)
```

Vollständiges Log (verbatim, Adressen gekürzt):

```
socket(AF_NETLINK, SOCK_RAW, NETLINK_NETFILTER) = 3
bind(3, {sa_family=AF_NETLINK, nl_pid=0, nl_groups=00000000}, 12) = 0
sendto(3, [{nlmsg_len=28, nlmsg_type=0, nlmsg_flags=0, ...},
  "\x02\x00\x00\x00\x03\x00\x00\x00\x05\x00\x00\x00"], 28, 0, NULL, 0) = 28
sendto(3, [{nlmsg_len=32, ...}], 32, 0, NULL, 0) = 32
sendto(3, [{nlmsg_len=28, ...}], 28, 0, NULL, 0) = 28
sendto(3, [{nlmsg_len=36, ...}], 36, 0, NULL, 0) = 36
recvfrom(3, 0x..., 8192, 0, NULL, NULL) = ? ERESTARTSYS   # nur das SIGTERM von timeout
```

Der Prozess kommt nie an `einrichten` vorbei: das **erste** `empfange`
(ACK #1) blockiert ewig — der Kernel antwortet auf keine der vier
Config-Nachrichten, und die Queue wird nie gebunden.

### M3 — die Queue-Seite funktioniert, die Pakete stapeln sich

Gleicher Aufbau, **ohne** verdict-Prozess (Kontrollversuch):

```
curl80 ohne verdict: http=000 exit=28      # haengt, max-time 10s
nft: tcp dport { 80, 81 } counter packets 3 bytes 180 queue to 0
```

3 Pakete (SYN + 2 Retransmits à 60 B) matchen die Regel und bleiben in der
ungebundenen Queue stecken. Mit verdict-Prozess das gleiche Bild: beide
`curl` (`:80` wie `:81`) laufen ins Timeout, `sendto`-Zähler im
verdict-strace bleibt bei 4 (nur Config, null Urteile).

### M4 — die Draht-Bytes sind falsch (Beweiskette für Q-1)

Beabsichtigt laut `gab/netzverbindung.gab` (`baue_binden`, Bytes 0–27):

```
1c 00 00 00 | 02 03 05 00 | 00 00 00 00 | 00 00 00 00 |
02 00 00 00 | 08 00 01 00 | 01 00 00 00
(len=28, type=0x0302, flags=5=REQUEST|ACK, nfgenmsg, Attr len=8 …)
```

Tatsächlich auf dem Draht (strace, alle vier Nachrichten gleiches Muster):

```
1c 00 00 00 | 00 00 00 00 | 00 00 00 00 | 00 00 00 00 |
02 00 00 00 | 03 00 00 00 | 05 00 00 00
(len=28, type=0, flags=0, …)
```

Erklärung, Zeile für Zeile aus dem emitierten C (`bau/netzverbindung.c`):

```c
typedef struct {
    uint32_t byte;          // JEDER Byte-Slot ist eine 4-Byte-Zelle
} Senden_slot;
static Senden Senden_speicher;   // slots[SENDEN_GROESSE]
```

`sende(fd, 28)` ruft `sendto(fd, &Senden, 28)` — 28 **Bytes** ab Strukturstart
= Slots 0–6 mit je 3 Null-Pad-Bytes: `28,0,0,0` → `1c 00 00 00` (len zufällig
richtig), Slots 1–3 = 0 (type=0, flags=0, seq/pid=0), Slots 4–6 = 2,3,5
(erscheinen an Offset 16–27 statt 4–7). Rechnung geht byte-genau auf.

## 3. Befund

**Q-1 — Byte-Tabellen sind im emitierten C keine gepackten Bytes.**
Ein Gabbro-`table`-Slot `u32 in 0 .. 255` wird als `struct { uint32_t byte; }`
emittiert: Slot *i* liegt an Draht-Offset *4·i*, nicht *i*. Jede Stelle, die
eine Tabelle per `&T`-Zeiger an den Kernel (oder aus ihm) reicht, liest bzw.
schreibt ein anderes Layout als das Protokoll verlangt:

- Sendepfad (gemessen): `Senden` (Config + Urteile) und `Adresse` (bind)
  verlassen den Prozess 4-fach gespreizt; der Kernel sieht
  `nlmsg_type=0, nlmsg_flags=0` und schweigt (mit Rechten) bzw. antwortet
  EPERM (ohne Rechte — die Perm-Prüfung feuert vor der Typ-Dispatch, weshalb
  der Host-Lauf „gesund" aussah).
- Empfangspfad (Folgerung, ungemessen — ohne funktionierenden Sendepfad
  unerreichbar): der Kernel schreibt gepackte Bytes nach `Empfang`, Gabbro
  liest `slots[i]` als u32 über 4 gepackte Bytes (LE-vermischt). `suche_paket`
  würde auf echten Nachrichten falsche Typen/Längen sehen.

Warum die Harnesses das nicht sahen: Harness 1/2 füllen und prüfen Tabellen
**slot-weise** (`lege_empfang`, `hole_senden`) — innerhalb einer Repräsentation
selbstkonsistent. Der Längen-Check (28/32/28/36) zählt Slots, nicht
Draht-Bytes. Erst der echte Kernel unterscheidet. BERICHT-bm11 §2
(„TRANSPORT GESCHLOSSEN") ist damit zu relativieren: Socket lebt, bind trägt
die Adresse, Längen stimmen — aber die **Nachrichteninhalte ab Byte 4** sind
auf dem Draht falsch, und die beanspruchten ACK-Flag-Bytes stehen in Wahrheit
an Offset 16+, wo der Kernel keinen Header sucht.

Möglicher Weg (neue Bahn, hier nicht angefangen): Packen in Gabbro selbst —
je 4 Slots per Shift/Or zu einem u32-Wort zusammensetzen
(`b0 + b1*256 + b2*65536 + b3*16777216`), Worte in eine u32-Tabelle schreiben
und **deren** Adresse mit Byte-Länge übergeben; Empfang spiegelbildlich per
Division/Modulo. Ob Kosten-/Effekt-Prüfer und `narrow`-Formen das tragen,
ist unvermessen.

## 4. Was in der VM als Nächstes zu tun wäre (nach Q-1-Reparatur)

1. Gleicher Aufbau, Binary neu bauen, M2 wiederholen: erwartet 4 ACKs,
   `recvfrom`-Block in `arbeite`, dann `curl :80 → 200` (ACCEPT, Regel) und
   `curl :81 → Timeout` (DROP, Default) — Rückweg wird nie gequect
   (Regel matcht nur Input-Dport), daher kein SYN-ACK-Problem.
2. Urteils-Bytes aus verdict-strace gegen `baue_urteil`-Spez prüfen
   (Verdict-Wort + Big-Endian-Id).
3. Erst danach: Flood/Connection-Table-voll und Contention (Residuen seit bm8).

## 5. Reproduktion

```
# Host: Binary (Stub nie committen)
cc -std=c11 -Wall -Wextra -Werror -O2 -pthread -I bau -o /tmp/opencode/verdict \
  bau/*.c /tmp/opencode/verdict-stub.c   # Stub: 4 Exits als abort()
# Host: VM booten (Platte bleibt in /tmp/opencode/qemu/disk.qcow2)
tmux new-session -d -s verdict-vm '/tmp/opencode/qemu/test-boot.sh'
# Gast (serielle Konsole): Dateien holen, Test fahren
wget http://10.0.2.2:8000/verdict http://10.0.2.2:8000/vm-test.sh  # Host-HTTP auf :8000
nft add table inet filter
nft add chain inet filter input '{ type filter hook input priority 0; policy accept; }'
nft add rule inet filter input tcp dport { 80, 81 } queue num 0
timeout 8 strace -f -o v2.log -e trace=network ./verdict   # M2
```

Gast-Testskript: (Host) `/tmp/opencode/qemu/share/vm-test.sh` — bewusst nicht
im Baum: es referenziert Gast-Pfade und das Wegwerf-Passwort.
