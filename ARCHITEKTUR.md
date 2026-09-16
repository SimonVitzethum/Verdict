# The split, so that parallel work does not collide

**One module per lane, one file per module, no lane edits another's file.** Where two modules
must agree on a shape (a decoded header, a verdict number), the shape is fixed HERE and both
sides read it from this file.

## The fixed shapes (agreed once, read by everyone)

**Verdicts** — one `u32`, and nothing else is a verdict:

| value | meaning |
|---|---|
| `0` | DROP — the kernel discards the packet |
| `1` | ACCEPT — the kernel continues |
| `2` | REJECT — discard and let the driver send an ICMP/RST (the driver does that, not Gabbro) |

**The decoded header** — what `pakete.gab` produces and everyone else consumes. A table
`Kopf count 1` per worker (one in flight per thread), with these slot fields:

| field | type | meaning |
|---|---|---|
| `gueltig` | `u32 in 0 .. 1` | 1 if decoding succeeded; 0 means "malformed", and a malformed packet is DROPped |
| `proto` | `u32 in 0 .. 255` | IP protocol: 6 TCP, 17 UDP, 1 ICMP |
| `quelle` | `u32` | source IPv4 address, host order |
| `ziel` | `u32` | destination IPv4 address, host order |
| `qport` | `u32 in 0 .. 65535` | source port, 0 for ICMP |
| `zport` | `u32 in 0 .. 65535` | destination port, 0 for ICMP |
| `flaggen` | `u32 in 0 .. 255` | TCP flags byte, 0 for non-TCP |
| `laenge` | `u32 in 0 .. 65535` | total IP length as decoded |

**The packet buffer** — `Paket count 1600`, one byte per slot (`u32 in 0 .. 255`), filled by the
driver before the decision runs. 1600 covers an Ethernet MTU with headroom; a longer packet is
truncated by the driver and decoded as far as it goes.

**Connection key** — the 5-tuple in canonical direction: the smaller (address, port) pair first,
so both directions of a flow hash to the same bucket, plus a direction bit carried beside it.

## The modules

| file | owns | must not touch |
|---|---|---|
| `gab/pakete.gab` | the packet buffer, decoding into `Kopf`, all bounds checks | rules, connections, counters |
| `gab/regeln.gab` | the rule table, first-match-wins matching, the default policy | decoding, connections |
| `gab/verbindungen.gab` | the connection table, its hash, states, timeouts, its lock | decoding, rules |
| `gab/zaehler.gab` | counters per verdict and per rule, atomics only | everything else |
| `gab/entscheidung.gab` | the one function the driver calls per packet; calls the four above | the internals of any of them |
| `treiber/*.c` | NFQUEUE, netlink, threads, verdict calls, the extern surface | any `.gab` file |

## The border to C

Every C function the Gabbro side calls is an `extern fn` with a named assumption. Keep that list
short and write it down in `messung/GRENZE.md`: each entry says what the C side promises and what
happens if it breaks that promise.

The driver calls exactly **one** Gabbro function per packet:

```
pub impl fn entscheide(laenge : u32 in 0 .. 1600, faden : u32 in 0 .. 15) -> u32 in 0 .. 2
```

— the packet already lies in the `Paket` table, the worker's index is `faden`, and the answer is
the verdict. Everything else is internal.

## Order of work

1. `pakete.gab` and `zaehler.gab` can start immediately — they depend on nothing.
2. `regeln.gab` needs the `Kopf` shape above, not the decoder's code.
3. `verbindungen.gab` needs the key rule above, not the decoder's code.
4. `entscheidung.gab` comes last and is small: it is the wiring.
5. `treiber/` runs in parallel with all of them — it needs only the one function signature.
