# Findings lane bm6 (`gab/netzverbindung.gab`) — compiler refusals met while writing the NFQUEUE module

Every entry is something `./werkzeug/gabbro` actually said, against the
source shape that produced it. Probes live in `.tmp/bm6/` (gitignored);
only the resolutions stand in `gab/netzverbindung.gab`. Nothing below was
worked around silently.

## A-1 — `M127`: no address-of for a table — the sendto/recvfrom handoff is not expressible (genuine gap)

Shape (`.tmp/bm6/v11.gab`, `.tmp/bm6/v12.gab`):

```gabbro
pub table Empfang count 64 {
    slot {
        byte : u32 in 0 .. 255,
    }
}
pub impl fn adresse() -> u64
    effects { pure }
    costs <= 8 ops
{
    let p : u64 = &Empfang;
    return p;
}
```

Tool (`./werkzeug/gabbro pruefe`):

```text
error: [M127] .tmp/bm6/v11.gab:11:19: `&Empfang` does not name a function
   11 |     let p : u64 = &Empfang;
      |                   ^^^^^^^^
      = `&` makes a FUNCTION into a value; there is no address-of for a variable or a type in Gabbro
```

The call form (`sende_nachrichten(&Empfang, 64)` against an
`extern fn sende_nachrichten(adresse : u64, laenge : u64)`) fails identically
(`.tmp/bm6/v12.gab:12:30`, same code, same sentence).

Consequence, stated openly in the module head: this file builds config and
verdict bytes in `Senden` and parses datagrams out of `Empfang`, but the
`sendto`/`recvfrom` calls themselves — which need the buffers as `u64`
addresses for `netz_senden`/`netz_empfangen` from `gab/systemrufe.gab` — are
the driver lane's (`lauf.gab`). The driver drains `Senden` through
`hole_senden` and fills `Empfang` through `lege_empfang`; the address
formation at that boundary is outside the language. No syscall is
re-declared here, and no wrapper is duplicated: the needed signatures are
`netz_socket`, `netz_binden`, `netz_senden`, `netz_empfangen` in
`gab/systemrufe.gab`, referenced by name only.

## R-1 — `C001`: `retry` without `until` has no lowering

Shape (`.tmp/bm6/v1.gab` — checked clean under `pruefe`, 0 errors):

```gabbro
    retry schleife
        bounded 512 ops
        on_exceeded aufgegeben
        effects { reads Puffer, reads Puffer.slots, writes Puffer.slots }
    {
        ...
    }
```

Tool (`./werkzeug/gabbro emit`):

```text
error: [C001] .tmp/bm6/v1.gab:13:5: no lowering: `retry` without `until` -- nothing bounds the condition
   13 |     retry schleife
      |     ^^^^^^^^^^^^^^^^^^
      = the emitter refuses by name instead of emitting something plausible -- a generator that guesses undoes every pass in front of it
```

Resolution: every loop in the module is `retry <label> until <pred>
bounded <n> ops on_exceeded <ident> effects { ... }` (`.tmp/bm6/v2.gab`
proves the shape emits a bounded `for` with the overrun arm). The attribute
walk is `retry attr until versatz >= mlen bounded 300000 ops on_exceeded
netz_streit`. The bound is derived, not guessed: worst-case passes are
(8192 − 20) / 4 = 2043 minimal attributes; the emitter grants
bounded / per-pass iterations (144 here: `_r1 >= 2083u` in the emitted C),
and 2083 ≥ 2043, so `netz_streit` (`extern … -> never effects {
diverges }`, same shape as `zaehler_streit` in `gab/zaehler.gab`) is
unreachable. A 7640-byte message with 1900 minimal attributes plus header
and payload parses in the harness without firing it (BERICHT-bm6.md §5).

An earlier draft carried `bounded 250000 ops` (1736 iterations < 2043
worst-case passes) — caught by reading the emitted iteration count, fixed to
300000 before any test depended on it.

## W-1 — `M103`: a write through a narrowed index kills the narrow fact — re-narrow before every indexed write

Shape (`.tmp/bm6/v5.gab`, minimal):

```gabbro
    narrow o to 0 .. 60 else { return; }
    Empfang.slots[o].byte = w;        -- ok
    Empfang.slots[o + 1].byte = w;    -- ok
    Empfang.slots[o + 2].byte = w;    -- M103, index reported as u32 in 2 .. 65
    Empfang.slots[o + 3].byte = w;    -- M103, reported as u32 in 3 .. 66
```

Tool:

```text
error: [M103] .tmp/bm6/v5.gab:14:19: the index has `u32 in 2 .. 65`, the array has 64 elements
   14 |     Empfang.slots[o + 2].byte = w;
      |                   ^^^^^
      = M4: no unchecked indexing -- the bound comes from the declaration of the carrier
```

