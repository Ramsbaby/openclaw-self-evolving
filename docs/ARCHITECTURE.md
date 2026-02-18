# Architecture — OpenClaw Self-Evolving Agent

> System design, data flow, script roles, full config reference, and extension points.

---

## Design Philosophy

This system is intentionally **zero-model, zero-API**. Every analysis is pure log parsing with shell and Python. There are no LLM calls in the analysis pipeline — only in the approval step (which is handled by you, the human operator).

This means:
- No API costs per analysis run
- Fully auditable: every decision is traceable to a log line
- Works offline
- Fast: a 7-day, 50-session analysis completes in under 10 seconds

---

## Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     Weekly Cron Trigger                      │
│              (0 9 * * 0 — Sunday 09:00)                     │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│              generate-proposal.sh  (orchestrator)           │
│                                                             │
│  1. Calls analyze-behavior.sh                               │
│  2. Reads analysis JSON output                              │
│  3. Generates improvement proposals                         │
│  4. Builds human-readable Markdown report                   │
│  5. Saves proposal JSON to data/proposals/                  │
│  6. Archives expired proposals (> 30 days)                  │
│  7. Prints report to stdout                                 │
└────────────────────────┬────────────────────────────────────┘
                         │
           ┌─────────────┴─────────────┐
           ▼                           ▼
