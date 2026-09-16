# Befunde bm11 — where the language said no (or nothing)

Lane bm11, after `git pull` of the Gabbro trunk (`57c44087`, "four topics
Lean model plus checker/emitter": M127 `&T`, N042/N323 lock contract,
never+asm N321, syscall-costs N322). Tool: `./werkzeug/gabbro` is that
build (copied into `werkzeug/`, as the README orders). Every entry is
something the tool actually said, pasted verbatim, with the source shape.
Probes in `/tmp/opencode/` (scratch, not committed).

## U-1 — `&T` checks, `u64` does not (M127 gefallen, M140 steht)

Probe `probe2.gab` (unchanged since bm10) with the new binary:

```
/tmp/opencode/probe2.gab: 4 items, 0 errors, 0 hints
```

`&Puffer` binds `ptr<normal, rw> Puffer`. The `u64` shape (probe1) is now
refused the other way:

```
error: [M140] /tmp/opencode/probe1.gab:8:19: binding requires `u64`, the value has `ptr<…> probe::p1::Puffer` -- a pointer does not answer for a number
```

Rightly so: provenance is not a number. Consequence used across the lane:
syscalls take `ptr` params, addresses never cross as `u64` again.

## U-2 — `use` carries types across files, cycles included

- `use` + foreign table in a `syscall` param: clean single-file with
  `--with` (probe `sw.gab`: 7 items, 0 errors, 0 hints) and in `--unit`.
- `use` + foreign table in an `impl fn` param: clean (probe `v5.gab`;
  the earlier `s2`/`s3` N040s were MY probe bug -- the defining file was
  missing from the unit, so the `use` dangled).
- Mutual `use` (caller owns table, callee names its type): clean
  (probes `c1`/`c2`: unit of 2 files, 0 errors).
- `.gabi` carries `pub table` (measured output of `gabbro abi`).

What the lane builds on this: `gab/systemrufe.gab` names three foreign
tables for TYPES through `use` (checked with generated `bau/netz.gabi`);
every VALUE (`&Senden` etc.) is bound by the owning module and travels as
a parameter. No second border, no cycle at check time.

## U-3 — full unit over the firewall: 6 errors, all collisions

`./werkzeug/gabbro pruefe --unit gab/*.gab` (old files):

```
error: [N039] gab/systemrufe.gab:68:11: `KEIN_WERT` binds twice in this build: `brandmauer::lauf::KEIN_WERT` in this unit carries the same C name
error: [N039] gab/systemrufe.gab:69:11: `NOCHMAL` binds twice ...
error: [N039] gab/systemrufe.gab:70:11: `PAKETE_VERLOREN` binds twice ...
error: [N042] gab/verbindungen.gab:56:10: `VSPERRE_gib` is the C name of two different declarations
error: [N042] gab/verbindungen.gab:56:10: `VSPERRE_nimm` is the C name of two different declarations
error: [N039] gab/verbindungen.gab:56:10: `VSPERRE` binds twice in this build: `brandmauer::entscheidung::VSPERRE` in this unit carries the same C name
```

The lane does NOT migrate to unit builds because of this: the mirror
architecture (single-file gate, prototype diffs, all bm7-bm9 measurements)
stays, and the new edges fit it (U-2). The collisions are filed, not
worked around.

## U-4 — N042 fires beside meeting bodies, by design

Probe `ulock.gab` (ticket-shaped `VSPERRE_nimm`/`gib` beside the lock):

```
error: [N042] /tmp/opencode/ulock.gab:15:13: `VSPERRE_nimm` is the C name of two different declarations
error: [N323] /tmp/opencode/ulock.gab:6:13: `VSPERRE_nimm` is the acquire primitive of `lock VSPERRE`, and its body does not meet the lock contract
```

(`namen.rs::sperrprimitiv_vertrag`: "N042 also keeps firing beside this
rule -- the contract check does not move the name.") So the implementation
lives in `gab/sperre.gab` with NO lock declaration: per-file emit plus the
C link resolve the pair, N042/N323 never see it. Residue, stated in
`gab/sperre.gab` and BERICHT-bm11.md: the contract holds BY SHAPE
(reference `laufzeit/sperre.gab`, proved in `CTicket.lean`), not by N323.

## U-5 — exits stay external (both asm shapes refused, forever needs a watchdog)

- `-> never` + asm WITH `out`: clean refusal `N321` (probe `ph3.gab`) --
  the broken `_Noreturn void result;` C of bm10 is gone, replaced by words.
- `-> never` + asm WITHOUT `out`: `C001` unchanged (probe `ph2.gab`).
- `-> never` + `forever` without `on_exceeded`: the grammar has no such
  loop (probe `pfl.gab`: `P001: on_exceeded expected`), and any watchdog
  regresses (T-4: H022/K008). Hence the four diverging exits stay `extern`
  (foreign trust base, gift-988 pattern) and the stub stays -- now 4
  symbols instead of 6.

## U-6 — `extern fn` carries costs (K003-Kette schließt)

Probe `ec2.gab` (`extern fn fremd ... effects { pure } costs <= 8 ops;`
calling it under a promise):

```
/tmp/opencode/ec2.gab: 3 items, 0 errors, 0 hints
ruf	9	16	7
```

Consequence used: every mirror repeats its owner's measured number
(C-neutral claims, checked at the prototype+cost diff, never by proof).
Straight-line callers promise their computed costs (`zaehle_weiter`
16/16, `lade_grundregeln` 1084/1084, the three transport wrappers
14/15/15, `verbinde` 41, `sende`/`empfange` 19, `einrichten` 829).
`forever` sites stay OFFEN by construction (5 sites: `behandle`,
`arbeite`, `main`, `treffer_index`, `entscheide`-via-`treffer_index`) --
no refusal, the loop form has no total.

## U-7 — N322 fallout (10 errors, one edit)

After the binary swap, `gab/systemrufe.gab`: 56 items, 10 errors -- one
`N322` per `syscall` without a `costs` clause:

```
error: [N322] gab/systemrufe.gab:283:9: `roh_ende` carries no countable cost promise -- declares no `costs` -- a call through it counts nothing, and no bounded loop can host one
```

Fixed with `costs <= 8 ops` on all ten (the `beispiele/90` dispatch-bound
convention), one `replaceAll`. Fallout of progress, not of the firewall.

## U-8 — honest `K007` on the first costed run

`treffer_index`'s pass cost 86 against promised `per_pass` 64 -- because
`passt` now costs its 71. Promised the measured 86. The checker earning
its keep: a stale bound fell the moment the callee became countable.

## Silence worth writing down

- `emit --with` writes full struct DEFINITIONS for used tables into the
  using TU (no storage). Per-file link: identical tags+layouts, compatible.
  `#include`-all single-TU harnesses die on it (conflicting anonymous
  structs) -- bm11 harnesses compile+link separately, like the real build.
- A virgin copy is never referenced: `gab/systemrufe.gab`'s TU holds
  unused `Senden`/`Empfang`/`Adresse` struct decls (emitter behavior);
  every body forwards caller-handed pointers. Waste (~8 KB), not wrongness.
- `strace` decodes our `nlmsg_type` as `0 /* NLMSG_??? */` -- it does not
  know NFNL subtypes; the bytes (`02 03` = 770) are ours and the kernel
  answers EPERM, never EINVAL.
