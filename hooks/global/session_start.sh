#!/bin/bash
# SessionStart hook: warn if SESSION_STATE.md is stale.
#
# Checks for a "마지막 업데이트: YYYY-MM-DD" marker inside
# $CLAUDE_PROJECT_DIR/.claude/SESSION_STATE.md and emits a systemMessage
# once it is ≥ 3 days old. Replace the marker string below if you prefer
# English ("Last updated:").

STATE_FILE="${CLAUDE_PROJECT_DIR:-.}/.claude/SESSION_STATE.md"
[ -f "$STATE_FILE" ] || exit 0

MARKER="마지막 업데이트"   # change to "Last updated" for English docs

LAST_UPDATE=$(grep -m1 "$MARKER" "$STATE_FILE" | grep -oP '\d{4}-\d{2}-\d{2}' || true)
[ -z "$LAST_UPDATE" ] && exit 0

LAST_TS=$(date -d "$LAST_UPDATE" +%s 2>/dev/null || true)
TODAY_TS=$(date +%s)
[ -z "$LAST_TS" ] && exit 0

DIFF=$(( (TODAY_TS - LAST_TS) / 86400 ))

if [ "$DIFF" -ge 3 ]; then
  echo "{\"systemMessage\": \"SESSION_STATE.md has not been updated for ${DIFF} days (last: $LAST_UPDATE). Please refresh it when you're done.\"}"
fi

exit 0
