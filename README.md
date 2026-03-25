<div align="center">

# 🧠 Self-Evolving Agent

### *Your AI agent reviews its own logs and proposes behavior improvements — weekly, automatically.*

**Stop making the same mistakes. Let your agent learn from them.**

[![GitHub stars](https://img.shields.io/github/stars/Ramsbaby/openclaw-self-evolving?style=social)](https://github.com/Ramsbaby/openclaw-self-evolving/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Platform: macOS/Linux](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue)](#)
[![No Silent Modification](https://img.shields.io/badge/policy-proposals%20only%2C%20human%20approves-brightgreen)](#)
[![Zero API Cost](https://img.shields.io/badge/analysis-zero%20API%20cost-blueviolet)](#)
[![False Positive Rate](https://img.shields.io/badge/false_positive_rate-8%25-brightgreen)](#)

> If this improved your agent's behavior, a ⭐ helps others find it.

[⚡ Quick Start](#-quick-start) · [🔍 What It Detects](#-what-it-detects-6-pattern-types) · [📋 Real Results](#-real-results) · [🤖 Claude Code](#-claude-code--agentsmd)

</div>

---

## What Is This?

**Self-Evolving is a weekly agent improvement pipeline** — no LLM, no API calls, no cloud.

It reads your agent's session logs, finds patterns of bad behavior (retry loops, broken rules, user frustration), and surfaces exact `AGENTS.md` or `CLAUDE.md` rule changes you can approve or reject in under a minute.

**The agent doesn't change itself.** You approve every change. That's the point.

---

## The Problem

AI agents make the same mistakes repeatedly. Nobody has time to manually review thousands of conversation logs. The mistakes keep accumulating, silently.

```
Week 1: Agent calls git directly — you correct it
Week 2: Same mistake again
Week 3: Same mistake
Week 4: Still happening — 3 weeks wasted
```

**Self-Evolving automates the review** — and brings you a short list of what to fix, every week.

```
Week 1: Agent calls git directly 4 times despite CLAUDE.md rule
Week 2: Same mistake, 3 more times
Week 3: Self-Evolving flags it → you approve the stronger rule → never happens again
```

---

## How It Works

```
Your agent runs                    Self-Evolving runs (weekly)
──────────────                    ──────────────────────────────

Session logs         ─────────►   1. analyze-behavior.sh
~/.openclaw/logs/                    • Scans JSONL session logs
~/.claude/logs/                      • Finds retry loops, errors,
                                       rule violations, frustration
AGENTS.md / CLAUDE.md ──────────►    • Zero API calls — pure bash + python3
  (current rules)
                                  2. generate-proposal.sh
                                     • Builds Before/After diff proposals
                                     • Filters previously-rejected IDs
                                     • Posts to Discord / creates GitHub Issue

                                  3. You review
                     ◄─────────     • React ✅ = apply + git commit
                                     • React ❌ = reject (stored, won't resurface)
                                     • React 1️⃣–5️⃣ = approve specific proposals
```

**One pipeline, three scripts, zero ongoing cost.**

---

## Before & After

### Before Self-Evolving

```
Agent behavior log (4 weeks):
  [Week 1] exec: git push origin main      ← CLAUDE.md says use git-sync.sh
  [Week 2] exec: git push origin main      ← same violation
  [Week 3] exec: git pull                  ← same violation
  [Week 4] exec: git commit -m "fix"       ← still happening

User message: "why are you calling git directly AGAIN?"
Agent: "I apologize, I'll use git-sync.sh going forward"
[Week 5] exec: git push origin main        ← happens again anyway
```

### After One Self-Evolving Cycle

**Proposal generated automatically:**

```diff
## Git Rules
- Direct git commands prohibited.
+ Direct git commands prohibited. (includes git add / commit / push / pull / fetch)
+ ⚠️ CRITICAL — Violated 4× in 3 weeks. Use bash ~/openclaw/scripts/git-sync.sh for ALL git ops.
```

**You react ✅ → rule applied → never happens again.**

---

## Real Example Output

```
🧬 Self-Evolving Agent Weekly Report v3.1

Analysis period: 2026-03-17 ~ 2026-03-24
Sessions analyzed: 23
Tool retry events: 47 ← newly detected
Improvement proposals: 3

---

### 🔁 Proposal #1: `exec` tool consecutive retry pattern (8 sessions affected)

Severity: 🔴 HIGH  |  Type: 📝 AGENTS.md addition

> Evidence:
> Last 7 days: `exec` called 5+ times consecutively in 8 sessions
> Worst streak: 23 consecutive calls (no interruption)
> Total retry events: 47
> → 5+ consecutive identical tool calls = failure/retry loop signal

Before (current):
  No rule for consecutive exec retries

After (proposed):
  ## ⚡ exec Consecutive Retry Prevention
  Before retrying the same exec 3+ times:
  1. First failure: report error to user
  2. Second attempt: change approach (different flags/path)
  3. Third failure: stop and ask for manual confirmation

---

### ✅ Approval

React to approve/reject:
| Reaction | Action |
|----------|--------|
| ✅ | Approve all → auto-apply + git commit |
| 1️⃣ – 5️⃣ | Approve only that proposal |
| ❌ | Reject (add comment → fed into next analysis) |
| 🔄 | Request revision |
```

---

## Works With

| Platform | Support | Notes |
|----------|---------|-------|
| **Claude Code** | ✅ Full | CLAUDE.md / AGENTS.md rules |
| **OpenClaw** | ✅ Full | Native log format support |
| **Any JSONL agent logs** | ✅ Partial | Session logger compatible |

> OpenClaw is one supported platform — not a requirement. Claude Code works out of the box.

---

## ⚡ Quick Start

### Prerequisites

- `python3` (built-in on macOS/Linux)
- `bash` 3.2+
- Agent logs in JSONL format (Claude Code: `~/.claude/logs/`, OpenClaw: `~/.openclaw/agents/`)
- 5 minutes

### Option A: Claude Code (most common)

```bash
git clone https://github.com/Ramsbaby/openclaw-self-evolving.git
cd openclaw-self-evolving
cp config.yaml.example config.yaml
```

Edit `config.yaml`:
```yaml
agents_md: ~/your-project/CLAUDE.md    # path to your CLAUDE.md
logs_dir: ~/.claude/logs               # Claude Code log path
```

```bash
# Dry run first — see what would be detected, no changes made
bash scripts/generate-proposal.sh --dry-run

# If it finds things worth fixing, run the full setup
bash scripts/setup-wizard.sh   # registers weekly cron
```

### Option B: OpenClaw (clawhub)

```bash
clawhub install openclaw-self-evolving
bash scripts/setup-wizard.sh
```

### First Run Output

```
[09:00:01] === Self-Evolving Agent behavior analysis v3.1 ===
[09:00:01] Analysis period: last 7 days / max 50 sessions
[09:00:03] Sessions found: 23
[09:00:04] Analysis complete: 23 sessions, 2 complaints, 1 violation, 47 retry events
[09:00:04] === generate-proposal.sh v3.1 started ===
[09:00:04] Generating proposals...
[09:00:05] Proposal saved: data/proposals/proposal_20260324_090005.json

## 🧬 Self-Evolving Agent Weekly Report v3.1
...3 proposals ready for your review
```

---

## 🤖 Claude Code / AGENTS.md

Works directly with Claude Code's `CLAUDE.md` or `AGENTS.md` behavior rules.

**Setup:**
```yaml
# config.yaml
agents_md: ~/your-project/CLAUDE.md   # or AGENTS.md
logs_dir: ~/.claude/logs               # or your log path
```

**What it does:**
1. Scans your Claude Code session logs
2. Detects patterns: rule violations, repeated mistakes, user frustration
3. Proposes exact diffs to your `CLAUDE.md`
4. You approve → it applies the change + git commits

**Example — detected violation in Claude Code logs:**
```
[Session #312] User: "why are you calling git directly again?"
[Session #318] User: "you did it again"
[Session #325] exec: git commit -m "fix"  ← CLAUDE.md violation flagged
```

**Proposed fix:**
```diff
## Git Rules
+ ⚠️ CRITICAL — Never run git directly. Violated 4× in 3 weeks.
- Direct git commands prohibited.
+ Direct git commands prohibited. (includes git add / commit / push)
  Conflicts: report to user.
```

---

## 🔍 What It Detects (6 Pattern Types)

**1. Tool retry loops** — Same tool called 5+ times consecutively. Agent confusion signal.

**2. Repeating errors** — Same error 5+ times across sessions. Unfixed bug, not a fluke.

**3. User frustration** — Keywords like "you said this already", "why again", "다시", "또" — with context filtering.

**4. AGENTS.md / CLAUDE.md violations** — Rules broken in actual `exec` tool calls, cross-referenced against your rules file.

**5. Heavy sessions** — Sessions hitting >85% context window. Tasks that should be sub-agents.

**6. Unresolved learnings** — High-priority items in `.learnings/` not yet promoted to rules.

**No LLM calls during analysis. No API fees. Pure local log processing.**

See [docs/DETECTION-PATTERNS.md](docs/DETECTION-PATTERNS.md) for full details.

---

## 📋 Real Results

*Single-user production instance (macOS, 4 weeks):*

| Metric | Result |
|--------|--------|
| Patterns detected | 85 across 30 sessions |
| Proposals per week | 4 on average |
| Rule violations caught | 13 |
| False positive rate | ~8% (v5.0) |
| API cost | **$0** |

*Your results will vary — these are from one instance.*

---

## Approval Workflow

After analysis, a report is posted to your configured channel (Discord/Telegram). React to approve or reject:

| Reaction | Action |
|----------|--------|
| ✅ | Approve all proposals → auto-apply + git commit |
| 1️⃣–5️⃣ | Approve only that numbered proposal |
| ❌ | Reject (add comment with reason → fed into next analysis) |
| 🔄 | Request revision |

Rejected proposal IDs stored in `data/rejected-proposals.json` — never proposed again.

---

## Options

```bash
# Dry run (no changes)
bash scripts/generate-proposal.sh --dry-run

# Scan more history
ANALYSIS_DAYS=14 bash scripts/generate-proposal.sh

# Auto-create a GitHub Issue with the proposal report
bash scripts/generate-proposal.sh --create-issue
# Requires: gh CLI + gh auth login

# Specify repo explicitly
EVOLVING_GITHUB_REPO="owner/repo" bash scripts/generate-proposal.sh --create-issue
```

---

## Configuration

```yaml
# config.yaml
analysis_days: 7          # Days of logs to scan
max_sessions: 50          # Max session files

# Paths (auto-detected for standard OpenClaw layout)
agents_dir: ~/.openclaw/agents
logs_dir: ~/.openclaw/logs
agents_md: ~/openclaw/AGENTS.md   # ← change to your CLAUDE.md path

# Notifications
notify:
  discord_channel: ""
  telegram_chat_id: ""

# Detection thresholds
thresholds:
  tool_retry: 5
  error_repeat: 5
  heavy_session: 85
```

---

## vs. Alternatives

| Feature | Capability Evolver | **Self-Evolving** |
|---|---|---|
| Silent modification | ⚠️ Yes (on by default) | ❌ Never |
| Human approval | Optional (off by default) | Required. Always. |
| API calls per run | Multiple LLM calls | **Zero** |
| False positive rate | ~22% (self-reported) | **~8%** (measured) |
| Rejection memory | None | Stored + fed back |

---

## Pairs Well With

**[openclaw-self-healing](https://github.com/Ramsbaby/openclaw-self-healing)** — Crash recovery + auto-repair. Self-healing fires on crash. Self-Evolving runs weekly to fix what *causes* the crashes — promoting error patterns directly into AGENTS.md rules.

**[openclaw-memorybox](https://github.com/Ramsbaby/openclaw-memorybox)** — Memory hygiene CLI. Keeps MEMORY.md lean so your agent doesn't crash from context overflow.

---

## File Structure

```
openclaw-self-evolving/
├── scripts/
│   ├── analyze-behavior.sh      # Log analysis engine (JSONL-aware)
│   ├── session-logger.sh        # Structured JSONL event logger
│   ├── generate-proposal.sh     # Pipeline orchestrator
│   ├── setup-wizard.sh          # Interactive setup + cron registration
│   └── lib/config-loader.sh
├── docs/
│   ├── DETECTION-PATTERNS.md
│   └── QUICKSTART.md
├── test/fixtures/               # Sample JSONL for contributor testing
├── data/
│   ├── proposals/
│   └── rejected-proposals.json
└── config.yaml.example
```

---

## 🌐 OpenClaw Ecosystem

| Project | Role |
|---------|------|
| **[openclaw-self-evolving](https://github.com/Ramsbaby/openclaw-self-evolving)** ← you are here | Weekly log review → propose AGENTS.md/CLAUDE.md improvements |
| **[openclaw-self-healing](https://github.com/Ramsbaby/openclaw-self-healing)** | 4-tier autonomous crash recovery |
| **[openclaw-memorybox](https://github.com/Ramsbaby/openclaw-memorybox)** | Memory hygiene CLI — prevents bloat crashes |
| **[jarvis](https://github.com/Ramsbaby/jarvis)** | 24/7 AI ops system using Claude Max |

---

## Contributing

PRs welcome — especially:
- New detection patterns for `analyze-behavior.sh`
- Better false-positive filtering  
- Support for other log formats (currently OpenClaw + Claude Code)
- Test fixtures in `test/fixtures/`

---

## License

[MIT](LICENSE) — do whatever you want, just don't remove the "human approval required" part. That part matters.

---

<div align="center">

**Made with 🧠 by [@ramsbaby](https://github.com/ramsbaby)**

*"The best agent is one that learns from its mistakes."*

[![Star History Chart](https://api.star-history.com/svg?repos=Ramsbaby/openclaw-self-evolving&type=Date)](https://star-history.com/#Ramsbaby/openclaw-self-evolving&Date)

</div>
