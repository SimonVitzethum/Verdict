# Befunde bm7 — where the language said no (or nothing)

Lane bm7, `gab/lauf.gab`. Every entry below is something the tool actually
said, pasted verbatim, with the source shape that produced it. All runs with
`./werkzeug/gabbro` from the tree root. Probes lived in `.tmp/sonde/` and are
not committed; the shapes that survived stand in `gab/lauf.gab`.

Numbering: L (lauf lane). K-1 is cited, not re-measured: it belongs to lane
bm5 (`messung/BEFUNDE-bm5.md`) and this lane builds on its verdict.

## L-1 — no address-of: a table's address cannot reach a `u64` parameter (M127)

This is the load-bearing wall of the whole driver lane. The border
(`gab/systemrufe.gab`) takes every address and length as `u64`: `bind`,
`sendto`, `recvfrom`, `mmap` (return), `futex`, `clock_gettime`, `write`. The
language offers no address of a table or a variable for it. Probe
`.tmp/sonde/adr1.gab`:

```gabbro
table Puffer count 64 {
    slot {
        byte : u32 in 0 .. 255,
    }
}

impl fn nimm_adresse() -> u64
    effects { pure }
{
    let a : u64 = &Puffer;
    return a;
}
```

```
error: [M127] .tmp/sonde/adr1.gab:12:19: `&Puffer` does not name a function
   12 |     let a : u64 = &Puffer;
      |                   ^^^^^^^
      = `&` makes a FUNCTION into a value; there is no address-of for a variable or a type in Gabbro
```

(`doku/SYNTAX.md` §3 still describes `&T` as the producer of a `ptr` to a
declared carrier; the binary refuses it. The document and the tool disagree,
and the tool decides.)

Consequences, each carried openly in `gab/lauf.gab` instead of worked around:

* `netz_binden` cannot be fed: the 16-byte `sockaddr_nl` cannot be built at a
  nameable address. The file does not call `bind`; the kernel autobinds on the
  first `recvfrom` (UNMEASURED here — no root, see BERICHT-bm7.md).
* `netz_senden` / verdict bytes cannot be fed (additionally bm6's module, which
  would own the bytes, is not in this clone).
* `bericht_schreiben` cannot be fed: statistics text cannot be handed to
  `write`. Counters live in `LaufStand`; the shutdown reason travels in the
  exit status, which is a value, not an address.
* `sperre_warten`, `sperre_wecken`, `zeit_lesen` cannot be fed (no word address,
  no `timespec` address). No futex waiting, no clock reads from this file.
* The only addresses the file holds are the ones the kernel hands back as
  `u64`: the `speicher_karte` return, passed to `netz_empfangen` as the receive
  buffer. Reading the received bytes back out of that memory from Gabbro is
  impossible for the same reason (no dereference of a `u64`), so the loop
  counts datagrams, not packets — the parse/record/decide/arm belongs to lanes
  bm6/bm8, and the exact insertion point stands in a comment in `arbeite`.

Rejected alternative: naming the emitted C symbol (`LaufStand_speicher`) from
an `asm` body. Writable as text, unchecked, and it would reimplement the
border behind `systemrufe.gab`'s back. Not built.

L-1 hits lanes bm6 and bm8 identically: neither can move bytes between a table
and a syscall without an address-of either.

## L-2 — no `open`/`read` in the border: the rule file is unwritable

