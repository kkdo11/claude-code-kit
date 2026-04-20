#!/bin/bash
# PostToolUse hook (matcher: Write|Edit): lightweight linter gate.
#
# Runs right after Claude writes to a file. Scans for:
#   - Hardcoded secrets (common patterns + AWS/OpenAI/GitHub key shapes)
#   - Java/Kotlin: empty catch blocks, System.out.print, @Query string
#     concatenation, CORS wildcards
#   - Python: bare except, stray print(), f-string SQL, eval/exec
#   - application.yml/properties with plaintext secrets
#
# Exit code 2 + stderr is how Claude Code feeds errors back to the model,
# so Claude will see the complaint and try to self-correct.

INPUT=$(cat)

if command -v jq &>/dev/null; then
    FILEPATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // .tool_input.path // empty')
else
    FILEPATH=$(echo "$INPUT" | python3 -c "
import sys, json
try:
    d = json.load(sys.stdin)
    ti = d.get('tool_input', {})
    print(ti.get('file_path') or ti.get('path') or '')
except:
    print('')
" 2>/dev/null)
fi

if [ -z "$FILEPATH" ] || [ ! -f "$FILEPATH" ]; then
    exit 0
fi

EXTENSION="${FILEPATH##*.}"
FILENAME=$(basename "$FILEPATH")
ERRORS=""

# 1. Secret detection (all files, skip self)
if [[ "$FILENAME" != "quality-gate.sh" ]]; then
    SECRET_PATTERNS=(
        'password\s*=\s*"[^"]+'
        'secret\s*=\s*"[^"]+'
        'api_key\s*=\s*"[^"]+'
        'token\s*=\s*"[^"]+'
        'jdbc:.*password=[^&]+'
        'AKIA[0-9A-Z]{16}'
        'sk-[a-zA-Z0-9]{32,}'
        'ghp_[a-zA-Z0-9]{36}'
    )

    for pattern in "${SECRET_PATTERNS[@]}"; do
        if grep -qEi "$pattern" "$FILEPATH" 2>/dev/null; then
            LINE=$(grep -nEi "$pattern" "$FILEPATH" | head -1 | cut -d: -f1)
            ERRORS+="[SECURITY] hardcoded secret ($FILEPATH:$LINE). Use env vars or a secret manager.\n"
        fi
    done
fi

# 2. Java / Kotlin
if [[ "$EXTENSION" == "java" || "$EXTENSION" == "kt" ]]; then
    if grep -qP 'catch\s*\([^)]+\)\s*\{\s*\}' "$FILEPATH" 2>/dev/null; then
        ERRORS+="[BUG] empty catch block ($FILEPATH). Log or handle the exception.\n"
    fi
    if grep -q 'System\.out\.print' "$FILEPATH" 2>/dev/null; then
        LINE=$(grep -n 'System\.out\.print' "$FILEPATH" | head -1 | cut -d: -f1)
        ERRORS+="[STYLE] System.out.println ($FILEPATH:$LINE). Use a Logger.\n"
    fi
    if grep -qP '@Query.*\+\s*' "$FILEPATH" 2>/dev/null; then
        ERRORS+="[SECURITY] string concat inside @Query ($FILEPATH). Use :param binding.\n"
    fi
    if grep -q 'allowedOrigins.*\*' "$FILEPATH" 2>/dev/null; then
        ERRORS+="[SECURITY] CORS wildcard (*) ($FILEPATH). Pin to explicit origins.\n"
    fi
fi

# 3. Python
if [[ "$EXTENSION" == "py" ]]; then
    if grep -qP '^\s*except\s*:' "$FILEPATH" 2>/dev/null; then
        LINE=$(grep -nP '^\s*except\s*:' "$FILEPATH" | head -1 | cut -d: -f1)
        ERRORS+="[BUG] bare except ($FILEPATH:$LINE). Specify the exception type.\n"
    fi
    if grep -qP '^\s*print\(' "$FILEPATH" 2>/dev/null; then
        LINE=$(grep -nP '^\s*print\(' "$FILEPATH" | head -1 | cut -d: -f1)
        ERRORS+="[STYLE] stray print() ($FILEPATH:$LINE). Use logger.\n"
    fi
    if grep -qP 'execute.*f["\\x27]' "$FILEPATH" 2>/dev/null; then
        ERRORS+="[SECURITY] f-string SQL ($FILEPATH). Use parameterized queries.\n"
    fi
    if grep -qP '^\s*(eval|exec)\(' "$FILEPATH" 2>/dev/null; then
        ERRORS+="[SECURITY] eval/exec ($FILEPATH). Code injection risk.\n"
    fi
fi

# 4. Config files
if [[ "$FILENAME" == "application.yml" || "$FILENAME" == "application.yaml" || "$FILENAME" == "application.properties" ]]; then
    if grep -qEi '(password|secret|token)\s*[:=]\s*[^$\{]' "$FILEPATH" 2>/dev/null; then
        ERRORS+="[SECURITY] plaintext secret in config ($FILEPATH). Use \${ENV_VAR} references.\n"
    fi
fi

if [[ "$FILENAME" == ".env" ]]; then
    ERRORS+="[SECURITY] .env file was modified ($FILEPATH). Make sure it's .gitignored.\n"
fi

if [ -n "$ERRORS" ]; then
    echo -e "Quality Gate issues found:\n$ERRORS\nPlease fix the issues above." >&2
    exit 2
else
    exit 0
fi
