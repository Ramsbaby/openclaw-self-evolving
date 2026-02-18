# 🏗️ Architecture

## Data Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│ Session Logs │────▶│   Analyzer   │────▶│  Patterns    │
│ (7 days)     │     │ (bash+grep)  │     │ (JSON)       │
└──────────────┘     └──────────────┘     └──────┬───────┘
                                                  │
                     ┌──────────────┐     ┌───────▼──────┐
                     │  AGENTS.md   │◀────│  Generator   │
                     │  (updated)   │     │ (proposals)  │
                     └──────────────┘     └───────┬──────┘
                           ▲                      │
                           │               ┌──────▼───────┐
                     ┌─────┴──────┐        │   Channel    │
                     │   Human    │◀───────│  (Discord/   │
                     │  Approval  │        │   Telegram)  │
                     └─────┬──────┘        └──────────────┘
                           │
                     ┌─────▼──────┐
                     │  Rejected  │──── fed back to next analysis
                     │  Reasons   │
                     └────────────┘
```

## Script Roles

| Script | Purpose | When |
|--------|---------|------|
| `analyze-behavior.sh` | Scans logs, detects patterns | Called by generator |
| `generate-proposal.sh` | Orchestrates full pipeline, generates proposals | Weekly cron |
| `setup-wizard.sh` | Interactive setup + cron registration | One-time setup |
| `lib/config-loader.sh` | Loads config.yaml values | Sourced by others |

## Config Reference

```yaml
# Analysis scope
analysis_days: 7          # Days of logs to scan (1-30)
max_sessions: 50          # Max session files to process
verbose: true             # Show progress output

# Paths (auto-detected for standard OpenClaw layout)
agents_dir: ~/.openclaw/agents
logs_dir: ~/.openclaw/logs
agents_md: ~/openclaw/AGENTS.md

# Notification
notify:
  discord_channel: ""     # Discord channel ID
  telegram_chat_id: ""    # Telegram chat ID (optional)

# Thresholds
thresholds:
  tool_retry: 5           # Min consecutive calls to flag
  error_repeat: 5         # Min error occurrences to flag
  heavy_session: 85       # Context % threshold
```

## Extension Points

### Custom Detection Patterns

Add functions to `analyze-behavior.sh`:

```bash
detect_my_pattern() {
    local session_file="$1"
    # Return count of matches
}
```

### Custom Notification Channels

Modify the `send_notification()` function in `generate-proposal.sh`.

### Integrating with CI/CD

Run analysis in CI to validate AGENTS.md changes:

```bash
bash scripts/analyze-behavior.sh --check-only
# Exit code 0 = no issues, 1 = patterns found
```
