# Report — lane bm11 (transports, lock, costs on the new tool)

Tool: `./werkzeug/gabbro` is trunk `57c44087` (four topics: M127 `&T`,
N042/N323 lock contract, N321, N322). `make pruefen`: 9/9 green (8 old
files plus `gab/sperre.gab`). Every `.gab` emits; the link is 9 Gabbro
units plus a 4-symbol scratch stub.

## 1. What the lane did

| change | file(s) |
|---|---|
| `costs <= 8 ops` on all ten syscalls (N322 fallout) | `systemrufe` |
| `use` of three tables + 3 `ptr` syscalls + 3 wrappers (14/15/15) | `systemrufe` |
| `Adresse` table + `lege_adresse` (12) | `netzverbindung` |
| 3 border mirrors + `verbinde` (41) / `sende` (19) / `empfange` (19) / `einrichten` (829) + `pruefe_quittung` (34) | `netzverbindung` |
| NLM_F_REQUEST\|NLM_F_ACK on the 4 config builders (verdicts stay REQUEST-only) | `netzverbindung` |
| 3 transport mirrors + `main`/`arbeite` rewire, mmap removed, exit 112, `behandle` pub | `lauf` |
| costs on all mirrors, `lade_grundregeln` (1084), `zaehle_weiter` (16), `per_pass` 86 | `entscheidung`, `lauf` |
| ticket lock `VSPERRE_nimm`/`gib`, new file | `sperre` |
| `.gabi` step + `--with`, fixed link line, red-link NOTE | `Makefile` |
| module row + three amendment paragraphs | `ARCHITEKTUR.md` |

## 2. Transports: measured against a real kernel, no root

Harness 3 (scratch, separate link of `systemrufe.o`+`netzverbindung.o`):

```
socket -> 3
R1 socket lebt               ok
verbinde -> 0
R2 bind an eigene Adresse    ok
einrichten -> 1 (ohne Root erwartet: 1)
R3 config ohne Rechte -> 1   ok
TRANSPORT GESCHLOSSEN
```

And the linked firewall itself (`strace`, unprivileged):

```
socket(AF_NETLINK, SOCK_RAW, NETLINK_NETFILTER) = 3
bind(3, {sa_family=AF_NETLINK, nl_pid=0, nl_groups=00000000}, 12) = 0
sendto(3, [{nlmsg_len=28, ...}, "...\x05..."], 28, 0, NULL, 0) = 28
... (32, 28, 36 the same, ACK-flag bytes on the wire)
recvfrom(3, [{nlmsg_len=48, nlmsg_type=NLMSG_ERROR, ...}, {error=-EPERM, ...}], 8192, 0, NULL, NULL) = 48
exit_group(112)   +++ exited with 112 +++
```

Read it as five verified facts: the socket lives; the bind names
`&Adresse_speicher` and the kernel takes it (`= 0`); all four config
messages leave whole (28/32/28/36) with the ACK flag set; the kernel
answers EPERM -- never EINVAL, i.e. well-formed messages refused for
rights, not for shape; `einrichten` reads the four answers, finds no
ACK, returns 1, and the process ends 112 (fail closed, operator
restarts). The exit-112 path is measured, not reviewed.

## 3. Lock: Gabbro, linked, uncontended

`gab/sperre.gab`: 7 items, 0 errors, 2 hints (the muster E247 class).
Emits real `VSPERRE_nimm`/`gib` (`acquire` load in the spin, CAS-loop
draw). Harness 1 re-run links `sperre.o` instead of the pthread stub --
no pthread anywhere in the lane -- and still reads `E2C GESCHLOSSEN`
(identical verdicts/walks/counters at -O2). Contention is unmeasured
(single worker, K-1); the bodies never spin here beyond the first ticket.

## 4. Costs: maximal closure

OFFEN before → after: `entscheidung` 3→2 (`zaehle_weiter` closed 16/16),
`lauf` 3→2 sites... precisely: `lade_grundregeln` closed 1084/1084.
Remaining OFFEN, all by loop-form construction, none a refusal:
`behandle`, `arbeite`, `main`, `treffer_index` (`forever` has no total),
`entscheide` (calls `treffer_index`). Six modules report 0 open
(`verbindungen` 5, `netzverbindung` 26, `sperre` 3, `pakete` 11, `regeln`
4, `zaehler` 270 bodies). Mirror numbers repeat owners' measured costs;
the check is the kosten diff (all slacks 0 where promised).

## 5. Re-measured, unchanged in behaviour

- Harness 1 (E2c): `E2C GESCHLOSSEN` (P1..E2c identical, counters 6=6).
- Harness 2 (chain): `KETTE GESCHLOSSEN` (T1..T4; T4 expectation updated
  to the ACK-flag byte).
- Link: 9 units + stub exit 0; `nm`: `main`, `entscheide`, `behandle`,
  `einrichten`, `suche_nur`, `VSPERRE_nimm` each exactly once.
- Prototype identity holds for all new edges (3 `ptr` pairs incl.
  `const`, 3 transport pairs, 7 chain pairs -- `__attribute__`s aside,
  same precedent as bm7/bm9).

## 6. What still needs root, step by step

```
unshare -rn
nft add table inet filter
nft add chain inet filter input '{ type filter hook input priority 0; policy accept; }'
nft add rule inet filter input queue num 0
./bau/brandmauer; echo $?     # expect 0, not 112: four ACKs this time
curl --connect-timeout 2 http://<test-ip>/      # P1/P2/P3 pattern
curl --connect-timeout 2 http://<test-ip>:81/   # E2a/E2b/E2c pattern
```

What root would show that is open today: four ACKs (error=0) instead of
four EPERMs, exit past 112 into `arbeite`, and the first live verdict on
the wire. Everything before that line is measured above; everything
after it is the same decision chain harness 2 measures.

## 7. Refusals and residues (verbatim in `messung/BEFUNDE-bm11.md`)

U-1 M127 gefallen/M140 steht; U-2 `use`-Muster; U-3 unit-Kollisionen
(N039/N042 -- keine Migration); U-4 N042+N323 (Split-Datei); U-5
N321/C001/`forever`-Pflicht (Exits extern); U-6 `extern`-Kosten; U-7 N322;
U-8 K007. Residues: N323 sieht Split-Dateien nicht (Form statt Prüfung);
virgin TU-Kopien (~8 KB); `make`-Link rot auf genau 4 Exit-Symbolen
(Makefile NOTE); Contention, Fuzzer, Wall-Clock offen seit bm8.
