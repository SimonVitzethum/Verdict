# BERICHT-bm6 — NFQUEUE protocol (`gab/netzverbindung.gab`)

Lane bm6. Module checks clean, emits C, the C compiles at -O0 and -O2
under `cc -std=c11 -Wall -Wextra -Werror`, and a functional harness with
wire-exact vectors passes at -O0, -O2 and under ASan+UBSan — including a
7640-byte message with 1900 attributes that exercises the loop bound.

## 1. What the module does

`module brandmauer::netzverbindung`, 57 items, self-contained (no `use`,
no syscall declarations — see §4). Three tables, all `pub` so the driver
lane can name them through the `.gabi` interface:

- `Empfang count 8192` — one netlink datagram, filled by the driver through
  `lege_empfang(i : index into Empfang, w)`;
- `Senden count 64` — config and verdict messages, drained by the driver
  through `hole_senden(i : index into Senden)`;
- `Ergebnis count 1` — parse result: `zustand` (0..7), `kennung` (packet
  id, host order), `versatz` (payload offset in `Empfang`), `laenge`
  (payload bytes, capped at 1600), `reihung` (queue), `haken` (hook),
  `typ` (message type).

Functions (`pub impl`, costs measured — §3):

- `drehe32` / `drehe16` — the hand-written byte swap (Gabbro has no
  `htonl`). Load-bearing at six sites: res_id and packet-id reads;
  copy-range/maxlen/mask/flags and queue-id/verdict/packet-id writes. Rule:
  headers assemble low-byte-first; attribute payloads assemble
  low-byte-first then swap (reads) or swap then split low-byte-first
  (writes).
- `baue_binden` (28 B), `baue_werte` (32 B), `baue_wartelang` (28 B),
  `baue_merkmale` (36 B) — `NFQNL_MSG_CONFIG` messages: bind command,
  copy mode `NFQNL_COPY_PACKET` with range (packed 5-byte struct, attribute
  length 9, padded to 12), queue maxlen, mask+flags (fail-open).
- `suche_paket(meldung) -> Zustand` — parses one datagram: nlmsghdr
  length/type, nfgenmsg family/version/queue, then a `retry … until`
  attribute walk with NLA_ALIGN (`(ende + 3) / 4 * 4`), gathering
  `NFQA_PACKET_HDR` (id, hook) and `NFQA_PAYLOAD` (offset, length capped at
  1600), skipping unknown attributes. Every refused path funnels through
  `ergebnis_leer`, which zeroes all fields (same write discipline as
  `ungueltig` in `gab/pakete.gab`).
- `baue_urteil(kennung, urteil, reihung)` (32 B) — `NFQNL_MSG_VERDICT`
  with `NFQA_VERDICT_HDR` (verdict and id, big-endian).
- `hole_nutzlast(i : 0..1599)` — one payload byte with both bound checks
  (against `laenge` and, via `narrow`, the buffer count); out of payload
  yields 0. The driver copies `Paket` byte by byte through this (see §4).
- `gib_zustand/kennung/laenge/versatz/reihung/haken/typ` readers.

Outcomes (`Zustand`): 0 `BEREIT`, 1 `KURZ`, 2 `TYP_FEHLER`, 3
`ATTR_FEHLER`, 4 `IDS_FEHLER`, 5 `LEER` (6, 7 reserved). Strictness points,
all refusing, never interpreting: short message, foreign message type,
nonzero family or version, attribute overrun or short header, short packet
header, missing header, missing or empty payload.

Wire constants were read off the local kernel headers
(`/usr/include/linux/netfilter/nfnetlink_queue.h`,
`nfnetlink.h`, `/usr/include/linux/netlink.h`): subsystem QUEUE = 3, so
message types 768/769/770; attribute numbers 1/2/10 and 1–5; bind = 1,
copy-packet = 2, fail-open = 1; `nfqnl_msg_config_cmd` = {u8 command, pad,
be16 pf}; packed `config_params` = {be32 range, u8 mode}.

## 2. What the checker said (verbatim)

```text
$ ./werkzeug/gabbro pruefe gab/netzverbindung.gab
gab/netzverbindung.gab: 57 items, 0 errors, 11 hints
  M1 saw 893 expressions, 0 of them without a type (100 % coverage)

Not checked in this run: 9 passes -- 0 open, 9 CARRIED (the rest is NAMED), 0 only partial
  2 D1/D2, 4 M3, 5 M2, 12 Sperren, 11 Phasen, 7 Paarung, 8 effects, 10 Gruppe, 9 costs
  register 4dd17209 -- the FULL text with `gabbro pruefe --paesse` or `gabbro paesse`
  it is a property of this BINARY, not of the file just checked -- and it did not shrink, it moved
```

The 11 hints are all one code (`E247`, no signature lock over
per-worker buffers) — deliberate, see BEFUNDE-bm6.md H-1. Refusals met on
the way (`C001` retry-without-until, `M103` narrow-killed-by-indexed-write,
`M147` stale names across the walk, `M127` no address-of, `K001` costs)
stand in `messung/BEFUNDE-bm6.md`, each with code, verbatim message, shape
and resolution.

```text
$ ./werkzeug/gabbro kosten gab/netzverbindung.gab
-- site	computed	promised	slack
sonde_klein_endian	0	4	4
drehe32	31	32	1
drehe16	11	16	5
lege_empfang	3	4	1
hole_senden	2	4	2
hole_nutzlast	15	16	1
gib_zustand	1	4	3
gib_kennung	1	4	3
gib_laenge	1	4	3
gib_versatz	1	4	3
gib_reihung	1	4	3
gib_haken	1	4	3
gib_typ	1	4	3
baue_binden	51	56	5
baue_werte	101	112	11
baue_wartelang	96	104	8
baue_merkmale	149	160	11
baue_urteil	145	152	7
ergebnis_leer	10	16	6
suche_paket	300110	301000	890
-- 20 bodies computed, 0 open, 0 derived.
```

