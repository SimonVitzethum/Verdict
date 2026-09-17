#!/bin/bash
# Verdict-VM: Gast-Dateien per HTTP anbieten (Gast holt per wget ueber 10.0.2.2).
#   tmux new-window -t verdict-vm -n http -d 'vm/teile-aus.sh'
#   Gast: wget http://10.0.2.2:8000/verdict http://10.0.2.2:8000/vm-test.sh
set -e
REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec python3 -m http.server 8000 --directory "$REPO/vm/abbilder/share"
