#!/usr/bin/env python3
"""PostToolUse(Bash) hook: sync test count into SESSION_STATE.md.

Watches for pytest / gradle test invocations in the Bash tool input.
When a run passes cleanly, it rewrites two markers inside
`$CLAUDE_PROJECT_DIR/.claude/SESSION_STATE.md`:

    테스트 N개 통과           -> "테스트 <new count>개 통과"
    마지막 업데이트: YYYY-MM-DD -> "마지막 업데이트: <today>"

If you prefer English markers (e.g. "Tests passing:" / "Last updated:"),
change the two regexes near the bottom of this file.

Covered runners:
  - pytest            matches `pytest` or `python -m pytest`
  - gradle            matches `gradlew test` or `gradle test`
"""
import json
import os
import re
import sys
from datetime import date

try:
    data = json.load(sys.stdin)
except (json.JSONDecodeError, EOFError):
    sys.exit(0)

command = data.get("tool_input", {}).get("command", "")

is_pytest = bool(re.search(r"pytest|python3? -m pytest", command))
is_gradle = bool(re.search(r"gradlew.*test|gradle.*test", command))

if not (is_pytest or is_gradle):
    sys.exit(0)

result = data.get("tool_response", {})
output = (
    result.get("stdout", "")
    if isinstance(result, dict)
    else (str(result) if result else "")
)

# Any failures → bail out, don't pollute state with a broken number.
if is_pytest and re.search(r"\d+ failed", output, re.IGNORECASE):
    sys.exit(0)
if is_gradle and re.search(r"FAILED|BUILD FAILED", output, re.IGNORECASE):
    sys.exit(0)

count = None
if is_pytest:
    m = re.search(r"(\d+) passed", output)
    if m:
        count = m.group(1)
elif is_gradle:
    m = re.search(r"(\d+) tests? successful", output) or re.search(
        r"(\d+) tests? completed", output
    )
    if m:
        count = m.group(1)

if not count:
    sys.exit(0)

project_dir = os.environ.get("CLAUDE_PROJECT_DIR", ".")
state_file = os.path.join(project_dir, ".claude", "SESSION_STATE.md")

if not os.path.isfile(state_file):
    sys.exit(0)

today = date.today().isoformat()
content = open(state_file).read()
content = re.sub(r"테스트 \d+개? 통과", f"테스트 {count}개 통과", content)
content = re.sub(
    r"마지막 업데이트: \d{4}-\d{2}-\d{2}",
    f"마지막 업데이트: {today}",
    content,
)
open(state_file, "w").write(content)
