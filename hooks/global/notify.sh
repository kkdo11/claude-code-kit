#!/bin/bash
# Notification hook: Windows toast popup from WSL2.
#
# WSL2-ONLY. On native Linux or macOS, replace the wscript.exe block with
# `notify-send` or `osascript -e 'display notification'`.
#
# Uses a VBS helper written to the Windows temp dir as UTF-16 LE so that
# Korean / non-ASCII characters render correctly in the toast.

INPUT=$(cat)

CWD=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('cwd',''))" 2>/dev/null)
PROJECT=$(basename "$CWD")

NTYPE=$(echo "$INPUT" | python3 -c "import json,sys; print(json.load(sys.stdin).get('notification_type',''))" 2>/dev/null)
case "$NTYPE" in
  permission_prompt) BODY="Permission needed — waiting for approval" ;;
  idle)              BODY="Task complete — ready for your next step" ;;
  *)                 BODY="Claude is waiting for input" ;;
esac

TITLE="Claude Code"
[ -n "$PROJECT" ] && TITLE="Claude Code — $PROJECT"

# WSL2 → Windows temp path
WIN_TEMP=$(wslpath "$(cmd.exe /c 'echo %TEMP%' 2>/dev/null | tr -d '\r')")
VBS="$WIN_TEMP/claude_notify.vbs"

python3 -c "
content = 'WScript.CreateObject(\"WScript.Shell\").Popup \"$BODY\", 6, \"$TITLE\", 64\n'
with open('$VBS', 'w', encoding='utf-16-le') as f:
    f.write(content)
"

# Fire and forget (don't block Claude)
wscript.exe "$(wslpath -w "$VBS")" &

exit 0
