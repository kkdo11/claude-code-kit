#!/bin/bash
# PreToolUse(Edit|Write) hook: snapshot important docs before modification.
#
# Protects a small allowlist of high-value markdown files (SESSION_STATE,
# CLAUDE, MEMORY, PHASE_TRACKER, current-sprint). Snapshots older than 7
# days are purged automatically. If a snapshot was taken within the last
# 5 minutes we skip to avoid spam.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except: print('')
" 2>/dev/null)

echo "$FILE_PATH" | grep -qE '(SESSION_STATE|CLAUDE|current-sprint|MEMORY|PHASE_TRACKER)\.md$' || exit 0
[ -f "$FILE_PATH" ] || exit 0

SNAPSHOT_DIR="$HOME/.claude/snapshots"
mkdir -p "$SNAPSHOT_DIR"

FILENAME=$(basename "$FILE_PATH")

RECENT=$(find "$SNAPSHOT_DIR" -name "${FILENAME}.*" -mmin -5 2>/dev/null | head -1)
if [ -n "$RECENT" ]; then
  exit 0
fi

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
cp "$FILE_PATH" "$SNAPSHOT_DIR/${FILENAME}.${TIMESTAMP}.bak"

find "$SNAPSHOT_DIR" -name "*.bak" -mtime +7 -delete 2>/dev/null || true

exit 0
