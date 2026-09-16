# Brandmauer — a Linux firewall written in Gabbro

**A working, multithreaded packet filter whose decisions are written in Gabbro, not in shell.**
Started 2026-09-16 as a real test of the language: not a demo, not a fragment — a firewall you
can put in front of a machine.

> This is a separate project. It uses the Gabbro compiler
> ([`werkzeug/gabbro`](werkzeug/gabbro), copied from the Gabbro tree) and nothing else of it.
> Nothing here edits the compiler; **where Gabbro refuses something, that refusal is a finding
> and gets written down** — it is the most valuable thing this project produces for the
> language.

## What it is

A **userspace firewall on NFQUEUE**: the kernel hands every packet of the configured hook to
user space, this program decides, and the kernel executes the verdict. That is a real firewall
path (not a simulation), and it puts every decision in Gabbro:

```
   kernel netfilter hook ──queue──► worker thread 0 ──► decision (Gabbro) ──► verdict
                         (fanout)   worker thread 1 ──► decision (Gabbro) ──► verdict
                                    worker thread N ──► decision (Gabbro) ──► verdict
                                                           │
                                            shared: rule table, connection table, counters
```

**One nft rule attaches it** (that rule is configuration, not the firewall):

```
nft add rule inet filter input queue num 0-3 fanout
```

## What is written in Gabbro, and what is not

| Part | Where | Why |
|---|---|---|
| packet decoding (Ethernet/IP/TCP/UDP → 5-tuple, flags, lengths) | **Gabbro** | `gab/pakete.gab` |
| the rule table and first-match-wins evaluation | **Gabbro** | `gab/regeln.gab` |
| connection tracking (fixed hash table, states, timeouts) | **Gabbro** | `gab/verbindungen.gab` |
| counters and statistics | **Gabbro** | `gab/zaehler.gab` |
| the per-packet decision that ties them together | **Gabbro** | `gab/entscheidung.gab` |
| the system calls: sockets, netlink, `mmap`, `clone`, `futex` | **Gabbro** | `gab/systemrufe.gab` |
| the NFQUEUE netlink protocol and the verdict message | **Gabbro** | `gab/netzverbindung.gab` |
| `main`, the worker threads, the receive loop | **Gabbro** | `gab/lauf.gab` |

**There is no C in this project.** The compiler emits C and `cc` compiles it — that is the
compiler's business. Everything this program does to the outside world it does with a system
call declared in Gabbro (number, register map, errno decoding, and a named assumption about what
the kernel promises); the entry point is a Gabbro function called `main`; threads come from
`clone`, memory from `mmap`, waiting from `futex`. *Where that turns out to be impossible, the
impossibility is the finding, and it gets written down with the compiler's own words.*

## Constraints this project works under (all measured, not assumed)

- **No dynamic memory.** Every table has a `count` fixed at compile time: the rule table, the
  connection table, the packet buffer. A firewall under load must behave when a table is full,
  and that behaviour is a decision written into the rules, not an allocation failure.
- **No standard library.** No `memcpy`, no queues, no strings. What is needed gets written.
- **Threads come from `clone`**, called as a system call from Gabbro, and the shared state is
  protected by locks and atomics the Gabbro side declares.
- **Costs and effects are declared.** Every function says what it writes and what it costs; the
  checker holds it to that. A packet path with an undeclared write does not compile.

## Layout

```
gab/          the firewall, in Gabbro
werkzeug/     the Gabbro compiler used here
doku/         the language and its grammar (copies)
muster/       worked examples from the Gabbro tree, including its runtime
messung/      what was measured, and every refusal met on the way
```

## Building

```
make            # checks every .gab, emits C, compiles and links the program
make pruefen    # the checker alone, over every module
make lauf       # a loopback test against a network namespace
```

## Status

Started 2026-09-16. Nothing is finished. What holds and what does not is measured in
[`messung/`](messung/), and every refusal of the compiler is recorded there with its code.
