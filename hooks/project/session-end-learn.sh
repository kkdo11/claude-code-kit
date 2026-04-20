#!/bin/bash
# SessionEnd hook: remind the user to record learnings.
#
# If the user never appended a dated entry to Learnings.md during this
# session, nudge them on the way out. stderr is shown to the user but
# not blocking.

LEARNINGS="$CLAUDE_PROJECT_DIR/.claude/skills/learnings/Learnings.md"

TODAY=$(date +%Y-%m-%d)
if [ -f "$LEARNINGS" ] && grep -q "$TODAY" "$LEARNINGS" 2>/dev/null; then
    exit 0
fi

echo "" >&2
echo "No /learn entry was added in this session. Consider recording lessons before the next one." >&2
echo "" >&2
exit 0
