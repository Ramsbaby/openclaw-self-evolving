<div align="center">

# \ud83e\udde0 OpenClaw Self-Evolving Agent

[![GitHub stars](https://img.shields.io/github/stars/Ramsbaby/openclaw-self-evolving?style=flat-square)](https://github.com/Ramsbaby/openclaw-self-evolving/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Platform: macOS/Linux](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue?style=flat-square)](#)
[![OpenClaw Required](https://img.shields.io/badge/requires-OpenClaw-orange?style=flat-square)](https://github.com/openclaw/openclaw)
[![No Silent Modification](https://img.shields.io/badge/policy-no%20silent%20modification-brightgreen?style=flat-square)](#)
[![False Positive Rate](https://img.shields.io/badge/false_positive_rate-8%25-brightgreen)](README.md)

*Your AI agent reviews its own conversation logs and proposes how to improve \u2014 every week, automatically.*

> **Honest disclaimer:** This is not AGI. It's a weekly log review with pattern matching.
> It finds things you'd find yourself \u2014 if you had time to read 500 conversation logs.

</div>

---

## The Problem

AI agents make the same mistakes repeatedly.
Nobody has time to manually review thousands of conversation logs.
The mistakes keep accumulating, silently.

Self-Evolving automates the review \u2014 and brings you a short list of what to fix.

---

## How It Works

```
Session Logs (7 days)
    \u2192 Analyzer (bash + Python, no API calls)
    \u2192 Detected Patterns (JSON)
    \u2192 Proposal Generator (template-based, 6 pattern types)
    \u2192 Discord / Telegram Report
    \u2192 GitHub Issue (optional, --create-issue flag)   \u2190 NEW in v3.1
    \u2192 You approve or reject (emoji reactions)
    \u2192 Approved: auto-apply to AGENTS.md + git commit
    \u2192 Rejected: reason stored \u2192 fed into next week's analysis
```

**No LLM calls during analysis. No API fees. Pure local log processing.**

---

> \u26a0\ufe0f **OpenClaw required.** This tool analyzes OpenClaw session logs specifically (`~/.openclaw/agents/*/sessions/*.jsonl`). Other platforms are not supported yet.

## \u26a1 Quick Start

```bash
# Install via ClawHub
clawhub install openclaw-self-evolving

# Run setup wizard (registers weekly cron)
bash scripts/setup-wizard.sh
```

<details>
<summary>Manual install</summary>

```bash
git clone https://github.com/Ramsbaby/openclaw-self-evolving.git
cd openclaw-self-evolving
cp config.yaml.example config.yaml
# Edit config.yaml: set agents_dir, logs_dir, agents_md
bash scripts/setup-wizard.sh
```
</details>

---

## What It Detects (6 Pattern Types)

**1. Tool retry loops** \u2014 Same tool called 5+ times consecutively. Agent confusion signal.

**2. Repeating errors** \u2014 Same error 5+ times across sessions. Unfixed bug, not a fluke.

**3. User frustration** \u2014 Keywords like "you said this already", "why again", "\ub2e4\uc2dc", "\ub610" \u2014 with context filtering to reduce false positives.

**4. AGENTS.md violations** \u2014 Rules broken in actual `exec` tool calls (not conversation text). Cross-referenced against your current AGENTS.md.

**5. Heavy sessions** \u2014 Sessions hitting >85% context window. Tasks that should be sub-agents.

**6. Unresolved learnings** \u2014 High-priority items in `.learnings/` not yet promoted to AGENTS.md.

Full details: [docs/DETECTION-PATTERNS.md](docs/DETECTION-PATTERNS.md)

---

## Proposal Generation

Proposals are **template-based**, not LLM-generated. Each detected pattern maps to a structured template with:

- **Evidence** \u2014 exact log excerpts, occurrence counts, affected sessions
- **Before** \u2014 current state in AGENTS.md (or "no rule exists")
- **After** \u2014 concrete diff: what to add or change
- **Section** \u2014 which AGENTS.md section to update

Example output for a detected violation:

```
[PROPOSAL #1 \u2014 HIGH] git \uc9c1\uc811 \uba85\ub839 4\ud68c \uc704\ubc18 \uac10\uc9c0

Evidence:
  - Session #325: exec "git commit -m 'fix'" \u2190 violates AGENTS.md rule
  - Session #331: exec "git add -A && git commit"
  - Total: 4 violations in 3 weeks

Before:
  \uc9c1\uc811 git \uba85\ub839 \uae08\uc9c0.

After (diff)
+ \u26a0\ufe0f CRITICAL \u2014 NEVER run git directly. Violated 4\u00d7 in 3 weeks.
  \uc9c1\uc811 git \uba85\ub839 \uae08\uc9c0. (git add / git commit / git push \uc804\ubd80 \ud3ec\ud568)
  \ucda9\ub3cc \uc2dc \uc815\uc6b0\ub2d8\uaed8 \ubcf4\uace0.

React \u2705 to apply | \u274c to reject (add reason)
```

---

## Real Results (single-user production, macOS/OpenClaw)

After 4 weeks running on a real OpenClaw setup:

- 85 frustration patterns detected across 30 sessions
- 4 proposals generated per week on average
- 13 AGENTS.md violations caught and corrected
- False positive rate: ~8% (v5.0, down from 15% in v4)

*Your mileage will vary. These numbers are from one production instance.*

---

## Before / After Example

**Raw pattern found in logs:**

```
[Session #312] User: "why are you calling git directly again?? I told you to use git-sync.sh"
[Session #318] User: "you did it again, direct git command"
[Session #325] exec: git commit -m "fix"   \u2190 AGENTS.md violation flagged
[Session #331] User: "stop using git directly!!!"
```

**After proposal approved:**

```diff
## \ud83d\udd04 Git Sync

+ \u26a0\ufe0f  CRITICAL \u2014 NEVER run git directly. Violated 4\u00d7 in 3 weeks.
  \ud30c\uc77c \uc218\uc815 \uc804 \ubc18\ub4dc\uc2dc: `bash ~/openclaw/scripts/git-sync.sh`
- \uc9c1\uc811 git \uba85\ub839 \uae08\uc9c0.
+ \uc9c1\uc811 git \uba85\ub839 \uae08\uc9c0. (git add / git commit / git push \uc804\ubd80 \ud3ec\ud568)
  \ucda9\ub3cc \uc2dc \uc815\uc6b0\ub2d8\uaed8 \ubcf4\uace0.
```

---

## Approval Workflow

After analysis, a report is posted to your configured channel. React to approve or reject:

- \u2705 Approve all \u2192 auto-apply to AGENTS.md + git commit
- 1\ufe0f\u20e3\u20135\ufe0f\u20e3 Approve only that numbered proposal
- \u274c Reject all (add a comment with reason \u2014 it feeds back into next analysis)
- \ud83d\udd04 Request revision (describe what you want changed)

Rejected proposal IDs are stored in `data/rejected-proposals.json` and excluded from future analyses.

---

## Pairs Well With

**[openclaw-self-healing](https://github.com/Ramsbaby/openclaw-self-healing)** \u2014 Crash recovery + auto-repair.

Self-healing fires on crash. Self-evolving runs weekly to fix what *causes* the crashes \u2014 including promoting self-healing error patterns directly into AGENTS.md rules.

Integration: set `SEA_LEARNINGS_PATHS` to include your self-healing `.learnings/` directory. Detected errors automatically surface as self-evolving proposals.

---

## Structured Event Logging (session-logger.sh)

`session-logger.sh` is a companion script that standardizes session events into JSONL format, enabling precise analysis beyond raw log parsing.

**Usage (source as library):**
```bash
source scripts/session-logger.sh
log_session_start "$SESSION_ID" "$MODEL" "$TASK"
log_session_end "$SESSION_ID" "$EXIT_CODE" "$DURATION" "$TOKENS_IN" "$TOKENS_OUT"
log_error "$SESSION_ID" "TypeError" "Cannot read property" true
log_recovery "$SESSION_ID" "crash_loop" "tmux_ai" true
```

**Usage (standalone CLI):**
```bash
session-logger.sh log session_start '{"session_id":"abc","model":"claude-opus-4-5"}'
```

Each line written to `~/.openclaw/logs/sessions.jsonl`:
```json
{"ts":"2026-03-11T08:00:00Z","event":"session_start","data":{"session_id":"abc","model":"claude-opus-4-5","task":"standup"}}
```

`analyze-behavior.sh` v3.1 automatically reads `sessions.jsonl` if present and adds structured metrics (`jsonl_summary`) to its JSON output \u2014 top tools by call volume, recent errors with full metadata.

---

## vs. Capability Evolver

Capability Evolver was recently suspended from ClawHub. If you're looking for an alternative:

| Feature | Capability Evolver | Self-Evolving |
|---|---|---|
| Silent modification | \u26a0\ufe0f Yes (on by default) | \u274c Never |
| Human approval | Optional (off by default) | Required. Always. |
| API calls per run | Multiple LLM calls | Zero |
| Transparency | Closed analysis | Full audit log |
| Rejection memory | None | Stored + fed back |
| False positive rate | ~22% (self-reported) | ~8% (v5, measured) |

---

## Configuration

```yaml
# config.yaml
analysis_days: 7          # Days of logs to scan
max_sessions: 50          # Max session files to analyze
verbose: true

# Paths (auto-detected for standard OpenClaw layout)
agents_dir: ~/.openclaw/agents
logs_dir: ~/.openclaw/logs
agents_md: ~/openclaw/AGENTS.md

# Notifications
notify:
  discord_channel: ""     # Discord channel ID
  telegram_chat_id: ""    # Optional

# GitHub integration (for --create-issue)
# github:
#   repo: "owner/repo"    # auto-detected from git remote if blank

# Detection thresholds
thresholds:
  tool_retry: 5           # Consecutive calls to flag
  error_repeat: 5         # Error occurrences to flag
  heavy_session: 85       # Context % threshold
```

**Weekly cron (Sunday 22:00):** `bash scripts/setup-wizard.sh` sets this up automatically.

---

## Options & Flags

```bash
# Run analysis without modifying anything
bash scripts/generate-proposal.sh --dry-run

# Scan more history
ANALYSIS_DAYS=14 bash scripts/generate-proposal.sh

# Auto-create a GitHub Issue with the weekly proposal report
bash scripts/generate-proposal.sh --create-issue

# Specify repo explicitly (or set EVOLVING_GITHUB_REPO env var)
EVOLVING_GITHUB_REPO="owner/repo" bash scripts/generate-proposal.sh --create-issue

# Reset rejection history
rm data/rejected-proposals.json
```

> **`--create-issue` requirements:** `gh` CLI installed + authenticated (`gh auth login`).
> Repo is auto-detected from `git remote origin` if `EVOLVING_GITHUB_REPO` is not set.
> Labels `self-evolving` and `automated` are created automatically if they don't exist.

---

## File Structure

```
openclaw-self-evolving/
\u251c\u2500\u2500 scripts/
\u2502   \u251c\u2500\u2500 analyze-behavior.sh      # Log analysis engine (v3.1) \u2014 JSONL-aware
\u2502   \u251c\u2500\u2500 session-logger.sh        # Structured JSONL event logger (dual-mode: library + CLI)
\u2502   \u251c\u2500\u2500 generate-proposal.sh     # Pipeline orchestrator + proposal builder (v3.1)
\u2502   \u251c\u2500\u2500 setup-wizard.sh          # Interactive setup + cron registration
\u2502   \u2514\u2500\u2500 lib/config-loader.sh     # Config loader (sourced by scripts)
\u251c\u2500\u2500 docs/
\u2502   \u251c\u2500\u2500 ARCHITECTURE.md
\u2502   \u251c\u2500\u2500 DETECTION-PATTERNS.md
\u2502   \u2514\u2500\u2500 QUICKSTART.md
\u251c\u2500\u2500 test/
\u2502   \u2514\u2500\u2500 fixtures/                # Sample session JSONL for testing / contributing
\u251c\u2500\u2500 data/
\u2502   \u251c\u2500\u2500 proposals/               # Saved proposal JSON files
\u2502   \u2514\u2500\u2500 rejected-proposals.json  # Rejection history
\u2514\u2500\u2500 config.yaml.example
```

---

## \ud83c\udf10 OpenClaw Ecosystem

| Project | Role |
|---------|------|
| **[openclaw-self-evolving](https://github.com/Ramsbaby/openclaw-self-evolving)** \u2190 you are here | Weekly log review \u2192 propose AGENTS.md improvements |
| **[openclaw-self-healing](https://github.com/Ramsbaby/openclaw-self-healing)** | 4-tier autonomous crash recovery \u2014 gateway back in ~30s |
| **[openclaw-memorybox](https://github.com/Ramsbaby/openclaw-memorybox)** | Zero-dep memory hygiene CLI \u2014 prevents bloat crashes |
| **[claude-discord-bridge](https://github.com/Ramsbaby/claude-discord-bridge)** | Full AI company-in-a-box \u2014 where all OpenClaw tools run in production |

All MIT licensed, all battle-tested on the same 24/7 production instance.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs welcome \u2014 especially:

- New detection patterns for `analyze-behavior.sh`
- Better false-positive filtering
- Support for other platforms (currently OpenClaw-specific \u2014 log format abstraction layer planned)
- Test fixtures in `test/fixtures/` (sample `.jsonl` files to enable contributor testing without real logs)

---

## License

[MIT](LICENSE) \u2014 do whatever you want, just don't remove the "human approval required" part. That part matters.
