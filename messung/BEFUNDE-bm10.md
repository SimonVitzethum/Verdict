# Befunde bm10 — where the language said no (or nothing)

Lane bm10, `gab/lauf.gab` (decision chain), `gab/pakete.gab` (`setze_paket`),
`gab/verbindungen.gab` (`suche_nur`), `gab/entscheidung.gab` (verdict gating).
Every entry below is something the tool actually said, pasted verbatim, with
the source shape that produced it. All runs with `./werkzeug/gabbro` from the
tree root. Probes lived in `/tmp/opencode/` (scratch, not committed); the
shapes that survived stand in `gab/`.

Numbering: T (transport/runtime lane). L-1, K-1, N-2 are cited, not
re-measured: they belong to lanes bm5/bm7 and this lane builds on them.

## T-1 — the transport in both directions has no producer (M127 + M140)

The brief asks for `bind` + `sendto` (config, verdict) fed from tables, and
`recvfrom` bytes lifted out of mmap'd memory. Both need a table's address as
a `u64`, or a `ptr` value. Neither has a producer in this binary.

**Shape 1: `&T` as a `u64`** (probe `probe1.gab`, re-measured 2026-09-16 --
same wall as BEFUNDE-bm7.md L-1, same code):

```
error: [M127] /tmp/opencode/probe1.gab:8:19: `&Puffer` does not name a function
    8 |     let a : u64 = &Puffer;
      |                   ^^^^^^^
      = `&` makes a FUNCTION into a value; there is no address-of for a variable or a type in Gabbro
```

**Shape 2: `&T` as a `ptr`** (probe `probe2.gab`): the same M127, at the
`ptr`-typed binding. `doku/SYNTAX.md` §3/§4 documents `&T` as the one
producer of a `ptr` (`Expr.ptrOf`); the binary refuses it. Document and tool
disagree, tool decides.

**Shape 3: a `syscall` taking `ptr`** (probes `probe3.gab`/`probe3b.gab`):
the declaration itself checks clean (0 errors, 0 hints) and emits a stub
taking `Puffer *` -- but no caller can produce the argument. Passing the
table name is refused:

```
error: [M140] /tmp/opencode/probe3b.gab:16:22: argument `p` requires `ptr<…> probe::p3b::Puffer`, the value has `probe::p3b::Puffer` -- a table does not answer for a pointer
   16 |     let v = roh_nimm(Puffer) else (e) { return 0; }
      |                      ^^^^^^
```

So the honest split stands as lane bm7 drew it, now with both halves
measured on this binary: builders/parsers/copies/decisions are Gabbro
(`behandle` is real code), the three transports (`bind`, `sendto`,
mmap-read) are not writable. `gab/lauf.gab` mirrors exactly what it calls
and deliberately NOT `lege_empfang`, `netz_binden`/`netz_senden`, or the
config builders (each overwrites `Senden` from slot 0 -- building without
the withheld `sendto` between builds would be theatre). No theatre call
(`bind(fd, 0, 0)` with literals would check and do nothing) was added.

## T-2 — `WARTESCHLANGE` meant two things (cc, not the checker)

`gab/lauf.gab` (queue NUMBER, 0) and `gab/netzverbindung.gab` (queue DEPTH,
1024) declared the same `pub const` name. Per-file `pruefe` is green on both;
the composed harness refused at `cc`:

```
In file included from harness2.c:26:
lw/lauf.c:33: error: "WARTESCHLANGE" redefined [-Werror]
   33 | #define WARTESCHLANGE 0u
In file included from harness2.c:25:
netzverbindung.c:65: note: this is the location of the previous definition
   65 | #define WARTESCHLANGE 1024u
```

Fixed in Gabbro, in the lane's own file: lauf's constant is now
`WARTESCHLANGEN_NR` (with the collision named at the declaration). No logic
changed. Lesson for the next lane: `pruefe` is per-file; the C name
namespace is project-wide, and nothing but the link checks it.

## T-3 — lock primitives cannot be defined beside the lock (N042)

The shipped runtime would define `VSPERRE_nimm`/`_gib` (futex-based, no
libc) in the language. Probe `pc.gab` (a lock plus same-named functions):

```
error: [N042] /tmp/opencode/pc.gab:11:13: `VSPERRE_gib` is the C name of two different declarations
   11 | pub impl fn VSPERRE_gib()
      |             ^^^^^^^^^^^
      = the generator forms `VSPERRE_gib` here as `{fn}` -- the function
      = and it forms the same name as `{Lock}_gib` -- the release primitive
      = the lowering goes to C and there is no renaming in between -- what stands in Gabbro stands in C, plus a suffix the generator adds
      = measured 2026-08-31 with `cc -std=c11 -O0 -Wall -Wextra -Werror`; the nine forms and their probes stand in `messung/ERZEUGERNAMEN.md`
      = rename one of the two -- the name is fine everywhere except where the other declaration stands next to it
```

(plus the `VSPERRE_nimm` twin). Renaming is no fix: the call sites the
`locks` blocks emit are fixed names. A ticket lock in Gabbro
(`muster/sperre-muster.gab`) checks AND emits (exit 0, this lane) but
cannot be wired to `lock VSPERRE`; `futex` needs a word address (T-1).
Hence the stub (`VSPERRE_nimm`/`_gib` + the four diverging exits) stays
scratch and out of the tree, as the brief orders. The `treiber/` lane is
real future work, not a rename.

