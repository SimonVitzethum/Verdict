YOUR MODULE: `gab/regeln.gab` — the rule table and the match. A firewall is its rules: a fixed table `Regel count 256`, each slot carrying a match (protocol, source address and mask, destination address and mask, source port range, destination port range, TCP flag mask and value, an "any" marker per field) and a verdict (0 DROP, 1 ACCEPT, 2 REJECT), plus an `aktiv` flag and a rule number.

Write:
- `pub impl fn passt(r : index into Regel, ...)` — does one rule match the decoded header? Take the header fields as parameters (the shapes are in ARCHITEKTUR.md); do NOT read another module's table.
- `pub impl fn entscheide_regeln(...) -> u32 in 0 .. 2` — first match wins, walking the table in order; if no rule matches, the **default policy** applies, and that policy is a declared constant in your file, not a magic number.
- A way to load a rule (`pub impl fn setze_regel(...)`) that the driver can call at startup — a firewall with a hardcoded rule set is not usable.

**The interesting part, and say what you find:** a table walk with an early exit, under a declared cost bound, over a fixed count. Gabbro asks you to say what it costs and what it writes; if the loop form you need is refused, that refusal is a finding — with the code and the shape that produced it.
