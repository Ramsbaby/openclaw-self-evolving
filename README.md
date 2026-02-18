<div align="center">

# 🧠 OpenClaw Self-Evolving Agent

[![GitHub stars](https://img.shields.io/github/stars/Ramsbaby/openclaw-self-evolving?style=flat-square)](https://github.com/Ramsbaby/openclaw-self-evolving/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Platform: macOS/Linux](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue?style=flat-square)](#)
[![ClawHub](https://img.shields.io/badge/ClawHub-openclaw--self--evolving-orange?style=flat-square)](https://clawhub.com)
[![No Silent Modification](https://img.shields.io/badge/policy-no%20silent%20modification-brightgreen?style=flat-square)](#)

![Demo](https://raw.githubusercontent.com/Ramsbaby/openclaw-self-evolving/main/assets/demo.gif)

*Weekly log analysis → Pattern detection → AGENTS.md improvement proposals*

> **Your AI agent reviews its own conversations and suggests how to improve.**

> **Honest disclaimer:** This is not AGI. It's a weekly log review with pattern matching.
> It finds things you'd find yourself — if you had time to read 500 conversation logs.

</div>

---

## The Problem

AI agents make the same mistakes repeatedly.
Nobody has time to manually review thousands of conversation logs.
So the mistakes just keep accumulating, silently.

---

## ⚡ Quick Start

```bash
# One-liner install
clawhub install openclaw-self-evolving

# Then run setup and you're live:
bash scripts/setup-wizard.sh
# That's it — weekly cron is now scheduled.
```

<details>
<summary>Manual install (without clawhub)</summary>

```bash
git clone https://github.com/Ramsbaby/openclaw-self-evolving.git
cd openclaw-self-evolving
cp config.yaml.example config.yaml
# Edit config.yaml to set your paths
bash scripts/setup-wizard.sh
```
</details>

---

## How It Works

```
Session Logs → [Analyzer] → Patterns → [Generator] → Proposals → [Human] → AGENTS.md
                                                          ↑
                                             Rejected reasons fed back
```

```
1. Collect  → Scans last 7 days of conversation session logs
2. Analyze  → Detects recurring patterns, complaints, and failures
3. Propose  → Generates AGENTS.md improvement candidates
4. Review   → You approve or reject (emoji reactions supported)
5. Learn    → Rejection reasons feed into the next analysis cycle
```

No model calls. No API fees. Pure log analysis with shell + Python.

---

## 👀 Before / After — What It Actually Does

**Before self-evolving** (raw pattern found in logs):

```
[Session #312] User: "why are you calling git directly again?? I told you to use git-sync.sh"
[Session #318] User: "you did it again, direct git command"
[Session #325] exec: git commit -m "fix" ← AGENTS.md violation detected
[Session #331] User: "stop using git directly!!!"
```

**After proposal approved** (AGENTS.md diff):

```diff
## 🔄 Git Sync

+ ⚠️  CRITICAL — NEVER run git directly. This has been violated 4× in 3 weeks.
  파일 수정 전 반드시: `bash ~/openclaw/scripts/git-sync.sh`
- 직접 git 명령 금지.
+ 직접 git 명령 금지. (git add / git commit / git push 전부 포함)
  충돌 시 정우님께 보고.
```

The agent found the pattern, wrote the proposal, and after your approval — the rule is now harder to miss.

---

## 📊 Real Results (from actual production use)

After 4 weeks of running:

- **85 frustration patterns** detected across 30 sessions
- **4 proposals** generated per week on average
- **13 AGENTS.md violations** caught and corrected
- **False positive rate**: ~8% (down from 15% in v4)

Numbers from a single-user production setup on macOS/OpenClaw. Your mileage will vary.

---

## What It Detects

- **Tool retry loops** — Same tool called 5+ times in a row (agent confusion signal)
- **Repeating errors** — Same error appearing 5+ times = unfixed bug, not a fluke
- **User frustration** — Expressions like "you said this already", "why again" (context-filtered)
- **AGENTS.md violations** — Rules broken in actual exec commands (not false positives from conversation text)
- **Heavy sessions** — Compaction-heavy sessions = tasks that should be sub-agents
- **Unresolved learnings** — High-priority items in `.learnings/` not yet promoted to `AGENTS.md`

---

## Coming from Capability Evolver?

Capability Evolver was recently suspended from ClawHub. If you're looking for an alternative — this is the honest one.

> **Why switch?** Silent modification is a liability. One bad auto-edit to AGENTS.md can break your entire agent workflow. Self-Evolving never touches a file without your explicit sign-off.

| Feature | Capability Evolver | Self-Evolving |
|---------|-------------------|---------------|
| Silent modification | ⚠️ Yes (on by default) | ❌ Never |
| Human approval | Optional (off by default) | **Required. Always.** |
| API calls per run | Multiple LLM calls ($$$) | Zero (pure log analysis) |
| Transparency | Closed analysis | Full audit log |
| Rejection memory | ❌ None | ✅ Stored + fed back |
| False positive rate | ~22% (self-reported) | ~8% (v5, measured) |

Migration: just install and run. No data migration needed — we scan raw session logs directly.

---

## Approval Workflow

After analysis, a report is posted to your configured channel:

| Reaction | Meaning |
|----------|---------|
| ✅ | Approve all → auto-apply to AGENTS.md + git commit |
| 1️⃣–5️⃣ | Approve only that numbered proposal |
| ❌ | Reject all (add a comment with your reason — it feeds back in) |
| 🔄 | Request revision (describe what you want changed) |

Rejected proposal IDs are stored in `data/rejected-proposals.json` and excluded from future analyses.

---

## Configuration

```yaml
# config.yaml
analysis_days: 7          # How many days of logs to scan
max_sessions: 50          # Max session files to analyze
verbose: true             # Show analysis progress

# Paths (auto-detected if using standard openclaw layout)
agents_dir: ~/.openclaw/agents
logs_dir: ~/.openclaw/logs
agents_md: ~/openclaw/AGENTS.md
```

**Cron (weekly, Sunday 09:00):** `bash scripts/setup-wizard.sh` — or add manually:
```
0 9 * * 0 bash ~/projects/openclaw-self-evolving/scripts/generate-proposal.sh
```

**Notification channels:** set `notify.discord_channel` or `notify.telegram_chat_id` in `config.yaml`.

---

## Pairs Well With

→ **[openclaw-self-healing](https://github.com/Ramsbaby/openclaw-self-healing)** — Crash recovery + auto-repair.

Self-evolving makes your agent **smarter**. Self-healing keeps it **alive**.
Self-healing fires on crash; self-evolving runs weekly to fix what *causes* the crashes.

---

## File Structure

```
openclaw-self-evolving/
├── assets/
│   └── demo.gif                 # Demo animation (header)
├── scripts/
│   ├── analyze-behavior.sh      # Core log analysis engine (v5.0)
│   ├── generate-proposal.sh     # Proposal generator + report builder
│   └── setup-wizard.sh          # Interactive setup
├── config.yaml.example
├── data/
│   ├── proposals/               # Saved proposal JSON files
│   └── rejected-proposals.json  # Rejection history
└── README.md
```

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). PRs welcome — especially for:
- New detection patterns
- Support for other AI platforms (currently optimized for OpenClaw)
- Better false-positive filtering

---

## License

[MIT](LICENSE) — do whatever you want, just don't remove the "human approval required" part. That part matters.
