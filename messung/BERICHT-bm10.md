# Report — lane bm10 (E2c verdict gating + driver decision chain)

## 1. What the lane did

Four files, all additive except the `entscheide` body rewire (`git diff`:
320 insertions, 60 deletions):

| file | change |
|---|---|
| `gab/verbindungen.gab` | +`suche_nur` (read-only lookup, 0 errors, costs 178/256) |
| `gab/entscheidung.gab` | verdict gating: `suche_nur` before the verdict, `suche_oder_lege_an` only after `NIMM_AN` (+`suche_nur` mirror) |
| `gab/pakete.gab` | +`setze_paket` (one-byte writer, owner's precedent `lege_empfang`) |
| `gab/lauf.gab` | +`behandle` (parse → copy → decide → verdict bytes), 7 mirrors, `strikt` counter, `WARTESCHLANGEN_NR` rename (Befund T-2) |

Two enemy findings closed, one transport chain built, five refusals filed
(`messung/BEFUNDE-bm10.md`). No hand-written C anywhere: the only C in the
lane's measurements is what `gabbro emit` wrote plus scratch harnesses in
`/tmp` (out of the tree, following BERICHT-bm9.md §4).

## 2. E2c is closed (verdict-gated connection table)

**Design.** `suche_nur` answers the stored state (0 frei/unbekannt, 1 NEU,
2 BESTEHEND, 3 SCHLIESSEND) with zero writes: no create, no
`treffer_pflegen`, no `Stand` counter. Canonicalization and hash stand line
for line as in `suche_oder_lege_an`. The decision calls it before the
verdict; `suche_oder_lege_an` (unchanged) runs only after `NIMM_AN` -- on
the fast path and after the rules alike. DROP and ABGEWIESEN perform zero
writes to `Verbindung` and `Stand`. A confirm refused by a full bucket
(answer 0) keeps the ACCEPT verdict the rules gave and surfaces through
`zaehle_voll` -- that flow's every packet walks the rules (stateless
fallback, still fail-closed, same semantics as the old bucket-full path).

**Checker words.**

```
gab/verbindungen.gab: 13 items, 0 errors, 0 hints
  M1 saw 722 expressions, 0 of them without a type (100 % coverage)
gab/entscheidung.gab: 30 items, 0 errors, 1 hints
  M1 saw 142 expressions, 7 of them without a type (95 % coverage)
```

The 1 hint is the standing E247 on `UHR_TICK` (bm8/bm9). Costs:
`suche_nur` computed 178, promised 256, slack 78; `suche_oder_lege_an`
419/512 and `treffer_pflegen` 39/48 unchanged. `entscheide` stays OFFEN
(K003 over the mirrors -- Befund T-5).

**Prototype identity.** All 15 mirror prototypes byte-identical to the
owners' emitted prototypes (14/14 from bm9 plus the new `suche_nur`):

```c
uint32_t suche_nur(uint32_t quelle, uint32_t ziel, uint32_t qport, uint32_t zport, uint32_t iprot);
```

**Behaviour (harness 1, bm9 method: per-file emits in one TU, pthread
`VSPERRE`, aborting exits, walk counter injected into a COPY of the emitted
`regeln.c` -- one added line, `diff`-proven).** Rules: ACCEPT TCP→:80 +
ACCEPT TCP-from-:80. Identical at -O0 and -O2:

```
P1   verdict=1 (want 1) walks=1 (want >0) ok
P2   verdict=1 (want 1) walks=1 (want >0) ok
P3   verdict=1 (want 1) walks=0 (want 0)  ok
E2a  verdict=0 (want 0) walks=1 (want >0) ok
E2b  verdict=0 (want 0) walks=1 (want >0) ok
E2c  verdict=0 (want 0) walks=1 (want >0) ok
konten gesamt=6 summe=6 ok
E2C GESCHLOSSEN
```

