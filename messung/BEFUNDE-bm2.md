# Findings — lane bm2 (`gab/regeln.gab`)

Every entry is something `./werkzeug/gabbro` actually said, against the
source shape that produced it. Nothing here is assumed.

## 1. `leave` cannot exit a `traverse` (S001) — finding, worked around honestly

The table walk with an early exit is the interesting part of this lane. The
first shape tried was `leave` out of the walk:

```gabbro
traverse k over slots of Regel by unvisited
    touches reads Regel, reads Regel.slots
{
    if Regel.slots[k].aktiv == 1 {
        leave k;
    }
}
```

Refused:

```
error: [S001] .tmp/bm2/t06.gab:18:19: `leave k` targets no enclosing loop label
   18 |             leave k;
      |                   ^
      = SPRACHE.md §8.2: there is no unnamed `break`/`continue` -- with nested loops the target would be convention
      = no label is in scope here; `retry`/`forever` take one
```

A `traverse` takes no label, so `leave`/`next` cannot target it at all; only
`retry`/`forever` take labels, and neither is a table walk. The early exit
this module needs is therefore a `return` out of the `traverse` body, which
is what `entscheide_regeln` does (first match returns the verdict directly).
For first-match-wins that is the honest design, not a workaround: there is
nothing left to do after the match. But it is a genuine expressiveness limit
worth writing down: a `traverse` that must stop early *and then continue the
enclosing function* (e.g. "find the first matching index, then do more work
with it") has no loop form — `return` leaves the function, `leave` has no
label to name. This module never needs that shape, so nothing was weakened.

## 2. No lock on the rule table — deliberate, with three E247 hints

`gab/regeln.gab` checks with 0 errors and 3 hints, all three the same code
(E247), one per reading function:

```
hint: [E247] gab/regeln.gab:124:30: `Regel` is read by the body of `entscheide_regeln` but no signature lock guarding it is held, and some function writes it
  124 |     traverse k over slots of Regel by unvisited
      |                              ^^^^^
      = the footprint carries what the contract saw: every written carrier wants a `requires Held(L)` guard over a `lock L protects` line, not merely a `reads` or `writes` entry in `effects`
      = carriers no function writes need no guard; device registers read bare carry none either, until the declaration names their carriers
```

(The other two point at `passt`, line 74, and `raeume_alle`, line 170, with
identical text.)

The hint is correct: `setze_regel`/`raeume_alle` write `Regel`, and the
readers hold no lock. Adding `lock REGELN protects { Regel }` with
`requires Held(REGELN)` would silence the hints, but the lock would be a
contract the driver lane (`lauf.gab`) and the decision lane
(`entscheidung.gab`) must take at every call — and ARCHITEKTUR.md names no
such lock, and rule 1 forbids editing another lane's contract surface by
side effect. The discipline instead is stated in the file header:
`setze_regel`/`raeume_alle` run once at startup before the workers start;
after that the table is read-only shared data (the "stable reads" shape of
SYNTAX.md §11). If the project later wants live rule reloads under load,
that is a new cross-lane contract (lock or generation stamp), not a line in
this file.

## 3. Development trail — refusals met and resolved (checker working as designed)

- **N038** (`pub` function naming a non-`pub` table): the first draft
  declared `table Regel` without `pub` while `hole(i : index into Regel)`
  was `pub`. Message: `` `hole` is exported and names `Regel`, which is not
  -- the interface would point at something that does not travel``.
  Resolved by declaring the table `pub` — the index type is part of the
  interface the other lanes call through.
- **E010** (reads declared incompletely): `effects { reads Regel.slots }`
  alone does not cover `traverse k over slots of Regel`, which reads the
  carrier `Regel` itself. Message: `` `Regel` is read but appears in no
  `reads` effect of `suche` `` with a machine-applicable fix. Resolved by
  writing `effects { reads Regel, reads Regel.slots }` (and the same pair in
  `touches`).
- **K001** (cost promise below the computed cost): the first
  `entscheide_regeln` promised `<= 4096 ops` against a computed `68096`.
  Message: `` `entscheide_regeln` promises <= 4096 ops, the body costs 68096
  `` with the fix pointing at the exact number. Resolved by copying the
  measured numbers into the promises (71 / 68096 / 60 / 1024), each printed
  by `gabbro kosten`, not estimated.

None of the three is a language gap; all three are the checker holding the
writer to the declared contract.
