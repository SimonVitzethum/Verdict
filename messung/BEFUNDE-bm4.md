# Findings lane bm4 (counters) — compiler refusals met while writing `gab/zaehler.gab`

Every entry is something the tool actually said. Each entry names the code, the
verbatim message (shortened only where marked), the source shape that produced
it, and how the module deals with it. Nothing below was worked around silently:
the resolutions stand in `gab/zaehler.gab` and in `BERICHT-bm4.md`.

## F1 — `N038`: an exported function must not name a non-`pub` carrier in `effects`

Shape:

```gabbro
atomic Z : u32 relaxed;
pub impl fn hoch()
    effects { reads Z, writes Z }
```

Tool (`./werkzeug/gabbro pruefe`):

```text
error: [N038] .tmp/bm4/v1.gab:11:21: `hoch` is exported and names `Z`, which is not -- the interface would point at something that does not travel
```

Resolution: all 263 atomics are declared `pub atomic`. Routine, but it combines
with F6 into a hard wall.

## F2 — `N271`: an `atomic` is a scalar; a bare indexed read is refused

Shape:

```gabbro
pub atomic REGEL : [u32; 256] relaxed;
...
    let n : u32 = REGEL[r];   -- r : u32 in 0 .. 255
```

Tool:

```text
error: [N271] .tmp/bm4/v5.gab:24:19: `REGEL` is an `atomic`, a scalar -- `REGEL[…]` names no element or field
```

Note the asymmetry, measured not assumed: the *same* file's
`REGEL[r] exchange update(t) …` checked clean (0 errors). The checker models an
indexed-atomic update; only the plain indexed read is refused here. What kills
the array anyway is F3.

## F3 — `C001`: no lowering for an atomic array (the expensive one)

Shape: `pub atomic REGEL : [u32; 256] relaxed;` plus an indexed exchange update
(which checks clean, see F2).

Tool (`./werkzeug/gabbro emit`):

```text
error: [C001] .tmp/bm4/v6.gab:2:5: no lowering: `atomic` of an unresolvable type
    2 | pub atomic REGEL : [u32; 256] relaxed;
      |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      = the emitter refuses by name instead of emitting something plausible -- a generator that guesses undoes every pass in front of it
error: [C001] .tmp/bm4/v6.gab:14:5: no lowering: `exchange` on something that is not a declared `atomic` -- without a declaration there is no memory ordering, and choosing one would mean inventing it
```

Consequence: per-rule counters are 256 scalar atomics (`REGEL000 .. REGEL255`)
with if/else dispatch, not one array. The module is 5137 lines because of this
finding, not because counting needs it. If the emitter ever learns atomic
arrays, this module collapses to ~60 lines plus the readers.

## F4 — `C001`: `exchange update` without `bounded … on_exceeded …` has no lowering

Shape (checks clean under `pruefe`, 0 errors):

```gabbro
    let alt : u32 = Z exchange update(t)
    { return t; } publishes nothing;
```

Tool (`emit`):

```text
error: [C001] .tmp/bm4/r1.gab:8:5: no lowering: `exchange update(v) { … }` without `bounded … ops on_exceeded …` -- SPRACHE.md lowers it to a BOUNDED CAS loop, and an unbounded one is exactly what this language forbids. The two clauses are the same ones a `retry` carries, and for the same reason
```

Resolution: every one of the 263 increments carries `bounded 64 ops` and
`on_exceeded zaehler_streit` (`extern … -> never effects { diverges }`). This is
SPRACHE.md «C4b» as an emitter refusal. The 64-race abort is documented in the
module header as the mandated price of boundedness.

## F5 — `C001`: wrapping `+%` over the exchange binder (or any local) is refused at emit

Shape (checks clean under `pruefe`, 0 errors):

```gabbro
    { return t +% 1; } publishes nothing;
```

Tool (`emit`):

```text
error: [C001] .tmp/bm4/r2.gab:11:14: no lowering: wrapping `+%` over operands whose exact ranges cannot be read off their declarations -- both sides need an exact unsigned range `0 .. 2^N - 1` on one storage width
```

