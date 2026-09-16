# Report — lane bm9 (`gab/entscheidung.gab` + Kopf accessors, F5 repair)

## 1. What the module does

`gab/entscheidung.gab` (`module brandmauer::entscheidung`) is the
per-packet decision wiring, second generation: it owns `entscheide`
(the one function the driver calls per packet), the `UHR_TICK` clock
atomic with `tick`, the rule-hit lookup `treffer_index` (now a counted
`forever` loop), and the checker-shaped `zaehle_weiter`. It owns no
other table and duplicates none. Every foreign name arrives through an
`extern fn` mirror -- or, for the connection lock, a `lock` mirror --
with a C-identical prototype (the lane-bm7 shape). The eight units
compose in C: per-module emit, one `cc` link.

The policy, in wire order (the order IS the firewall): decode (malformed
→ double-counted DROP, no rules for unread packets); tuple via the new
Kopf accessors + local flow direction; connection lookup under `VSPERRE`
(one table operation in the block); repaired fast path (ACCEPT without a
rule walk ONLY for a forward packet answering ESTABLISHED); otherwise
the rules with fail-closed default DROP (bucket-full likewise, after
`zaehle_voll`); counting (verdict always, rule hit when matched,
`GESAMT == VERWORFEN + AKZEPTIERT + ABGEWIESEN` by construction).

