YOUR MODULE: `gab/pakete.gab` — the packet decoder. The driver drops a raw frame into the `Paket` table (1600 byte slots, `u32 in 0 .. 255` each) and calls you with its length. You produce the decoded header in `Kopf` exactly as ARCHITEKTUR.md fixes it: `gueltig`, `proto`, `quelle`, `ziel`, `qport`, `zport`, `flaggen`, `laenge`.

Decode IPv4 over Ethernet: the EtherType at offset 12/13 (0x0800 is IPv4; anything else is `gueltig = 0`), then the IPv4 header — version and IHL, total length, protocol, source and destination address — and then TCP (ports at the IHL-derived offset, flags byte) or UDP (ports only) or ICMP (ports 0).

**Every read of the packet is bounds-checked against the length you were given, and a truncated packet is `gueltig = 0`, never a guess.** A firewall that reads past a short packet is the classic hole; the checker will help you here, and where it refuses, that refusal belongs in your finding file.

Write `pub impl fn entpacke(laenge : u32 in 0 .. 1600) -> u32 in 0 .. 1` — it fills `Kopf.slots[0]` and answers 1 for a decoded packet, 0 for a malformed one. Keep it to one table write per field and declare your effects and costs honestly.
