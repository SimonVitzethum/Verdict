YOUR MODULE: `gab/entscheidung.gab` — the wiring, and it is deliberately small. Five modules exist and check clean in your clone: `pakete.gab` (decoder), `regeln.gab` (rule table), `verbindungen.gab` (connection table), `zaehler.gab` (counters), `systemrufe.gab` (the kernel border). **Read their public signatures, do not read their internals, and change none of them.**

Write the one function the program calls per packet:

```
pub impl fn entscheide(laenge : u32 in 0 .. 1600, faden : u32 in 0 .. 15) -> u32 in 0 .. 2
```

The order is the firewall's policy and you write it down as such:
1. decode (`entpacke`); a malformed packet is counted and DROPped — no rule is consulted for a packet we could not read;
2. look the flow up in the connection table (`suche_oder_lege_an`) with the decoded tuple and the current time;
3. an ESTABLISHED flow takes the fast path: ACCEPT without walking the rules, and say in a comment why that is the right semantics (and what it costs in security if the rule set changes at runtime);
4. otherwise walk the rules (`entscheide_regeln`), and the default policy decides when nothing matches;
5. count the verdict and the rule hit (`zaehle_urteil`, `zaehle_regel`).

**The cost declaration is the interesting part of this lane**: your `costs` must cover the worst case through all five modules, and the checker will hold you to it. Report the number it computes and where it comes from — that number is the worst-case per-packet work of this firewall, and an operator would want to know it.

Where a module's signature does not give you what the order above needs, do NOT reach into the module: write down what is missing in `messung/BEFUNDE-bm8.md` and solve it within your own file if you honestly can.