`gab/pakete.gab` grew exactly the accessors the decision needs and
nothing else: eight `pub impl fn gib_kopf_<feld>()` (lines 154–219:
`gueltig`, `proto`, `quelle`, `ziel`, `qport`, `zport`, `flaggen`,
`laenge`), each `effects { reads Kopf, reads Kopf.slots }`,
`costs <= 4 ops`, each returning one slot field with its declared
range. The decoding above them is untouched (`git diff`: +66 lines,
−0). The decision mirrors the six it reads (`gueltig` arrives as
`entpacke`'s answer; `laenge` never reaches the verdict).

**Accessor shape and why.** One `pub impl fn` per field, not one
indexed reader. The fields carry different ranges (`0..1`, `0..255`,
`u32`, `0..65535`); per-field results keep those ranges at the six call
sites with no `narrow` and no magic index numbers, and each mirror is a
three-line function with a checkable contract. An indexed reader would
answer plain `u32` (ranges lost), dispatch over eight arms (cost and
the `match`-without-wildcard gap of BEFUNDE-bm4.md), and still need one
mirror -- eight prototypes against one is no saving once the readers
themselves are three lines each.

## 2. What the checker said (verbatim)

Final gate, both touched files:

```
$ ./werkzeug/gabbro pruefe gab/entscheidung.gab
hint: [E247] gab/entscheidung.gab:171:19: `UHR_TICK` is read by the body of `tick` but no signature lock guarding it is held, and some function writes it
  168 |     let t : u32 = UHR_TICK;
      |                   ^^^^^^^^
  = the footprint carries what the contract saw: every written carrier wants a `requires Held(L)` guard over a `lock L protects` line, not merely a `reads` or `writes` entry in `effects`
  = carriers no function writes need no guard; device registers read bare carry none either, until the declaration names their carriers
gab/entscheidung.gab: 29 items, 0 errors, 1 hints
  M1 saw 142 expressions, 7 of them without a type (95 % coverage)
```

```
$ ./werkzeug/gabbro pruefe gab/pakete.gab
gab/pakete.gab: 13 items, 0 errors, 8 hints
  M1 saw 296 expressions, 0 of them without a type (100 % coverage)
```

The 1 hint is the standing atomic-discipline hint (bm8's, kept). The 8
hints are one E247 per new accessor (no-lock discipline, same class as
the regeln/lauf lanes' standing hints). The 7 untyped expressions are
bm8's 7 statement-position void counter calls. All eight modules lone-
checked in the same run: regeln 13/0/3, verbindungen 12/0/0, zaehler
535/0/526, lauf 22/0/2, netzverbindung 57/0/11, systemrufe 56/0/0 --
the hint counts of the untouched files are their lanes', not mine.

Costs (`gabbro kosten gab/entscheidung.gab`):

```
-- site	computed	promised	slack
tick	10	10	0
sonde_treffer_suche	0	0	0 (derived)
treffer_index	OFFEN	--	-- a `forever` loop has no total cost -- its promise is `per_pass`, not `costs`
zaehle_weiter	OFFEN	--	-- the call to `zaehle_urteil` declares no `costs`
entscheide	OFFEN	--	-- the call to `zaehle_urteil` declares no `costs`
-- 2 bodies computed, 3 open, 0 derived.
```

Three OFFEN sites: the price of the mirror pattern (a `costs` promise
over an `extern` body is K003 -- BEFUNDE-bm8.md F1). Same split as
`gab/lauf.gab`, which carries no `costs` line anywhere (BEFUNDE-bm5.md
N-2). The 91166-ops worst case stands in BERICHT-bm8.md as the last
composed measurement.

Refusals met on the road (codes, messages, shapes: all in
`messung/BEFUNDE-bm9.md`): the inherited 25-error gate (6×M119, 6×M147,
9×H021, 3×K003, 1×H016); E006+H016 for a `locks` block over an
undeclared lock; N038 for the `pub` lock mirror; and the codeless one --
`traverse` over an unknown table checks silent (0/0) and emits C that
`cc` refuses (`'Regel' undeclared`), which is why `treffer_index` is a
counted `forever` loop now.

## 3. What the emitted C looks like at the interesting places

`emit` exits 0 for all eight modules; each emitted C compiles under
`cc -std=c11 -Wall -Wextra -Werror -c` at -O0 and -O2 (16 silent
compiles). The decision unit emits 14 prototypes plus its own items:

```c
uint32_t entpacke(uint32_t laenge);
uint32_t gib_kopf_proto(void);
/* ... quelle, ziel, qport, zport, flaggen ... */
uint32_t passt(uint32_t r, uint32_t proto, uint32_t quelle, uint32_t ziel, uint32_t qport, uint32_t zport, uint32_t flaggen);
uint32_t entscheide_regeln(uint32_t proto, uint32_t quelle, uint32_t ziel, uint32_t qport, uint32_t zport, uint32_t flaggen);
void VSPERRE_nimm(void);
void VSPERRE_gib(void);
uint32_t suche_oder_lege_an(uint32_t quelle, uint32_t ziel, uint32_t qport, uint32_t zport, uint32_t iprot, uint32_t flaggen, uint32_t jetzt);
void zaehle_urteil(uint32_t u);
void zaehle_regel(uint32_t r);
void zaehle_fehl(void);
void zaehle_voll(void);
_Atomic uint32_t UHR_TICK;
```

Prototype identity (the composition check that replaces `--unit`):
all 14 mirror prototypes are byte-identical to the owners' emitted
prototypes (`entpacke`, six `gib_kopf_*`, `passt`,
`entscheide_regeln`, `suche_oder_lege_an`, `zaehle_urteil`,
`zaehle_regel`, `zaehle_fehl`, `zaehle_voll` -- 14/14 IDENTICAL,
diffed mechanically). The `locks` block lowers to
`VSPERRE_nimm(); { zustand = suche_oder_lege_an(...); } VSPERRE_gib();`
-- no early return inside, release on all paths. `tick` lowers to
relaxed load / guarded store / re-read. `treffer_index` lowers to a
plain `for(;;)` with `goto suche_ende` on hit or on `k >= 256`, and
`passt(k, ...)` after the guard -- the guard is the index proof the
`u32` mirror parameter cannot carry. The accessors lower to single
slot loads (`return Kopf_speicher.slots[0].proto;` etc., pure).
`UHR_TICK` is defined exactly once (in the decision unit); every other
carrier exactly once in its owner -- nothing is defined twice, so the
BEFUNDE-bm8.md split-brain warning does not apply to this
construction.

## 4. The link (the deliverable -- eight units, one program)

Exact command (per-module emits in `.tmp/bm9/emit-final/`, runtime stub
`.tmp/bm9/laufzeit-stub.c`):

```
cc -std=c11 -Wall -Wextra -Werror -O0 -pthread \
  pakete.c regeln.c verbindungen.c zaehler.c entscheidung.c \
  lauf.c netzverbindung.c systemrufe.c laufzeit-stub.c \
  -o brandmauer-O0
cc -std=c11 -Wall -Wextra -Werror -O2 -pthread \
  ... (same inputs) ... -o brandmauer-O2
```

Output at both levels: empty; exit 0. Both binaries link (no
undefined, no duplicate symbols); `nm` shows one `main` (lauf),
`entscheide`, `entpacke`, `entscheide_regeln`, `suche_oder_lege_an`,
`VSPERRE_nimm` each exactly once.

The stub defines what the emitter declares but never defines -- the
lock primitives and the four diverging exits -- following
`muster/start-muster.c` ("a lock is a runtime object, never program
text", "checked by `cc`, not by care"): a pthread mutex for `VSPERRE`
plus aborting `zaehler_streit`, `netz_streit`, `lauf_aufgegeben`,
`treffer_aufgegeben`. Hosted measurement shape (pthread + libc), same
kind as the muster driver. The shipped runtime (futex-based, no libc)
is treiber-lane work: no `treiber/` dir exists in this clone although
the Makefile already links `treiber/*.c`. The stub is scratch
(`.tmp/`, not committed); its content stands in §4 of this report so
the link is reproducible.

## 5. The F5 repair, with before/after behaviour

Setup (scratch, firewall sources untouched): HEAD five-file unit emit
vs repaired per-file emits, each in a single-TU harness feeding
hand-built Ethernet/IPv4/TCP frames, with a rule-walk counter injected
into a COPY of the emitted C (one added line,
`bm9_walk_note();` -- both diffs prove it). Rules: ACCEPT TCP→:80 plus
ACCEPT TCP-from-:80 (a bidirectionally allowed flow, so establishment
is reachable now that the promoting reply must pass the rules);
default DROP.

BEFORE (the hole, identical at -O0 and -O2):

```
P1       verdict=1 (want 1) walks=1 (want 1) ok
P2       verdict=1 (want 1) walks=0 (want 0) ok
P3       verdict=1 (want 1) walks=0 (want 0) ok
E2a      verdict=0 (want 0) walks=1 (want 1) ok
E2b      verdict=1 (want 1) walks=0 (want 0) ok
E2c      verdict=1 walks=0 (informativ: Fluss war vor diesem Paket ESTABLISHED)
konten   gesamt=6 summe=6 ok
```

AFTER (the repair, identical at -O0 and -O2):

```
P1       verdict=1 (want 1) walks=1 (want 1) ok
P2       verdict=1 (want 1) walks=1 (want 1) ok
P3       verdict=1 (want 1) walks=0 (want 0) ok
E2a      verdict=0 (want 0) walks=1 (want 1) ok
E2b      verdict=0 (want 0) walks=1 (want 1) ok
E2c      verdict=1 walks=0 (informativ: Fluss war vor diesem Paket ESTABLISHED)
konten   gesamt=6 summe=6 ok
```

Read it as: the NEW packet (P1) and its promoting reply (P2) both walk
the rules; the established flow's third packet (P3) takes the fast
path; the E2 recipe (SYN to a dropped port + spoofed reply) now ends in
a walked DROP instead of an unwalked ACCEPT. The repair is the fast-path
condition `zustand == BESTEHEND && richtung == 0`, where `richtung`
mirrors the ARCHITEKTUR.md canonicalization line for line -- exact
because a forward packet answering ESTABLISHED was ESTABLISHED before
this packet (read `treffer_pflegen`). Price, measured: reverse traffic
on established flows pays the walk (P2's walk is that price, fail-
closed direction).

What the repair does NOT fix (E2c, both builds): a DROPPed packet
still moves the connection table -- E2b's DROP leaves the flow
ESTABLISHED, and the next forward packet fast-paths (`verdict=1
walks=0`) on a flow that never saw an ACCEPT. Undoing that wants a
verdict-gated lookup or a pre-transition answer -- both are
`gab/verbindungen.gab` signature changes, another lane's file. E2c is
the regression test for that next repair.

## 6. What I could NOT write and why

- **Composed `costs` promises.** K003 over `extern` bodies; three
  OFFEN sites. The number last composed (91166) is measurement, not
  promise.
- **`traverse` over the rule table.** Emits uncompilable C against an
  unknown table (BEFUNDE-bm9.md B-2); the counted `forever` loop is
  the honest spelling (same per-pass bound class as lauf's loops).
- **Verdict-gated table updates.** See E2c above -- owned elsewhere.
- **Wall clock, per-thread buffers, one-walk counting.** Inherited
  from bm8 (F3/F4/F6), kept as-is, documented there.
- **The shipped runtime.** Lock + exits are stubbed hosted; the
  futex/no-libc half belongs to the treiber lane.

Nothing was weakened to please the checker without saying so: the
`u32` index parameter, the lock mirror, the OFFEN costs, the E2c
residual and the hosted stub are each stated with their reason and
their price.

## 7. What I did not measure

- **Multithreaded behaviour.** The link is single-threaded by
  construction (lauf lane: one worker, K-1). `VSPERRE` is a real mutex
  in the harness, but no two threads ever contend in any run above;
  `UHR_TICK` loss under contention, bucket-full behaviour under flood,
  and the `altere` cadence (who sweeps, how often -- uncalled on the
  packet path) are unmeasured, same as bm8's open items.
- **Time calibration.** Expiry is still packet-counted (300 unobserved
  packets, not seconds); the flood/idle skews of BEFUNDE-bm8.md F3
  stand.
- **Adversarial traffic.** Five crafted frames plus one informational;
  no fuzzer, no hash-flooding, no rule-reload-under-load (the loader-
  before-workers discipline is assumed by both walks, as in bm8).
- **The deployed binary's behaviour.** The linked `brandmauer-O0/O2`
  were linked, not run: `main` needs a netlink socket (root) and the
  shipped runtime does not exist yet. All behaviour above comes from
  the harness builds, which share the exact firewall object code
  (same emits, same flags) minus the driver loop.
