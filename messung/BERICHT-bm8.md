# Report — lane bm8 (`gab/entscheidung.gab`)

## 1. What the module does

`gab/entscheidung.gab` (`module brandmauer::entscheidung`) is the wiring:
it owns no table except one clock atomic, duplicates no other module's
declaration, and exports the one function the driver calls per packet:

```
pub impl fn entscheide(laenge : u32 in 0 .. 1600, faden : u32 in 0 .. 15) -> u32 in 0 .. 2
```

plus two helpers, `tick` and `treffer_index`, and one checker-shaped
helper, `zaehle_weiter`. Every foreign name arrives through an item-level
`use` line (modules alone leave the edge carrying nothing — H021, see
BEFUNDE-bm8.md F1); the composition is checked as a unit with the five
owner files. The policy, in wire order, stands as numbered comments in
the source and is repeated here because the order IS the firewall:

1. **Decode** (`entpacke`). Malformed → `zaehle_fehl()` AND
   `zaehle_urteil(DROP)`, then DROP. Both counters: `FEHLFORM` names the
   event, the verdict counter keeps `GESAMT` exactly per-packet, so
   `GESAMT == VERWORFEN + AKZEPTIERT + ABGEWIESEN (mod 2^32)` holds by
   construction on every path, including the `faden > 15` boundary guard.
   No rule is consulted for a packet we could not read.
2. **Lookup** (`suche_oder_lege_an`) with the decoded tuple and `jetzt`,
   under `VSPERRE`. The `locks` block holds exactly the lookup and its
   assignment — rule matching and counting stay outside the critical
   section (rules are read-only after startup, counters are lock-free
   atomics). The held sub-budget measures 520 of the lock's 1024.
3. **Fast path**: state 2 (ESTABLISHED) → ACCEPT, no rule walk. The branch
   comment states why (a flow reaching 2 passed the rules packet by
   packet in both directions) and the price (a reloaded rule set does not
   apply to already-established flows — a documented lag, fail-open for
   old flows; live revocation wants a generation stamp).
4. **Rules** (`entscheide_regeln`, default DROP owned by regeln.gab).
   State 0 (bucket full, flow refused) also lands here — fail closed —
   after `zaehle_voll()` surfaces the event.
5. **Count**: `zaehle_urteil` exactly once per call (via `zaehle_weiter`,
   see §4), plus `zaehle_regel(treffer)` when a rule matched
   (`treffer_index` re-walks with `passt`; 256 = default policy, no slot
   to count).

`jetzt` is a saturating packet-count atomic (`UHR_TICK`, relaxed), not
wall-clock time — entries expire after 300 unobserved packets
(BEFUNDE-bm8.md F3). `faden` is boundary-checked and otherwise unused:
per-thread buffers need an ARCHITEKTUR change (F4).

## 2. What the checker said (verbatim)

Unit check, final:

```
$ ./werkzeug/gabbro pruefe --unit gab/pakete.gab gab/regeln.gab gab/verbindungen.gab gab/zaehler.gab gab/entscheidung.gab
gab/entscheidung.gab: 22 items, 0 errors, 3 hints
unit of 5 file(s): 587 items, 0 errors, 532 hints
  M1 saw 5262 expressions, 7 of them without a type (100 % coverage)
```

Same file against the generated interfaces (`.gabi` via `gabbro abi`,
scratch in `.tmp/bm8/`):

```
$ ./werkzeug/gabbro pruefe --with .tmp/bm8/unit.gabi gab/entscheidung.gab
gab/entscheidung.gab: 320 items, 0 errors, 3 hints
  M1 saw 117 expressions, 7 of them without a type (94 % coverage)
```

The 3 hints are one code, three sites, all deliberate (E247 — reads of
`Kopf`/`Regel`/`UHR_TICK` with no signature guard: the no-lock
disciplines of the pakete/regeln lanes and the atomic discipline of the
counters lane; a lock here would invent a cross-lane contract):