┌─────────────────────┐     ┌─────────────────────────────────┐
│  analyze-behavior.sh│     │      build_report (inline py)   │
│                     │     │                                 │
│  Inputs:            │     │  Inputs:                        │
│  ┌───────────────┐  │     │  - proposals JSON               │
│  │Session .jsonl │  │     │  - analysis meta (sessions,     │
│  │files (7 days) │  │     │    retry events, heavy sessions)│
│  └───────────────┘  │     │                                 │
│  ┌───────────────┐  │     │  Output:                        │
│  │Cron log files │  │     │  - Markdown report (stdout)     │
│  └───────────────┘  │     │  - Emoji reaction guide         │
│  ┌───────────────┐  │     └─────────────────────────────────┘
│  │AGENTS.md      │  │
│  └───────────────┘  │
│  ┌───────────────┐  │
│  │.learnings/    │  │
│  │  ERRORS.md    │  │
│  │  LEARNINGS.md │  │
│  │  FEATURE_REQ..│  │
│  └───────────────┘  │
│  ┌───────────────┐  │
│  │rejected-      │  │
│  │proposals.json │  │
│  └───────────────┘  │
│                     │
│  Analysis (Python): │
│  ① Tool retry loops │
│  ② Repeating errors │
│  ③ User frustration │
│  ④ AGENTS violations│
│  ⑤ Heavy sessions   │
│  ⑥ Unresolved learns│
│                     │
│  Output:            │
│  /tmp/self-evolving │
│  -analysis.json     │
└─────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                     Proposal Output                          │
│                                                             │
│  data/proposals/proposal_20260218_090125.json               │
│    └─ Contains: proposals array, analysis summary,          │
│       created_at, status: "awaiting_approval"               │
│                                                             │
│  Stdout: Markdown report with Before/After for each         │
│  proposal, sorted by severity (high → medium → low)         │
└────────────────────────┬────────────────────────────────────┘
                         │
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Human Approval Step                       │
│                                                             │
│  (Discord emoji reactions / terminal review)                │
│                                                             │
│  ✅ Approve all   → auto-apply to AGENTS.md + git commit    │
│  1️⃣–5️⃣ Approve N  → apply only that proposal               │
│  ❌ Reject all    → log reason to rejected-proposals.json   │
│  🔄 Revise        → re-run with modified constraints        │
│                                                             │
│  Rejected proposal IDs are stored in:                       │
│  data/rejected-proposals.json                               │
│  → Excluded from all future analysis runs                   │
└─────────────────────────────────────────────────────────────┘
```

---

## Script Roles

### `scripts/analyze-behavior.sh`

**Role:** Core log analysis engine (v3.0). Scans session files and log files, runs a Python analysis script, outputs structured JSON.

**Called by:** `generate-proposal.sh` (Step 1), or directly for debugging.

**Inputs:**
- Session `.jsonl` files under `agents_dir` (modified within the analysis window)
- Log files under `logs_dir`
- `AGENTS.md` (for violation baseline)
- `.learnings/` directory (for unresolved items)
- `data/rejected-proposals.json` (for exclusion list)

**Output:** `/tmp/self-evolving-analysis.json` (or path from `SEA_ANALYSIS_JSON`)

**Key design decisions:**
- Session files are sorted by modification time; oldest are dropped when `max_sessions` is exceeded, keeping analysis focused on recent activity.
- The Python analysis script is written to a temp file and executed — this avoids heredoc indentation issues with complex Python embedded in bash.
- All temp files are cleaned up via `trap 'rm -rf "$tmp_dir"' EXIT INT TERM`.

**Environment variable overrides:**

| Variable | Default | Description |
|----------|---------|-------------|
| `SEA_DAYS` / `ANALYSIS_DAYS` | `7` | Days of history to scan |
| `SEA_MAX_SESSIONS` | `50` | Max session files |
| `AGENTS_DIR` | `~/.openclaw/agents` | Session files location |
| `LOGS_DIR` | `~/.openclaw/logs` | Cron log files location |
| `AGENTS_MD` | `~/openclaw/AGENTS.md` | AGENTS.md path |
| `SEA_VERBOSE` | `true` | Progress output to stderr |
| `SEA_ANALYSIS_JSON` | `/tmp/self-evolving-analysis.json` | Output path |

---

### `scripts/generate-proposal.sh`

**Role:** Orchestrator. Runs the analysis, generates improvement proposals from analysis data, builds the human-readable report, saves the proposal JSON, and archives expired proposals.

**Called by:** Cron, or manually via `bash scripts/generate-proposal.sh`.

**Internal steps:**

1. **`run_analysis()`** — Calls `analyze-behavior.sh`. On failure, generates a minimal fallback JSON (so the proposal pipeline can continue with zero-data).

2. **`generate_proposals()`** — Pure Python, no LLM. Reads the analysis JSON and applies a set of rules to produce structured proposal objects. Each proposal has:
   - `id` — stable identifier (used for rejection tracking)
   - `source` — which detection pattern generated it
   - `title` — one-line summary
   - `severity` — `high`, `medium`, or `low`
   - `evidence` — specific data that triggered the proposal
   - `before` — current state (from actual AGENTS.md where possible)
   - `after` — proposed change (copy-paste ready)
   - `section` — which AGENTS.md section to update
   - `diff_type` — `agents_md_addition`, `agents_md_update`, or `action_required`

3. **`build_report()`** — Formats proposals as Markdown with severity emoji, Before/After blocks, and approval instructions.

4. **`save_proposal()`** — Saves the full proposal JSON with metadata to `data/proposals/`.

5. **`archive_expired_proposals()`** — Moves proposal files older than `expire_days` to `data/proposals/archive/`.

**Proposal severity thresholds:**

| Source | high trigger | medium trigger | low trigger |
|--------|-------------|----------------|-------------|
| Tool retry loops | `total_retry_events >= 20` | `>= 5` | — |
| Repeating errors | `occurrences >= 5` in a log file | — | — |
| Cron errors | `consecutive_errors >= 2` | — | — |
| Violations | severity=high in rule config | severity=medium | severity=low |
| Session health | — | — | `heavy_sessions >= 3` or `max_compaction >= 20` |
| Unresolved learnings | — | `total_high_priority >= 1` | — |
| User frustration | `total_hits >= 5` | `>= 3` | — |

---

### `scripts/setup-wizard.sh`

**Role:** Interactive one-time setup. Verifies dependencies, creates `config.yaml`, creates data directories, runs a test analysis, and optionally installs the weekly cron.

**When to use:** Run once after cloning/installing. Safe to re-run — it skips steps that are already complete.

**Cron format installed:**

```bash
0 9 * * 0 bash /path/to/scripts/generate-proposal.sh >> ~/.openclaw/logs/self-evolving-cron.log 2>&1
```

---

### `scripts/lib/config-loader.sh`

**Role:** YAML config loader. Parses `config.yaml` with Python (PyYAML if available, built-in line parser as fallback) and exports values as environment variables for use in the analysis scripts.

**Variable export mapping:**

| config.yaml key | Shell variable |
|-----------------|---------------|
| `analysis.days` | `SEA_DAYS` |
| `analysis.max_sessions` | `SEA_MAX_SESSIONS` |
| `analysis.include_memory_md` | `SEA_INCLUDE_MEMORY` |
| `analysis.complaint_patterns` | `SEA_COMPLAINT_PATTERNS` (comma-separated) |
| `analysis.log_files` | `SEA_LOG_FILES` (comma-separated) |
| `analysis.learnings_paths` | `SEA_LEARNINGS_PATHS` (comma-separated) |
| `proposals.complaint_min_hits` | `SEA_COMPLAINT_MIN` |
| `proposals.repeat_request_min` | `SEA_REPEAT_MIN` |
| `proposals.expire_days` | `SEA_EXPIRE_DAYS` |
| `cron.schedule` | `SEA_CRON_SCHEDULE` |
| `cron.discord_channel` | `SEA_DISCORD_CHANNEL` |
| `output.verbose` | `SEA_VERBOSE` |
| `output.analysis_json` | `SEA_ANALYSIS_JSON` |
| `output.max_message_length` | `SEA_MAX_MSG_LEN` |

**Priority:** Environment variables set before calling the script take precedence over `config.yaml` values. This allows per-run overrides without modifying the config file.

---

## `config.yaml` — Full Option Reference

```yaml
# ============================================================
# config.yaml — OpenClaw Self-Evolving Agent
# Full reference with all available options and defaults
# ============================================================

