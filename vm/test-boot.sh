#!/bin/bash
# Verdict-VM: installierte Platte booten. Seriell = stdio (tmux-Pane),
# Monitor-Socket fuer info/screendump.
#   tmux new-session -d -s verdict-vm -x 160 -y 50 vm/test-boot.sh
#   tmux send-keys -t verdict-vm root Enter  (dann Passwort)
#   printf 'screendump ...' | socat UNIX-CONNECT:vm/abbilder/mon.sock -
set -e
VM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AB="$VM/abbilder"
[ -f "$AB/disk.qcow2" ] || { echo "keine Platte -- erst vm/install-boot.sh"; exit 1; }
rm -f "$AB/mon.sock"
exec qemu-system-x86_64 \
  -enable-kvm -m 2048 -smp 2 \
  -drive file="$AB/disk.qcow2",if=virtio,format=qcow2 \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -display none -serial stdio \
  -monitor unix:"$AB/mon.sock",server,nowait
