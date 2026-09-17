#!/bin/bash
# Verdict-VM: Binary bauen (Gabbro only) + Gast-Dateien bereitstellen.
# Der Link braucht die 4 divergierenden Exits (Sprache hat kein `never`-Asm,
# Befund U-5/T-4); der Stub wird HIER per printf erzeugt -- kein C im Baum,
# kein C im Commit. Artefakte landen in vm/abbilder/share (git-ignoriert).
# Gebrauch: vm/baue-binary.sh  (aus dem Repo-Root oder ueberall)
set -e
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AB="$REPO/vm/abbilder"
STUB="$AB/stub.c"
OUT="$AB/share/verdict"
mkdir -p "$AB/share"
printf '%s\n' \
  '/* Scratch-Stub bm13: nur die 5 divergierenden Exits (abort).' \
  '   Erzeugt von vm/baue-binary.sh, nie committen (Makefile-NOTE).' \
  '   VSPERRE kommt aus gab/sperre.gab. */' \
  '#include <stdlib.h>' \
  '_Noreturn void zaehler_streit(void) { abort(); }' \
  '_Noreturn void netz_streit(void) { abort(); }' \
  '_Noreturn void lauf_aufgegeben(void) { abort(); }' \
  '_Noreturn void treffer_aufgegeben(void) { abort(); }' \
  '_Noreturn void verbindung_aufgegeben(void) { abort(); }' > "$STUB"
make -C "$REPO" pruefen >/dev/null
make -C "$REPO" >/dev/null 2>&1 || true   # Link ohne treiber/ bleibt rot (NOTE)
cc -std=c11 -Wall -Wextra -Werror -O2 -pthread -I "$REPO/bau" \
  -o "$OUT" "$REPO"/bau/*.c "$STUB"
cp "$REPO/vm/gast/vm-test.sh" "$AB/share/"
ls -lh "$OUT"
nm "$OUT" | grep -E " (main|entscheide|behandle|einrichten|VSPERRE_nimm)$"