Every promise was copied from `computed`, plus single-digit headroom.

## 3. Emitted C at the interesting places

`./werkzeug/gabbro emit gab/netzverbindung.gab` exits 0 (558 lines).
Tables lower to static storage addressed by name; every `pub` function
keeps its name for the driver (`uint32_t baue_urteil(…);` etc.). Three
places worth quoting:

The swap both directions use (`drehe32` in, `drehe32` + low-byte split
out — BEFUNDE-bm6.md M-1):

```c
uint32_t drehe32(uint32_t x) {
    uint32_t b0 = x & 255;
    ...
    return t0 + t1 + t2 + b3;
}
```

Each `narrow` becomes the one runtime check it is (here the HDR re-narrow
inside the walk, `a <= 8180` proven off `ende <= mlen` and `alen >= 12`):

```c
                if (alen < 12) {
                    fehler = 4;
                    goto attr_ende;
                }
                if (!(a <= 8180)) {
                    fehler = 3;
                    goto attr_ende;
                }
```

The bounded walk with its named overrun (300000 ops buy 2083 passes
against 2043 worst-case; `netz_streit` is `extern`, stubbed `abort()` in
the harness and never fired):

```c
        if (_r1 >= 2083u && !(versatz >= mlen)) { netz_streit(); }
```

`cc -std=c11 -Wall -Wextra -Werror -O0 -c` and `-O2 -c` both pass silently.

## 4. What I could NOT write and why

1. **The `sendto`/`recvfrom` calls.** Handing a buffer to a syscall needs
   its address as `u64`, and Gabbro has no address-of for tables (`M127`,
   BEFUNDE-bm6.md A-1). The module therefore ends at `hole_senden` /
   `lege_empfang`; the calls with `netz_senden`/`netz_empfangen` (declared
   in `gab/systemrufe.gab`, referenced here by name only, never
   re-declared) are the driver lane's. This is a genuine expressiveness
   gap, written down, not worked around.
2. **The copy into `Paket`.** `Paket` belongs to `gab/pakete.gab` and
   emitted tables are per-unit `static`, so no second module can write it
   (and must not: ARCHITEKTUR.md fixes one owner per file). The driver
   performs the byte-by-byte copy through `hole_nutzlast`/`gib_laenge`;
   each call moves exactly one checked byte. Unifying the buffer instances
   across lanes (one `--unit` translation unit vs. per-file units with a C
   driver) is the wiring lanes' (`entscheidung`/`lauf`) open question.
3. **A real endianness falsifier.** `rechner_klein_endian` carries a
   shape-only `sonde_klein_endian` (`return true`), same standing as the
   `sonde_*` in `gab/systemrufe.gab`: a probe that reinterprets a word as
   bytes has no Gabbro form. The assumption is named and counted instead
   of being silent.

Weakened nothing: every malformed input below yields a named `Zustand`,
and the two value compromises (payload capped at 1600, out-of-payload
read yields 0) are documented at the site, with the cap recorded in
`Ergebnis.laenge` so the driver never guesses.

## 5. Measurement (all run, all pasted from the tools)

Functional harness `.tmp/bm6/test_nv.c` (scratch, gitignored) `#include`s
the emitted C and drives every function — `ALL OK` at -O0, -O2 and under
`-fsanitize=address,undefined`:

- 8 `drehe` vectors (`0x01020304↔0x04030201`, `0`, `max`, `0xAABBCCDD`,
  `0x1234↔0x3412`, `0x0007↔0x0700`);
- all five builders byte-exact against independently computed wire layouts
  (lengths 28/32/28/36/32; res_id `00 07`; copy-range `00 00 06 40`;
  verdict/id `00 00 00 01` / `01 02 03 04`);
- full `NFQNL_MSG_PACKET` (queue 7, id `AABBCCDD`, hook 3, MARK attr
  skipped, 20-byte payload): `BEREIT`, all `Ergebnis` fields exact, all 20
  payload bytes exact through `hole_nutzlast`, byte 20 and byte 1599 read 0;
- 12 refusal vectors: short message, length-field/long-buffer mismatch,
  foreign type (records 773), nonzero family, nonzero version, attribute
  overrun, attribute length < 4, missing header, missing payload, empty
  payload, short header — each with the exact `Zustand` and zeroed result
  fields (stale-field check: good parse then short parse leaves id, length,
  offset, queue, hook zeroed);
- payload of 1700 bytes capped at `laenge == 1600` with first/last bytes
  exact;
- 7640-byte message with 1900 minimal attributes + header + payload:
  parses `BEREIT` without firing `netz_streit` (the loop-bound proof,
  BEFUNDE-bm6.md R-1).

`make`-style sweep: all six `gab/*.gab` files check `ok`.

## 6. What I did not measure

- No traffic against a live kernel: no NFQUEUE socket was opened, no
  real queued packet parsed, no verdict sent. The wire layouts are exact
  against the headers, not against packets.
- No timing figures; `costs`/`bounded` are static ops, not cycles.
- No cross-lane composition: `entscheidung`/`lauf` do not exist yet in
  this clone, so the `hole_nutzlast → Paket` copy and the
  `hole_senden → sendto` handoff are interfaces, not runs
  (`gabbro abi` output for this module was generated and is well-formed,
  but no consumer was checked against it).
- The `assume rechner_klein_endian` falsifier never ran as a probe (it is
  `return true` by construction, §4.3).
