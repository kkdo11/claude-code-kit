#!/usr/bin/env python3
"""PreToolUse(Bash) hook: block dangerous commands before they run.

Matches common destructive patterns (rm -rf /, DROP TABLE, FLUSHALL, ...)
and returns a block decision. Quoted strings are stripped first so that
`echo 'FLUSHALL'` does not trigger a false positive.
"""
import json
import re
import sys

try:
    data = json.load(sys.stdin)
except (json.JSONDecodeError, EOFError):
    sys.exit(0)

cmd = data.get("tool_input", {}).get("command", "")


def strip_quoted(s: str) -> str:
    s = re.sub(r"'[^']*'", "''", s)
    s = re.sub(r'"[^"]*"', '""', s)
    return s


cmd_unquoted = strip_quoted(cmd)

BLOCKED = [
    (r"rm\s+-r[f]?\s+/(?!\w)", "Delete system root"),
    (r"DROP\s+TABLE", "Drop DB table"),
    (r"TRUNCATE\s+TABLE", "Truncate DB table"),
    (r"redis-cli\s+FLUSHALL", "Flush all Redis caches"),
    (r"redis-cli\s+FLUSHDB", "Flush Redis DB"),
]

for pattern, reason in BLOCKED:
    if re.search(pattern, cmd_unquoted, re.IGNORECASE):
        result = {
            "decision": "block",
            "reason": (
                f"Blocked: {reason} | command: {cmd[:100]} | "
                "Run it directly in your terminal if you really mean it."
            ),
        }
        print(json.dumps(result))
        sys.exit(0)
