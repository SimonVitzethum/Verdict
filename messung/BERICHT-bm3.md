# Bericht — lane bm3: `gab/verbindungen.gab`

## What the module does

Fixed hash table for connection tracking: `Verbindung count 4096` organised
as 1024 buckets × 4 slots (`EIMER`, `FACH`). Key is the canonical 5-tuple per
ARCHITEKTUR.md — smaller (address, port) pair first, so both directions hash
to one bucket; the direction survives as a local (`richtung`) and steers the
per-direction counters (`hin`, `rueck`, saturating). Each entry: state
(0 free, 1 NEW, 2 ESTABLISHED, 3 CLOSING), the tuple, `gesehen` timestamp,
both counters. One lock: `VSPERRE protects { Verbindung, Stand } rank 0`.

- `pub impl fn suche_oder_lege_an(quelle, ziel, qport, zport, iprot,
  flaggen, jetzt) -> u32 in 0 .. 3` — canonicalise, hash (`^` chain,
  `% EIMER`), scan the 4 slots unrolled: hit → `treffer_pflegen` (timestamp,
  counter, NEW+reply→ESTABLISHED, FIN/RST→CLOSING, answer state); miss with a
  free slot → create as NEW, answer 1; miss with a full bucket → `voll++`,
  answer 0. Caller contract: `requires Held(VSPERRE)` — workers take the
  lock around the call (proven shape, see below).
- `pub impl fn altere(jetzt)` — one `traverse` over all slots, frees entries
  with `jetzt - gesehen > ABLAUF` (300 s). `jetzt < gesehen` (clock stepped
  back) keeps the entry: never expire into uncertainty.
- `pub impl fn lies_stand(w : u32 in 0 .. 3) -> u32` — the four counters
  (`voll`, `neu`, `treffer`, `abgelaufen`) in the lock-guarded `Stand`
  table, for the driver's statistics. No atomics needed: every write happens
  under `VSPERRE`.
- FULL means REFUSE, not evict (design decision): a full bucket answers 0
  and counts `voll`. Evicting the oldest would let a SYN flood displace
  established flows and costs a table scan per insert; refusing protects them
  and falls back to the rules (default DROP — fail-closed). Measured: the 5th
  colliding flow in a bucket answers 0 with `voll = 1` (C test, both -O0/-O2).

## What the checker said (verbatim)

```
$ ./werkzeug/gabbro pruefe gab/verbindungen.gab
gab/verbindungen.gab: 12 items, 0 errors, 0 hints
  M1 saw 466 expressions, 0 of them without a type (100 % coverage)

Not checked in this run: 9 passes -- 0 open, 9 CARRIED (the rest is NAMED), 0 only partial
  2 D1/D2, 4 M3, 5 M2, 12 Sperren, 11 Phasen, 7 Paarung, 8 effects, 10 Gruppe, 9 costs
  register 4dd17209 -- the FULL text with `gabbro pruefe --paesse` or `gabbro paesse`
```

No hints either — including no E247, because the guard is at every
signature. Costs are measured, not guessed (`gabbro kosten`):

```
-- site              computed  promised  slack
treffer_pflegen     39        48        9
suche_oder_lege_an  419       512       93
altere              86016     90112     4096
lies_stand          7         8         1
```

The road there is `messung/BEFUNDE-bm3.md`: N038 (`pub` is transitive),
E010 (traverse reads the carrier AND the slots), E247 (guard at the
signature — this ruling killed per-bucket locks), M147 twice
(path-insensitive staleness → decide-write-reread), plus three caller-side
refusals (P001, N280/H021/K003) that fix the import shape for the other lanes.

## What the emitted C looks like at the interesting places

`./werkzeug/gabbro emit gab/verbindungen.gab` → 235 lines; `cc -std=c11
-Wall -Wextra -Werror -c` clean at -O0 and -O2.

- `traverse … by unvisited` lowers to a plain index `for` loop over all 4096
  slots (`altere`); `narrow s0 to 0 ..< ANZAHL else { return 0; }` lowers to
  `if (!(s0 < ANZAHL)) { return 0; }` — four such guards, dead by
  construction, kept as the price of the index type.
- The lock declaration emits only `void VSPERRE_nimm(void);` /
  `void VSPERRE_gib(void);` — no calls, because this module never takes the
  lock itself. Mutual exclusion is a contract (`requires Held`), not code
  here. The caller's `locks VSPERRE { … }` DOES emit the pair, including a
  release on the early-return path (verified via `emit --unit` with a caller
  probe; that unit also compiles at -O2). The runtime/lauf lane owns those
  two symbols — same split as `muster/start-muster.c` (`L_nimm`/`L_gib`).
- Saturating counters emit guarded increments
  (`if (….hin < 4294967295u) { ….hin += 1; }`); the hash emits as
  `(((a ^ b) ^ pa) ^ pb) ^ iprot` plus `h % EIMER`. Range types emit as plain
  `uint32_t` (see Befunde/Silence).
- Behaviour measured in C (scratch driver over the emitted unit, -O0 and
  -O2, identical): create→1, same-dir→1, reply→2, FIN→3, CLOSING stable,
  expiry after 301 s (`neu=3 treffer=5 abgelaufen=2` in the run), bucket-full
  refusal with `voll=1`. The one test bug found on the way (a re-lookup
  refreshing `gesehen`, derailing the expiry arithmetic) was the test's, not
  the module's — which is exactly what the timestamp update is FOR.

## What I could NOT write and why

- **Per-bucket-group locks.** Refused by the discipline, not by a code
  (E247 demands the guard at the signature; a data-dependent lock choice
  cannot stand there). Single coarse lock, documented in F6 with the honest
  upgrade path (stripe TABLES, not stripe locks).
- **Evict-oldest on FULL.** Writable, deliberately not written: refusing is
  the safer firewall semantic (see above). If operations ever wants
  eviction, it is a one-`traverse` change plus a policy line here — not a
  refactor.
- **Per-state timeouts** (shorter for NEW/CLOSING). Omitted for review
  surface, not for language reasons: one `ABLAUF` keeps `altere` a single
  comparison. Named here so nobody mistakes it for a limit.

## What I did not measure

- Contention: no multithreaded run (the `clone`/futex runtime is the lauf
  lane's; my contract is `requires Held`, proven at check time, not at run
  time). Whether the coarse lock costs throughput is open until the driver
  exists — the `treffer`/`voll` counters are the instruments for exactly that.
- Hash quality: XOR-fold is distribution by hope. Collision behaviour is
  bounded (4 slots, then refuse + count), so a bad hash degrades to
  refuse-new, never to wrong answers — but nobody has fed it real traffic.
- Timeout value: 300 s is a constant, not a measurement. It wants traffic
  data, and it is one line to change.
- `concurrent { … }` membership: this module declares no threads; the worker
  roots belong to the lauf lane, which must hold `VSPERRE` across these calls.