# ── Analysis settings ──────────────────────────────────────

analysis:
  # How many days of session logs to scan
  days: 7                          # Default: 7

  # Maximum number of session files to analyze (most recent first)
  max_sessions: 50                 # Default: 50

  # Whether to include MEMORY.md in the analysis
  include_memory_md: true          # Default: true

  # Minimum occurrences before a "repeat request" is flagged
  repeat_request_min: 3            # Default: 3

  # Frustration/complaint phrases to detect in user messages.
  # These are exact substring matches (case-sensitive).
  complaint_patterns:
    - "말했잖아"
    - "했잖아"
    - "이미 말했"
    - "왜 또"
    - "몇 번"
    - "또?"
    - "기억 못"
    - "저번에도"
    - "왜 자꾸"
    - "또 그러네"
    - "안 되잖아"
    - "또 하네"
    - "다시 해야"
    - "다시 또"
    # English examples:
    # - "you said that already"
    # - "I told you"
    # - "stop doing that"

  # Cron/heartbeat log files to scan for repeating errors.
  # These are filenames only; full path = logs_dir/<filename>
  log_files:
    - "cron-catchup.log"
    - "heartbeat-cron.log"
    - "context-monitor.log"
    - "metrics-cron.log"

  # Directories to scan for .learnings/ entries (ERRORS.md, LEARNINGS.md, FEATURE_REQUESTS.md)
  # Relative paths are resolved from $HOME
  learnings_paths:
    - "openclaw/.learnings"
    - ".openclaw/.learnings"

  # Filter analysis to sessions belonging to specific agents (by agent name/ID)
  # Empty = analyze all agents
  agent_filter: []

# ── Path overrides ─────────────────────────────────────────
# These are auto-detected for standard openclaw layouts.
# Only set if your layout differs from the defaults.

# agents_dir: ~/.openclaw/agents        # Where session .jsonl files live
# logs_dir: ~/.openclaw/logs            # Where cron/heartbeat logs live
# agents_md: ~/openclaw/AGENTS.md       # Your AGENTS.md rules file
# memory_md: ~/openclaw/MEMORY.md       # Your MEMORY.md (for issue count)

# ── Proposal settings ──────────────────────────────────────

proposals:
  # Minimum complaint hits before generating a user frustration proposal
  complaint_min_hits: 2            # Default: 2

  # How many days before old proposal files are moved to archive/
  expire_days: 30                  # Default: 30

# ── Cron / scheduling ──────────────────────────────────────

cron:
  # Cron schedule (standard cron format)
  schedule: "0 9 * * 0"           # Default: Sunday 09:00

  # Discord channel ID for posting reports (leave empty to disable)
  discord_channel: ""              # e.g. "1469905074661757049"

# ── Output settings ────────────────────────────────────────

output:
  # Show progress during analysis (to stderr)
  verbose: true                    # Default: true

  # Custom path for the intermediate analysis JSON file
  analysis_json: "/tmp/self-evolving-analysis.json"

  # Maximum Markdown report length (characters) before truncation
  max_message_length: 3500         # Default: 3500
```

---

## Extension Points

### Adding a Custom Detection Pattern

All detection logic lives in a single Python script that is written to a temp file inside `analyze-behavior.sh`. To add a new pattern, there are two approaches:

#### Approach A: Add a violation rule (simplest)

Edit the `violation_config` array in `scripts/analyze-behavior.sh`:

```python
violation_config = [
    # ... existing rules ...
    {
        'pattern': r'\blaunchctl\s+load\b',     # regex to match in exec commands
        'rule': 'launchctl 직접 호출 금지',       # human-readable rule name
        'severity': 'high',                      # high / medium / low
        'min_hits': 1,                           # minimum occurrences to report
        'source': 'exec_commands',               # always exec_commands for violations
        'fix': 'openclaw gateway restart'        # suggested replacement
    },
]
```

This will automatically:
- Detect the pattern in executed `exec` commands
- Report hit count and examples
- Generate a proposal with the `fix` text in the "After" block

#### Approach B: Add a full analysis section (advanced)

Add a new numbered section in the Python analysis script in `analyze-behavior.sh`. Follow the existing pattern:

```python
# ── 10. Custom Pattern: <your description> ──────────────────
your_results = []