`gab/systemrufe.gab` declares ten calls: socket, bind, sendto, recvfrom,
mmap, clone, futex, clock_gettime, exit_group, write
(measured: `gabbro abi gab/systemrufe.gab`, 13 `pub const` + 11 `pub extern fn`,
no file calls). There is no `open`, no `openat`, no `read`. A rule file "read
through `read`" therefore has no border to go through, and this lane may not
add a second border (another module's file).

Consequence: `lade_grundregeln` loads a compiled-in default policy —
`raeume_alle()` plus one `setze_regel` (ACCEPT TCP to destination port 80),
everything else falling through to STANDARD (DROP). Fail closed. The brief's
fallback, stated as the design: a firewall nobody configured drops.

## L-3 — neither `retry` shape lowers to C (C001, twice)

`retry ... until` checks clean (probe `.tmp/sonde/rt1.gab`: 0 errors,
0 hints) but emission refuses it:

```
error: [C001] gab/lauf.gab:197:5: no lowering: `bounded … ops` -- the per-pass cost is not fixed, so the budget yields no iteration count
  197 |     retry versuch until fertig
      |     ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
      = the emitter refuses by name instead of emitting something plausible -- a generator that guesses undoes every pass in front of it
```

and `retry` without `until` (probe `.tmp/sonde/rr1.gab`) is refused the other
way:

```
error: [C001] .tmp/sonde/rr1.gab:8:5: no lowering: `retry` without `until` -- nothing bounds the condition
```

So no `retry` form reaches C in this binary (the `sperre-muster.gab` in
`muster/` is checker evidence, not emitted product). The startup NOCHMAL retry
therefore runs as a counted `forever` loop with `leave` (64 attempts), which
checks AND emits (probe `.tmp/sonde/fw2.gab`: emit exit 0). The counter and
the `leave` stand in the body instead of in the loop form; the comment at the
loop says so.

## L-4 — `use` needs a unit; mirrors keep the single-file gate green (H021)

Calling the border through `use systemrufe::netz_socket;` is refused by a
single-file `pruefe` (probe `.tmp/sonde/p3.gab`):

```
hint: [E009] .tmp/sonde/p3.gab:3:13: the call effects of `main` are undecidable: `netz_socket` is unknown to the graph
    3 | pub impl fn main() -> i32
      |             ^^^^
      = the effect set is only a LOWER bound here -- no completeness follows from it
      = what still IS checked below: every effect the PARTIAL hull already contains must be declared -- a lower bound refutes, it just cannot confirm
error: [H021] .tmp/sonde/p3.gab:3:13: `main` calls `netz_socket`, and `netz_socket` is unknown to the graph -- the edge carries nothing across
    3 | pub impl fn main() -> i32
      |             ^^^^
      = the derivation drops the edge and records a lower bound instead -- and a lower bound is not an answer
      = compare `E009`: a hint where the target is merely imprecise -- here there is no target at all
```

(`pruefe --with sys.gabi` accepts the same file with 0 errors, 0 hints, so
the `use` spelling is right; the single-file gate of this lane and of the
`Makefile` target `pruefen` is what forbids it.) The file therefore declares
local `extern fn` mirrors with C-identical prototypes; `emit` writes plain
prototypes plus calls, and the unit links against the emitted `systemrufe` and
`regeln` units. The prototype identity is diffed in BERICHT-bm7.md. The
`index into Regel` parameter of `setze_regel` lowers to `uint32_t` and travels
as a plain `u32` here — same C, weaker Gabbro type, stated here instead of
hidden.

Two companion refusals met on the way there, both answered by house
convention:

* `leave;` without a label is `P003` (`identifier expected, `;` found`):
  `leave` names its loop, so both `forever` loops carry labels (`start`,
  `runde`).
* a `pub` function whose `effects` name a non-`pub` table is `N038` (`main` is
  exported and names `Stand`, which is not). All tables and constants of the
  file are `pub`, as in every other lane.

## L-5 — no `sigaction` in the border: shutdown is a counter threshold

Same class as L-2, no checker involved: none of the ten syscalls installs a
signal handler, so "shutdown on a signal" has no border to go through.
`arbeite` leaves its `forever` loop when `pakete >= GRENZE` (rebuild to tune)
or when the receive path dies, and `main` ends through `anhalten` with the
shutdown reason as the status (0 clean, 1 drops seen, 120 receive dead;
110/111 for dead startup). Signal handling stays future work for the border
lane.

## L-6 — two E247 footprint hints, deliberate (bm2 precedent)

```
hint: [E247] gab/lauf.gab:169:16: `LaufStand` is read by the body of `arbeite` but no signature lock guarding it is held, and some function writes it
hint: [E247] gab/lauf.gab:261:8: `LaufStand` is read by the body of `main` but no signature lock guarding it is held, and some function writes it
```

One worker, one row, loader before loop: no second thread exists that could
take the lock, so a `lock ... protects { LaufStand }` would be a contract
nobody takes. `gab/regeln.gab` commits three identical hints on the same
reading (`messung/BEFUNDE-bm2.md` §2); this file follows it. Hints, not
errors: `pruefe` exits 0.

## Cited, not re-measured

* **K-1** (`messung/BEFUNDE-bm5.md`): `clone` is declarable, the child handoff
  ("the child runs on the handed stack and must never return into the caller's
  frame") has no checked shape. Hence one worker, queue 0, no `faden_start`
  call. Scale-out is a root procedure (one process per queue, BERICHT-bm7.md),
  not a second thread.
* **N-2** (`messung/BEFUNDE-bm5.md`): a caller that promises `costs` over a
  `syscall` call is refused (K003). All callees behind the mirrors declare no
  `costs`, so `gab/lauf.gab` carries no `costs` line anywhere; `gabbro kosten`
  reports three sites OFFEN (see BERICHT-bm7.md).
