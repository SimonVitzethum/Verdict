# Befunde bm13 — Härtung (fail-closed verdicts, Ablauf, Routing)

Lane bm13 macht die Firewall vollständig im Sinne von: jedes gequecte Paket
mit bekannter Id bekommt ein explizites Urteil, die Tabelle läuft ab, Urteile
routen zur eigenen Queue. Alles in Gabbro. Drei Weigerungen mit den Worten
des Werkzeugs, eine gemessene Laufzeit-Falle, eine latente Fußangel.

## H-1 — K002: kein Voll-Scan unter dieser Wache (wörtlich)

```
error: [K002] gab/entscheidung.gab:346:15: the block holds `VSPERRE` for
90113 ops, the lock promises `held <= 1024 ops`
```

`altere` (90112, ganzer Tisch per `traverse`) in `locks VSPERRE` gerufen.
Die Schranke steht in `gab/verbindungen.gab` UND im Spiegel in
`gab/entscheidung.gab` — beide nennen 1024 (SPRACHE.md §9.3). Antwort der
Lane: kein Anheben der Schranke (sie trägt die Latenz aller Kerne), sondern
`altere_fenster` — 16 Plätze ab `start` in `retry`-Form (wie `suche_paket`:
prüft, trägt ein Total, emittiert). Takt in `entscheide`: jedes 1024. Paket,
Fenster `(k % 256) * 16`, Vollumlauf alle 262144 Pakete. Was abläuft, ist
dasselbe (älter als ABLAUF=300, nie früh) — grob verspaetet, nie irrig.

## H-2 — M101/M104: die Bereichsrechnung sieht `k - 1` nicht (wörtlich)

```
error: [M104] ... `u32 in 0 .. 4194303 - u8 in 1 .. 1` leaves the width ...
error: [M101] ... binding requires `u32`, the value has `u32 in -32 .. 134217664`
```

`(k - 1) * 32` für den Fensterstart: `k` ist zur Laufzeit immer ≥ 1 (Takt
feuert nur bei `jetzt % 1024 == 0`, `jetzt` ≥ 1 per `tick`), aber der Typ
weiß es nicht — kein Wrap, sondern Compile-Fehler. Antwort: subtraktionsfrei
formuliert (`(k % 256) * 16`, alle Werte 0..4080, beweisbar im Typ). Lehre in
einem Satz: wer gegen die Bereichsrechnung arbeitet, verliert; wer ihre Form
wählt (`%` dann `*`), gewinnt.

## H-3 — die Retry-Schranke gilt zur Laufzeit (gemessener Abort)

Erstfassung mit 32er-Fenster: `kosten` 967/1000 (statisch grün), im Harness
beim ersten Takt (Paket 1024) `SIGABRT` durch `verbindung_aufgegeben` —
der tatsächliche Retry-Verbrauch lag über `bounded 960`. Statik und Laufzeit
messen hier verschiedene Dinge: das Total deckt, die Schranke tötet. Antwort:
16er-Fenster (`bounded 576`, gemessen 583/640). Das 32er-Fenster (~1088)
passt grundsätzlich nicht unter `held <= 1024` — die Schranke hat recht.

## H-4 — STALL statt Schweigen war auch ein Testfehler (Verfahren)

`vm/gast/vm-test.sh` tötete per `kill $SPid` nur das `strace`, nicht den
getracten verdict: die Waise hielt Queue 0, der Folgelauf starb EPERM → 112
(erneutes Binden ist keine Berechtigung). Seitdem `pkill -9 -x verdict` vor
und nach jedem Lauf. Kein Sprach-Befund — aber ohne ihn wäre jede
Folgemessung falsch gewesen.

## H-5 — latent: Urteilswort 2 heißt NF_QUEUE (notiert, nicht gerührt)

`setze_regel` nimmt `urteil in 0 .. 2`; Wort 2 auf dem Draht liest der Kernel
als NF_QUEUE (erneutes Einreihen), nicht als REJECT. Die einkompilierten
Regeln laden nur ACCEPT; ohne Regellader (Befund L-2) ist kein Wort 2
erreichbar. Sobald Regeln zur Laufzeit ladbar werden, muss Wort 2 entweder
ein RST/ICMP-Treiber werden (ARCHITEKTUR.md sieht ihn vor) oder aus dem
Wertebereich fallen — bis dahin steht es hier.

## Residuen

- Fremdtypen ohne Id bleiben still (Kernel-Timeout-Drop, `strikt` zählt) —
  ohne Id gibt es kein adressierbares Urteil; das ist Physik, kein Mangel.
- TEIL-DROPs zählen in `strikt` (LaufStand), nicht in VERWORFEN — die
  Zähler-Invariante GESAMT==... gilt pro `entscheide`-Aufruf, TEIL läuft
  daran vorbei (bewusst, dokumentiert).
- `altere` (Voll-Scan) bleibt als Eigentümer-API, ruft aber niemand — der
  Takt nutzt `altere_fenster`.
- Contention, Fuzzer, Wall-Clock: offen seit bm8.
