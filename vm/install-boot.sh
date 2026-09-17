#!/bin/bash
# Verdict-VM: unbeaufsichtigte Debian-Installation (Kernel-Direktboot + ISO als CD).
# Laeuft in tmux (Ausgabe = Pane):  tmux new-session -d -s verdict-vm -x 160 -y 50 vm/install-boot.sh
# WICHTIG: Preseed faehrt am Ende per Poweroff herunter (kein Reboot-Loop, siehe
# BERICHT-qemu.md). QEMU beendet sich dann selbst (QEMU-EXIT:0 im Pane).
set -e
VM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AB="$VM/abbilder"
[ -f "$AB/vmlinuz" ] || { echo "erst vm/bereit-install.sh"; exit 1; }
[ -f "$AB/disk.qcow2" ] || qemu-img create -f qcow2 "$AB/disk.qcow2" 8G
exec qemu-system-x86_64 \
  -enable-kvm -m 2048 -smp 2 \
  -kernel "$AB/vmlinuz" \
  -initrd "$AB/initrd-seed.gz" \
  -append "auto=true priority=critical preseed/file=/preseed.cfg console=ttyS0,115200n8 DEBIAN_FRONTEND=text" \
  -drive file="$AB/disk.qcow2",if=virtio,format=qcow2 \
  -cdrom "$AB/debian-netinst.iso" \
  -netdev user,id=n0 -device virtio-net-pci,netdev=n0 \
  -nographic