Read it as: P1 (SYN→:80) and its promoting reply P2 both walk the rules;
P3 fast-paths on the established flow; E2a (SYN→:81) DROP-walks and --
this is the repair -- creates nothing, so E2b (spoofed reply) DROP-walks
instead of promoting+ACCEPTing, and E2c (E2a again) DROP-walks on a table
with no entry. The bm9 AFTER-table ended at `E2b verdict=0 walks=1` with
E2c informational (`verdict=1 walks=0`); E2c now reads `verdict=0 walks=1`.
Price, stated in the source: two lock acquisitions per accepted packet;
reverse traffic on established flows still walks (F5).

## 3. The driver decision chain (`behandle`)

**Wiring.** `arbeite`'s byte-count arm narrows `v` to `0 .. 8192`
(`u32(v)` conversion, both shapes probed clean -- Befund T-1) and calls
`behandle(meldung)`: `suche_paket` (non-BEREIT → 0, no verdict, never a
guess) → copy loop (`gib_laenge`/`hole_nutzlast`/`setze_paket`, double
guard `i >= n` + `narrow i to 0 .. 1599`) → `entscheide(n, 0)` (faden 0,
one worker -- K-1) → `gib_kennung` re-read after the decision (V4) →
`baue_urteil(kennung, urteil, WARTESCHLANGEN_NR)`. Returns the verdict
length for the withheld `sendto`; 0 feeds the new `strikt` counter.
Oversize datagrams (> 8192) never reach the parse (counted as `verlust`).

Seven new mirrors (`suche_paket`, `gib_laenge`, `hole_nutzlast`,
`gib_kennung`, `baue_urteil`, `setze_paket`, `entscheide`), all
`effects { pure }` under the file's house convention (stated price: blind
M147 across these edges; staleness handled inside `entscheidung.gab`).
All 7 prototypes C-identical to the owners (modulo
`__attribute__((pure))` on owner definitions -- same precedent as bm7/bm9).
Deliberately unmirrored: `lege_empfang`, `netz_binden`/`netz_senden`, the
four config builders (Befund T-1).

**Checker words.**

```
gab/lauf.gab: 32 items, 0 errors, 2 hints
  M1 saw 178 expressions, 4 of them without a type (98 % coverage)
gab/pakete.gab: 14 items, 0 errors, 9 hints
```

The 2 lauf hints are the standing E247 on `LaufStand` (bm7). The 9th
pakete hint is new and correct: `entpacke` reads `Paket` with no guard,
and since this lane something (`setze_paket`) writes it -- same class.

**Emitted C at the receive site** (`emit gab/lauf.gab`, exit 0): the copy
loop lowers to `for(;;)` with `goto kopie_ende`; both narrows lower to
unsigned comparisons (`if (!(i <= 1599))`, `if (!(v <= 8192))` with `goto
runde_weiter` for the `next`); `u32(v)` lowers to `(uint32_t)(v)`; the
chain reads `suche_paket → gib_laenge → hole_nutzlast → setze_paket →
entscheide → gib_kennung → baue_urteil` in order. **At the send site
there is no C**: no `sendto` call is emitted anywhere in the program,
because no Gabbro expression can feed it (Befund T-1) -- the `gebaut`
bytes end in `Senden` and the emitted `arbeite` counts them.

**Behaviour (harness 2: all 8 units' emits in one TU, `main` deleted from
a COPY of the `lauf` emit, `Empfang` filled through the real
`lege_empfang`, verdict read through the real `hole_senden`).**
Hand-built 92-byte NFQUEUE message (type 768, id `0x12345678`, hook 3,
54-byte SYN→:80 payload). Identical at -O0 and -O2:

```
T1 nachricht=92              ok
T1 behandle=32               ok
T1 urteilsbytes ACCEPT+id    ok     (00..: 20 00 00 00 01 03 ... 00 00 00 01 12 34 56 78)
T1 kennung                   ok
T2 fremdtyp->0               ok     (type 769: strict, no verdict)
T3 behandle=32               ok
T3 urteilsbytes DROP+id      ok     (verdict word 00 00 00 00, id AA BB CC DD)
T4 baue_binden bytes         ok     (28 bytes, checked byte for byte)
KETTE GESCHLOSSEN
```

