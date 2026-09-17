#!/bin/bash
# Verdict-VM: Installations-Vorbereitung. Legt Kernel+Initrd aus der netinst-ISO
# nach vm/abbilder und haengt preseed.cfg als zweites cpio-Archiv an die Initrd
# (Debian findet /preseed.cfg darin; der Kernel meldet "junk within compressed
# archive" -- harmlos, siehe BERICHT-qemu.md). ISO wird NICHT committet.
# Gebrauch: vm/bereit-install.sh  (einmalig; danach vm/install-boot.sh)
set -e
VM="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AB="$VM/abbilder"
ISO="$AB/debian-netinst.iso"
[ -f "$ISO" ] || { echo "FEHLT: $ISO -- laden:"; echo "  wget -O $ISO https://cdimage.debian.org/debian-cd/current/amd64/iso-cd/debian-13.7.0-amd64-netinst.iso"; exit 1; }
mkdir -p "$AB/boot-extract"
bsdtar -xf "$ISO" -C "$AB/boot-extract" install.amd/vmlinuz install.amd/initrd.gz
cp "$AB/boot-extract/install.amd/vmlinuz" "$AB/vmlinuz"
cp "$AB/boot-extract/install.amd/initrd.gz" "$AB/initrd-seed.gz"
chmod u+w "$AB/initrd-seed.gz"
mkdir -p "$AB/seed" && cp "$VM/preseed.cfg" "$AB/seed/preseed.cfg"
(cd "$AB/seed" && find . -print0 | cpio --format=newc --create --null 2>/dev/null | gzip >> "$AB/initrd-seed.gz")
ls -lh "$AB/vmlinuz" "$AB/initrd-seed.gz"
echo BEREIT
