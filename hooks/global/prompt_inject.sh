#!/bin/bash
# UserPromptSubmit hook: inject per-project numbers into Claude's context.
#
# Reads $CLAUDE_PROJECT_DIR/.claude/SESSION_STATE.md and extracts a handful
# of key metrics (test count, tuned thresholds, ...) every time the user
# submits a new prompt. Returns them as `additionalContext` so Claude
# always has the latest numbers without re-reading the file.
#
# Staleness handling: ≥ 3 days → warn alongside the context;
#                    ≥ 7 days → skip injection entirely, warn only.
#
# The EXAMPLES below show two projects; swap their names and metric
# regexes for your own.

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
PROJECT=$(basename "$PROJECT_DIR")
STATE_FILE="$PROJECT_DIR/.claude/SESSION_STATE.md"

[ -f "$STATE_FILE" ] || exit 0

LAST_UPDATE=$(grep -m1 "마지막 업데이트" "$STATE_FILE" | grep -oP '\d{4}-\d{2}-\d{2}' || true)
STALE_DAYS=0
if [ -n "$LAST_UPDATE" ]; then
  LAST_TS=$(date -d "$LAST_UPDATE" +%s 2>/dev/null || echo 0)
  TODAY_TS=$(date +%s)
  STALE_DAYS=$(( (TODAY_TS - LAST_TS) / 86400 ))
fi

if [ "$STALE_DAYS" -ge 7 ]; then
  echo "{\"hookSpecificOutput\": {\"hookEventName\": \"UserPromptSubmit\", \"additionalContext\": \"SESSION_STATE is ${STALE_DAYS} days stale — do not trust its numbers\"}}"
  exit 0
fi

CONTEXT=""

# -------- EXAMPLE 1: Python project, extract threshold + test count --------
if [ "$PROJECT" = "my-python-project" ]; then
  THRESHOLD=$(grep -oP 'threshold=\K[\d.]+' "$STATE_FILE" | head -1)
  TEST=$(grep -m1 "tests.*passing\|[0-9]*개 통과" "$STATE_FILE" | head -c 60)
  CONTEXT="[my-python-project] threshold=${THRESHOLD:-N/A} | ${TEST:-no test info}"

# -------- EXAMPLE 2: Java project, extract test count only --------
elif [ "$PROJECT" = "my-java-project" ]; then
  TEST=$(grep -m1 "tests.*passing\|[0-9]*개 통과" "$STATE_FILE" | head -c 60)
  CONTEXT="[my-java-project] ${TEST:-no test info}"
fi

if [ -n "$CONTEXT" ]; then
  [ "$STALE_DAYS" -ge 3 ] && CONTEXT="$CONTEXT | SESSION_STATE is ${STALE_DAYS} days stale"
  echo "{\"hookSpecificOutput\": {\"hookEventName\": \"UserPromptSubmit\", \"additionalContext\": \"$CONTEXT\"}}"
fi

exit 0
