YOUR MODULE: `gab/netzverbindung.gab` — the NFQUEUE protocol over raw netlink, in Gabbro. This is the part that makes the firewall real: the kernel sends queued packets as netlink messages, and the verdict goes back the same way. **No library does this for you here — you write the bytes.**

What it must do:
1. **Configuration**, sent once per worker queue: `NFQNL_MSG_CONFIG` with `NFQA_CFG_CMD` = `NFQNL_CFG_CMD_BIND`, then `NFQA_CFG_PARAMS` with copy mode `NFQNL_COPY_PACKET` and a copy range, and the flags that let the queue keep working under load. The message layout is `nlmsghdr` (16 bytes) + `nfgenmsg` (4 bytes) + TLV attributes (`nlattr`: 2-byte length, 2-byte type, payload, padded to 4).
2. **Receiving**: parse the `nlmsghdr`/`nfgenmsg` of an incoming message, walk its attributes, find `NFQA_PACKET_HDR` (the packet id, big-endian) and `NFQA_PAYLOAD` (the packet itself), and copy the payload into the `Paket` table byte by byte with a bound check against both the message length and the table's `count`.
3. **The verdict**: build `NFQNL_MSG_VERDICT` with `NFQA_VERDICT_HDR` carrying the packet id and the verdict word, and hand it to `sendto`.

**Byte order is the trap and the point.** Netlink headers are host order; nfnetlink attribute payloads (the packet id, the verdict, the protocol family fields) are **big-endian**. Write the conversion by hand, name it, and test it — Gabbro has no `htonl`.

Take the syscall signatures from `gab/systemrufe.gab`'s lane (ARCHITEKTUR.md names them); if that file is not in your clone yet, declare what you need as a comment block at the top of your file and say so in your report — do not write a second copy of the syscalls.

Everything is table work over fixed buffers: a receive buffer table, a send buffer table, and bounds checks that the checker will hold you to. Report every refusal with its code.
