# Bericht bm7 — `gab/lauf.gab`: the program that runs the firewall

## What the module does

`gab/lauf.gab` (`module brandmauer::lauf`, 22 items) is the driver lane: it
turns the five modules into something that runs. Single worker, queue 0,
checked alone, linked as a unit. Startup before the first datagram, sentinel
discipline in the loop, threshold shutdown through `exit_group`.

| part | shape | what it does |
|---|---|---|
| `main` | `pub impl fn main() -> i32` | socket (counted NOCHMAL retry, 64 attempts) → mmap 65536 → default policy → `arbeite` → `anhalten` with the shutdown reason |
| `arbeite` | `forever runde` + `leave` | one `netz_empfangen` per pass; NOCHMAL counted, PAKETE_VERLOREN counted, KEIN_WERT ends with `fehler = 120`, byte counts end at `GRENZE` |
| `lade_grundregeln` | straight-line loader | `raeume_alle()` + one `setze_regel` (ACCEPT TCP dport 80); rest is STANDARD/DROP |
| `LaufStand` | `pub table ... count 1` | `pakete`, `verlust`, `nochmal`, `fehler` — the worker's statistics |
| mirrors | 4 border + 2 loader `extern fn` | C-identical prototypes of `systemrufe`/`regeln` wrappers (names, parameters, answers); the single-file gate forbids `use` (BEFUNDE-bm7.md L-4) |
| assumes | `paketstrom_fliesst`, `steckdose_kommt` | the two `progress` ends of the two `forever` loops, with `sonde_*` falsifiers of the house shape |

Exit statuses (literal at the `anhalten` call and at the `return` — a `u64`
status cannot narrow to the `i32` answer, so the number stands twice): 0
threshold clean, 1 threshold with drops counted, 110 socket never came up,
111 buffer never mapped, 120 receive path dead.

## What the checker said

```
$ ./werkzeug/gabbro pruefe gab/lauf.gab
hint: [E247] gab/lauf.gab:169:16: `LaufStand` is read by the body of `arbeite` but no signature lock guarding it is held, and some function writes it
  169 |             if LaufStand.slots[0].nochmal < u32::max {
      |                ^^^^^^^^^^^^^^^^^^^^^^^^^^
      = the footprint carries what the contract saw: every written carrier wants a `requires Held(L)` guard over a `lock L protects` line, not merely a `reads` or `writes` entry in `effects`
      = carriers no function writes need no guard; device registers read bare carry none either, until the declaration names their carriers
hint: [E247] gab/lauf.gab:261:8: `LaufStand` is read by the body of `main` but no signature lock guarding it is held, and some function writes it
  261 |     if LaufStand.slots[0].fehler == 120 {
      |        ^^^^^^^^^^^^^^^^^^^^^^^^^
      = the footprint carries what the contract saw: every written carrier wants a `requires Held(L)` guard over a `lock L protects` line, not merely a `reads` or `writes` entry in `effects`
      = carriers no function writes need no guard; device registers read bare carry none either, until the declaration names their carriers
gab/lauf.gab: 22 items, 0 errors, 2 hints
  M1 saw 178 expressions, 4 of them without a type (98 % coverage)

Not checked in this run: 9 passes -- 0 open, 9 CARRIED (the rest is NAMED), 0 only partial
  2 D1/D2, 4 M3, 5 M2, 12 Sperren, 11 Phasen, 7 Paarung, 8 effects, 10 Gruppe, 9 costs
  register 4dd17209 -- the FULL text with `gabbro pruefe --paesse` or `gabbro paesse`
  it is a property of this BINARY, not of the file just checked -- and it did not shrink, it moved
```

Exit code 0. The two E247 hints are deliberate (one worker, one row — same
reading as `messung/BEFUNDE-bm2.md` §2); the refusals met on the way
(M127, C001 ×2, H021, P003, N038) are filed in `messung/BEFUNDE-bm7.md`.