```
hint: [E247] gab/entscheidung.gab:166:35: `Kopf` is read by the body of `entscheide` but no signature lock guarding it is held, and some function writes it
hint: [E247] gab/entscheidung.gab:87:19: `UHR_TICK` is read by the body of `tick` but no signature lock guarding it is held, and some function writes it
hint: [E247] gab/entscheidung.gab:104:30: `Regel` is read by the body of `treffer_index` but no signature lock guarding it is held, and some function writes it
```

The 7 expressions "without a type" are chased down in full (probes
`.tmp/bm8/m1*.gab`): they are exactly the 7 statement-position calls to
`->`-less (void) counter functions (`zaehle_urteil` ×4 sites,
`zaehle_fehl`, `zaehle_voll`, `zaehle_regel`). M1 types ranges; a void
call has no result range, so there is nothing to type — a coverage
counter, not a gap. (Control: the same shape with a valued callee types
clean; every other lane shows 0 only because its callees all return
values.) No refusal, no finding — but the number is explained, not waved
past.

Costs. `kosten` does not follow `use` (OFFEN in every cross-file mode —
BEFUNDE-bm8.md, Silence), so the numbers come from a scratch mirror
(`.tmp/bm8/spiegel.gab`: identical bodies, `use` lines replaced by
verbatim interface copies), whose computed values transfer exactly:

```
-- site         computed  promised  slack
tick           10        10        0
treffer_index  20480     20480     0
zaehle_weiter  16        16        0
entscheide     91166     91166     0
  entscheide / held VSPERRE  520   1024      504
-- 4 bodies computed, 0 open, 0 derived.
```

All promises are tool-computed, slack 0 — the tightest ratchet: any
callee growth breaks the promise by name. **91166 ops is the worst-case
per-packet work of this firewall**, composed as: decode 200 + tick 10 +
locked lookup block 520 (512 `suche_oder_lege_an` + block) + rule walk
68096 + hit-index walk 20480 (256 slots × 80: 71 `passt` + 9 walk
overhead) + rule-hit count 1797 + verdict count 16 + 47 own wiring.
Note the shape the number has: three quarters of it is the two rule
walks. An operator who wants a cheaper worst case shortens the rule
table walk or teaches `entscheide_regeln` its hit index (which would
delete the second walk entirely — BEFUNDE-bm8.md F6).

Refusals met on the road (all in `messung/BEFUNDE-bm8.md` with code,
message, and shape): N038 (`UHR_TICK` needs `pub`), K001 (`tick`
promised 8, costs 10), the M147 cross-unit staleness that forced
`zaehle_weiter` (F2), and the 25-error lone-file boundary (F1).

## 3. What the emitted C looks like at the interesting places

`emit --unit` over the five files exits 0 (10413 lines); the single file
via `emit --with` exits 0 (761 lines). Both compile under
`cc -std=c11 -Wall -Wextra -Werror -c` at -O0 and -O2 (four builds,
all silent). The whole `entscheide` body, as emitted:

```c
uint32_t entscheide(uint32_t laenge, uint32_t faden) {
    if (faden > 15) {
        zaehle_urteil(DROP);
        return DROP;
    }
    uint32_t ok = entpacke(laenge);
    if (ok == 0) {
        zaehle_fehl();
        zaehle_urteil(DROP);
        return DROP;
    }
    uint32_t proto = Kopf_speicher.slots[0].proto;
    /* ... quelle, ziel, qport, zport, flaggen ... */
    uint32_t jetzt = tick();
    uint32_t zustand = FREI;
    VSPERRE_nimm();
    {
        zustand = suche_oder_lege_an(quelle, ziel, qport, zport, proto, flaggen, jetzt);
    }
    VSPERRE_gib();
    if (zustand == BESTEHEND) {
        zaehle_urteil(NIMM_AN);
        return NIMM_AN;
    }
    if (zustand == FREI) {
        zaehle_voll();
    }
    uint32_t urteil = entscheide_regeln(proto, quelle, ziel, qport, zport, flaggen);
    uint32_t treffer = treffer_index(proto, quelle, ziel, qport, zport, flaggen);
    if (treffer <= 255) {
        zaehle_regel(treffer);
    }
    return zaehle_weiter(urteil);
}
```

