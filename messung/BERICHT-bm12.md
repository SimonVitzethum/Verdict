# Report — lane bm12 (Q-1…Q-4: die Firewall urteilt in der VM)

Tool: `./werkzeug/gabbro` wie bm11. `make pruefen`: 9/9 grün. Kein C im Baum,
kein C in der Lane: der einzige C-Text dieser Lane ist, was `gabbro emit`
schreibt, plus der 4-Symbol-Scratch-Stub außerhalb des Baums
(`vm/baue-binary.sh` erzeugt ihn per printf nach `vm/abbilder/`, nie committet).

## 1. Was die Lane tat

| Änderung | Datei(en) |
|---|---|
| `PaketWort count 16` / `FangWort count 2048` (gepackte Draht-Worte) | `netzverbindung` |
| `packe_senden` / `lege_fang` (Wort-Translation, `forever`, ohne `costs`) + `draht_zaehlung`-Annahme | `netzverbindung` |
| `sende` packt vor `netz_senden2`, `empfange` packt aus nach `netz_empfangen2`; beide ohne `costs`, erweiterte Effekte | `netzverbindung` |
| `einrichten` ohne `costs` (829 fällt), Effekte um Wort-Tabellen erweitert | `netzverbindung` |
| `ptr`-Spiegel auf Wort-Tabellen (`&PaketWort`, `&FangWort`) | `netzverbindung`, `systemrufe` (`use`, 2 Syscalls, 2 Wrapper) |
| 3 Transport-Spiegel ohne `costs` (Eigentümer kostenlos) | `lauf` |
| `suche_paket`: nur AF_INET passiert (Q-2) | `netzverbindung` |
| `NFQA_PACKET_HDR`-Mindestlänge 12 → 11 (Q-4) | `netzverbindung` |
| `entpacke`: nacktes IPv4 statt Ethernet (Q-3), Kosten 175/200 | `pakete` |
| L3-Zusatz (Puffer ab IP-Header, `Kopf` unverändert) | `ARCHITEKTUR.md` |
| VM-Kram aus /tmp (RAM) ins Repo: `vm/` (Skripte), Blobs in `vm/abbilder/` (ignoriert) | `.gitignore`, `vm/` |

Diff-Umfang: `git diff --stat` zeigt fünf geänderte `.gab`-Dateien plus
ARCHITEKTUR.md; alles andere ist unberührt (Entscheidung, Regeln,
Verbindungen, Zähler, Sperre: keine Zeile).

## 2. Prüf-Worte und Kosten

```
gab/entscheidung.gab         ok
gab/lauf.gab                 ok
gab/netzverbindung.gab       ok
gab/pakete.gab               ok
gab/regeln.gab               ok
gab/sperre.gab               ok
gab/systemrufe.gab           ok
gab/verbindungen.gab         ok
gab/zaehler.gab              ok
```

`kosten`: `entpacke` 175/200 (Spiegel ehrlich), `netz_*2` 14/15/15
unverändert (Körper gleich), `packe_senden`/`lege_fang`/`sende`/`empfange`/
`einrichten` OFFEN (K003-Kette, BEFUNDE-bm12.md Q-5). Neue E247 über den
Wort-Tabellen: stehende Klasse.

## 3. Gemessen: Host-Draht, dann VM-grün

Host (`strace`, unprivilegiert): alle vier Config-Nachrichten vollständig
dekodiert — `type=NFNL_SUBSYS_QUEUE<<8|NFQNL_MSG_CONFIG`,
`flags=NLM_F_REQUEST|NLM_F_ACK`, BIND-Cmd 1, PARAMS range 1600/mode
COPY_PACKET, Depth 1024, FAIL_OPEN-Flags — dann EPERM → Exit 112
(fail-closed intakt).

VM (Debian 13, QEMU/KVM, Verfahren in BERICHT-qemu.md, Binary aus
`vm/baue-binary.sh`):

```
einrichten: 4 × NLMSG_ERROR error=0 (alle ACKs)
curl :80  → http=200 exit=0 in 13 ms (ACCEPT, kompletter Flow)
curl :81  → http=000 exit=28 (DROP, Timeout)
Urteile auf dem Draht: 7 × ACCEPT (Wort 1), 4 × DROP (Wort 0),
  Typ NFQNL_MSG_VERDICT, REQUEST ohne ACK (wie spezifiziert)
Dauerlauf: 3 × :80 → 200, :81 → Timeout, Prozess gesund
nobody → Exit 112 (fail-closed mit neuem Code)
```

Erste echte Urteile dieses Projekts: SYN→:80 ACCEPT (Regel), SYN→:81 DROP
(Default), mehrpaketiger :80-Flow (Handshake + GET + FIN) durch
Conntrack-Fast-Path und Regelwerk.

## 4. Test-Hygiene-Befund (Verfahren, kein Sprach-Befund)

`vm/gast/vm-test.sh` tötete per `kill $SPid` nur das `strace`, nicht den
getracten verdict: die Waise hielt Queue 0, der Folgelauf starb mit EPERM →
112 (erneutes Binden ist keine Berechtigung). Seitdem: `pkill -9 -x verdict`
vor und nach jedem Lauf (exakter Prozessname, trifft weder Host noch Skript).

## 5. Was offen bleibt

- Harness-1/2-Frames (Ethernet, family 0, HDR-len 12) sind gegen echte
  Nachrichten falsch — Scratch außerhalb des Baums; die VM ist der
  maßgebliche Harness (BEFUNDE-bm12.md Residuen).
- Contention, Fuzzer, Wall-Clock: offen seit bm8.
- `bind` (`Adresse`) wirkt per 4er-Ausrichtung — notiert, unangetastet.
