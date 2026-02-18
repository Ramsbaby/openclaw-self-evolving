# Contributing to openclaw-self-evolving

This project does one thing: analyze AI agent logs and propose `AGENTS.md` improvements.

## Ground Rules

1. **No silent modification** — any change to `AGENTS.md` must go through human approval. Don't add code that bypasses this.
2. **No external API calls** — analysis stays local. No sending logs to external services.
3. **False positive > missed signal** — better to detect nothing than flood the user with noise. Filter aggressively.

## What's Welcome

- New detection patterns for `analyze-behavior.sh`
- Better false-positive filtering for complaint/violation detection
- Support for other AI platforms (currently OpenClaw-specific — log format abstraction layer planned)
- Test fixtures in `test/fixtures/` (sample `.jsonl` session files)
- Performance improvements for large log volumes

## How to Contribute

```bash
# Fork the repo
git checkout -b feature/your-feature-name

# Test with fixture files (no real logs needed)
AGENTS_DIR=test/fixtures bash scripts/analyze-behavior.sh /tmp/test-output.json

# Or dry-run the full pipeline
bash scripts/generate-proposal.sh --dry-run

# Run against your own real logs
bash scripts/generate-proposal.sh
```

Open a PR with a short description of what you detected and why it matters.

## Adding Detection Patterns

Edit `analyze-behavior.sh` and add a detection function:

```bash
detect_my_pattern() {
    local session_file="$1"
    local count=0
    # Your detection logic
    echo "$count"
}
```

Register it in the `PATTERNS` array at the top of the file.

Document it in `docs/DETECTION-PATTERNS.md` with: what it detects, why it matters, detection method, false positive prevention.

## Adding Test Fixtures

Add anonymized session `.jsonl` files to `test/fixtures/`. See `test/fixtures/README.md` for format and anonymization guidelines.

## Questions

Open an issue. Keep it concise.