Measured behaviour (`.tmp/bm6/v3`–`v8.gab`): any number of *reads* through
one narrowing is fine (also `pakete.gab`'s whole decoder, which reads only);
indexed *writes* through it stop checking after two. This is SPRACHE.md
§3.2's rule made visible — the fact set dies on a write to a participating
place, and the index participates in the written place. Resolution: narrow
again before every indexed write (`.tmp/bm6/v8.gab`, 0 errors). The module
does this at each multi-byte store site; each re-narrow emits one runtime
bounds check, which is the firewall's defence in depth, not overhead to
optimise away. Stores at literal indices need no narrowing (no place
involved) and are used wherever the layout is static (all builders).

## F-1 — `M147`: carrier-derived names do not cross the retry boundary — re-read after the barrier

Shapes in `gab/netzverbindung.gab` (`suche_paket`): `mlen` (assembled from
`Empfang.slots[0..3]` before the walk) compared inside the walk
(`if ende > mlen`), and `typ` (from `Empfang.slots[4..5]`) passed to
`ergebnis_leer` after the walk — although nothing in the walk writes
`Empfang`:

```text
error: [M147] gab/netzverbindung.gab:551:19: `mlen` may be stale here: its carrier was written since `mlen` was read
  551 |         if ende > mlen {
      |                   ^^^^
      = re-read the carrier into this name after the write -- the re-read IS the refresh; storing or moving the name needs none, acting on it does
```

(plus six identical lines for `typ` at the three post-walk error paths).
Minimal reproduction: `.tmp/bm6/v13.gab`. The `until` predicate itself was
never flagged, and storing a stale name (`Ergebnis.slots[0].typ = typ;`)
needs no refresh — only acting on it (comparing, passing as an argument)
does, exactly as the message says.

Resolution, following the message: `mlen` is re-read every pass into
`mlen_now` (same bytes, fresh name) and `typ` is re-read after the walk
into `typ_now`. This is the same V4/M147 discipline `gab/verbindungen.gab`
documents ("Die Lesung steht NACH den Schreibungen … gelesen danach").

## K-1 — `K001`: cost promises below the computed cost (routine)

Every promise in the file is a measured number (`gabbro kosten`), never an
estimate. Shapes met while writing: `fuelle` 512→514 (probe),
`lies_u32be` 32→33 (probe), `baue_merkmale` 128→149 and `baue_urteil`
128→145 after the `drehe32`/`drehe16` calls made the byte serialisation
honest (see M-1). Final table, all green:

```text
drehe32	31	32	1        drehe16	11	16	5
lege_empfang	3	4	1    hole_senden	2	4	2
hole_nutzlast	15	16	1  ergebnis_leer	10	16	6
baue_binden	51	56	5  baue_werte	101	112	11
baue_wartelang	96	104	8  baue_merkmale	149	160	11
baue_urteil	145	152	7  suche_paket	300110	301000	890
```

## M-1 — no checker refusal: the harness caught a double byte-swap (measurement finding)

The first complete draft assembled big-endian payloads most-significant-byte
first (`k0 * 16777216 + …`) and *then* called `drehe32` — swapping twice.
`pruefe` was green (0 errors): both the assembly and the swap are
range-correct in isolation. The C harness (BERICHT-bm6.md §5) failed 12
checks in one pattern: `gib_kennung`/`gib_reihung` wrong, single-byte fields
right.

The module now keeps one rule, stated in its head comment: header fields
assemble low-byte-first (host order); attribute payloads assemble
low-byte-first and run through `drehe32`/`drehe16` — the swap IS the
big-endian interpretation, in both directions (serialising swaps first,
then splits low-byte-first). `drehe32`/`drehe16` are load-bearing at six
call sites (res_id read, packet-id read, copy-range/maxlen/mask/flags,
queue-id/verdict/packet-id writes), tested directly (8 vectors) and through
every message test. A conversion that is never called would be decoration;
this one cannot be removed without breaking the wire format.

## H-1 — hint `E247` (11×): noted, not obeyed — per-worker buffers carry no lock

```text
hint: [E247] gab/netzverbindung.gab:255:12: `Ergebnis` is read by the body of `gib_haken` but no signature lock guarding it is held, and some function writes it
  255 |     return Ergebnis.slots[0].haken;
      |            ^^^^^^^^^^^^^^^^^^^^^^^
      = the footprint carries what the contract saw: every written carrier wants a `requires Held(L)` guard over a `lock L protects` line, not merely a `reads` or `writes` entry in `effects`
```

All 11 hints of the final file are this one (one per reader over
`Empfang`/`Senden`/`Ergebnis`). Same standing as BEFUNDE-bm2.md §2: each
worker owns its queue and its buffers, ARCHITEKTUR.md names no lock for
this module, and adding one would impose a contract on the driver and
decision lanes by side effect. The discipline is stated in the file head
instead.