## T-4 — diverging exits cannot be defined in Gabbro either (H022/K008, C001, cc)

Three shapes tried for a `-> never` exit without hand-written C:

**Recursion** (probe `pf.gab`: `anhalten(1); treffer_aufgegeben();` --
exit_group never returns, so the recursion is unreachable at run time):

```
error: [H022] /tmp/opencode/pf.gab:3:13: `treffer_aufgegeben` stands in a call cycle and declares no `decreases`
error: [K008] /tmp/opencode/pf.gab:3:13: `treffer_aufgegeben` reaches itself and declares no `decreases`
```

A `decreases` measure on an abort would be false advertising (it claims a
termination argument where none is owed), so none was written.

**`asm` without `out`** (probe `ph2.gab`): checks (0 errors, 0 hints) but
emission refuses:

```
error: [C001] /tmp/opencode/ph2.gab:2:13: no lowering: `asm` body returns a value but names no `out { result : … }`
```

**`asm` with `out`** (probe `ph3.gab`): emits (exit 0) -- but C the compiler
refuses:

```
ph3.c: In function ‘halt’:
ph3.c:22:20: error: variable or field ‘result’ declared void
   22 |     _Noreturn void result;
```

`-> never` lowers the `result` binder to `void`, and a `void` variable is
not C. Filed as an emitter bug (same class as BEFUNDE-bm5.md E-1/E-2:
`werkzeug/` is off-limits, so filed, not fixed). A non-`never` asm abort
would type a lie (it claims an answer it never gives) and cannot serve as
an `on_exceeded` watchdog (S006) anyway.

## T-5 — costs over a mirror call (K003, re-measured)

Probe `pe.gab` (a `costs` promise over an `extern` body):

```
error: [K003] /tmp/opencode/pe.gab:7:12: `ruf` promises costs, but the call to `fremd` declares no `costs`
    7 |     return fremd(x);
      |            ^^^^^^^^
      = a cost promise over an unknown quantity is a promise nobody can check
```

Same as BEFUNDE-bm5.md N-2. Consequence used across the lane:
`gab/lauf.gab` carries `costs` only on the three `sonde_*` (local bodies);
`behandle`, `arbeite`, `main` and `lade_grundregeln` carry none --
`gabbro kosten` reports them OFFEN (see BERICHT-bm10.md). A `syscall` item
has no `costs` clause in the grammar, so no lane can close this from its
side.

## T-6 — `--unit` is dead for the mirror construction (N042/N039)

```
error: [N042] gab/entscheidung.gab:142:10: `VSPERRE_gib` is the C name of two different declarations
error: [N042] gab/entscheidung.gab:142:10: `VSPERRE_nimm` is the C name of two different declarations
error: [N039] gab/entscheidung.gab:142:10: `VSPERRE` binds twice in this build: `brandmauer::verbindungen::VSPERRE` in this unit carries the same C name
```

`./werkzeug/gabbro emit --unit gab/pakete.gab gab/regeln.gab
gab/verbindungen.gab gab/zaehler.gab gab/entscheidung.gab` exits 1.
As BEFUNDE-bm9.md predicted: the composition check is the C prototype diff
(15/15 identical with the new `suche_nur`, see BERICHT-bm10.md) plus the
link -- per-file emits, one `cc` link. `make pruefen` (single-file gate)
is the checking half.

## Shapes that worked (no refusal, recorded so nobody re-probes)

- **u64 count to ranged call** (probe `pa.gab`, 0 errors, 0 hints):
  `if v > 8192 { return; } narrow v to 0 .. 8192 else { return; }` then
  `let meldung : u32 in 0 .. 8192 = u32(v);` -- the conversion call (G9)
  holds on the narrowed range. This is `arbeite`'s datagram gate.
- **`next` diverges a `narrow`-`else`** (probe `pb.gab`, 0 errors, 0 hints):
  `narrow v to 0 .. 8192 else { next runde; }` inside `forever runde`.
- **`extern fn` with ranged results** (re-used, still clean): all seven new
  lauf mirrors carry their owners' ranges; the copy loop needs no `narrow`
  at any call site except the index proof into `hole_nutzlast`.

## Silence worth writing down

- **`suche_nur` costs measured, not estimated:** computed 178, promised
  256, slack 78 (`gabbro kosten gab/verbindungen.gab`). All five bodies
  computed, 0 open -- the only fully-promised module of the firewall.
- **One new E247 hint in `gab/pakete.gab`** (9 instead of 8): `entpacke`
  reads `Paket` with no guard, and since this lane some function
  (`setze_paket`) writes it. Same no-lock-discipline class as the other
  eight; hints, not refusals -- `pruefe` exits 0.
- **`asm` checks but does not promise:** `ph2.gab` (0 errors, 0 hints) vs
  C001 at emission -- the checker/emitter split of BEFUNDE-bm7.md L-3 in a
  new shape.
- **`make` is red, `make pruefen` is green:** `bau/brandmauer` links
  `treiber/*.c`, and no `treiber/` dir exists (already noted in
  BERICHT-bm7.md). T-3/T-4 say why no Gabbro file can take its place yet;
  the Makefile was left untouched -- a green link today would need the
  hand-written C the project forbids.
