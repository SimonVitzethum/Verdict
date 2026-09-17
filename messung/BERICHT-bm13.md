# Report — lane bm13 (vollständige sichere Firewall: Urteile, Ablauf, Routing)

Tool: `./werkzeug/gabbro` wie bm12. `make pruefen`: 9/9 grün. Kein C im Baum;
einziger C-Text: `gabbro emit` plus 5-Symbol-Scratch-Stub (`vm/baue-binary.sh`
erzeugt ihn, nie committet; Makefile-NOTE auf 5 aktualisiert).

## 1. Was die Lane tat

| Änderung | Datei(en) |
|---|---|
| `TEIL` (6): Id bekannt, Rest unbrauchbar → explizites DROP statt Schweigen; `ergebnis_teil`-Helfer; Familie 2\|10 (IPv6 parst, Dekoder verwirft per Urteil) | `netzverbindung` |
| `behandle`: TEIL-Zweig (DROP mit `gib_kennung`), Urteile routen per `gib_reihung` (eigene Queue) statt Konstanten | `lauf` (+ `gib_reihung`-Spiegel 4 ops, TEIL-Konstante) |
| `altere_fenster` (16 Plätze, `retry`, 583/640) + `verbindung_aufgegeben`-Wache | `verbindungen` |
| Ablauf-Takt in `entscheide` (jedes 1024. Paket, Fenster rotiert, 262144 Vollumlauf) + `altere_fenster`-Spiegel 640 ops | `entscheidung` |
| VM-Hygiene (`pkill -x verdict`), Harness um Fall E erweitert | `vm/gast/vm-test.sh`, `bau/scratch/harness-bm13.c` (Scratch) |
| bm13-Zusatz (TEIL, Takt, Routing) | `ARCHITEKTUR.md` |

## 2. Prüf-Worte

`make pruefen` 9/9. `kosten`: `altere_fenster` 583/640 (Block 584 ≤ 1024 —
K002 erfüllt), `ergebnis_teil` 11/20, `suche_paket` 300136/301000,
`entpacke` 175/200. Neue E247: stehende Klasse.

## 3. Gemessen: Harness 15/15, VM grün

Harness bm13 (alle Units eine TU, Scratch in `bau/`): golden ACCEPT mit Id,
IPv6-DROP mit Id, TEIL-DROP (HDR ohne Payload) mit Id, Fremdtyp-Stille —
plus Fall E: 262200 Pakete, Fluss Y danach `abgelaufen ≥ 1`, Fluss X weiter
ACCEPT mit Urteil 1. `HARNESS-BM13 GESCHLOSSEN`, Exit 0.

VM (Debian 13, QEMU/KVM, Binary aus `vm/baue-binary.sh`):

```
4 × ACK error=0, Queue gebunden
curl :80        → http=200 in ~15 ms (ACCEPT, kompletter Flow)
curl :81        → Timeout (DROP)
curl -g [::1]/  → Timeout, 5 × Urteilswort 0 (IPv6-DROP explizit)
Dauerlauf 3 × :80 → 200, Prozess gesund
nobody → Exit 112 (fail-closed mit neuem Code)
```

Jedes gequecte Paket mit bekannter Id bekommt seit bm13 ein Urteil auf dem
Draht; was keine Id trägt, zählt `strikt` und fällt ins Kernel-Timeout.

## 4. Was „vollständig" hier heißt — und was nicht

Vollständig: explizite Urteile (kein Schweigen mit Id), IPv4+IPv6-Dekoderpfad
mit Urteil, Tabellenablauf mit Takt, Queue-Routing, Dauerlauf, fail-closed
ohne Rechte. Draußen bleiben (Sprachmauern, keine Ausreden): Threads/K-1
(ein Worker, Queue 0), Regellader/L-2 (einkompiliert), Signale/L-5
(Zählerschwelle), Wort-2-REJECT (H-5), Wall-Clock/F3 (Paket-Takt). Das ist
der Stand, an dem jede weitere Lane ansetzen kann.
