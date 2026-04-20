#!/bin/bash
# SessionStart hook: inject accumulated learnings into Claude's context.
#
# Reads $CLAUDE_PROJECT_DIR/.claude/skills/learnings/Learnings.md and
# extracts three sections:
#
#   1. ### Critical Learnings   — permanent do/don't rules
#   2. ## Recent Sessions       — last 5 dated entries
#   3. ### Patterns             — recurring observations
#
# Whatever is written to stdout gets appended to Claude's context at
# session start, so past lessons are always available.

LEARNINGS="$CLAUDE_PROJECT_DIR/.claude/skills/learnings/Learnings.md"
OUTPUT=""

if [ -f "$LEARNINGS" ]; then
    CRITICAL=$(sed -n '/^### Critical Learnings/,/^### /{ /^### Critical Learnings/d; /^### /d; p; }' "$LEARNINGS" | head -20)
    if [ -n "$CRITICAL" ] && [[ "$CRITICAL" =~ [^[:space:]] ]]; then
        OUTPUT+="=== Critical Learnings ===\n$CRITICAL\n\n"
    fi
fi

if [ -f "$LEARNINGS" ]; then
    RECENT=$(awk '
        /^### [0-9]{4}-[0-9]{2}-[0-9]{2}/ { count++; if (count > 5) exit }
        count >= 1 { print }
    ' <(sed -n '/^## Recent Sessions/,$ p' "$LEARNINGS" | tail -n +2))

    if [ -n "$RECENT" ] && [[ "$RECENT" =~ [^[:space:]] ]]; then
        OUTPUT+="=== Recent Session Learnings (last 5) ===\n$RECENT\n\n"
    fi

    PATTERNS=$(sed -n '/^### Patterns/,/^### /{ /^### Patterns/d; /^### /d; p; }' "$LEARNINGS" | head -10)
    if [ -n "$PATTERNS" ] && [[ "$PATTERNS" =~ [^[:space:]] ]]; then
        OUTPUT+="=== Recurring Patterns ===\n$PATTERNS\n\n"
    fi
fi

if [ -n "$OUTPUT" ]; then
    echo -e "$OUTPUT"
    echo "Above are lessons accumulated in previous sessions. Refer to them during this work."
fi

exit 0
