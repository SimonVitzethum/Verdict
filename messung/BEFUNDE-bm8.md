# Findings — lane bm8 (`gab/entscheidung.gab`)

Every entry is something `./werkzeug/gabbro` actually said (or something
the composed C actually did), against the source shape that produced it.
Probes lived in `.tmp/bm8/` (scratch, not committed); the resolutions below
are all in `gab/entscheidung.gab`, which checks with 0 errors in the unit.

## F1 — a wiring file does not check alone (M119/H021/K003/H016)

Shape: `gab/entscheidung.gab` with item-level `use` lines
(`use brandmauer::pakete::entpacke;` etc.), checked as a lone file:

```
$ ./werkzeug/gabbro pruefe gab/entscheidung.gab
error: [M119] gab/entscheidung.gab:166:35: `Kopf` is declared nowhere
  166 |     let proto : u32 in 0 .. 255 = Kopf.slots[0].proto;
      |                                   ^^^^
  = an unknown name has no type, and every range rule silently steps aside
    where the type is missing -- including the index bound
error: [H021] gab/entscheidung.gab:…: `brandmauer::entscheidung::entscheide`
        calls `entpacke`, and `entpacke` is unknown to the graph -- the edge
        carries nothing across
error: [K003] gab/entscheidung.gab:…: `zaehle_weiter` promises costs, but
        `zaehle_urteil` is not declared here
  = a cost promise over an unknown quantity is a promise nobody can check
error: [H016] gab/entscheidung.gab:142:192: this `locks` effect names
        `VSPERRE`, and no `lock` declaration explains it
  = the rank IS the lock order -- an undeclared lock has none, so the rank
    rules compare nothing and stay silent
```

25 errors total (6 × M119 on the `Kopf` reads, 9 × H021 one per foreign
call, 3 × K003, 1 × H016, 6 × M147 cascade on the unreadable tuple).
None of them is a defect of this module: a file whose whole job is calling
five other files cannot resolve its imports alone. The checkable thing is
the unit, two spellings, both green (0 errors):

```
$ ./werkzeug/gabbro pruefe --unit gab/pakete.gab gab/regeln.gab \
      gab/verbindungen.gab gab/zaehler.gab gab/entscheidung.gab
gab/entscheidung.gab: 22 items, 0 errors, 3 hints
unit of 5 file(s): 587 items, 0 errors, 532 hints
$ ./werkzeug/gabbro pruefe --with .tmp/bm8/unit.gabi gab/entscheidung.gab
gab/entscheidung.gab: 320 items, 0 errors, 3 hints
```

(The `.gabi` interfaces are generated scratch via `gabbro abi` into
`.tmp/bm8/`; the three remaining hints are E247, deliberate — see the
report.) Consequence for the other lanes, stated once: **whoever checks or
builds this project names the unit, never a lone wiring file.**

## F2 — M147 across foreign calls: count-then-return is not two lines

The refusal that shaped this file. Shape (real unit, `entscheide` tail):

```gabbro
let urteil : u32 in 0 .. 2 = entscheide_regeln(proto, quelle, ziel, qport, zport, flaggen);
-- ...
zaehle_urteil(urteil);
return urteil;
```

```
error: [M147] gab/entscheidung.gab:189:12: `urteil` may be stale here: its
carrier was written since `urteil` was read
  189 |     return urteil;
      |            ^^^^^^
  = re-read the carrier into this name after the write -- the re-read IS the
    refresh; storing or moving the name needs none, acting on it does
```

Bisected to the minimum (probes `.tmp/bm8/k*.gab`, foreign `walk` reading
a table + foreign `wges` writing an atomic, `--unit` checked):

- local `walk` + local `countu`, `countu(u); return u;` — CLEAN.
- foreign `walk` + foreign `countu`, same two lines — M147 at `return u`.
- `countu(0); return u;` (u never passed) — STILL M147. Passing is not
  the trigger; any straight-line call with write effects after a foreign
  call-result binding taints every later use of that result.
- `narrow u to 0 .. 2 else { return 0; }` before or after the write —
  STILL M147. Narrowing does not clear the taint.