`gabbro kosten` (no `costs` line anywhere — every callee behind the mirrors
declares none, K003, BEFUNDE-bm5.md N-2):

```
-- site	computed	promised	slack
sonde_strom	0	4	4
sonde_dose	0	4	4
lade_grundregeln	OFFEN	--	-- the call to `raeume_alle` declares no `costs`
arbeite	OFFEN	--	-- a `forever` loop has no total cost -- its promise is `per_pass`, not `costs`
main	OFFEN	--	-- a `forever` loop has no total cost -- its promise is `per_pass`, not `costs`
-- 2 bodies computed, 3 open, 0 derived.
```

`gabbro annahmen`: 2 assumptions (`paketstrom_fliesst`, `steckdose_kommt`),
both `ungedeckt`, both probes STRUCK — same class as the ten in
`systemrufe.gab` (BEFUNDE-bm5.md S-1): shape without teeth, stated, not run.

## What the emitted C looks like at the interesting places

`./werkzeug/gabbro emit gab/lauf.gab` exits 0 (187 lines). `pub impl fn
main() -> i32` emits `int32_t main(void)` — the task's claim, measured:

```c
int32_t main(void) {
    uint64_t steckdose = KEIN_WERT;
    ...
    lade_grundregeln();
    arbeite(steckdose, puffer);
    ...
    (void)anhalten(0);
    return 0;
}
```

The worker loop lowers to `for (;;)` with `goto runde_ende` for `leave`, the
`per_pass`/`progress` clauses as comments plus a referenced-but-unused
watchdog pointer (`runde_wachhund`, `__attribute__((unused))`), and the
loader call lands literally:

```c
raeume_alle();
setze_regel(0, 1, 0, 6, 1, 0, 0, 1, 0, 0, 1, 0, 0, 0, 80, 80, 1, 0, 0, 1, 0);
```

Prototype identity (mirror claim, verified line by line): the file's
`uint64_t netz_socket(void);`,
`uint64_t netz_empfangen(uint64_t fd, uint64_t puffer, uint64_t laenge,
uint64_t zeichen, uint64_t quelle, uint64_t quell_laenge);`,
`uint64_t speicher_karte(uint64_t laenge);`, `uint64_t anhalten(uint64_t
status);`, `void raeume_alle(void);` and the 21-parameter `void
setze_regel(uint32_t i, ...)` are textually identical to the declarations and
definitions in the emitted `systemrufe` and `regeln` units.

The emitted unit compiles warning-free at both levels:

```
$ cc -std=c11 -Wall -Wextra -Werror -O0 -c .tmp/lauf.c -o .tmp/lauf-O0.o   # exit 0
$ cc -std=c11 -Wall -Wextra -Werror -O2 -c .tmp/lauf.c -o .tmp/lauf-O2.o   # exit 0
```

## Build, attach, run — measured and unmeasured

**Build (measured).** Exact command line that builds the runnable unit from
this clone (emitted files are build artefacts in `.tmp/`, never sources):

```
./werkzeug/gabbro emit gab/lauf.gab > .tmp/lauf.c
./werkzeug/gabbro emit gab/systemrufe.gab > .tmp/systemrufe.c
./werkzeug/gabbro emit gab/regeln.gab > .tmp/regeln.c
cc -std=c11 -Wall -Wextra -Werror -O2 -o .tmp/brandmauer_test \
    .tmp/lauf-O2.o .tmp/systemrufe.c .tmp/regeln.c
```

Link exits 0 — the mirrors resolve against the real units, including the
default-policy load.

**Run (measured, unprivileged).** No root and no queue exist in this clone, so
the worker blocks in its first `recvfrom` — which is itself the measurement:
`strace` shows the whole startup path executed for real, ending parked where
a worker belongs:

```
$ timeout 3 strace -f -e trace=socket,mmap,recvfrom,sendto,bind,exit_group .tmp/brandmauer_test
socket(AF_NETLINK, SOCK_RAW, NETLINK_NETFILTER) = 3
mmap(NULL, 65536, PROT_READ|PROT_WRITE, MAP_PRIVATE|MAP_ANONYMOUS, -1, 0) = 0x7ffff7fa2000
recvfrom(3, strace: Process 2211072 detached
 <detached ...>
```

Read it as three verified facts: `netz_socket()` performed
`socket(16, 3, 12)`; `speicher_karte(65536)` performed exactly the wrapper's
fixed anonymous mapping (addr 0, prot 3, flags 34, fd −1); the rule load ran
(no syscalls, code order in the emitted `main`); the loop sits in `recvfrom`
on fd 3. EINTR/EAGAIN/ENOBUFS handling, the threshold exit and the exit
statuses are code-reviewed, not run — no queue delivered any of those events
here.

**Attach (UNMEASURED — no root in this clone).** The single `nft` line that
would feed queue 0, plus its scaffolding:

```
nft add table inet filter
nft add chain inet filter input '{ type filter hook input priority 0; policy accept; }'
nft add rule inet filter input queue num 0
```

**Root procedure (UNMEASURED, step by step, no hand-waving).** Someone with
root and a test machine (or `unshare -rn` + veth pair) would:

1. Build as above and copy `.tmp/brandmauer_test` to the test machine.
2. Stall the worker deliberately first: run `./brandmauer_test &`, confirm
   with `strace -p` (or `/proc/<pid>/syscall`) that it sits in `recvfrom` —
   startup is green before any packet exists.
3. Attach the queue: the three `nft` lines above; generate traffic (e.g.
   `curl --connect-timeout 2 http://<test-ip>/` for the TCP/80 rule, plus any
   other packet for the DROP default).
4. Watch the worker: with bm6/bm8 NOT landed it cannot answer verdicts, so the
   queue fills and the kernel starts dropping — `verlust` rises and the
   process keeps running. That is the honest current end state: the drop path
   demonstrates itself.
5. Threshold test without traffic is impossible (no packets, no counts); lower
   `GRENZE` to e.g. 3, rebuild, replay 3 packets, expect exit status 1 (drops
   seen) and `verlust > 0` in a debugger read of `LaufStand_speicher`.
6. Scale-out: one process per queue number (`WARTESCHLANGE` is a const —
   rebuild per number), one `queue num N` rule each. No threads (K-1).
7. Cleanup: `nft delete rule ...` / `nft flush chain inet filter input`, kill
   the workers (no signal handling — `kill -9`, Befund L-5).

## What the module could NOT do, and why

Everything refused is refused in `messung/BEFUNDE-bm7.md` with code, message
and shape: no buffer/bind/send/write addresses (M127, L-1), no rule file (no
`open`/`read`, L-2), no `retry` lowering (C001, L-3 — startup retry is a
counted `forever`), no `use` in the single-file gate (H021, L-4 — mirrors),
no signal shutdown (L-5 — threshold), no threads (K-1, cited), no costs lines
(K003, cited). The per-packet parse → `Paket` → `entscheide` → verdict path is
a marked insertion point in `arbeite`, not code: lanes bm6/bm8 are not in this
clone.

## What was not measured

* No packet was ever filtered: without bm6/bm8 there is no verdict, and
  without root there is no queue. The `nft` rule and the 7-step procedure are
  written for re-execution, not quoted from a run.
* Kernel autobind on the un-bound socket is assumed, not observed (L-1).
* `bind(fd, 0, 0)` was NOT attempted — skipped deliberately, same wall.
* The `GRENZE = 1000000` threshold never fired here; the `verlust > 0 → exit
  1` mapping is reviewed, not run.
* The two `assume` probes are STRUCK (shape without teeth, like the border's
  ten).
* `gabbro build` with a `.bau` manifest was not used: the repo `Makefile`
  compiles per-file `pruefe` plus a `treiber/*.c` link that does not exist in
  this clone, so the measured build is the explicit four-line recipe above.
