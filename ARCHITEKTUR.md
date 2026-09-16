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
| `gab/systemrufe.gab` | every `syscall` declaration: socket, bind, sendto, recvfrom, mmap, clone, futex, exit_group, clock_gettime | the modules above |
| `gab/netzverbindung.gab` | the netlink/NFQUEUE protocol: config messages, parsing a packet out of a netlink message, building the verdict message | the modules above |
| `gab/lauf.gab` | `main`, the buffers, the worker threads via `clone`, the receive loop, the rule file | the internals of any of them |
| `gab/sperre.gab` | the lock primitive: `VSPERRE_NEXT`/`VSPERRE_NOW` and `VSPERRE_nimm`/`VSPERRE_gib` (ticket lock) | everything (standalone file, no lock declaration inside) |

**Lane bm11 amendments** (no shape above changed):

- **Transports ride on pointers.** The `u64`-address syscalls stay for
  what the kernel hands back (`mmap`, raw shapes). `bind`/`sendto`/
  `recvfrom` additionally exist as `ptr` variants (`roh_binden2` etc. in
  `gab/systemrufe.gab`), naming `gab/netzverbindung.gab`'s tables through
  `use` (checked single-file with the generated `bau/netz.gabi` --
  Makefile). The pointer is always a parameter from the owning module;
  `gab/systemrufe.gab`'s TU-local copies are never referenced. File
  descriptors, counts and lengths still cross every boundary as values.
- **The lock implementation lives apart from the lock.** `N042` refuses a
  bodied `VSPERRE_nimm` beside `lock VSPERRE` in one unit, so
  `gab/sperre.gab` holds the bodies and no lock declaration; per-file emit
  plus the C link resolve the pair. The bodies follow
  `laufzeit/sperre.gab` shape for shape (N323 cannot see split files --
  residue named in `messung/BEFUNDE-bm11.md`).
- **Config asks, verdicts do not.** The four config builders set
  `NLM_F_REQUEST|NLM_F_ACK` so `einrichten` reads four ACKs; `baue_urteil`
  keeps REQUEST alone (an ACK per verdict would flood the receive path).

## There is no C. The border is the kernel ABI.

**Nothing in this project is written in C.** The compiler emits C and `cc` compiles it, and that
is the compiler's business, not ours. Everything this program does to the outside world it does
with a **system call**, declared in Gabbro:

```
syscall socket(domain : u64, typ : u64, proto : u64) -> u64 or NetzFehler
    abi linux arch x86_64 number 41
    regs in { rdi = domain, rsi = typ, rdx = proto }
    regs out { rax }
    clobbers { rcx, r11 }
    errors { EAFNOSUPPORT => FamilieFehlt, EMFILE => ZuVieleDateien }
    effects { pure }
    assume linux_socket_contract falsifier sonde_socket;
```

That is the whole border: the number, the register map, the errno decoding, and a NAMED
assumption about what the kernel promises. `beispiele/90-syscall-errno.gab` in `muster/` is the
worked example; `doku/SYNTAX.md` §12.1 is the rule.

**The entry point is a Gabbro function called `main`** — it emits `int32_t main(void)`, which is
how this becomes a program you can run. Threads come from the `clone` system call, memory from
`mmap`, waiting from `futex`, time from `clock_gettime`. No libc call is written by us.

## What "the kernel part" means here

Not a configuration frontend. **The deciding engine itself.** The kernel's netfilter hook hands
every packet to this program over a netlink socket (NFQUEUE), and this program — decoding,
rule matching, connection tracking, verdict — is what decides. The single `nft` line that
attaches the hook is configuration, the way a cable is configuration.

*The other reading of "the kernel part" is a loadable kernel module. That is a different
project: the module skeleton is C macros and the kernel's own build system, and this one is
about what Gabbro can carry on its own.*

## Order of work

1. `pakete.gab` and `zaehler.gab` can start immediately — they depend on nothing.
2. `regeln.gab` needs the `Kopf` shape above, not the decoder's code.
3. `verbindungen.gab` needs the key rule above, not the decoder's code.
4. `systemrufe.gab` can start immediately — it is declarations, and it blocks the two below it.
5. `netzverbindung.gab` needs the syscall signatures, not their bodies.
6. `entscheidung.gab` and `lauf.gab` come last: they are the wiring.
