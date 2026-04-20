#!/bin/bash
# Stop hook: force update of SESSION_STATE.md before ending a session.
#
# If the current project directory has subprojects (each with their own
# .claude/SESSION_STATE.md), iterate through all of them. Otherwise treat
# the project directory itself as the single target.
#
# Emits a {"decision":"block"} JSON only when recently-modified source
# files exist that are newer than SESSION_STATE.md — this forces Claude
# to refresh the state doc before the user leaves. A per-day marker in
# /tmp ensures we don't block the same project twice on one day.

TODAY=$(date +%Y-%m-%d)
ROOT="${CLAUDE_PROJECT_DIR:-.}"
PROJECTS=()

for DIR in "$ROOT"/*/; do
  if [ -f "${DIR}.claude/SESSION_STATE.md" ]; then
    PROJECTS+=("$DIR")
  fi
done

if [ ${#PROJECTS[@]} -eq 0 ]; then
  PROJECTS=("$ROOT")
fi

STALE_MESSAGES=""

for PROJECT_DIR in "${PROJECTS[@]}"; do
  PROJECT_DIR="${PROJECT_DIR%/}"
  STATE_FILE="$PROJECT_DIR/.claude/SESSION_STATE.md"
  [ -f "$STATE_FILE" ] || continue

  LAST_UPDATE=$(grep -m1 "마지막 업데이트" "$STATE_FILE" | grep -oP '\d{4}-\d{2}-\d{2}' || true)
  [ "$LAST_UPDATE" = "$TODAY" ] && continue

  MARKER="/tmp/claude_stop_hook_${TODAY}_$(basename "$PROJECT_DIR")"
  [ -f "$MARKER" ] && continue

  # Any source files newer than the state doc?
  RECENT=$(find "$PROJECT_DIR" \
    \( -name "*.py" -o -name "*.java" -o -name "*.sh" -o -name "*.tsx" -o -name "*.ts" -o -name "*.js" \) \
    -newer "$STATE_FILE" \
    -not -path "*/__pycache__/*" \
    -not -path "*/.git/*" \
    -not -path "*/node_modules/*" \
    -not -path "*/build/*" \
    2>/dev/null | head -5)

  if [ -n "$RECENT" ]; then
    touch "$MARKER"
    PROJECT_NAME=$(basename "$PROJECT_DIR")
    FILES=$(echo "$RECENT" | while read f; do echo "  - $(basename "$f")"; done)
    STALE_MESSAGES="${STALE_MESSAGES}[${PROJECT_NAME}] SESSION_STATE.md is out of date (last: ${LAST_UPDATE:-none}). Changed files:\n${FILES}\n"
  fi
done

if [ -n "$STALE_MESSAGES" ]; then
  echo "{\"decision\":\"block\",\"reason\":\"${STALE_MESSAGES}Please refresh .claude/SESSION_STATE.md.\"}"
fi

exit 0