- writer call wrapped in `if flag == 1 { wges(0); }`, return after the
  `if` — CLEAN. Writes inside a branch do not taint past the join.
- local helper `lokal_zaehler(u) { wges(u); return u; }`,
  `return lokal_zaehler(u);` at the call site — CLEAN, both sides. A
  helper's parameter carries no carrier taint.

So the rule as built: a FOREIGN call's result is treated as
carrier-derived, and any straight-line writing call afterwards closes all
later uses — while branch-wrapped writes do not (a leniency in the
path-sensitivity, honestly recorded: this file's
`if treffer <= 255 { zaehle_regel(treffer); }` ahead of the return relies
on exactly that join behaviour, and the underlying truth holds anyway —
no writer to `Regel` runs on the packet path by the startup-loader
discipline both lanes document).

Resolution: the two lines stand in a local helper whose parameter is
untainted (`zaehle_weiter`), and the caller ends in
`return zaehle_weiter(urteil);` — an argument use, which never falls.
Same value counted, same value returned; the shape changed, the semantics
did not. The helper's comment says exactly this.

## F3 — no wall clock reaches this file (no refusal code)

`suche_oder_lege_an` needs `jetzt : u32`. The kernel border offers
`zeit_lesen(uhr : u64, adresse : u64)`, but no Gabbro term produces a
memory address: `&f` is a function-pointer producer, `&T` a carrier
capability (SYNTAX.md §4) — there is no address-of on a local, a static,
or a table slot, and no shared timespec carrier with the ABI. Passing a
fabricated `u64` would type-check and die at run time (`EFAULT` →
`KEIN_WERT`): typeable but meaningless, which is worse than a refusal, so
it is not written. This is inexpressibility, not a refusal — hence no code.

Resolution in-file: `UHR_TICK`, a saturating `atomic … relaxed` bumped
once per decided packet and handed over as `jetzt`. Consequences, stated
in the source: entries expire after `ABLAUF` (300) unobserved PACKETS,
not 300 seconds — faster than intended under flood (fail closed: flows
fall back to the rules, default DROP), slower than intended at idle
(ESTABLISHED fast path outlives a rule change longer — the documented lag
at the fast-path branch). Saturating, not wrapping: after a wrap
`jetzt < gesehen` would pin every entry under the clock-stepped-back
rule. A lost bump under contention re-reads as the same value — time runs
slow, never backwards. Wall-clock expiry wants an address primitive plus
a timespec carrier: other lanes' work, named here.

## F4 — `faden` indexes nothing (M103)

Shape (probe `.tmp/bm8/faden.gab`, `Kopf count 1`):

```gabbro
return Kopf.slots[faden].gueltig;   -- faden : u32 in 0 .. 15
```

```
error: [M103] .tmp/bm8/faden.gab:11:23: the index has `u32 in 0 .. 15`,
the array has 1 elements
  = M4: no unchecked indexing -- the bound comes from the declaration of
    the carrier
```

