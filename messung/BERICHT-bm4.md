# Report lane bm4 — `gab/zaehler.gab`: concurrent packet counters

## 1. What the module does

`gab/zaehler.gab` (`module brandmauer::zaehler`, 5136 lines, 535 items) owns all
firewall statistics. Every worker thread counts through it; no other lane
touches counters.

State: 7 scalar atomics plus 256 per-rule atomics, all `u32 relaxed`:

| counter | counts |
|---|---|
| `GESAMT` | packets decided (rises with every `zaehle_urteil`) |
| `VERWORFEN` / `AKZEPTIERT` / `ABGEWIESEN` | verdicts DROP (0) / ACCEPT (1) / REJECT (2) |
| `FEHLFORM` | malformed packets (`zaehle_fehl`) |
| `VOLL` | connection-table-full events (`zaehle_voll`) |
| `REGEL000 .. REGEL255` | per-rule hits (`zaehle_regel`) |
| `REGELSUMME` | total rule hits (rises with every `zaehle_regel`) |

API (all `pub impl`):

- `zaehle_urteil(u : u32 in 0 .. 2)` — verdict counter **and** `GESAMT`, so
  `GESAMT == VERWORFEN + AKZEPTIERT + ABGEWIESEN (mod 2^32)` by construction.
- `zaehle_regel(r : u32 in 0 .. 255)` — rule counter **and** `REGELSUMME`.
- `zaehle_fehl()`, `zaehle_voll()` — the two event counters.
- `lies_zaehler(welcher : u32 in 0 .. 15) -> u32` — 0 GESAMT, 1 VERWORFEN,
  2 AKZEPTIERT, 3 ABGEWIESEN, 4 FEHLFORM, 5 VOLL, 6 REGELSUMME, 7..15 reserved (0).
- `lies_regel_treffer(r : u32 in 0 .. 255) -> u32` — the per-rule value (16
  addresses cannot name 256 rules, hence the second reader).

Design decisions, each with its reason in the file header: **atomics, never a
lock** (a counter that loses increments is an operator-visible bug); **relaxed**
— counters are payload-free statistics, no pairing is owed, losslessness comes
from the CAS loop, not the order; **wrapping** at 2^32, SNMP-style (a saturating
counter hides traffic once full); **263 private increment helpers** returning
the pre-increment value (see §4, last row — the return exists for the C
compiler); **flat** 256-way if-dispatch (the parser refuses nesting past 32,
P038); accounting discipline stated in the header (one `zaehle_urteil` per
packet; `zaehle_fehl`/`voll`/`regel` never touch `GESAMT`).

## 2. What the checker said

Final run, verbatim tail:

```text
gab/zaehler.gab: 535 items, 0 errors, 526 hints
  M1 saw 4232 expressions, 0 of them without a type (100 % coverage)

Not checked in this run: 9 passes -- 0 open, 9 CARRIED (the rest is NAMED), 0 only partial
  2 D1/D2, 4 M3, 5 M2, 12 Sperren, 11 Phasen, 7 Paarung, 8 effects, 10 Gruppe, 9 costs
  register 4dd17209 -- the FULL text with `gabbro pruefe --paesse` or `gabbro paesse`
  it is a property of this BINARY, not of the file just checked -- and it did not shrink, it moved
```

All 526 hints are one hint, sampled (full list is 526 repetitions of it):

```text
hint: [E247] gab/zaehler.gab:…: `R000` is read by the body of `ink_r000` but no signature lock guarding it is held, and some function writes it
      = the footprint carries what the contract saw: every written carrier wants a `requires Held(L)` guard over a `lock L protects` line, not merely a `reads` or `writes` entry in `effects`
```

`E247` is a hint, not a refusal, and for atomics it is correctly ignored (see
`BEFUNDE-bm4.md`, H1): the race discipline for an atomic global is the
machine's, and the lane brief mandates atomics instead of a lock.

Costs (`gabbro kosten`): every promise equals the computed value, slack 0
everywhere — 263 increment helpers at 5/5, `folge` 2/2, `zaehle_urteil` 14/14,
`zaehle_regel` 1797/1797, `zaehle_fehl`/`zaehle_voll` 5/5, `lies_zaehler`
32/32, `lies_regel_treffer` 1538/1538; "270 bodies computed, 0 open,
0 derived."

## 3. What the emitted C is — per atomic operation, with the C beside it

`./werkzeug/gabbro emit gab/zaehler.gab` exits 0 (9824 lines of C). The
emitted C compiles under `cc -std=c11 -Wall -Wextra -Werror -c` at both `-O0`
and `-O2`, both exit 0. There is **no `atomic_fetch_add` anywhere**: every
increment is a bounded compare-exchange loop, exactly as the Gabbro tree
reported.

| Gabbro | emitted C (C11 function + order) |
|---|---|
| `pub atomic GESAMT : u32 relaxed;` (×263) | `_Atomic uint32_t GESAMT;` — one object per counter, file scope |
| bare read `let n : u32 = GESAMT;` | `uint32_t n = atomic_load_explicit(&GESAMT, memory_order_relaxed);` |
| wrap step `return x +% 1;` in `folge(x : u32)` | `return (uint32_t)(((uint32_t)(x) + (uint32_t)(1)));` in a `__attribute__((const))` helper |
| increment `Z exchange update(t) bounded 64 ops on_exceeded zaehler_streit { return folge(t); } publishes nothing;` | initial `atomic_load_explicit(&Z, memory_order_relaxed)`, then `for(;;)` recompute + `atomic_compare_exchange_weak_explicit(&Z, &_cx1, _cn1, memory_order_relaxed, memory_order_relaxed)`; on 64 lost races call `zaehler_streit()` (`_Noreturn`, `extern`, defined outside Gabbro). Full body pasted below |
| discarded call `ink_r007();` | `(void)ink_r007();` — the emitter adds the `(void)` itself |
| dispatch `if r == 7 { ink_r007(); }` (×256) | `if (r == 7) { (void)ink_r007(); }` — straight-line C, no jump table |

