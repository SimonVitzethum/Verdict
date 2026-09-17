# Befunde bm12 — wo die Wirklichkeit nein sagte (QEMU-Lane)

Lane bm12 repariert den QEMU-Befund aus `messung/BERICHT-qemu.md` — in reinem
Gabbro, ohne eine Zeile C. Vier Stellen, an denen Hand-Nachrichten und Harnesses von Anfang an unbemerkt das Falsche prüften, und eine Stelle, an der die
Sprache selbst das Kostenversprechen verweigerte. Jeder Eintrag mit Beleg.

## Q-1 — Byte-Slots sind u32-Zellen: das Draht-Layout war 4-fach gespreizt

Erstfund aus BERICHT-qemu.md §2/M4, hier mit den Worten des Emitters.
`bau/netzverbindung.c` (vor bm12):

```c
typedef struct {
    uint32_t byte;
} Senden_slot;
```

Slot *i* liegt an Draht-Offset *4i*, nicht *i*. `sende(fd, 28)` rief
`sendto(fd, &Senden, 28)` — 28 Bytes ab Strukturstart = Slots 0–6 mit je drei
Null-Pad-Bytes. Auf dem Draht (strace, Host wie Gast):

```
len=28, type=0, flags=0, ... 02 00 00 00 03 00 00 00 05 00 00 00
```

statt `type=0x0302, flags=5`. Der Kernel schwieg mit Rechten (kein ACK ohne
`NLM_F_ACK` bei Erfolg) und antwortete ohne Rechte EPERM (Perm-Prüfung vor
Typ-Dispatch) — weshalb der Host-Lauf „gesund" aussah und `einrichten` in der
VM ewig im ersten `empfange` hing. Kein Harness sah es: Harness 1/2 füllen und
prüfen slot-weise (`lege_empfang`, `hole_senden`) — innerhalb einer
Repräsentation selbstkonsistent; Längen zählen Slots, keine Draht-Bytes.

Reparatur (diese Lane, Gabbro only): `PaketWort count 16` / `FangWort count
2048` tragen GEpackte Little-Endian-Worte über die Kerngrenze;
`packe_senden`/`lege_fang` übersetzen (Shift-/Multiplikations-Muster aus
`drehe32`, keine neue Operator-Klasse); `sende`/`empfange` packen aus/ein;
die `ptr`-Syscalls zeigen auf die Wort-Tabellen (`use` + `bau/netz.gabi`,
bm11-Verfahren). Danach dekodiert strace die Nachrichten vollständig
(`NFNL_SUBSYS_QUEUE<<8|NFQNL_MSG_CONFIG`, `NLM_F_REQUEST|NLM_F_ACK`,
copy_range 1600, mode COPY_PACKET, depth 1024, FAIL_OPEN).

## Q-2 — die Queue stempelt AF_INET, der Parser wollte 0

`suche_paket` verweigerte jede echte Nachricht:

```
let familie : Einzelbyte = Empfang.slots[16].byte;
if familie != 0 { return ergebnis_leer(2, typ); }
```

Echte `NFQNL_MSG_PACKET`-Nachrichten tragen `nfgen_family=AF_INET` (2) —
strace-Beleg aus der VM. Der bm6-Harness fütterte family 0 von Hand. Seit
bm12: nur AF_INET passiert (IPv4-Firewall; IPv6 fällt ins strikte Nein, der
Dekoder liest nur IPv4).

## Q-3 — NFQUEUE liefert Schicht 3, der Dekoder las Ethernet

Der bm1-Dekoder las den EtherType an Offset 12/13. Echte Payloads beginnen
mit 0x45 (strace: `45 00 00 3c ... 7f 00 00 01 ...`) — kein Ethernet-Header,
nie. `entpacke` dekodiert seit bm12 nacktes IPv4 (alle Fest-Offsets −14,
EtherType-Prüfung entfallen; Version/IHL/Fragment/Proto-Disziplin
unverändert). `Kopf`-Form unverändert; ARCHITEKTUR.md trägt den
bm12-Zusatz. Kosten: `entpacke` 175/200 (Spiegel in `entscheidung.gab`
bleibt ehrlich).

## Q-4 — NFQA_PACKET_HDR ist 11 Bytes lang, nicht 12

```
if atyp == 1 {
    if alen < 12 { fehler = 4; leave attr; }   -- bm11 stand
```

Der Kernel zählt die WAHRE Länge: id[4] + hw_protocol[2] + hook[1] + Header[4]
= 11 (strace: `nla_len=11`), Padding ist implizit. Der Harness fütterte 12
(Pad mitgezählt). Seit bm12: `alen < 11`. `haken` an `a+10` stimmte schon
immer für das 11er-Layout. Vorlauf (`(ende+3)/4*4`) war und ist korrekt.

## Q-5 — K003 über den Pack-Pfad (Sprache, wörtlich)

```
error: [K003] ... `packe` promises costs, but a `forever` loop has no total
cost -- its promise is `per_pass`, not `costs`
```

(probe `bau/probe-pack.gab`, vor dem Edit gemessen). Folgerung ehrlich
getragen: `packe_senden`/`lege_fang` ohne `costs` (OFFEN wie
`behandle`/`arbeite`/`main`), damit `sende`/`empfange`/`einrichten` ohne
`costs` (Aufrufer kostenloser Funktionen), damit die drei Spiegel in
`gab/lauf.gab` ohne `costs`. Sechs neue OFFEN-Stellen neben den fünf
stehenden — alle per Schleifenform, keine eine Weigerung. Die
`netz_*2`-Wrapper behalten 14/15/15 (Körper unverändert, `kosten` belegt).

## Residuen dieser Lane

- `bind` (`Adresse`) funktioniert per 4er-Ausrichtung (Familie/Pid/Groups
  sitzen zufällig richtig) — angefasst wird es nicht, notiert ist es hier.
- E247-Hinweise über den neuen Tabellen (stehende Klasse seit bm6).
- Harness 1/2-Frames (Ethernet + family 0 + HDR-len 12) sind gegen echte
  Nachrichten falsch — sie liegen als Scratch außerhalb des Baums; ihre
  Erneuerung steht aus. Die VM ist seit bm12 der maßgebliche Harness.
- Contention, Fuzzer, Wall-Clock: offen seit bm8, unverändert.
