# Report — lane bm2 (`gab/regeln.gab`)

## 1. What the module does

Fixed rule table `Regel count 256` (module `brandmauer::regeln`). Each slot:

- `aktiv : u32 in 0 .. 1` — inactive slots never match;
- per-field match with an "any" marker each: `proto_any`/`proto`,
  `quell_any`/`quelle`/`qmask`, `ziel_any`/`ziel`/`zmask`,
  `qport_any`/`qport_lo`/`qport_hi`, `zport_any`/`zport_lo`/`zport_hi`,
  `flaggen_any`/`flaggen_maske`/`flaggen_wert`;
- `urteil : Urteil` (`u32 in 0 .. 2`: 0 DROP, 1 ACCEPT, 2 REJECT per
  ARCHITEKTUR.md), `nummer : u32 in 0 .. 255` (rule identity, e.g. for the
  counters lane's per-rule statistics).

Four public functions:

- `passt(r : index into Regel, proto, quelle, ziel, qport, zport, flaggen)
  -> Treffer` — single-rule match, 1/0. Header fields are plain parameters;
  the module never reads another module's table.
- `entscheide_regeln(proto, quelle, ziel, qport, zport, flaggen) -> Urteil`
  — first match wins walking slots 0..255 with early `return`; no match
  returns the declared constant `STANDARD` (= 0, DROP — fail closed).
- `setze_regel(i, ...all fields...)` — the loader the driver calls at
  startup, once per configured rule. The only way into the table.
- `raeume_alle()` — deactivates every slot (`aktiv = 0`,
  `urteil = STANDARD`); the driver calls it once before loading.

Declared constants: `REGELZAHL = 256`, `VERWIRF = 0`, `NIMM_AN = 1`,
`WEISE_AB = 2`, `STANDARD = 0`. Types `Urteil`, `Treffer` are exported for
the other lanes' signatures. The ABI (`gabbro abi`) carries all of the
above; the certificate (`gabbro certificate`) reports 0 assumptions,
2 proved templates, 6 direct lowering forms, 0 foreign bodies.

Interface contract the other lanes must keep: `passt`/`entscheide_regeln`
take the *decoded-valid* header. `Kopf.gueltig == 0` (malformed) must be
DROPped by the caller (`entscheidung.gab`) *before* calling — this module
has no `gueltig` parameter and does not re-check it. An inverted port range
(`lo > hi`) matches nothing (fail closed, documented in the source, not
refused).

## 2. What the checker said (verbatim)

```
$ ./werkzeug/gabbro pruefe gab/regeln.gab
hint: [E247] gab/regeln.gab:124:30: `Regel` is read by the body of `entscheide_regeln` but no signature lock guarding it is held, and some function writes it
  124 |     traverse k over slots of Regel by unvisited
      |                              ^^^^^
      = the footprint carries what the contract saw: every written carrier wants a `requires Held(L)` guard over a `lock L protects` line, not merely a `reads` or `writes` entry in `effects`
      = carriers no function writes need no guard; device registers read bare carry none either, until the declaration names their carriers
hint: [E247] gab/regeln.gab:74:8: `Regel` is read by the body of `passt` but no signature lock guarding it is held, and some function writes it
      [same two explanation lines]
hint: [E247] gab/regeln.gab:170:30: `Regel` is read by the body of `raeume_alle` but no signature lock guarding it is held, and some function writes it
      [same two explanation lines]
gab/regeln.gab: 13 items, 0 errors, 3 hints
  M1 saw 176 expressions, 0 of them without a type (100 % coverage)

Not checked in this run: 9 passes -- 0 open, 9 CARRIED (the rest is NAMED), 0 only partial
  2 D1/D2, 4 M3, 5 M2, 12 Sperren, 11 Phasen, 7 Paarung, 8 effects, 10 Gruppe, 9 costs
  register 4dd17209 -- the FULL text with `gabbro pruefe --paesse` or `gabbro paesse`
```

Exit code 0. The three hints are one deliberate decision (no lock — see
`messung/BEFUNDE-bm2.md` §2), not three problems.

Costs (`gabbro kosten`), promises copied from the computed column:

```
-- site              computed  promised  slack
passt               71        71        0
entscheide_regeln   68096     68096     0
setze_regel         60        60        0
raeume_alle         1024      1024      0
-- 4 bodies computed, 0 open, 0 derived.
```

Per-pass cost of the walk is 68096 / 256 = 266 ops (71 for the `passt` call
plus loop, comparison, and verdict-load overhead). Worst case is a full
256-slot walk with no match; the common case (early match) costs less but
the declared bound is the static worst case — that is what the number means.

## 3. What the emitted C looks like at the interesting places

`./werkzeug/gabbro emit gab/regeln.gab` exits 0 (149 lines). Constants lower
to `#define`s (`REGELZAHL 256u`, `STANDARD 0u`); the table to a static
struct array (`static Regel Regel_speicher;`); `index into Regel` to
`uint32_t`. The walk lowers to a plain bounded `for` with the early exit
preserved:

```c
uint32_t entscheide_regeln(uint32_t proto, uint32_t quelle, uint32_t ziel, uint32_t qport, uint32_t zport, uint32_t flaggen) {
    for (uint32_t k = 0; k < (uint32_t)(sizeof(Regel_speicher.slots) / sizeof(Regel_speicher.slots[0])); k += 1) {
        if (passt(k, proto, quelle, ziel, qport, zport, flaggen) == 1) {
            return Regel_speicher.slots[k].urteil;
        }
    }
    return STANDARD;
}
```

`passt` (only reads) is emitted `__attribute__((pure))`; the mask checks
lower to plain `&`/`!=`, the port ranges to `<`/`>` pairs. No allocation, no
library calls, no strings anywhere in the unit.

Compilation: `cc -std=c11 -Wall -Wextra -Werror -c` passes at both `-O0`
and `-O2`.

Behavioural check (harness in `.tmp/bm2/pruefstand.c`, gitignored, not part
of the firewall): 16 assertions over the emitted C — empty-table default,
TCP/80 accept, first-match-wins ordering, /16 subnet mask in/out, SYN-only
flag match incl. SYN+ACK, inactive slot, port-range edges 999/1000/2000/
2001, inverted range matching nothing. All 16 pass at `-O0` and `-O2`
(`ALLE PRUEFUNGEN BESTANDEN`, exit 0 both levels).

## 4. What I could NOT write and why

- Early exit from `traverse` with continuation (`leave`): refused as S001 —
  a `traverse` takes no label. Recorded in `messung/BEFUNDE-bm2.md` §1 with
  code, message, and shape. Not needed here (`return` is the design), but a
  real limit for "find first, then continue" walks.
- A lock around the rule table: deliberately not written (cross-lane
  contract, ARCHITEKTUR.md names none). Recorded in
  `messung/BEFUNDE-bm2.md` §2. Consequence: live rule reload under load is
  NOT safe with this file alone; rules are load-at-startup only.

## 5. What I did not measure

- Concurrency: the startup-write / hot-path-read discipline is a stated
  convention, not a tested interleaving. No threads exist in this lane.
- Time: `costs` are static op counts, not cycles. Worst-case packet latency
  of the 256-walk on real hardware was not measured.
- Integration: no other `gab/` module exists yet, so the call chain
  decoder → `entscheide_regeln` → verdict was tested only against the C
  harness with hand-supplied header fields, not against `pakete.gab` output.
- Rule-file parsing (text → `setze_regel` arguments) belongs to the driver
  lane; this module takes decoded values.
