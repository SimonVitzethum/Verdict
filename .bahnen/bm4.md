YOUR MODULE: `gab/zaehler.gab` — counters, and they must be correct under concurrency. Every worker thread counts: packets seen, packets accepted, dropped, rejected, malformed, per-rule hits, connection-table full events.

Use ATOMICS, not a lock: `muster/116-payload-free-counter.gab` shows an atomic counter in this language, and `doku/SPRACHE.md` has the orderings. A counter that loses increments under load is a bug a firewall operator will see and not understand.

Write:
- the atomic declarations,
- `pub impl fn zaehle_urteil(u : u32 in 0 .. 2)` and `pub impl fn zaehle_regel(r : u32 in 0 .. 255)` and the few others your design needs,
- `pub impl fn lies_zaehler(welcher : u32 in 0 .. 15) -> u32` so the driver can print statistics.

**Measure and report what the emitted C actually is** for each atomic operation — which C11 function, which memory order. The Gabbro tree learned yesterday that its emitter has no atomic fetch-add and lowers an update to a bounded compare-exchange loop; find out what your counters become, and say it plainly with the C beside it. That measurement is worth as much as the module.