One full increment body, as emitted (`ink_gesamt`, all 263 are this shape with
their own counter):

```c
static uint32_t ink_gesamt(void) {
    /* GESAMT exchange update(t) -- a bounded CAS loop, and bounded is
     * the point: SPRACHE.md forbids an unbounded one. The body computes
     * old -> new and is pure, so re-running it on a lost race is free of
     * consequence. `zaehler_streit` is the exit at 64 passes. */
    uint32_t alt_gesamt;
    {
        uint32_t _ci1 = 0;
        uint32_t _cx1 = atomic_load_explicit(&GESAMT, memory_order_relaxed);
        for (;;) {
            uint32_t _cn1;
            {
                const uint32_t t = _cx1;
                _cn1 = folge(t); goto _cn1_fertig;
                _cn1_fertig: ;
            }
            if (atomic_compare_exchange_weak_explicit(
                    &GESAMT, &_cx1, _cn1, memory_order_relaxed, memory_order_relaxed)) break;
            if (_ci1 >= (uint32_t)(64)) { zaehler_streit(); }
            _ci1++;
        }
        alt_gesamt = _cx1;
    }
    return alt_gesamt;
}
```

Plain statement of the measurement: increments are
`atomic_compare_exchange_weak_explicit` with `memory_order_relaxed` for both
success and failure orders, wrapped in a 64-pass bounded loop whose overrun
diverges; reads are `atomic_load_explicit(…, memory_order_relaxed)`; the
declared order is `relaxed` everywhere and the emitter honors it — no
promotion to `seq_cst`, no fence emitted. Correctness under concurrency comes
from retry-until-CAS-wins (each pass re-reads the current value into `_cx1`),
not from the order.

## 4. What was measured, not assumed — the threaded test

`.tmp/bm4/test.c` (scratch, not committed) links the emitted C against a
harness: `zaehler_streit` stubbed to print `STREIT` and abort (it must exist at
link; it must never run), then single-threaded accounting plus 4 pthreads ×
200 000 `zaehle_urteil(1)` + `zaehle_regel(7)` hammering the *same* counters.
Result, identical at `-O0` and `-O2`:

```text
gesamt=3 (want 3) verworfen=1 (1) akzeptiert=1 (1) abgewiesen=1 (1)
fehlform=2 (want 2) voll=1 (1) regelsumme=2 (want 2)
regel0=1 (1) regel255=1 (1) regel7=0 (0) reserviert=0 (0)
conc: gesamt+=800000 (want 800000) akzeptiert+=800000 (want 800000)
conc: regelsumme+=800000 (want 800000) regel7+=800000 (want 800000)
ALL OK
```

800 000 / 800 000 on four counters, zero lost increments, `STREIT` never
printed. That is the lane's core claim as a run, not a reading.

## 5. What could NOT be written, and why

- **One atomic array** (`atomic REGEL : [u32; 256]`): checker accepts the
  indexed update, emitter refuses with `C001` — so 256 scalars + dispatch
  (5136 lines instead of ~60). `BEFUNDE-bm4.md` F2/F3.
- **`accumulates`** for any counter: `pub` is ungrammatical on it (`P041`)
  while `N038` demands `pub` for anything a `pub` function names — F6.
- **Unbounded or binder-local increments**: `bounded`/`on_exceeded` are
  emitter-mandatory (`C001`, F4); `+%` must live in a parameter-typed helper
  (`C001`, F5). The 64-race abort is carried openly, not hidden.
- **Nested 256-dispatch / integer `match`**: `P038` caps nesting at 32 and
  `match` has no integer arms (F7/F8) — hence flat sequential ifs, with the
  measured cost (1797 ops for `zaehle_regel`).

Nothing was weakened to please the checker: wrapping, relaxed ordering, the
abort exit and the flat dispatch are all stated in the module header as design
with reasons.

## 6. What was not measured

- **Weak memory architectures**: all C shapes verified on x86_64 only
  (SYNTAX.md §11 bounds its own table the same way). On ARM/AArch64 the
  `relaxed` CAS loop is still lossless, but no run here shows it.
- **The contention abort**: `zaehler_streit` never fired in 3.2 M colliding
  increments; the "64 consecutive lost races" case is reasoned about, not
  triggered. A test that forces it needs scheduler control this lane does not have.
- **Wrap behavior at 2^32**: by construction (`+%`), not by a 4-billion-iteration run.
- **Integration**: `entscheidung.gab` / `lauf.gab` are other lanes' files; the
  call shapes they need (`zaehle_urteil(0..2)` etc.) are fixed here, but no
  cross-file `--unit` check or driver printout was run — there is no driver in
  this clone yet.
- **Performance**: no packets-per-second comparison of CAS-loop counters vs.
  per-CPU cells; the CAS design was chosen for exact API fit (no worker index
  in the required signatures), not for speed.
