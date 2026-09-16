YOUR MODULE: `gab/systemrufe.gab` — the border to the kernel, and nothing else. **Every other lane waits on your signatures**, so declarations first, wrappers second.

Declare, as `syscall` items (the worked example is `muster/90-syscall-errno.gab`, the rule is `doku/SYNTAX.md` §12.1 — number, `regs in`, `regs out`, `clobbers`, `errors`, a named `assume` with a falsifier):

| call | number (x86_64) | what the firewall needs it for |
|---|---|---|
| `socket` | 41 | the netlink socket: `AF_NETLINK` (16), `SOCK_RAW` (3), `NETLINK_NETFILTER` (12) |
| `bind` | 49 | binding the netlink address |
| `sendto` | 44 | configuration messages and every verdict |
| `recvfrom` | 45 | receiving queued packets |
| `mmap` | 9 | the per-thread receive buffers and the thread stacks |
| `clone` | 56 | the worker threads |
| `futex` | 202 | waiting without spinning, where a lock must block |
| `clock_gettime` | 228 | the connection timeouts |
| `exit_group` | 231 | shutting down |
| `write` | 1 | statistics on stderr |

For each: the exact error mapping that matters to a firewall (`EINTR` is not a failure, `EAGAIN` is not a failure, `ENOBUFS` on a netlink socket means the kernel dropped queued packets and the operator must learn about it), and an `assume` naming what the kernel promises.

**`clone` is the one that decides whether this project is possible**, so do it first and report on it before the rest: the raw system call returns 0 in the CHILD, on the stack you handed it, and the child must then run a worker. Find out whether that shape can be written in Gabbro — with a `syscall` item, or with an `asm` body (`muster/` has `beispiele/36-asm.gab`'s shape in `doku/`), or not at all. **If it cannot be written, say so with the compiler's exact words; that single finding is worth more than the whole rest of the file.**

Also write the thin typed wrappers the other lanes will call (`pub impl fn netz_socket() -> u64 or NetzFehler`, and so on), so that nobody else has to touch a register map.
