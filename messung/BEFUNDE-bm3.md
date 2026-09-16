# Befunde — lane bm3 (`gab/verbindungen.gab`)

Every refusal met while writing the connection table, with the code, the
message (abridged to the ruling line) and the source shape that produced it.
Probes lived in `.tmp/probe*.gab` (scratch, not committed); the resolutions
below are all in `gab/verbindungen.gab`, which checks with 0 errors, 0 hints.

## F1 — N038: a `pub` signature may name nothing non-`pub`

```
error: [N038] probe1.gab:14:33: `lies` is exported and names `Tab`, which is not
error: [N038] probe1.gab:16:38: `lies` is exported and names `S`, which is not
error: [N038] probe1.gab:5:21: `Tab` is exported and names `N`, which is not
```

Shape: `pub impl fn lies(i : index into Tab)` with a non-`pub` table, a
non-`pub` lock in `effects`, and `pub table Tab count N` with a non-`pub`
const `N`. The chain is transitive: table → count const, function → table,
function → lock. Resolution: `pub` on the tables, the lock, and every const
a `pub` signature transitively names (`ANZAHL`, `EIMER`, `FACH`, `ABLAUF`).
Consequence for the other lanes: whatever my callers name in their `use`
lines travels through the `pub` interface — nothing is hidden, nothing is free.

## F2 — E010: a `traverse` domain reads the carrier, not the slots

```
error: [E010] probe2.gab:20:30: `Tab` is read but appears in no `reads` effect of `altere`
   20 |     traverse k over slots of Tab by unvisited
      = reading A: reads are declared as completely as writes
      = declared are: Tab.slots
      fix: 370..370 -> , reads Tab
```

Shape: `traverse k over slots of Tab` with `effects { reads Tab.slots, … }`.
The domain read is a read of the carrier `Tab`; the field reads are reads of
`Tab.slots`. Both must be declared. The offered `fix:` (insert `, reads Tab`)
was applied verbatim and is exactly what `altere` carries now
(`reads Verbindung` beside `reads Verbindung.slots`). Slot access alone
(`Tab.slots[i].f`) needs only `….slots` — the two readings are distinct and
the checker tells them apart.

## F3 — E247 (hint): the guard belongs at the signature, not in a block

```
hint: [E247] probe2.gab:35:34: `Tab` is read by the body of `hole` but no
signature lock guarding it is held, and some function writes it
      = every written carrier wants a `requires Held(L)` guard over a
        `lock L protects` line, not merely a `reads` or `writes` entry
```

Shape: a function taking the lock itself (`locks S { … }` around the body)
with no `requires Held(S)`. This is a hint, not a refusal — but the hint text
is the ruling: take-inside does not discharge the footprint. All three public
functions (`suche_oder_lege_an`, `altere`, `lies_stand`) and the private
helper therefore carry `requires Held(VSPERRE)`. See F6 for what this decided.

## F4 — M147: staleness is path-insensitive (twice, same function)

```
error: [M147] gab/verbindungen.gab:89:8: `z` may be stale here: its carrier
was written since `z` was read
   89 |     if z == 2 {
      = re-read the carrier into this name after the write
```

Shape (first draft of `treffer_pflegen`): `z` read from
`Verbindung.slots[s].zustand`, then `zustand = 2` written on the `z == 1`
branch (which returns), then `z` tested again (`if z == 2`) and returned.
The write never runs on the path that reaches the second use — the checker
does not care: any use of a carrier-derived name after ANY write to that
carrier falls. Second error at `return z;`, same cause. Resolution:
decide-then-write-once-then-reread — compute `neu_zustand` from `z` with no
`Verbindung` write in between, write once, re-read into `frisch`, return
`frisch` (`Stand` writes in between are a different carrier and do not
invalidate). A read placed AFTER writes is fresh (the V4 idiom from
`muster/01-tabelle.gab`); a use placed after a write never is, on any path.

## F5 — caller-side shapes (cross-module probe, `.tmp/caller.gab`)

Three refusals on the first caller draft, all three about naming across the
module boundary, none about the lock discipline itself:

- `P001` at `::` inside `effects`: an effect list takes bare carrier names,
  never paths (`reads brandmauer::verbindungen::Verbindung.slots` refused;
  `reads Verbindung.slots` with item-level `use` accepted).
- `N280` / `H021` / `K003` / hint `E009`: `use brandmauer::verbindungen;`
  (module only) leaves the callee "unknown to the graph" — the edge carries
  nothing, costs are uncheckable. Item-level `use` lines
  (`use brandmauer::verbindungen::suche_oder_lege_an;` etc.) resolve it.
  With those, `locks VSPERRE { return suche_oder_lege_an(…); }` checks with
  0 errors, 0 hints as a `--unit` of both files — the exact shape the
  entscheidung lane must write. Note for bm6/bm8: import ITEMS, not modules.

## F6 — considered and rejected: one lock per bucket group

The lane brief calls per-group locks "the interesting design". It was tried
on paper and refused by F3, not by a code: `requires Held` names a FIXED set,
but which stripe lock a packet needs is data (the hash). A signature would
have to name all stripe locks, serialising the contract to the coarse lock
anyway — or drop `requires Held` and take the stripe lock inside, which is
exactly the E247 hint shape. Striping buys runtime parallelism only by
leaving the checked discipline. One table, one lock (`VSPERRE protects
{ Verbindung, Stand } rank 0`), honestly coarse. If a later measurement
shows the lock is the bottleneck, the honest upgrade is N stripe TABLES
(disjoint carriers, one lock each) — not N locks on one carrier.

## Silence worth writing down (no refusal, still load-bearing)

- **Re-taking a held lock passes silently.** `requires Held(S)` plus a
  `locks S { … }` block around the body: 0 errors, 0 hints (probe3). At run
  time that is a self-deadlock under a mutex runtime. The checker proves the
  rank order across DIFFERENT locks; the same lock twice is nobody's theorem.
  My module never takes a lock inside — the `locks` blocks belong to the
  callers — so the shape cannot arise here, but no pass would catch it if it did.
- **Provably in-range values still narrow.** `s0 = eimer * 4 + 0` with
  `eimer ≤ 1023` is `≤ 4092` by construction, yet `narrow s0 to 0 ..< ANZAHL`
  is compulsory before indexing — a computed `u32` never IS an
  `index into T`. The four emitted `if (!(sN < ANZAHL)) return 0;` are dead
  code with a purpose: the price of the index type. Kept, not worked around.
- **Ranges do not reach the C.** `zustand : u32 in 0 .. 3` emits plain
  `uint32_t`; the 0..3 promise holds at every Gabbro call site and nowhere
  else. A C caller can store 7. The border is the checker, not the type.
