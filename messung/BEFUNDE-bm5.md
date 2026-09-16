# Befunde bm5 — where the language said no (or nothing)

Lane bm5, `gab/systemrufe.gab`. Every entry below is something the tool
actually said, pasted verbatim, with the source shape that produced it.
Numbered K (kernel/clone), F (foreign interface), E (emitter), R (retry),
N (costs/effects). All runs: `./werkzeug/gabbro` from the tree root,
file `gab/systemrufe.gab` unless a `.tmp/` probe is named.

## K-1 — clone is declarable; the child handoff is not (the project decision)

This is the finding the lane brief calls worth more than the rest of the
file. Three shapes were tried.

**Shape 1: `syscall` item.** Checks clean (still in the module):

```
syscall roh_klonen(kind : u64, stapel : u64, eltern : u64, kindspeicher : u64, tls : u64) -> u64 or NetzFehler
    abi linux arch x86_64 number 56
    regs in { rdi = kind, rsi = stapel, rdx = eltern, r10 = kindspeicher, r8 = tls }
    regs out { rax }
    clobbers { rcx, r11 }
    errors { EAGAIN => Wiederholen, ENOMEM => KeinSpeicher,
             EINVAL => FalscherWert, EPERM => Verboten }
    effects { pure }
    assume linux_faden_start_vertrag falsifier sonde_faden_start;
```

A wrapper distinguishing father from child also checks clean (probe
`.tmp/clone.gab`, 0 errors, 0 hints):

```gabbro
let v = clone(kind, stapel, eltern, kindspeicher, tls) else (e) { return 999; }
if v == 0 {
    return arbeiter();
}
return v;
```

**But the emitted C proves the shape is broken at run time.** The stub is
inline `syscall` inside the caller's C frame; after a stack-switching
clone the child returns into that frame on the NEW stack:

```c
static uint64_t starte(uint64_t kind, ...) {
    uint64_t v;
    { CloneFehler e; (void)e;
      if (!clone(kind, stapel, eltern, kindspeicher, tls, &v, &e)) { return 999; } }
    if (v == 0) {
        return arbeiter();   /* child: old frame, new stack -- corrupt */
    }
    return v;
}
```

The declaration is the honest half (number, registers, error map). The
handoff "the child starts on the stack from rsi and must never return
into the caller's frame" has no checked shape: no `syscall` clause names
the stack register as a stack, and no statement says "do not return here".

**Shape 2: `asm` body.** An `asm` function checks and emits (probe
`.tmp/asm1.gab`, 0 errors, 0 hints) — but only as opaque machine text.
First attempt, refused for two honest reasons:

```
error: [A001] .tmp/asm1.gab:1:9: `kind_einstieg` has an `asm` body but names no `arch`
    1 | impl fn kind_einstieg(stapel : u64) -> u64
      |         ^^^^^^^^^^^^^
      = the same instruction text does something else on another machine -- without `arch` this unit is silently wrong there
      = `aarch64` is sealed in this folder: `arch aarch64` is an error, not a gap
error: [A003] .tmp/asm1.gab:1:9: `kind_einstieg` has an `asm` body but no `costs`
    1 | impl fn kind_einstieg(stapel : u64) -> u64
      |         ^^^^^^^^^^^^^
      = without it the termination chain tears at this call
hint: [N026] .tmp/asm1.gab:3:7: this `asm` block declares no `clobbers memory`
    3 |     = asm {
      |       ^
      = `memory` is the DEFAULT here, not the exception -- without it the C compiler may move memory accesses across the block
```

With `arch x86_64`, `costs` and `clobbers { ..., memory }` it passes — yet
the checker still cannot see that rsp is reseated or that the old frame is
dead. Writable as text, not as a construct the language understands.

**Shape 3: `concurrent { }`.** The language's own thread story
(`muster/124-two-threads-private.gab`, driver `muster/start-muster.c`):
declared roots, threads started by a C runtime via pthread, not by
clone-from-Gabbro. Available to the `lauf` lane, at the price of a C
driver outside the language.

