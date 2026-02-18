# ⚡ Quick Start Guide

Get your agent analyzing itself in under 5 minutes.

## Prerequisites

- OpenClaw installed and running
- bash 4.0+, Python 3.8+
- At least 7 days of session logs

## Step 1: Install

```bash
# Option A: ClawHub (recommended)
clawhub install openclaw-self-evolving

# Option B: Manual
git clone https://github.com/Ramsbaby/openclaw-self-evolving.git
cd openclaw-self-evolving
```

## Step 2: Configure

```bash
cp config.yaml.example config.yaml
```

Edit `config.yaml` — you only need to set 3 paths:

```yaml
agents_dir: ~/.openclaw/agents      # Where your agent sessions live
logs_dir: ~/.openclaw/logs          # Session log directory
agents_md: ~/openclaw/AGENTS.md     # Your AGENTS.md file
```

## Step 3: First Run

```bash
bash scripts/generate-proposal.sh
```

You'll see output like:

```
📂 Scanning 967 session files...
📂 Selected 30 most recent sessions (last 7 days)
🔍 Analyzing patterns...
⚠️  Found: Tool retry loop — 8 occurrences
⚠️  Found: AGENTS.md violation — 13 occurrences
📝 Generating 2 improvement proposals...
📣 Proposals sent to #jarvis-dev
```

## Step 4: Review Proposals

Check your configured Discord/Telegram channel. React with:

| Reaction | Action |
|----------|--------|
| ✅ | Approve all proposals |
| 1️⃣-5️⃣ | Approve specific proposal |
| ❌ | Reject (add comment with reason) |

## Step 5: Schedule Weekly Runs

```bash
bash scripts/setup-wizard.sh
```

This registers a cron job for Sunday 22:00 (configurable).

---

## Troubleshooting

**Q: "No session files found"**
→ Check `logs_dir` in config.yaml. OpenClaw stores sessions in `~/.openclaw/agents/` by default.

**Q: "0 patterns detected"**
→ Normal if your agent is well-configured. Try increasing `analysis_days` to 14 or `max_sessions` to 100.

**Q: Proposals seem irrelevant**
→ Check `data/rejected-proposals.json` — rejected patterns are excluded. Delete this file to reset the rejection history.
