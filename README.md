<div align="center">

# 🧠 OpenClaw Self-Evolving Agent

[![GitHub stars](https://img.shields.io/github/stars/Ramsbaby/openclaw-self-evolving?style=flat-square)](https://github.com/Ramsbaby/openclaw-self-evolving/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Platform: macOS/Linux](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue?style=flat-square)](#)
[![OpenClaw Required](https://img.shields.io/badge/requires-OpenClaw-orange?style=flat-square)](https://github.com/openclaw/openclaw)
[![No Silent Modification](https://img.shields.io/badge/policy-no%20silent%20modification-brightgreen?style=flat-square)](#)

> ⚠️ **OpenClaw required.** This tool analyzes OpenClaw session logs specifically (`~/.openclaw/agents/*/sessions/*.jsonl`). Other platforms are not supported yet.

*Your AI agent reviews its own conversation logs and proposes how to improve — every week, automatically.*

> **Honest disclaimer:** This is not AGI. It's a weekly log review with pattern matching.
> It finds things you'd find yourself — if you had time to read 500 conversation logs.

</div>

---

## The Problem

AI agents make the same mistakes repeatedly.
Nobody has time to manually review thousands of conversation logs.
The mistakes keep accumulating, silently.

Self-Evolving automates the review — and brings you a short list of what to fix.

---

## How It Works

```
Session Logs (7 days)
    → Analyzer (bash + Python, no API calls)
    → Detected Patterns (JSON)
    → Proposal Generator (template-based, 6 pattern types)
    → Discord / Telegram Report
    → You approve or reject (emoji reactions)
    → Approved: auto-apply to AGENTS.md + git commit
    → Rejected: reason stored → fed into next week's analysis
```

**No LLM calls during analysis. No API fees. Pure local log processing.**

---

## ⚡ Quick Start

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

**1. Tool retry loops** — Same tool called 5+ times consecutively. Agent confusion signal.

**2. Repeating errors** — Same error 5+ times across sessions. Unfixed bug, not a fluke.

**3. User frustration** — Keywords like "you said this already", "why again", "다시", "또" — with context filtering to reduce false positives.

**4. AGENTS.md violations** — Rules broken in actual `exec` tool calls (not conversation text). Cross-referenced against your current AGENTS.md.

**5. Heavy sessions** — Sessions hitting >85% context window. Tasks that should be sub-agents.

**6. Unresolved learnings** — High-priority items in `.learnings/` not yet promoted to AGENTS.md.

Full details: [docs/DETECTION-PATTERNS.md](docs/DETECTION-PATTERNS.md)

---

## Proposal Generation

Proposals are **template-based**, not LLM-generated. Each detected pattern maps to a structured template with:

- **Evidence** — exact log excerpts, occurrence counts, affected sessions
- **Before** — current state in AGENTS.md (or "no rule exists")
- **After** — concrete diff: what to add or change
- **Section** — which AGENTS.md section to update

Example output for a detected violation:

```
[PROPOSAL #1 — HIGH] git 직접 명령 4회 위반 감지

Evidence:
  - Session #325: exec "git commit -m 'fix'" ← violates AGENTS.md rule
  - Session #331: exec "git add -A && git commit"
  - Total: 4 violations in 3 weeks

Before:
  직접 git 명령 금지.

After (diff):
+ ⚠️ CRITICAL — NEVER run git directly. Violated 4× in 3 weeks.
  직접 git 명령 금지. (git add / git commit / git push 전부 포함)
  충돌 시 정우님께 보고.

React ✅ to apply | ❌ to reject (add reason)
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
[Session #325] exec: git commit -m "fix"   ← AGENTS.md violation flagged
[Session #331] User: "stop using git directly!!!"
```

**After proposal approved:**

```diff
## 🔄 Git Sync

+ ⚠️  CRITICAL — NEVER run git directly. Violated 4× in 3 weeks.
  파일 수정 전 반드시: `bash ~/openclaw/scripts/git-sync.sh`
- 직접 git 명령 금지.
+ 직접 git 명령 금지. (git add / git commit / git push 전부 포함)
  충돌 시 정우님께 보고.
```

---

## Approval Workflow

After analysis, a report is posted to your configured channel. React to approve or reject:

- ✅ Approve all → auto-apply to AGENTS.md + git commit
- 1️⃣–5️⃣ Approve only that numbered proposal
- ❌ Reject all (add a comment with reason — it feeds back into next analysis)
- 🔄 Request revision (describe what you want changed)

Rejected proposal IDs are stored in `data/rejected-proposals.json` and excluded from future analyses.

---

## Pairs Well With

**[openclaw-self-healing](https://github.com/Ramsbaby/openclaw-self-healing)** — Crash recovery + auto-repair.

Self-healing fires on crash. Self-evolving runs weekly to fix what *causes* the crashes — including promoting self-healing error patterns directly into AGENTS.md rules.

Integration: set `SEA_LEARNINGS_PATHS` to include your self-healing `.learnings/` directory. Detected errors automatically surface as self-evolving proposals.

---

## vs. Capability Evolver

Capability Evolver was recently suspended from ClawHub. If you're looking for an alternative:

| Feature | Capability Evolver | Self-Evolving |
|---|---|---|
| Silent modification | ⚠️ Yes (on by default) | ❌ Never |
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

# Reset rejection history
rm data/rejected-proposals.json
```

---

## File Structure

```
openclaw-self-evolving/
├── scripts/
│   ├── analyze-behavior.sh      # Log analysis engine (v3.0, 647 lines)
│   ├── generate-proposal.sh     # Pipeline orchestrator + proposal builder (705 lines)
│   ├── setup-wizard.sh          # Interactive setup + cron registration
│   └── lib/config-loader.sh     # Config loader (sourced by scripts)
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DETECTION-PATTERNS.md
│   └── QUICKSTART.md
├── test/
│   └── fixtures/                # Sample session JSONL for testing / contributing
├── data/
│   ├── proposals/               # Saved proposal JSON files
│   └── rejected-proposals.json  # Rejection history
└── config.yaml.example
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs welcome — especially:

- New detection patterns for `analyze-behavior.sh`
- Better false-positive filtering
- Support for other platforms (currently OpenClaw-specific — log format abstraction layer planned)
- Test fixtures in `test/fixtures/` (sample `.jsonl` files to enable contributor testing without real logs)

---

## License

[MIT](LICENSE) — do whatever you want, just don't remove the "human approval required" part. That part matters.
