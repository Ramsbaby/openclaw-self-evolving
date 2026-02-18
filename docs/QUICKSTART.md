# Quick Start Guide — OpenClaw Self-Evolving Agent

> Get your agent reviewing its own behavior in under 5 minutes.

---

## Prerequisites

Before you begin, make sure you have:

- **OpenClaw** installed and configured (at least one session log exists in `~/.openclaw/agents/`)
- **bash** (macOS/Linux, v4+)
- **Python 3** (`python3 --version` → 3.8 or higher)
- An `AGENTS.md` file at `~/openclaw/AGENTS.md` (or you'll configure a custom path)

Optional:
- A Discord channel ID (for approval workflow notifications)
- `crontab` access (for scheduled weekly analysis)

---

## Step 1: Install

**Option A — via clawhub (recommended):**

```bash
clawhub install openclaw-self-evolving
```

This installs the skill into `~/openclaw/skills/` and registers the weekly cron automatically.

**Option B — git clone (manual):**

```bash
git clone https://github.com/Ramsbaby/openclaw-self-evolving.git ~/projects/openclaw-self-evolving
cd ~/projects/openclaw-self-evolving
```

---

## Step 2: Configure

Copy the example config and set your three paths:

```bash
cp config.yaml.example config.yaml
```

Open `config.yaml` and edit only these three lines:

```yaml
# config.yaml — the only 3 lines you need to change

# Path to your OpenClaw agents directory (where session .jsonl files live)
agents_dir: ~/.openclaw/agents          # ← Set this

# Path to your OpenClaw AGENTS.md (the rules file the agent follows)
agents_md: ~/openclaw/AGENTS.md         # ← Set this

# Path to your OpenClaw session logs directory (cron/heartbeat logs)
logs_dir: ~/.openclaw/logs              # ← Set this
```

Everything else is optional. The defaults work for standard OpenClaw layouts.

**Optional — enable Discord notifications:**

```yaml
notify:
  discord_channel: "YOUR_CHANNEL_ID"   # e.g. "1469905074661757049"
```

---

## Step 3: First Run

Run the proposal generator manually:

```bash
bash scripts/generate-proposal.sh
```

You'll see progress output like:

```
[09:01:23] === Self-Evolving Agent 행동 분석 v3.0 ===
[09:01:23] 세션 파일 검색 중... (최근 7일, 최대 50개)
[09:01:24] 발견된 세션: 42개
[09:01:24] .learnings/ 분석 중...
[09:01:25] 분석 완료 → /tmp/self-evolving-analysis.json
```

Followed by the full Markdown report in your terminal.

**Scan a longer window (optional):**

```bash
ANALYSIS_DAYS=14 bash scripts/generate-proposal.sh
```

---

## Step 4: Review the Results

After the run completes, your report appears in two places:

**Terminal:** The full Markdown report is printed to stdout. Proposals are sorted by severity (🔴 HIGH → 🟡 MEDIUM → 🟢 LOW).

**Discord (if configured):** The report is posted to your configured channel. React with emojis to approve or reject:

| Reaction | Meaning |
|----------|---------|
| ✅ | Approve all proposals → auto-apply to `AGENTS.md` + git commit |
| 1️⃣–5️⃣ | Approve only that numbered proposal |
| ❌ | Reject all (add a comment — it feeds into the next analysis) |
| 🔄 | Request revision (describe what you want changed) |

**Saved proposal file:**

```bash
ls data/proposals/
# proposal_20260218_090125.json
```

Each proposal is stored as JSON and archived after 30 days (`data/proposals/archive/`).

---

## Step 5: Register the Weekly Cron

Run the interactive setup wizard to register a weekly cron job:

```bash
bash scripts/setup-wizard.sh
```

The wizard will:
1. Verify dependencies (`python3`, `bash`)
2. Create `config.yaml` if missing
3. Create required data directories
4. Run a test analysis and report how many sessions were found
5. Ask if you want to register a Sunday 09:00 cron job

To add the cron manually instead:

```bash
# Weekly, Sunday at 09:00 local time
(crontab -l 2>/dev/null; echo "0 9 * * 0 bash ~/projects/openclaw-self-evolving/scripts/generate-proposal.sh >> ~/.openclaw/logs/self-evolving-cron.log 2>&1") | crontab -
```

Verify it was added:

```bash
crontab -l | grep self-evolving
```

---

## Troubleshooting FAQ

### Q1: "발견된 세션: 0개" — the analysis finds zero sessions

**Cause:** The `agents_dir` path doesn't point to where your session `.jsonl` files actually are.

**Fix:**

```bash
# Find where your session files actually are
find ~/.openclaw -name "*.jsonl" -path "*/sessions/*" 2>/dev/null | head -5

# Update config.yaml
agents_dir: /path/you/found/above
```

If no `.jsonl` files exist at all, OpenClaw may not have created session logs yet.
Run a session first, then re-analyze.

---

### Q2: Analysis completes but generates no proposals

**Cause:** This is normal if your agent has been well-behaved this week.
The analyzer only flags patterns above configured thresholds:
- Tool retry loops: 5+ consecutive calls to the same action tool
- Repeating errors: same error signature 3+ times in the same log file
- Complaint expressions: actual frustration phrases (not generic requests)

**Fix:** Lower thresholds temporarily to check if detection works:

```yaml
# config.yaml
repeat_min: 2        # default 3 — lower this to see more proposals
```

Or run with a wider window:

```bash
ANALYSIS_DAYS=30 bash scripts/generate-proposal.sh
```

---

### Q3: `python3: command not found` or YAML parse errors

**Cause:** Python 3 is not in your `PATH`, or the `pyyaml` package is missing.

**Fix:**

```bash
# Check Python
python3 --version

# The tool works without PyYAML (uses a built-in fallback parser)
# But if you want full YAML support:
pip3 install pyyaml

# On macOS with Homebrew:
brew install python3
```

The config loader includes a pure-Python YAML fallback — PyYAML is not required.
If `python3` itself is missing, install it via your package manager or Homebrew.

---

## What's Next?

- Read **[DETECTION-PATTERNS.md](DETECTION-PATTERNS.md)** to understand what exactly gets flagged and how to tune it
- Read **[ARCHITECTURE.md](ARCHITECTURE.md)** for a full system overview and extension guide
- Check **[CONTRIBUTING.md](../CONTRIBUTING.md)** to add custom detection patterns
