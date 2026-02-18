---
name: Bug Report
about: Report a defect in analysis, proposal generation, or setup
title: "[BUG] "
labels: bug
assignees: ""
---

## Summary

A clear, one-sentence description of the bug.

---

## Environment

- **OS:** (e.g. macOS 15.3 arm64, Ubuntu 22.04 x86_64)
- **bash version:** (`bash --version`)
- **Python version:** (`python3 --version`)
- **Script version:** (check `# v3.0` header in `analyze-behavior.sh`)
- **OpenClaw version:** (`openclaw --version` or `openclaw gateway status`)

---

## Steps to Reproduce

1. Step one
2. Step two
3. Step three

```bash
# Paste the exact command you ran
bash scripts/generate-proposal.sh
```

---

## Expected Behavior

What you expected to happen.

---

## Actual Behavior

What actually happened. Include the full terminal output if possible.

```
Paste output here
```

---

## Analysis JSON (if relevant)

If the bug relates to incorrect analysis results, paste the relevant section from `/tmp/self-evolving-analysis.json`:

```json
{
  "meta": { ... },
  "retry_analysis": { ... }
}
```

---

## Config (redact personal paths)

```yaml
# Paste your config.yaml here (redact real paths/channel IDs if preferred)
analysis:
  days: 7
  max_sessions: 50
```

---

## Additional Context

Any other information — related scripts, recent config changes, unusual log patterns, etc.