**Verdict:** the raw-clone child that runs a worker on a handed stack
cannot be written in checked Gabbro. `gab/systemrufe.gab` declares the
call and stops there; the file head and the `faden_start` comment say so.
If the project needs threads from inside the language, the fork is:
(a) a C driver starting `concurrent` roots (checked, hosted), or
(b) raw clone with the child entry in `asm` text (unchecked, native).

## F-1 — a `pub` wrapper cannot carry `or R` (N038 + P041)

The brief asks for `pub impl fn netz_socket() -> u64 or NetzFehler`.
That exact shape is refused (probe `.tmp/pubor.gab`):

```
error: [N038] .tmp/pubor.gab:15:43: `netz_holen` is exported and names `NetzFehler`, which is not -- the interface would point at something that does not travel
   15 | pub impl fn netz_holen(a : u64) -> u64 or NetzFehler
      |                                           ^^^^^^^^^^
      = an interface that names something and does not explain it is none: `gabbro abi` writes only what carries `pub`
      = either write `pub` at `NetzFehler`, or keep it out of the signature
```

and the suggested fix does not exist (probe `.tmp/wrap2.gab`):

```
error: [P041] .tmp/wrap2.gab:3:1: `pub` is not in the grammar here: `reason` carries no `[ "pub" ]`
    3 | pub reason NetzFehler {
      | ^^^
      = `[ "pub" ]` stands at twelve item kinds: module use const static type fn atomic table arena device format lock -- the parser accepted it everywhere and threw it away
```

`pub module systemrufe { ... }` around it changes nothing (probe
`.tmp/wrap3.gab`: same N038). Consequence: **no fallible function can be
exported** — the `or` channel stops at the module boundary by construction.
The module's answer: private `syscall` items keep `or NetzFehler`; the
eleven `pub` wrappers return `u64` and map every reason onto three
sentinels (`KEIN_WERT` terminal, `NOCHMAL` = EINTR/EAGAIN retry,
`PAKETE_VERLOREN` = ENOBUFS). The error detail stays inside the file; the
border contract is three numbers. That is a weakening to please the
checker, stated here instead of hidden.

## E-1 — emitter drops the out-parameter for a syscall without `or`

With `syscall roh_ende(status : u64) -> u64` (no `or`, `errors { }`) the
checker is happy but the emitted C does not compile:

```
.tmp/systemrufe.c: In function ‘anhalten’:
.tmp/systemrufe.c:1306:18: error: too few arguments to function ‘roh_ende’
 1306 |     uint64_t v = roh_ende(status);
      |                  ^~~~~~~~
.tmp/systemrufe.c:664:17: note: declared here
  664 | static uint64_t roh_ende(uint64_t status, uint64_t *_wert) {
      |                 ^~~~~~~~
```

The stub is emitted with a `uint64_t *_wert` out-parameter; the call site
is emitted without it. `werkzeug/` is off-limits, so this is filed, not
fixed.

## E-2 — emitter leaves `_grund` unused for an empty error map

With `-> u64 or NetzFehler` plus `errors { }` the call site is right but
the stub is not:

```
.tmp/exit2.c: In function ‘beenden’:
.tmp/exit2.c:40:67: error: unused parameter ‘_grund’ [-Werror=unused-parameter]
   40 | static bool beenden(uint64_t status, uint64_t *_wert, NetzFehler *_grund) {
      |                                                       ~~~~~~~~~~~~^~~~~~
```

Workaround used in the module: `roh_ende` carries `or NetzFehler` with a
single `errors { EINTR => Unterbrochen }` arm that is dead by kernel
semantics (exit_group does not return). The arm exists for the emitter,
not for the kernel; the file says so at the declaration. With it:
`pruefe` 0/0, `emit` 0, `cc -O0` 0, `cc -O2` 0 (probe `.tmp/exit3.gab`).

