# Test Fixtures

Sample OpenClaw session `.jsonl` files for testing and contributing.

## Usage

```bash
# Point analyzer at fixture directory instead of real logs
AGENTS_DIR=test/fixtures bash scripts/analyze-behavior.sh /tmp/test-output.json
```

## Files

- `sample-violation.jsonl` — Session with AGENTS.md violation (direct git command)
- `sample-retry-loop.jsonl` — Session with tool retry loop (exec called 8× consecutively)
- `sample-frustration.jsonl` — Session with user frustration patterns
- `sample-clean.jsonl` — Clean session with no patterns (should produce 0 proposals)

## Adding Fixtures

Anonymize real session logs by replacing personal info:
- Replace usernames with `"user_id": "test-user"`
- Replace file paths with generic paths like `/home/user/project/`
- Remove API keys and credentials

Format: standard OpenClaw session JSONL (one JSON object per line, `role`/`content` structure).
