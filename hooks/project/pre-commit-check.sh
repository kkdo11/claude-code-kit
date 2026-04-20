#!/bin/bash
# PreToolUse hook (with if: "Bash(git commit*)"): block bad commits early.
#
# Runs only right before Claude invokes `git commit`. Inspects staged
# files and returns a deny decision if any of these show up:
#
#   - Hardcoded secrets (password/secret/api_key/token = "...")
#   - An .env file sneaking into the commit
#   - Leftover debug code: System.out.println, bare print(), breakpoint()
#
# Output format: if `jq` is available we emit a proper
# {permissionDecision: deny} JSON; otherwise we fall back to exit 2 with
# stderr so the user still sees why the commit was blocked.

INPUT=$(cat)
STAGED_FILES=$(git diff --cached --name-only 2>/dev/null)

if [ -z "$STAGED_FILES" ]; then
    exit 0
fi

ERRORS=""

for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        if grep -qEi '(password|secret|api_key|token)\s*[:=]\s*"[^"]+' "$file" 2>/dev/null; then
            ERRORS+="[SECURITY] hardcoded secret: $file\n"
        fi
        if [[ "$(basename "$file")" == ".env" ]]; then
            ERRORS+="[SECURITY] .env file in commit: $file\n"
        fi
    fi
done

for file in $STAGED_FILES; do
    if [ -f "$file" ]; then
        EXT="${file##*.}"
        if [[ "$EXT" == "java" || "$EXT" == "kt" ]]; then
            if grep -q 'System\.out\.print' "$file" 2>/dev/null; then
                ERRORS+="[STYLE] leftover debug: $file (System.out.println)\n"
            fi
        fi
        if [[ "$EXT" == "py" ]]; then
            if [[ "$file" != *"test"* ]] && grep -qP '^\s*print\(' "$file" 2>/dev/null; then
                ERRORS+="[STYLE] leftover debug: $file (print())\n"
            fi
            if grep -qP '^\s*(breakpoint|pdb\.set_trace)\(' "$file" 2>/dev/null; then
                ERRORS+="[BUG] leftover debugger: $file\n"
            fi
        fi
    fi
done

if [ -n "$ERRORS" ]; then
    REASON=$(echo -e "$ERRORS" | tr '\n' ' ' | sed 's/[[:space:]]*$//')
    if command -v jq &>/dev/null; then
        jq -n --arg reason "$REASON" '{
            hookSpecificOutput: {
                hookEventName: "PreToolUse",
                permissionDecision: "deny",
                permissionDecisionReason: $reason
            }
        }'
    else
        python3 -c "
import json, sys
reason = sys.argv[1]
print(json.dumps({
    'hookSpecificOutput': {
        'hookEventName': 'PreToolUse',
        'permissionDecision': 'deny',
        'permissionDecisionReason': reason
    }
}))
" "$REASON" 2>/dev/null || {
            echo "Commit blocked: $REASON" >&2
            exit 2
        }
    fi
    exit 0
else
    exit 0
fi
