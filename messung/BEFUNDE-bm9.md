# Befunde bm9 — where the language said no (or nothing)

Lane bm9, `gab/entscheidung.gab` (plus accessors in `gab/pakete.gab`).
Every entry below is something the tool actually said, pasted verbatim,
with the source shape that produced it. All runs with `./werkzeug/gabbro`
from the tree root. Probes lived in `.tmp/bm9/sonde/` (scratch, not
committed); the shapes that survived stand in `gab/entscheidung.gab` and
`gab/pakete.gab`.

Numbering: B (bm9 lane). F1–F6 are cited, not re-measured: they belong to
lane bm8 (`messung/BEFUNDE-bm8.md`) and the bm9 file keeps every one of
their resolutions (the packet-count clock, the `faden` guard, the
`zaehle_weiter` shape, the two-walk counting).

## B-1 — the inherited 25-error lone-file gate (M119/H021/K003/H016/M147)

Shape: `gab/entscheidung.gab` at HEAD (lane bm8, item-level `use` lines),
checked as a lone file. Measured 2026-09-16:

```
$ ./werkzeug/gabbro pruefe gab/entscheidung.gab
error: [M119] gab/entscheidung.gab:166:35: `Kopf` is declared nowhere
  166 |     let proto : u32 in 0 .. 255 = Kopf.slots[0].proto;
      |                                   ^^^^
  = an unknown name has no type, and every range rule silently steps aside where the type is missing -- including the index bound
... (6 x M119, one per Kopf read)
error: [M147] gab/entscheidung.gab:208:51: `proto` may be stale here: its carrier was written since `proto` was read
... (6 x M147, cascade on the unreadable tuple)
error: [K003] gab/entscheidung.gab:151:9: `entscheide` promises costs, but `zaehle_urteil` is not declared here
... (3 x K003: entscheide, zaehle_weiter, treffer_index)
error: [H021] gab/entscheidung.gab:141:13: `brandmauer::entscheidung::entscheide` calls `zaehle_voll`, and `zaehle_voll` is unknown to the graph -- the edge carries nothing across
... (9 x H021, one per foreign call)
error: [H016] gab/entscheidung.gab:142:192: this `locks` effect names `VSPERRE`, and no `lock` declaration explains it
  = across a library boundary this is the normal case: if the `.gabi` carries the `locks` effect but not the `lock … rank N` line, the whole lock order is disarmed without a word
```

25 errors total, exit 1. The `use` route is closed for the single-file
gate (BEFUNDE-bm7.md L-4); the honest move is the one lane bm7 used:
`extern fn` mirrors with C-identical prototypes, plus -- new in this lane
-- a `lock` mirror (B-3) and TRUE effects on the mirrors (not `pure`),
so the caller's coverage stays checked instead of going blind.

