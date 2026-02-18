# Changelog

All notable changes to OpenClaw Self-Evolving Agent are documented in this file.

Format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.0] - 2026-02-18

### Added

- **Initial release** of OpenClaw Self-Evolving Agent
- **6 detection patterns** in `scripts/analyze-behavior.sh` (v3.0):
  - Tool retry loops — detects 5+ consecutive calls to the same action tool per session
  - Repeating errors — flags the same error signature appearing 3+ times in a log file
  - User frustration — scans user messages for complaint/re-prompting expressions (context-filtered)
  - AGENTS.md violations — detects rule violations in actual `exec` commands (not conversation text)
  - Heavy sessions — identifies sessions with 5+ compaction events (sub-agent delegation signal)
  - Unresolved learnings — surfaces high-priority `.learnings/` entries not yet promoted to `AGENTS.md`
- **Approval workflow** with emoji reactions:
  - ✅ Approve all proposals → auto-apply to `AGENTS.md` + git commit
  - 1️⃣–5️⃣ Approve individual numbered proposals
  - ❌ Reject all (with optional reason comment that feeds back into future analyses)
  - 🔄 Request revision
  - Rejection history stored in `data/rejected-proposals.json` and permanently excluded from future runs
- **Capability Evolver migration guide** — comparison table and zero-friction migration path from the suspended ClawHub skill
- **Cross-link with [openclaw-self-healing](https://github.com/Ramsbaby/openclaw-self-healing)** — documented complementary relationship (self-healing for immediate crash recovery, self-evolving for weekly pattern improvement)
- `scripts/setup-wizard.sh` — interactive one-time setup with dependency checks, config creation, test analysis, and optional cron registration
- `scripts/lib/config-loader.sh` — YAML config loader with PyYAML + pure-Python fallback parser
- `config.yaml.example` with full option documentation
- `data/rejected-proposals.json` — persistent rejection history (initialized empty)
- Proposal archiving: proposals older than `expire_days` (default 30) are automatically moved to `data/proposals/archive/`
- `docs/QUICKSTART.md` — 5-minute getting-started guide with troubleshooting FAQ
- `docs/DETECTION-PATTERNS.md` — detailed pattern reference with criteria, examples, and false positive prevention
- `docs/ARCHITECTURE.md` — full system architecture, ASCII data flow diagram, script roles, complete config reference, and extension guide
- `.github/ISSUE_TEMPLATE/bug_report.md` and `feature_request.md` — standard GitHub issue templates

### Technical notes

- Analysis pipeline is zero-model, zero-API: no LLM calls, no API fees
- Session analysis is based on actual `toolCall` field names (v3.0 bugfix from `tool_use`)
- Violations are detected only in executed `exec` commands, eliminating false positives from conversational mentions
- All temp files (`/tmp/sea-*`) are cleaned up via `trap EXIT INT TERM`
- Config loader exports shell variables with `SEA_` prefix; environment variables override `config.yaml`