Worth pointing at: the lock pair wraps exactly one call with no early
return inside (release on all paths — the early returns all sit outside
the block); the `tick` lowers to relaxed load, guarded store, re-read
(`atomic_load_explicit`/`atomic_store_explicit`, `memory_order_relaxed`);
`treffer_index` to a plain bounded `for` with early `return k` and
`return KEIN_TREFFER`; `zaehle_weiter` to `zaehle_urteil(u); return u;`.
Ranges vanish into plain `uint32_t` (the report of every lane); the two
boundary checks that survive (`faden > 15`, `treffer <= 255`) are real
C-level defences, not range-system residue.

Composition warning (BEFUNDE-bm8.md, Silence): the single-file emit
defines its OWN `static Kopf Kopf_speicher;` — linking per-file objects
would split-brain the firewall. The unit emit carries exactly one
`Kopf_speicher`, one `Regel_speicher`, one `UHR_TICK` (verified by
count). Per-file `bau/%.c` + link cannot carry shared tables; the build
of the whole program must be one unit.

Behaviour, measured not assumed: a scratch harness (`.tmp/bm8/pruefstand.c`,
includes the unit C, pthread-mutex `VSPERRE`, aborting `zaehler_streit`;
NOT part of the firewall) checks 22 assertions — malformed DROP +
double count, SYN→ACCEPT with slot-0 hit, promoting reply ACCEPT with NO
rule walk (fast path), re-SYN fast path, wild-`faden` counted DROP, UDP
default DROP with no hit, and the full counter accounting
(`gesamt == verworfen + akzeptiert + abgewiesen` at every step):

```
ALLE PRUEFUNGEN BESTANDEN
```

identical at -O0 and -O2, exit 0 both. A second scratch probe
(`.tmp/bm8/sonde.c`) measures the promoting-reply edge and the E2
two-packet bypass — verbatim in BEFUNDE-bm8.md F5.

## 4. What I could NOT write and why

- **Wall-clock `jetzt`.** No address-of exists in the language; the
  packet counter stands in its place (F3). Expiry is packet-counted
  until another lane provides an address primitive and a timespec
  carrier.
- **Per-thread buffers.** `faden` cannot index `count 1` tables (M103);
  the 16-way `Kopf`/`Paket` change is cross-lane (F4).
- **The promoting packet's pre-transition state.** The signature answers
  only the state number; "promoted by this very packet" is
  indistinguishable from "established earlier" inside this file, so the
  handshake reply takes the fast path and the E2 bypass stands written
  down, not fixed (F5). Any fix moves the answer value (verbindungen),
  the lookup/verify order (all lanes), or adds a stamp (new contract).
- **One-walk rule counting.** The hit index is not in
  `entscheide_regeln`'s signature; the second walk is the honest price,
  inside the worst case (F6).
- **Count-then-return as two lines.** M147 across foreign calls forced
  `zaehle_weiter` (F2). Same semantics, checker-shaped.

Nothing was weakened to please the checker without saying so: each item
above names what is missing, what stands in its place, and what it costs.

## 5. What I did not measure

- **Contention.** `VSPERRE` is coarse by design (bm3 F6); `UHR_TICK` loses
  bumps under collision by design (F3). No multithreaded run exists —
  the `clone`/futex runtime is the lauf lane's. The `treffer`/`voll`
  counters are the instruments; a throughput claim waits for the driver.
- **Time calibration.** 91166 ops is a static count, not nanoseconds;
  the expiry behaviour (300 packets vs 300 seconds) wants traffic data.
- **`altere` cadence.** The expiry sweep (90112 ops declared) is NOT on
  the packet path and NOT called from here — who calls it, and how often,
  is the lauf lane's decision. Without it the table fills and new flows
  refuse (fail closed); that liveness half is unmeasured.
- **Adversarial traffic.** The harness speaks crafted frames, not a
  fuzzer; hash quality and bucket-full behaviour under flood are bm3's
  open items, observable through `VOLL`.
- **Rule reload under load.** Both walks assume the startup-loader
  discipline (bm2). A live-reload contract does not exist yet — and the
  fast-path lag (F5-adjacent) is its sharpest consequence.
