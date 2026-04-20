#!/bin/bash
# install.sh — copy global hooks into ~/.claude/hooks/
#
# For project hooks, see the README; they need to be copied per-repo.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEST="$HOME/.claude/hooks"

echo "Installing global hooks to $DEST"
mkdir -p "$DEST"

cp "$SCRIPT_DIR/hooks/global/"*.sh "$DEST/"
cp "$SCRIPT_DIR/hooks/global/"*.py "$DEST/"
chmod +x "$DEST/"*.sh "$DEST/"*.py

echo
echo "Done. Next steps:"
echo "  1. Open ~/.claude/settings.json"
echo "  2. Merge in examples/global-settings.json from this repo"
echo "  3. Replace every {HOME} placeholder with: $HOME"
echo
if [[ "$(uname -r)" != *microsoft* ]] && [[ "$(uname -r)" != *Microsoft* ]]; then
    echo "NOTE: you're not on WSL2 — edit or remove the Notification hook"
    echo "      entry (notify.sh) since it uses wscript.exe."
fi
