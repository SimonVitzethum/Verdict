YOUR MODULE: `treiber/` — the C driver, and nothing else. You write C, not Gabbro, and you are the only lane that does.

Build:
- a NFQUEUE receiver using **libnetfilter_queue** (if the library is unavailable in this clone, use raw netlink over `AF_NETLINK`/`NETLINK_NETFILTER` and say so; either way the packets must be real),
- **N worker threads** (default 4), each bound to its own queue number so the kernel's `fanout` spreads flows across them,
- per packet: copy the payload into the Gabbro `Paket` table, call the one entry point
  `uint32_t entscheide(uint32_t laenge, uint32_t faden);`
  and hand the answer back as the verdict (0 DROP, 1 ACCEPT, 2 REJECT — REJECT means the driver also sends the rejection, not Gabbro),
- the lock primitives the emitted Gabbro C declares but does not define (`L_nimm`, `L_gib` — see `muster/start-muster.c`, which does exactly this for the Gabbro tree's own runtime),
- a startup path that loads rules into the Gabbro rule table through its `setze_regel` entry, from a simple text file — a firewall nobody can configure is not usable,
- statistics printed on `SIGUSR1` by reading the Gabbro counters.

**The other lanes' `.gab` files do not exist yet.** Write against the signatures in `ARCHITEKTUR.md`, declare them in a header of your own, and keep the driver compiling on its own with a stub file that you keep OUT of the final link (say where it is). Your deliverable is a driver that is ready the moment the modules land.

Also: the exact `nft` rule needed to attach the firewall, and a loopback test procedure in a network namespace — written down, runnable, and honest about what it needs (root).