This is the refusal `muster/sperre-muster.gab` warns about ("a parameter (not a
`let` local and not an `exchange` binder) is what the emitter reads the exact
range off"). Resolution: the wrap step lives in `folge(x : u32) -> u32`
(`return x +% 1;`), called from every update body as `{ return folge(t); }`.
It emits `(uint32_t)(((uint32_t)(x) + (uint32_t)(1)))`.

## F6 — `P041` × `N038`: `accumulates` cannot serve an exported API

Shape:

```gabbro
pub accumulates SUMME : u32 merge add;
```

Tool:

```text
error: [P041] .tmp/bm4/v9.gab:2:1: `pub` is not in the grammar here: `accumulates` carries no `[ "pub" ]`
```

while a non-`pub` accumulator named from a `pub` function draws `N038` (F1).
The pincer: `accumulates` is unusable from any `pub` function, i.e. unusable
for a library module like this one. Additionally `SUMME += 1` on a full `u32`
draws `M104`/`M101` (checked add; the grammar has no `+%=`), so even a private
wrapping counter cannot be spelled through `+=`. `accumulates` was therefore
not used. Its documented price (SYNTAX.md §11: relaxed merge-add is a
load/add/store sequence needing single-writer-per-cell) would in any case not
fit workers that share every counter.

## F7 — `P034` / D2: no wildcard, no integer `match` arms — dispatch is if/else

Shape:

```gabbro
    match r {
        _ => { return r; }
    }
```

Tool:

```text
error: [P034] .tmp/bm4/v8.gab:7:9: `_` on its own is not an identifier
      = there is no catch-all arm (`match` is exhaustive) and no wildcard binder -- a new variant is meant to break the build
```

`match` arms are case names (`ident [(ident)]`), so an integer dispatch over
`0 .. 255` is not a `match` at all. Resolution: if/else chains (nested where
shallow, flat where deep — see F8).

## F8 — `P038`: nesting deeper than 32 is refused — the 256-dispatch must be flat

Shape: a 256-deep nested `if/else` chain (the natural spelling of
`zaehle_regel`).

Tool:

```text
error: [P038] gab/zaehler.gab:3329:128: nesting deeper than 32 -- the parser refuses instead of dying
```

(plus follow-on `P002`/`P003` parse errors). Resolution: `zaehle_regel` and
`lies_regel_treffer` use 256 sequential `if r == N { … }` blocks (nesting
depth 1). Cost consequence, measured: `zaehle_regel` computes 1797 ops
(sequential scan + one CAS call) instead of a ~25-op-deep chain. The shallow
dispatchers (`zaehle_urteil`, 3 arms; `lies_zaehler`, 16 arms) stay nested.

## F9 — C `‑Werror`: the exchange binding is set-but-unused unless returned

The language obliges `let alt = … exchange …`. If `alt` is never read, the
emitter writes a plain `uint32_t alt; … alt = _cx1;` and

```text
error: variable ‘alt’ set but not used [-Werror=unused-but-set-variable]
```

under `cc -std=c11 -Wall -Wextra -Werror`. A tempting consumer,
`if alt <= 4294967295 { }`, trades it for

```text
error: comparison is always true due to limited range of data type [-Werror=type-limits]
```

Resolution (in the module, stated openly): every increment helper returns the
pre-increment value (`-> u32`, `return alt;`) and callers discard it as a
statement, which the emitter writes as `(void)ink_rNNN();` — warning-free. The
return exists for the C compiler, not for the firewall; the report says so.

## H1 — hint `E247` (526×): noted, not obeyed — atomics need no lock

```text
hint: [E247] … `R000` is read by the body of `ink_r000` but no signature lock guarding it is held, and some function writes it
      = the footprint carries what the contract saw: every written carrier wants a `requires Held(L)` guard over a `lock L protects` line, not merely a `reads` or `writes` entry in `effects`
```

All 526 hints of the final file are this one. It is a hint, not a refusal, and
for atomics it is correctly ignored: SYNTAX.md §11 (`kein_wettlauf_global`)
proves the race discipline for a global that *is* atomic — "then the machine
orders it" — and the task mandates atomics instead of a lock. Putting these
counters under a lock to silence a hint would contradict the lane brief.
