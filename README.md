# claude-code-kit

> A battle-tested set of hooks for [Claude Code](https://docs.claude.com/en/docs/claude-code) — the CLI agent from Anthropic — that turn it from a "smart autocomplete" into a disciplined pair programmer.

Built and refined over months of real daily use on two production-ish projects:
a FastAPI LLM-caching proxy and a Spring Boot knowledge-graph agent.
Every hook in here exists because it prevented a real bug, caught a real mistake,
or removed a real piece of friction from my workflow.

If you use Claude Code day-to-day, there's a good chance at least one of these
will save you from something dumb. Take what's useful, leave the rest.

---

## What's inside

### 🌐 Global hooks (7) — `~/.claude/settings.json`

These run on **every** project. They guard against irreversible mistakes and
keep long-lived context files fresh.

| Hook | Event | What it does |
|------|-------|--------------|
| `security_gate.py` | `PreToolUse(Bash)` | Blocks `rm -rf /`, `DROP TABLE`, `FLUSHALL`, `FLUSHDB`, `TRUNCATE TABLE` before Claude can run them. Quote-aware, so `echo 'FLUSHALL'` won't trip it. |
| `snapshot.sh` | `PreToolUse(Edit\|Write)` | Timestamped backup of critical markdown docs (`SESSION_STATE.md`, `CLAUDE.md`, `MEMORY.md`, ...) right before Claude edits them. 5-min dedupe, 7-day retention. |
| `update_timestamp.sh` | `PostToolUse(Edit\|Write)` | Auto-refreshes the "last updated" line inside long-lived docs so it doesn't rot. |
| `prompt_inject.sh` | `UserPromptSubmit` | Injects per-project numbers (test count, tuned thresholds, …) extracted from `SESSION_STATE.md` into every user prompt. Warns if the state doc is ≥ 3 days stale, stops injecting at ≥ 7 days. |
| `session_start.sh` | `SessionStart` | On open, checks `SESSION_STATE.md` and warns if it hasn't been updated in 3+ days. |
| `session_end.sh` | `Stop` | If source files are newer than `SESSION_STATE.md`, blocks the stop event and forces Claude to refresh the state doc before the session ends. One-nudge-per-day to avoid loops. |
| `notify.sh` | `Notification` | **WSL2 only.** Shows a Windows toast popup when Claude needs permission or goes idle. UTF-16 LE encoded so Korean / non-ASCII renders correctly. |

### 📂 Project hooks (5) — `<repo>/.claude/settings.json`

These are the ones you commit into each repo so the whole team (including
future-you) gets the same safety rails.

| Hook | Event | What it does |
|------|-------|--------------|
| `pre-commit-check.sh` | `PreToolUse(Bash)` + `if: Bash(git commit*)` | Runs only right before Claude commits. Denies the commit if staged files contain hardcoded secrets, `.env`, `System.out.println`, bare `print()`, or leftover `breakpoint()`. |
| `quality-gate.sh` | `PostToolUse(Write\|Edit)` | Lint-on-write. Catches AWS / OpenAI / GitHub key shapes, bare `except:`, empty Java `catch`, f-string SQL, CORS wildcards, string concat in `@Query`, plaintext secrets in `application.properties`. Exit code 2 feeds the error back to Claude so it self-corrects. |
| `session-start-inject.sh` | `SessionStart` | Pulls `### Critical Learnings`, last 5 `## Recent Sessions`, and `### Patterns` from `.claude/skills/learnings/Learnings.md` into Claude's context automatically. |
| `session-end-learn.sh` | `SessionEnd` | Reminds you to append a `/learn` entry if you didn't record anything today. |
| `update_test_count.py` | `PostToolUse(Bash)` | When a pytest or gradle run passes cleanly, rewrites "테스트 N개 통과" and "마지막 업데이트: YYYY-MM-DD" markers inside `SESSION_STATE.md`. Supports pytest and Gradle; easy to extend. |

---

## Why this exists

Claude Code is an agent. Left alone, it will happily:
- Run `rm -rf` against the wrong directory
- Commit `.env` files with your OpenAI key
- Leave `print()` debug statements in production code
- Drift away from project context it loaded two hours ago

Each hook here closes one of those holes. They compose into something that
feels less like "AI doing things at you" and more like "a junior dev who
actually reads the style guide."

Concrete wins from daily use:
- **`security_gate.py`** has blocked 3 `FLUSHALL` attempts during cache debugging.
- **`quality-gate.sh`** catches a leaked API key roughly once a week when
  Claude copies sample code from docs.
- **`session_end.sh`** is the single biggest reason `SESSION_STATE.md`
  stays accurate across dozens of sessions.
- **`prompt_inject.sh`** means I never have to say "remember, the threshold
  is 0.75" again — it's always in context.

---

## Install

### Global hooks

```bash
# 1. Copy hooks into your Claude Code config
mkdir -p ~/.claude/hooks
cp hooks/global/* ~/.claude/hooks/
chmod +x ~/.claude/hooks/*.sh ~/.claude/hooks/*.py

# 2. Merge examples/global-settings.json into ~/.claude/settings.json
#    IMPORTANT: replace every {HOME} with your actual home path
#    (Claude Code does NOT expand $HOME in settings.json)
```

On macOS / native Linux, **skip `notify.sh`** or swap the `wscript.exe` block
for `notify-send` (Linux) or `osascript -e 'display notification ...'` (macOS).
See the comment at the top of the file.

### Project hooks

For each repo you want to protect:

```bash
mkdir -p <your-repo>/.claude/hooks
cp hooks/project/* <your-repo>/.claude/hooks/
chmod +x <your-repo>/.claude/hooks/*.sh <your-repo>/.claude/hooks/*.py

# Drop examples/project-settings.json into <your-repo>/.claude/settings.json
# ($CLAUDE_PROJECT_DIR IS expanded here, so no path editing needed.)
```

Commit `.claude/` into your repo so the rest of the team gets the same hooks.

### Verify

```bash
# Ask Claude to run something obviously blocked — should be stopped.
# In Claude Code, type:
#
#   Run: redis-cli FLUSHALL
#
# You should see the block message from security_gate.py.
```

---

## Conventions the hooks expect

A couple of hooks assume a simple convention you're free to adopt or tweak:

### `SESSION_STATE.md`

A small markdown file at `<repo>/.claude/SESSION_STATE.md` that contains at least:

```markdown
# Session State

마지막 업데이트: 2026-04-20

## Key Numbers
- 테스트 151개 통과
- threshold=0.75
```

The hooks key off the `마지막 업데이트:` and `테스트 N개 통과` markers. If you
prefer English, both are one-line sed changes inside the hooks — search for
the marker strings and swap them.

### `Learnings.md`

`<repo>/.claude/skills/learnings/Learnings.md` with this structure:

```markdown
### Critical Learnings
- Never mock the DB in integration tests.

## Recent Sessions

### 2026-04-20
- Fixed N+1 query in SearchService.

### 2026-04-18
- ...

### Patterns
- Cache misses spike after schema changes.
```

`session-start-inject.sh` pulls these three sections into every new session.

---

## Customizing

Every hook is a plain shell / Python script ≤ 100 lines. Open it, change what
you want. Some common edits:

- **Different markers** — `update_timestamp.sh` and `update_test_count.py`
  look for Korean markers by default; change `MARKER=` or the regex.
- **More blocked commands** — add a `(pattern, reason)` tuple to `BLOCKED`
  in `security_gate.py`.
- **More lint rules** — append a regex check to `quality-gate.sh`.
- **Different projects in `prompt_inject.sh`** — replace the two `EXAMPLE`
  branches with your own project names and regexes.

---

## Philosophy

- **Fail loud, fail early.** A blocked commit is cheaper than a reverted deploy.
- **Feedback over control.** `exit 2` + stderr lets Claude read the error and
  fix itself — almost always better than hard-blocking and making the human
  re-prompt.
- **Plain scripts, no framework.** Bash and Python. No Node, no deps beyond
  `python3` and (optionally) `jq`. Easy to read, easy to fork.
- **Sane defaults, not training wheels.** Every rule here exists because I
  hit the bug it prevents, not because it's theoretically nice.

---

## Contributing

This is a personal kit I'm sharing because a few people asked. PRs are very
welcome — especially:
- Native Linux / macOS variants of `notify.sh`
- English versions of the Korean marker strings
- New hooks with a clear "real-world bug this prevented" story

Open an issue first if you're proposing a big new hook so we can discuss
scope.

---

## License

MIT. Use it, fork it, ship it.

---

## About

Built by [@kkdo11](https://github.com/kkdo11) while running:

- **[llm-opt](https://github.com/kdw030612/llm-opt)** — FastAPI proxy with
  semantic caching (L1 hash + L2 HNSW) that cut GPU calls by 66%.
- **mindgraph-ai** — Personal Spring Boot knowledge-graph agent with
  RabbitMQ pipelines, pgvector + Neo4j hybrid RAG, and a React UI.

Both projects lived inside these hooks, so if anything breaks subtly,
it's been caught in anger. If you find something that could be better,
please tell me — I'd love to improve it.
