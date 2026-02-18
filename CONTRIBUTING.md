# Contributing to openclaw-self-evolving

Thanks for your interest. This project does one thing: analyze AI agent logs and propose `AGENTS.md` improvements.

## Ground Rules

1. **No silent modification** — any change to `AGENTS.md` must go through human approval. Don't add code that bypasses this.
2. **No API calls** — analysis stays local. No sending logs to external services.
3. **False positive > missed signal** — it's better to detect nothing than to flood the user with noise. Filter aggressively.

## What's Welcome

- New detection patterns for `analyze-behavior.sh`
- Better false-positive filtering for complaint/violation detection
- Support for other AI platforms (currently OpenClaw-specific paths)
- Performance improvements for large log volumes

## How to Contribute

1. Fork the repo
2. Create a branch: `git checkout -b feature/your-feature-name`
3. Test with your own logs: `bash scripts/generate-proposal.sh`
4. Open a PR with a short description of what you detected and why it's useful

## Testing

```bash
# Run analysis against your own logs
bash scripts/analyze-behavior.sh /tmp/test-analysis.json

# Generate proposal report
bash scripts/generate-proposal.sh
```

No test suite yet. PRs that add tests are especially welcome.

## Questions

Open an issue. Keep it concise.