## R-1 — `retry ... on_exceeded` takes no endblock in this binary

`doku/SYNTAX.md` §8 grammars `on_exceeded ( ident | endblock )`, but the
reader takes only the identifier (probe `.tmp/retry.gab`):

```
error: [P003] .tmp/retry.gab:24:21: identifier expected, `{` found
   24 |         on_exceeded { return KEIN_WERT; }
      |                     ^
error: [P017] .tmp/retry.gab:25:17: assignment or call expected, `{` found
   25 |         effects { pure }
      |                 ^
      = E2: an assignment is not an expression
error: [P003] .tmp/retry.gab:26:5: identifier expected, `{` found
   26 |     {
      |     ^
```

and the identifier form demands a watchdog that never returns (probe
`.tmp/ret2.gab`):

```
error: [S006] .tmp/ret2.gab:12:21: `on_exceeded aufgabe` names a function that returns
   12 |         on_exceeded aufgabe
      |                     ^^^^^^^
      = the watchdog is the exit at which the bound touches reality -- if it returned, the loop would carry on and the bound would be a number without a consequence
      = declare it `-> never` or `effects { diverges }`; a `reason` value would need an error-return convention, and that is not decided
```

A value-returning retry wrapper (EINTR loop inside the border) would need
a `-> never` watchdog the project cannot provide without a C body from
another lane. Not built; EINTR/EAGAIN retry lives with the caller via the
NOCHMAL sentinel instead (see BERICHT-bm5.md).

## N-1 — recursion retries, but leaves an E009 hint

Bounded retry by recursion (`decreases versuche`) checks with 0 errors
but one hint (probe `.tmp/rec.gab`):

```
hint: [E009] .tmp/rec.gab:18:9: the call effects of `holen_versuch` are undecidable: cycle over `holen_versuch`
   18 | impl fn holen_versuch(a : u64, versuche : u32 in 0 .. 3) -> u64 or NetzFehler
      |         ^^^^^^^^^^^^^
      = the effect set is only a LOWER bound here -- no completeness follows from it
      = what still IS checked below: every effect the PARTIAL hull already contains must be declared -- a lower bound refutes, it just cannot confirm
```

Structural to any recursive wrapper, not curable from this side. The
module uses single-attempt wrappers instead (0 errors, 0 hints); the
retry policy is IN the sentinel contract, not in a loop.

## N-2 — wrappers carry no `costs` (K003)

A caller that promises `costs` over a `syscall` call is refused, because
a `syscall` item declares none (probe `.tmp/s3.gab`):

```
error: [K003] .tmp/s3.gab:30:13: `rufe` promises costs, but the call to `write` declares no `costs`
   30 |     let v = write(1, 2, 3) else (e) { return 0; }
      |             ^^^^^^^^^^^^^^
      = a cost promise over an unknown quantity is a promise nobody can check
```

All eleven wrappers therefore omit `costs`; `gabbro kosten` reports each
as `OFFEN -- the call to ... declares no costs`. The grammar gives a
`syscall` item no `costs` clause to write. Filed, not worked around.

## S-1 — the falsifier probes are struck, not run

`gabbro annahmen gab/systemrufe.gab` ends with:

```
-- 10 probe name(s) STRUCK: no program stands for them. A name without a program asserts the absence of a refutation -- the assumption holds, its falsifiability does not.
```

and `gabbro certificate` lists all ten assumptions as `UNCOVERED -- no
program for this probe`. The ten `sonde_*` functions exist (`-> bool`,
`pure`, `return true`) and satisfy the checker's shape (`N056`: a probe
that resolves in-unit answers `-> bool`), but the tool does not count
them as programs standing for the probes, and none of them refutes
anything at run time — they are shape without teeth. Class: not run.
Running a probe would mean performing the syscall it names, which needs
buffers and addresses owned by other lanes; the pairing exists so the
assumption is named, not so it is discharged.
