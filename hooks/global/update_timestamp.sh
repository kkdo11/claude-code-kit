#!/bin/bash
# PostToolUse(Edit|Write) hook: auto-refresh "last updated" stamp on docs.
#
# Looks for the literal marker `마지막 업데이트:` (Korean: "last updated:")
# inside a narrow allowlist of files and replaces the date with today's.
# If you prefer English, change the marker below to `Last updated:`.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('tool_input', {}).get('file_path', ''))
except: print('')
" 2>/dev/null)

echo "$FILE_PATH" | grep -qE '(SESSION_STATE|PHASE_TRACKER|current-sprint)\.md$' || exit 0
[ -f "$FILE_PATH" ] || exit 0

TODAY=$(date +%Y-%m-%d)
MARKER="마지막 업데이트:"   # change to "Last updated:" for English docs

if grep -q "$MARKER" "$FILE_PATH"; then
  sed -i "s/$MARKER [0-9-]*/$MARKER $TODAY/" "$FILE_PATH"
fi

exit 0
