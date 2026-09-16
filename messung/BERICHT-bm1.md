# BERICHT-bm1 — packet decoder (`gab/pakete.gab`)

Lane bm1, branch `master`. Module checks clean, emits C, the C compiles at
-O0 and -O2 under `cc -std=c11 -Wall -Wextra -Werror`, and a functional
harness with 10 crafted-frame groups passes at -O0, -O2 and under
ASan+UBSan.

## 1. What the module does

`pub impl fn entpacke(laenge : u32 in 0 .. 1600) -> u32 in 0 .. 1`,
`effects { reads Paket.slots, writes Kopf.slots }`, `costs <= 200 ops`
(computed 189, see §3). It decodes IPv4 over Ethernet from the driver-filled
`Paket` table into `Kopf.slots[0]` exactly in the ARCHITEKTUR.md shape and
answers 1 (decoded) / 0 (malformed):

- Ethernet: needs 14 bytes; EtherType at 12/13 must be `0x0800`, else malformed.
- IPv4 fixed fields need 34 bytes (offsets 14..33): version must be 4
  (`vio >> 4`), IHL must be >= 5 (`vio & 15`); `hlen = ihl * 4` (20..60) and
  the whole header (`14 + hlen` bytes) must be present.
- Total length (16/17), fragment data (20/21: MF bit, offset), protocol (23),
  source/destination addresses (26..29, 30..33, big-endian bytes assembled
  into one `u32` each) are decoded.
- TCP (6): refuses fragments (MF set or offset nonzero — L4 ports of a
  fragment would be a guess, not a read); needs `bo + 14` bytes; ports at
  `bo..bo+3`, flags byte at `bo+13`, where `bo = 14 + hlen`.
- UDP (17): same fragment refusal; needs `bo + 4` bytes; ports only.
- ICMP (1): ports 0, flags 0; fragments allowed (nothing fragment-dependent
  is decoded).
- Any other protocol: malformed (refuse, never interpret).
- Write discipline: exactly one dynamic table write per field per call —
  either all eight fields zeroed in the `ungueltig()` helper (every malformed
  path funnels through `return ungueltig();`), or all eight decoded at the
  single exit. A malformed packet therefore never leaves stale fields behind
  (verified, §5 item 10).

## 2. What the checker said (verbatim)

```
$ ./werkzeug/gabbro pruefe gab/pakete.gab
gab/pakete.gab: 5 items, 0 errors, 0 hints
  M1 saw 280 expressions, 0 of them without a type (100 % coverage)

Not checked in this run: 9 passes -- 0 open, 9 CARRIED (the rest is NAMED), 0 only partial
  2 D1/D2, 4 M3, 5 M2, 12 Sperren, 11 Phasen, 7 Paarung, 8 effects, 10 Gruppe, 9 costs
  register 4dd17209 -- the FULL text with `gabbro pruefe --paesse` or `gabbro paesse`
  it is a property of this BINARY, not of the file just checked -- and it did not shrink, it moved
```

No refusal was ever produced by this module: the first full draft checked
with 0 errors, 0 hints, and the only later diagnostic was a `K001` costs
correction on a scratch experiment (promised 16, body 17), fixed by measuring
first. There is therefore no `messung/BEFUNDE-bm1.md` — nothing was refused,
so there is nothing to record with code and message.

```
$ ./werkzeug/gabbro kosten gab/pakete.gab
-- site	computed	promised	slack
ungueltig	8	16	8
entpacke	189	200	11
-- 2 bodies computed, 0 open, 0 derived.
```

The `costs <= 200` bound was copied from the tool's `computed 189`, plus 11
headroom — not guessed (first draft said 400, tightened after measuring).

## 3. Emitted C at the interesting places

`./werkzeug/gabbro emit gab/pakete.gab` exits 0 (173 lines). Tables lower to
static storage addressed by name; the function keeps its name for the driver:

```c
static Paket Paket_speicher;
static Kopf Kopf_speicher;
uint32_t entpacke(uint32_t laenge);
```

The `narrow bo to 0 .. 1599` index evidence becomes the only runtime cost of
the range system besides the real length checks:

```c
    if (!(bo <= 1599)) {
        return ungueltig();
    }
```

IHL-derived offsets lower to plain indexed reads, e.g.
`Paket_speicher.slots[bo + 13].byte` for the TCP flags. The length checks
compare directly against the `laenge` parameter (`if (laenge < bo + 14)`).
Both `cc -std=c11 -Wall -Wextra -Werror -O0 -c` and `-O2 -c` pass silently.

## 4. What I could NOT write — nothing refused, three judgment calls

No checker refusal stands against this module. The following are deliberate
decisions, not workarounds; each weakens nothing, each refuses rather than
guesses:

1. **Unknown IP protocol → `gueltig = 0`.** ARCHITEKTUR.md names only 6/17/1.
   Decoding e.g. GRE ports as if they were TCP ports would be interpretation.
2. **TCP/UDP fragments → `gueltig = 0`.** A non-first fragment carries no
   valid L4 ports at the IHL-derived offset; MF/offset are read from bytes
   20/21 and any fragment is refused for TCP/UDP. ICMP fragments still decode
   (ports are 0 by definition).
3. **The IP total-length field is decoded as-is** into `Kopf.laenge` with no
   consistency check against the `laenge` argument. A lying length field with
   all reads still inside `laenge` decodes; no out-of-bounds read can result
   from it. If the lanes want `tot != laenge`-style strictness, that is a
   one-`if` change with a documented DROP cost for padded captures.

## 5. Measurement (all run, all pasted from the tools)

Functional harness `.tmp/test_pakete.c` (scratch, gitignored) `#include`s the
emitted C and drives `entpacke` directly — 10 groups, all passing at -O0,
-O2 and under `-fsanitize=address,undefined`:

1. TCP SYN (60-byte frame): all 8 Kopf fields exact
   (quelle 3232235786, ziel 167772161, qport 12345, zport 80, flaggen 2).
2. UDP (proto 17, ports 53/5353, flags 0). 3. ICMP (proto 1, ports 0).
3. Truncations refused, boundary exact: len 13/33/47 → 0, len 48 → 1.
4. ARP EtherType 0x0806 → 0. 6. Version 6 and IHL 4 → 0.
5. GRE (proto 47) → 0. 8. MF-set and nonzero-offset TCP fragments → 0.
6. IHL=6 with 4 option bytes: ports/flags correctly read at offset 38.
7. Stale-field check: good decode then `entpacke(5)` leaves all 8 fields 0.

`make pruefen` prints `gab/pakete.gab  ok`.

## 6. What I did not measure

- No fuzzing beyond the 10 hand-built vectors (no truncated-length sweep over
  all 0..60, no randomized frames).
- No timing/performance figures; `costs` is static ops, not cycles.
- No interaction with other lanes: `regeln/entscheidungen/...` do not exist
  yet in this clone, so cross-module agreement (Kopf field use, driver call
  convention) is by reading ARCHITEKTUR.md only.
- No multithreading test: `Kopf ... per worker` is the driver's (`lauf.gab`)
  business; this module touches only its own two tables.
- The `tot`-vs-`laenge` mismatch (§4.3) was decided, not measured against traffic.
