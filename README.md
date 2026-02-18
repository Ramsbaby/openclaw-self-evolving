# 🧠 OpenClaw Self-Evolving Agent

> **Your AI agent reviews its own conversations and suggests how to improve.**

[![GitHub stars](https://img.shields.io/github/stars/Ramsbaby/openclaw-self-evolving?style=flat-square)](https://github.com/Ramsbaby/openclaw-self-evolving/stargazers)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=flat-square)](LICENSE)
[![Platform: macOS/Linux](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux-blue?style=flat-square)](#)

> **Honest disclaimer:** This is not AGI. It's a weekly log review with pattern matching.
> It finds things you'd find yourself — if you had time to read 500 conversation logs.

---

## The Problem

AI agents make the same mistakes repeatedly.
Nobody has time to manually review thousands of conversation logs.
So the mistakes just keep accumulating, silently.

---

## The Solution

Weekly automated analysis → pattern detection → improvement proposals for `AGENTS.md`.
**Human approval required. No silent modification. Ever.**

The agent reads your logs, finds recurring failure patterns, and writes a proposal.
You approve or reject it. Nothing changes without your explicit sign-off.

---

## Quick Start

**Option A — via clawhub (recommended):**
```bash
clawhub install openclaw-self-evolving
```

**Option B — manual clone:**
```bash
git clone https://github.com/Ramsbaby/openclaw-self-evolving.git
cd openclaw-self-evolving
cp config.yaml.example config.yaml
# Edit config.yaml to set your paths
bash scripts/setup-wizard.sh
```

---

## How It Works

```
1. Collect  → Scans last 7 days of conversation session logs
2. Analyze  → Detects recurring patterns, complaints, and failures
3. Propose  → Generates AGENTS.md improvement candidates
4. Review   → You approve or reject (emoji reactions supported)
5. Learn    → Rejection reasons feed into the next analysis cycle
```

No model calls. No API fees. Pure log analysis with shell + Python.

---

## What It Detects

- **Tool retry loops** — Same tool called 5+ times in a row (agent confusion signal)
- **Repeating errors** — Same error appearing 5+ times = unfixed bug, not a fluke
- **User frustration** — Expressions like "you said this already", "why again" (context-filtered)
- **AGENTS.md violations** — Rules broken in actual exec commands (not false positives from conversation text)
- **Heavy sessions** — Compaction-heavy sessions = tasks that should be sub-agents
- **Unresolved learnings** — High-priority items in `.learnings/` not yet promoted to `AGENTS.md`

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

**Cron setup (weekly, Sunday 09:00):**
```bash
bash scripts/setup-wizard.sh
# Or manually:
# 0 9 * * 0 bash ~/projects/openclaw-self-evolving/scripts/generate-proposal.sh
```

**Notification channels:**
```yaml
# config.yaml
notify:
  discord_channel: "1469905074661757049"   # #jarvis-dev
  # telegram_chat_id: ""                  # optional
```

---

## Coming from Capability Evolver?

Capability Evolver was recently suspended from ClawHub. If you're looking for an alternative:

| Feature | Capability Evolver | Self-Evolving |
|---------|-------------------|---------------|
| Silent modification | ⚠️ Yes | ❌ Never |
| Human approval | Optional | **Required** |
| API calls | Multiple LLM calls | Zero (pure log analysis) |
| Transparency | Closed analysis | Full logging |

Migration: just install and run. No data migration needed — we scan raw session logs directly.

---

## Pairs Well With

→ **[openclaw-self-healing](https://github.com/Ramsbaby/openclaw-self-healing)** — Crash recovery + auto-repair.

Self-evolving makes your agent **smarter** over time.
Self-healing keeps your agent **alive** when things break.

They're designed to complement each other:
- Self-healing fires immediately when something crashes
- Self-evolving runs weekly to improve the patterns that cause crashes in the first place

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

## File Structure

```
openclaw-self-evolving/
├── scripts/
│   ├── analyze-behavior.sh      # Core log analysis engine (v3.0)
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