**Composition (multi-TU link, bm9 §4 method).** `cc -Wall -Wextra -Werror`
at -O0 and -O2 over the 8 emitted units + scratch stub: exit 0, no
undefined, no duplicates; `nm`: one `main`, `entscheide`, `suche_nur`,
`suche_paket`, `baue_urteil` each exactly once. `strace` on the linked
binary shows the brief's signature unchanged and healthy: `socket(16, 3,
12) = 3`, one 65536 anonymous mapping, `recvfrom(3, …)` parked -- startup
(socket, buffer, compiled-in rule load) runs for real; the queue has
nothing to deliver without root.

## 4. What ran without privileges, and what needs root

Ran (above): every builder's bytes, the strict parse (ready/foreign/empty
paths), the payload copy, both rule walks, verdict gating with counters,
the verdict bytes including big-endian id and word, the composed link,
the startup path to `recvfrom`. None of it needs privileges: all tables
are process memory, all messages hand-built.

Needs root, step by step (re-executable procedure, not quoted from a run):

```
unshare -rn                          # or a test machine with two veth ends
nft add table inet filter
nft add chain inet filter input '{ type filter hook input priority 0; policy accept; }'
nft add rule inet filter input queue num 0
./bau/brandmauer &                   # blocks in recvfrom (measured above)
curl --connect-timeout 2 http://<test-ip>/      # SYN→:80, expect ACCEPT + P1/P2/P3 walk pattern in a debugger read of the counters
curl --connect-timeout 2 http://<test-ip>:81/   # expect DROP, E2a/E2b/E2c pattern, strikt==0, verlust==0
nft flush chain inet filter input    # + kill -9 (no signal handling -- Befund L-5)
```

What root would show that is open today: the FIRST live verdict -- the
`sendto` transport does not exist in the program (T-1), so the queue would
fill and the kernel would start dropping (`verlust` rises, like
BERICHT-bm7.md §"Watch the worker"). The decision chain feeding that
verdict is the measured one above; the two transports are the missing
half, named with the checker's own codes.

## 5. Refusals (all verbatim in `messung/BEFUNDE-bm10.md`)

T-1 M127/M140 (no address-of, no table-for-pointer -- the transport wall);
T-2 `WARTESCHLANGE` redefinition (fixed by rename); T-3 N042 (no
Gabbro lock primitives); T-4 H022/K008 + C001 + invalid `void result` C
(no Gabbro exits); T-5 K003 (OFFEN costs); T-6 N042/N039 (`--unit` dead).
Working shapes recorded: u64→range conversion, `next` in `narrow`-`else`,
ranged `extern` results.

## 6. Costs

`behandle`, `arbeite`, `main`, `lade_grundregeln` OFFEN (T-5 -- the
grammar gives `syscall` no `costs` clause); the three `sonde_*` computed
0/4. `suche_nur` 178/256 is the only new promise. Last composed worst
case (91166 ops, BERICHT-bm8.md) is not re-composed here: with verdict
gating the per-packet path does up to two rule walks plus two lock
acquisitions, and a composed number would be measurement, not promise --
it was not re-measured in this lane.

## 7. What was not measured

- No live packet (no root, no queue -- §4 is a procedure, not a log).
- No contention: `VSPERRE` is a real mutex in both harnesses, but a single
  thread ran; tick loss, bucket-full under flood, `altere` cadence open
  since bm8.
- No fuzzer over `suche_paket`/`behandle` (three hand messages + six
  hand frames); hash-flooding and reload-under-load open since bm8/bm9.
- The shipped runtime (futex, no libc) and the `treiber/` link: `make` is
  red, `make pruefen` 8/8 green -- T-3/T-4 say why, and the Makefile was
  left as found rather than greened with forbidden C.
- Time is still packet-counted (`UHR_TICK` saturating); wall clock open
  since bm8 (F3).
