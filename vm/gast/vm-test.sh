#!/bin/bash
# Verdict QEMU-Test, Gaesteseite (Debian 13, root). Erwartung:
#   curl :80 -> 200 (ACCEPT, Regel "TCP Zielport 80"), curl :81 -> Timeout (DROP, Default).
# Rueckweg (Sport 80/81) wird nie gequect (Regel matcht nur Input-Dport), also kein SYN-ACK-Problem.
set -u
VDIR=/root/verdict-test
mkdir -p "$VDIR"; cd "$VDIR"
exec > >(tee "$VDIR/test.log") 2>&1
echo "=== 0. Umgebung ==="
id; hostname; cat /etc/debian_version; nft --version
ls -l verdict && file verdict | cut -c1-100
echo "=== 1. nft-Regeln (nur Dports 80/81 in die Queue, SSH bleibt frei) ==="
nft flush ruleset
nft add table inet filter
nft add chain inet filter input '{ type filter hook input priority 0; policy accept; }'
nft add rule inet filter input tcp dport '{ 80, 81 }' queue num 0
nft list ruleset
echo "=== 2. verdict starten (genau eine Instanz, unter strace als Zweitbeleg) ==="
pkill -9 -x verdict 2>/dev/null; sleep 1
ps -C verdict 2>/dev/null || echo "kein alter verdict (erwartet)"
strace -f -o v-strace.log -e trace=network,exit_group ./verdict >stdout.log 2>stderr.log & SPid=$!
sleep 2
if kill -0 $SPid 2>/dev/null; then echo " verdict(strace) lebt (erwartet: blockiert in recvfrom)"; else echo " STRACE-VERDICT BEENDET"; tail -5 v-strace.log; fi
echo "--- strace-Anfang (socket/bind/sendto/ACKs erwartet) ---"
grep -a -E "socket|bind|sendto|recvfrom|exit_group" v-strace.log | head -8
echo "=== 3. Server :80 + :81 ==="
python3 -m http.server 80 --bind 127.0.0.1 >srv80.log 2>&1 &
python3 -m http.server 81 --bind 127.0.0.1 >srv81.log 2>&1 &
sleep 1
ss -tln | grep -E ":80|:81"
echo "=== 4. Client-Tests ==="
echo "--- :80 (erwartet ACCEPT -> 200) ---"
time curl --connect-timeout 4 --max-time 10 -s -o /dev/null -w "http=%{http_code} exit=%{exitcode}\n" http://127.0.0.1/ || true
echo "--- :81 (erwartet DROP -> Timeout) ---"
time curl --connect-timeout 4 --max-time 10 -s -o /dev/null -w "http=%{http_code} exit=%{exitcode}\n" http://127.0.0.1:81/ || true
echo "=== 5. Belege ==="
echo "--- nft-Zaehler (gequecte Pakete) ---"
nft list chain inet filter input
echo "--- verdict-Verdictwoerter aus strace (id + urteil) ---"
grep -a -c "sendto" v-strace.log | xargs echo "verdict-sendto-Antworten:"
echo "--- Prozesse ---"
kill -0 $SPid 2>/dev/null && echo "verdict laeuft noch" || echo "verdict beendet"
echo "=== 6. Aufraeumen ==="
kill $SPid 2>/dev/null; sleep 1
kill -9 $SPid 2>/dev/null; pkill -9 -x verdict 2>/dev/null; pkill -f "http.server 8" 2>/dev/null
nft flush ruleset
echo "FERTIG test.log in $VDIR"
