# Bericht bm5 — `gab/systemrufe.gab`: the border to the kernel

## What the module does

`gab/systemrufe.gab` (`module systemrufe`, 56 items) is the whole border
between the firewall and Linux/x86_64, and nothing else. No other lane
touches a register map: this file declares ten `syscall` items (number,
`regs in`, `regs out`, `clobbers`, `errors`, named `assume` with
falsifier) and eleven thin `pub` wrappers other lanes call.

| call | number | raw item | wrapper the lanes call |
|---|---|---|---|
| socket | 41 | `roh_socket(gebiet, typ, protokoll)` | `netz_socket()` — fixes (16, 3, 12) |
| bind | 49 | `roh_binden(fd, adresse, laenge)` | `netz_binden(fd, adresse, laenge)` |
| sendto | 44 | `roh_senden(fd, nachricht, laenge, zeichen, ziel, ziel_laenge)` | `netz_senden(...)` same shape |
| recvfrom | 45 | `roh_empfangen(fd, puffer, laenge, zeichen, quelle, quell_laenge)` | `netz_empfangen(...)` same shape |
| mmap | 9 | `roh_karte(adresse, laenge, schutz, zeichen, fd, versatz)` | `speicher_karte(laenge)` — anon, rw, private |
| clone | 56 | `roh_klonen(kind, stapel, eltern, kindspeicher, tls)` | `faden_start(...)` passthrough |
| futex | 202 | `roh_warten(adresse, vorgang, wert, frist)` | `sperre_warten(adresse, wert)` (WAIT, no timeout), `sperre_wecken(adresse, anzahl)` (WAKE) |
| clock_gettime | 228 | `roh_uhr(uhr, adresse)` | `zeit_lesen(uhr, adresse)` |
| exit_group | 231 | `roh_ende(status)` | `anhalten(status)` |
| write | 1 | `roh_schreiben(fd, puffer, laenge)` | `bericht_schreiben(adresse, laenge)` — fixes fd 2 |

Error policy, per wrapper (one attempt, exhaustive `match` over all 15
cases of `NetzFehler`): `Unterbrochen` (EINTR) and `Wiederholen` (EAGAIN)
return NOCHMAL — not a failure, call again; `PaketeVerloren` (ENOBUFS)
returns PAKETE_VERLOREN — the kernel dropped queued packets (recvfrom) or
its queue is full (sendto), and the caller must surface it; every other
reason returns KEIN_WERT. Reason numbers ARE the errnos, so the C side can
also compare. `gabbro abi` writes the interface the other lanes read:
13 `pub const` (ABI numbers plus the three sentinels) and the 11 wrappers
as `extern fn` declarations with `effects { pure }`.

`effects { pure }` everywhere is true in the language's sense: no wrapper
touches a Gabbro carrier. Everything the kernel does behind the call is
the named `assume`, not an effect.

## What the checker said

```
$ ./werkzeug/gabbro pruefe gab/systemrufe.gab
gab/systemrufe.gab: 56 items, 0 errors, 0 hints
  M1 saw 268 expressions, 0 of them without a type (100 % coverage)

Not checked in this run: 9 passes -- 0 open, 9 CARRIED (the rest is NAMED), 0 only partial
  2 D1/D2, 4 M3, 5 M2, 12 Sperren, 11 Phasen, 7 Paarung, 8 effects, 10 Gruppe, 9 costs
  register 4dd17209 -- the FULL text with `gabbro pruefe --paesse` or `gabbro paesse`
  it is a property of this BINARY, not of the file just checked -- and it did not shrink, it moved
```

Including hints seen along the way: the A001/A003/N026 trio on the first
`asm` probe (fixed by adding `arch`, `costs`, `memory`); the E009 hint on
the recursion probe (design changed instead — see BEFUNDE-bm5.md N-1).
The committed file reports **0 errors, 0 hints**.

## What the emitted C looks like at the interesting places

`./werkzeug/gabbro emit gab/systemrufe.gab` exits 0 (1368 lines). The
six-register shape lands where it must — the fourth argument in `r10`,
`rcx`/`r11` clobbered (clone stub, numbers verified against the table
above):

```c
    register uint64_t _sys_rdi __asm__("rdi") = (uint64_t)kind;
    register uint64_t _sys_rsi __asm__("rsi") = (uint64_t)stapel;
    register uint64_t _sys_rdx __asm__("rdx") = (uint64_t)eltern;
    register uint64_t _sys_r10 __asm__("r10") = (uint64_t)kindspeicher;
    register uint64_t _sys_r8 __asm__("r8") = (uint64_t)tls;
    register int64_t _sys_rax __asm__("rax") = (int64_t)56u;
    __asm__ __volatile__(
        "syscall\n"
        : "+a" (_sys_rax)
        : "r" (_sys_rdi), "r" (_sys_rsi), "r" (_sys_rdx), "r" (_sys_r10), "r" (_sys_r8)
        : "rcx", "r11", "memory");
```

Errno decoding is generated from the `errors` map; an unlisted errno is
`hardware (annahme)` via `__builtin_unreachable()` — which is why EINTR
and EAGAIN are listed on every call where they can occur: with no signal
handlers installed they are near-unreachable on blocking fds, but
"near-unreachable" is not "outside the contract". Wrappers lower to a
`switch` WITHOUT `default` (exhaustive by shape). Sentinels and reasons
are plain C:

```c
#define KEIN_WERT 18446744073709551615u
#define NOCHMAL 18446744073709551614u
#define PAKETE_VERLOREN 18446744073709551613u
typedef enum { NetzFehler_Unterbrochen = 4, ... NetzFehler_LeitungWeg = 32, ... } NetzFehler;
```

The emitted unit compiles warning-free:

```
$ cc -std=c11 -Wall -Wextra -Werror -O0 -c .tmp/systemrufe.c -o .tmp/systemrufe-O0.o   # exit 0
$ cc -std=c11 -Wall -Wextra -Werror -O2 -c .tmp/systemrufe.c -o .tmp/systemrufe-O2.o   # exit 0
```

And the border was measured live, not just compiled: a C driver calling
the emitted wrappers (no network traffic — socket creation, anonymous
mmap, monotonic clock, 19 bytes to stderr) returned `netz_socket -> 3`,
`speicher_karte -> 0x7ffff7fbc000`, `zeit_lesen -> 0`, 
...[truncated 1587 chars]