Resolution: all 25 gone in the rewrite (29 items, 0 errors, 1 hint --
the standing E247 on the owned atomic, same class as bm8's). What each
refusal cost, stated in the source: the three `costs` promises over
`extern` bodies are dropped (K003 -- `gabbro kosten` reports those sites
OFFEN, like `gab/lauf.gab`); the coverage is kept by declaring the
owners' real footprints on the mirrors.

## B-2 — `traverse` over an unknown table checks silent, emits broken C (no code at `pruefe`)

Shape (probe `.tmp/bm9/sonde/s8.gab`): `traverse k over slots of Regel`
with `Regel` declared nowhere, `passt` as an `extern fn` mirror:

```
$ ./werkzeug/gabbro pruefe .tmp/bm9/sonde/s8.gab
.tmp/bm9/sonde/s8.gab: 2 items, 0 errors, 0 hints
$ ./werkzeug/gabbro emit .tmp/bm9/sonde/s8.gab > .tmp/bm9/sonde/s8.c
(exit 0)
```

`pruefe` is silent -- 0 errors, 0 hints -- but the emitted C does not
compile:

```
$ cc -std=c11 -Wall -Wextra -Werror -c .tmp/bm9/sonde/s8.c
.tmp/bm9/sonde/s8.c: In function ‘treffer’:
.tmp/bm9/sonde/s8.c:24:48: error: ‘Regel’ undeclared (first use in this function)
   24 |     for (uint32_t k = 0; k < (uint32_t)(sizeof(Regel->slots) / sizeof(Regel->slots[0])); k += 1) {
      |                                                ^~~~~
```

The emitter resolves the traverse bound (`sizeof(Regel->slots)/...`)
against a declaration the unit cannot see, and no pass refuses it by
name -- the refusal arrives one stage later, from `cc`. This is the one
finding of this lane without a checker code, and it shaped
`treffer_index`: the second rule walk runs as a counted `forever` loop
with `leave` (probe `.tmp/bm9/sonde/s9.gab`: `pruefe` exit 0, `emit`
exit 0, `cc -c` clean), the same shape `gab/lauf.gab` uses for its
startup retry (BEFUNDE-bm7.md L-3). The guard `k >= 256` ahead of the
`passt` call IS the index proof the `u32` mirror parameter cannot
carry (the `index into Regel` weakening is stated at the mirror).

## B-3 — a `locks` block over an undeclared lock is two refusals (E006 + H016)

Shape (probe `.tmp/bm9/sonde/s5.gab`): `locks VSPERRE { ... }` with no
lock declaration and no `locks` effect:

```
error: [E006] .tmp/bm9/sonde/s5.gab:12:11: `locks VSPERRE` is in the body but not in the effects of `haupt`
   12 |     locks VSPERRE {
      |           ^^^^^^^
  = the lock order follows from the declared locks, not from the body
error: [H016] .tmp/bm9/sonde/s5.gab:12:11: this `locks` block names `VSPERRE`, and no `lock` declaration explains it
```

Adding the effect alone does not help (probe `.tmp/bm9/sonde/s7.gab`:
`locks VSPERRE` in an `extern fn` mirror's effects without a declaration
is H016 by itself). Consequence: the critical section around
`suche_oder_lege_an` -- dropping it would be a data race on the shared
connection table, i.e. weakening the firewall to please the checker --
needed a declaration, and the only available one is a mirror:
`pub lock VSPERRE protects { Verbindung, Stand } rank 0 held <= 1024 ops;`
(probe `.tmp/bm9/sonde/s10.gab`: 4 items, 0 errors, 0 hints; emits
`VSPERRE_nimm/gib` prototypes plus the calls; `cc -c` clean). Same name,
same rank, same held bound as `gab/verbindungen.gab`; the C is the same
call names and the link provides the single definition. If the owner's
rank or bound ever changes, the mirror follows it -- the comment at the
line says so.

## B-4 — development trail (refusals met and resolved)

- **N038** (`pub` is transitive, probe s10): `pub impl fn haupt` with
  `effects { locks VSPERRE }` over a non-`pub` lock --
  `` `haupt` is exported and names `VSPERRE`, which is not -- the
  interface would point at something that does not travel ''. Resolved
  by `pub lock VSPERRE`, same rule as the counters lane's own atomics
  (and bm8's `pub atomic UHR_TICK`).
- **M147 across true-effect calls: not fired.** With the mirrors
  carrying real (non-`pure`) effects, the tuple lets, the `tick()` call
  and the locked lookup compose with 0 M147 (probe
  `.tmp/bm9/sonde/s4.gab`: extern-result binding + local call with write
  effects + later use is clean). The `zaehle_weiter` shape is kept
  anyway: it is still the documented answer to bm8 F2, and the
  branch-wrapped `zaehle_regel` still relies on the join leniency F2
  measured.
- **Effects naming undeclared carriers: accepted** (probe
  `.tmp/bm9/sonde/s2.gab`: `effects { reads UHR, writes UHR, reads
  Fremd.slots }` with `Fremd` declared nowhere -- 0 errors). This is
  what makes TRUE-effect mirrors writable at all.
- **`costs` with no foreign callees: kept** (same probe s2:
  `costs <= 10 ops` on a body calling nothing foreign is clean).
  Hence `tick` keeps its measured promise and everything calling a
  mirror drops its own -- exactly the `gab/lauf.gab` split.
- **`extern fn` with ranged results: clean** (probe
  `.tmp/bm9/sonde/s1.gab`: `extern fn fremd_proto() -> u32 in 0 .. 255`
  -- 0 errors, 0 hints). The accessor mirrors keep their field ranges,
  which is the technical reason for per-field readers (see BERICHT).

## F5 — analysis (measured, repaired in `gab/entscheidung.gab`)

The hole is lane bm8's finding F5, re-measured by this lane before the
repair (unit emit of the five HEAD files + hosted harness + a
rule-walk counter injected into a COPY of the emitted C -- one added
line, diffed in the report; firewall sources untouched):

```
P1       verdict=1 (want 1) walks=1 (want 1) ok
P2       verdict=1 (want 1) walks=0 (want 0) ok     <- promoting reply: no rule walk
P3       verdict=1 (want 1) walks=0 (want 0) ok
E2a      verdict=0 (want 0) walks=1 (want 1) ok
E2b      verdict=1 (want 1) walks=0 (want 0) ok     <- spoofed reply: ACCEPTED, no rule walk
konten   gesamt=5 summe=5 ok
```

(identical at -O0 and -O2.) E2b is the sharp edge: a SYN to a dropped
port still creates the NEW entry, and the spoofed reverse-tuple reply
promotes it and is ACCEPTed -- a full rule bypass for that flow, all
later packets fast-pathed.

Why the repair can live in `gab/entscheidung.gab` alone: read
`treffer_pflegen` in `gab/verbindungen.gab`. A forward-direction hit on
NEW answers 1; a fresh entry answers 1; only a hit on ESTABLISHED (sans
FIN/RST) answers 2 in the forward direction. So `post == ESTABLISHED
AND forward` holds exactly when the flow was ESTABLISHED *before* this
packet -- the direction bit, computed locally from the ARCHITEKTUR.md
key rule (smaller (address, port) first, mirrored line for line from
`suche_oder_lege_an`), is the distinguisher the post-state signature
does not provide. A reverse packet answering 2 may be the promotion
itself and always walks the rules.

What the repair does NOT fix (measured, same harness, AFTER build):
a DROPPed packet still moves the connection table -- the lookup runs
before the verdict, and nothing in this file can undo the promotion.
E2c (the E2a frame sent again, after the dropped E2b promoted the flow
to ESTABLISHED): `verdict=1 walks=0` -- a forward packet on a flow that
reached ESTABLISHED without a single ACCEPT takes the fast path.
Undoing that wants a verdict-gated lookup (create/promote only on
ACCEPT) or a pre-transition answer -- both are `gab/verbindungen.gab`
signature changes, another lane's file. Until one lands, E2c is the
regression test for the NEXT repair, and the residual stands written
here, not hidden.

## Silence worth writing down

- **Eight new E247 hints in `gab/pakete.gab`** (one per accessor: `Kopf`
  read with no signature guard, `entpacke` writes it). Same class as the
  deliberately-standing hints of the regeln/lauf/entscheidung lanes
  (no-lock disciplines); hints, not refusals -- `pruefe` exits 0, and
  the decoding logic above them is byte-identical (`git diff`: +66/-0).
- **`pruefe --unit` over the five files is dead for this construction:**
  the `extern` mirrors collide with their same-named owners. The
  composition check is now the C prototype diff (14/14 identical, see
  BERICHT) plus the link. Whoever checks this project names the
  single-file gate per module and links; the Makefile's `pruefen`
  target already does the first half.
- **M1 coverage on the new file:** 142 expressions, 7 without a type
  (95 %). Same 7 statement-position void calls as bm8's (the counter
  calls); chased down there, not re-argued here.
