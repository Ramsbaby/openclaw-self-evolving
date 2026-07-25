#!/usr/bin/env bash
# ============================================================
# setup-wizard.sh — OpenClaw Self-Evolving Agent Setup
# Repo: https://github.com/Ramsbaby/openclaw-self-evolving
# ============================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

echo ""
echo "🧠 OpenClaw Self-Evolving Agent — Setup Wizard"
echo "================================================"
echo ""

# 1. Check dependencies
echo "Checking dependencies..."
for cmd in python3 bash; do
  command -v "$cmd" >/dev/null 2>&1 && echo "  ✓ $cmd" || { echo "  ✗ $cmd (required)"; exit 1; }
done
echo ""

# 2. Create config.yaml if missing
if [ ! -f "$REPO_DIR/config.yaml" ]; then
  cp "$REPO_DIR/config.yaml.example" "$REPO_DIR/config.yaml"
  echo "✓ Created config.yaml from example"
  echo "  → Edit $REPO_DIR/config.yaml to set your paths"
  echo ""
fi

# 3. Create data directories
mkdir -p "$REPO_DIR/data/proposals/archive"
[ ! -f "$REPO_DIR/data/rejected-proposals.json" ] && echo '[]' > "$REPO_DIR/data/rejected-proposals.json"
echo "✓ Data directories ready"

# 4. Test analysis
echo ""
echo "Running test analysis (last 7 days)..."
if bash "$SCRIPT_DIR/analyze-behavior.sh" /tmp/self-evolving-test.json >/dev/null 2>&1; then
  SESSION_COUNT=$(python3 -c "
import json
with open('/tmp/self-evolving-test.json') as f:
    d = json.load(f)
print(d.get('session_health', {}).get('total_sessions', 0))
" 2>/dev/null || echo "?")
  echo "  ✓ Analysis OK — found $SESSION_COUNT sessions"
  rm -f /tmp/self-evolving-test.json
else
  echo "  ⚠ Analysis returned errors (check your paths in config.yaml)"
fi

# 5. Optional cron setup
echo ""
read -rp "Set up weekly cron job (Sunday 09:00)? [y/N] " yn
# ${yn,,} is bash 4+; macOS ships bash 3.2, where it aborts with "bad substitution".
yn_lower="$(printf '%s' "$yn" | tr '[:upper:]' '[:lower:]')"
if [[ "$yn_lower" == "y" ]]; then
  CRON_CMD="0 9 * * 0 bash $SCRIPT_DIR/generate-proposal.sh >> ~/.openclaw/logs/self-evolving-cron.log 2>&1"
  mkdir -p "$HOME/.openclaw/logs"
  # On an empty crontab, grep exits 1 and `set -o pipefail` kills the subshell before
  # echo runs — first-time users ended up with no cron entry at all.
  { crontab -l 2>/dev/null | grep -v "generate-proposal.sh" || true; echo "$CRON_CMD"; } | crontab -
  echo "  ✓ Cron job added"
fi

echo ""
echo "✅ Setup complete!"
echo ""
echo "Run a manual analysis anytime:"
echo "  bash $SCRIPT_DIR/generate-proposal.sh"
echo ""