`Paket`/`Kopf` have count 1 shared by all 16 threads (ARCHITEKTUR.md fixes
the counts; changing them is not this lane's to do). Per-thread in-flight
buffers want `count 16` there plus a `faden`-indexed access here — until
that cross-lane change lands, `faden` is boundary-checked
(`if faden > 15 { zaehle_urteil(DROP); return DROP; }`, real defence at
the C boundary where the parameter arrives as plain `uint32_t`) and
otherwise unused. Two truths stand side by side: concurrent packets from
16 threads share one `Kopf` slot today (a race the architecture bakes in —
the decoder's single exit makes each decode atomic-ish, but two decodes
interleave), and this file neither causes nor cures it.

## F5 — the promoting reply answers ESTABLISHED (measured, no refusal)

`suche_oder_lege_an` answers the POST-transition state: the packet that
promotes a flow NEW → ESTABLISHED already answers 2, so under this lane's
specified fast path that packet never sees the rules. Measured over the
composed unit (`.tmp/bm8/sonde.c`, pthread-mutex `VSPERRE`, stub
`zaehler_streit`, identical at -O0/-O2):

```
E1 syn verdict=1 (want 1)
E1 slot0 hits=1 (want 1)
E1 reply verdict=1 (1=fast-or-rule, 0=rules-drop)
E1 regelsumme=1 (1=fast path taken, 2=rules walked)
E2 syn verdict=0 (want 0)
E2 spoofed-reply verdict=1 (0=safe, 1=HOLE)
E2 regelsumme=1
```

E1: with only `TCP→:80 ACCEPT` loaded, the reply (no rule covers it) is
ACCEPTed with no rule walk — fast path on the promoting packet itself.
E2 is the sharp edge: a SYN to a DROPPED port still creates the NEW entry
(lookup runs before the verdict by this lane's specified order), and a
spoofed reverse-tuple reply then promotes it and is ACCEPTed — two packets
to a full rule bypass for that flow, all later packets fast-pathed.

This file cannot distinguish "promoted by this very packet" from
"established earlier": the signature answers only the state number, and
reaching past it is forbidden. Keeping the specified behaviour (state 2 →
fast path) and writing the hole down is the honest move. Fix options,
all owned elsewhere: answer the PRE-transition state on the promoting
packet (verbindungen.gab), create entries only for SYNs or only after an
ACCEPT verdict (needs lookup-after-verdict — a reorder of this lane's
specified policy, for all lanes to agree), or a generation stamp for live
revocation (see the fast-path comment in the source). Until one lands,
the E2 recipe above is the regression test.

## F6 — signature gap: no rule-hit index (no refusal, solved in-file)

`entscheide_regeln` answers the verdict but not WHICH rule matched, while
the brief demands `zaehle_regel` per hit — and the default policy
(`STANDARD`) is indistinguishable from a matching DROP by value alone.
Resolution in-file: `treffer_index`, the same first-match walk over
`passt` returning the slot (256 = no match = default, nothing to count).
Price, measured not guessed: a second full walk, 20480 ops (256 × 80),
inside the 91166 worst case. The two walks can disagree only if the table
changes between them; the loader runs before the workers start, so the
verdict stays authoritative and the counter follows it.

## Development trail — refusals met and resolved

- **N038** (`pub` is transitive): `pub impl fn entscheide` naming
  non-`pub` `UHR_TICK` in `effects` — `` `entscheide` is exported and
  names `UHR_TICK`, which is not ``. Resolved by `pub atomic UHR_TICK`,
  same rule as the counters lane's own atomics.
- **K001**: `tick` promised `<= 8 ops`, body costs 10. Copied the measured
  10. (All four promises in the file are now tool-computed, slack 0 —
  see the report.)
- **H007** (probe only): reading a lock-guarded carrier without holding
  the lock. Met on a scratch table with a lock; the real file never
  touches `Verbindung`/`Stand` except through `suche_oder_lege_an`
  inside `locks VSPERRE`, so the shape cannot arise here.

## Silence worth writing down

- **Per-file emit duplicates shared carriers.** `emit --with` of this
  file alone defines its OWN `static Kopf Kopf_speicher;` beside the
  decoder's — linking per-file objects would split-brain the firewall
  (decode writes one copy, decide reads the other). Composition MUST be
  `emit --unit` (one `Kopf_speicher`, one `Regel_speicher`, one
  `UHR_TICK` — verified in the output). The `Makefile`'s `bau/%.c`
  per-file pattern cannot carry shared tables; the lauf lane owns that
  reckoning.
- **`kosten` does not follow `use`.** `kosten --unit` and `kosten --with`
  both report `OFFEN -- … is not declared here` for cross-file callees.
  The numbers in this lane come from a scratch mirror (`.tmp/bm8/spiegel.gab`:
  same bodies, `use` lines replaced by verbatim interface copies) whose
  computed values transfer exactly — same text, same declared callee
  costs. The mirror is scratch, the promises in `gab/entscheidung.gab`
  are its measured output.
- **Three E247 hints stand** (Kopf/Regel/UHR_TICK read without a
  signature guard): the no-lock disciplines of the pakete/regeln lanes
  and the atomic discipline of the counters lane, each documented there.
  Hints, not refusals; silencing them with a lock would invent a
  cross-lane contract by side effect.
