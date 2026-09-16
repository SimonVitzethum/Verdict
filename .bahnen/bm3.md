YOUR MODULE: `gab/verbindungen.gab` — connection tracking, and it is the multithreaded heart of this firewall. A fixed hash table (say `Verbindung count 4096`, or buckets × slots — your design, say why), keyed by the canonical 5-tuple of ARCHITEKTUR.md, each entry carrying: state (0 free, 1 NEW, 2 ESTABLISHED, 3 CLOSING), the tuple, a last-seen timestamp, and per-direction counters.

Write:
- `pub impl fn suche_oder_lege_an(...) -> u32 in 0 .. 3` — look up the flow, create it if it is new, answer the state. **Several worker threads call this at the same time**, so the table needs a lock (or a set of locks — one per bucket group is the interesting design) declared in Gabbro, and the checker will hold you to holding it.
- `pub impl fn altere(jetzt : u32)` — expire entries older than a declared timeout.
- Say in the report what happens when the table is FULL, because that is a design decision a real firewall must answer: refuse new flows, or evict the oldest? Pick one, write down why, and make the behaviour visible in a counter.

`muster/124-two-threads-private.gab` and `muster/sperre-muster.gab` show how locks and shared tables look in this language. **The lock discipline is where Gabbro is strongest and strictest — expect refusals, and write them down; they are the most valuable output of this lane.**