# Your detection logic here
# Use: user_texts, all_exec_cmds, tool_seq_per_session, etc.

result['your_pattern'] = your_results
```

Then add a corresponding proposal generator block in `generate-proposal.sh`:

```python
# ── Proposal source: your custom pattern ─────────────────────
your_data = data.get('your_pattern', [])
if your_data:
    proposals.append({
        'id': 'your-pattern-01',
        'source': 'your_pattern',
        'title': 'Your pattern title',
        'severity': 'medium',
        'evidence': f'Found {len(your_data)} occurrences',
        'before': 'Current state',
        'after': '## Proposed change\n...',
        'section': 'AGENTS.md section to update',
        'diff_type': 'agents_md_addition'
    })
```

And register the source emoji in `build_report`:

```python
source_emoji = {
    # ... existing entries ...
    'your_pattern': '🔍',
}
```

### Adding Support for a New Log Format

The log error scanner reads plain text files line by line. To add a new log format:

1. Add the filename to `analysis.log_files` in `config.yaml`
2. If the log uses a non-standard error prefix (not `error`, `failed`, `exception`, `traceback`, `panic`, `fatal`), modify the error pattern regex in `analyze-behavior.sh`:

```python
err_patterns = re.findall(
    r'(?i)(?:error|failed|exception|traceback|panic|fatal|YOUR_PREFIX)[^\n]{0,150}',
    content
)
```

### Adding a New Notification Channel

The current version outputs to stdout and optionally to Discord. To add Telegram, Slack, or webhook delivery, `config.yaml` has reserved fields:

```yaml
delivery:
  platform: discord           # discord | slack | telegram | webhook
  slack:
    webhook_url: ""
  telegram:
    bot_token: ""
    chat_id: ""
  webhook:
    url: ""
    method: POST
```

These are parsed by `config-loader.sh` into `SEA_DELIVERY_PLATFORM`, `SEA_SLACK_WEBHOOK_URL`, etc. Implement the delivery logic in `generate-proposal.sh` after the `build_report` step.

---

## Data Formats

### Analysis JSON (`/tmp/self-evolving-analysis.json`)

```json
{
  "meta": {
    "analysis_date": "2026-02-18",
    "analysis_timestamp": "2026-02-18T09:01:25",
    "analysis_days": 7,
    "session_count": 42,
    "version": "3.0.0"
  },
  "complaints": { ... },
  "errors": { "cron_errors": [...], "log_errors": [...] },
  "violations": { "violations": [...] },
  "repeat_requests": [...],
  "learnings": { ... },
  "memory_md": { ... },
  "retry_analysis": { "high_retry_tools": [...], "total_retry_events": 7, "worst_streaks": [...] },
  "session_health": { "total_sessions": 42, "heavy_sessions": 5, "avg_compaction_per_session": 1.8, "max_compaction": 31 },
  "previously_rejected": [...]
}
```

### Proposal JSON (`data/proposals/proposal_<timestamp>.json`)

```json
{
  "created_at": "2026-02-18T09:01:30",
  "status": "awaiting_approval",
  "analysis_days": 7,
  "proposals": [
    {
      "id": "retry-exec-01",
      "source": "retry_analysis",
      "title": "`exec` 도구 연속 재시도 패턴 개선 (3개 세션 영향)",
      "severity": "high",
      "evidence": "...",
      "before": "...",
      "after": "...",
      "section": "Exec 에러 노출 금지 규칙",
      "diff_type": "agents_md_addition"
    }
  ],
  "analysis_summary": {
    "session_count": 42,
    "total_complaint_hits": 7,
    "retry_events": 7,
    "heavy_sessions": 5
  }
}
```

### Rejection Log (`data/rejected-proposals.json`)

```json
[
  {
    "id": "session-health-01",
    "rejected_at": "2026-02-18T10:30:00",
    "reason": "Already addressed manually"
  }
]
```

Proposal IDs in this file are permanently excluded from future analysis outputs.

---

## Pairs With

→ **[openclaw-self-healing](https://github.com/Ramsbaby/openclaw-self-healing)** — While self-evolving runs weekly to improve long-term patterns, self-healing fires immediately on crashes to restore the agent to a working state. They share no code but complement each other in a complete agent reliability stack.
