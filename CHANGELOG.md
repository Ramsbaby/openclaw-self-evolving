# Changelog

All notable changes to this project will be documented in this file.

## [1.0.0] - 2026-02-17

### Added
- Initial release as independent project (split from openclaw-self-healing v3.0)
- 6 detection patterns: tool retry loops, repeating errors, user frustration, AGENTS.md violations, heavy sessions, unresolved learnings
- Approval workflow via emoji reactions (✅/❌/1️⃣-5️⃣/🔄)
- Rejection feedback loop (rejected reasons fed into next analysis)
- Interactive setup wizard (`scripts/setup-wizard.sh`)
- `--dry-run` flag: analyze and print proposals without saving or sending notifications
- Test fixtures in `test/fixtures/` (sample JSONL sessions for contributor testing)
- Proposal generation transparency: template-based with explicit before/after diffs
- Capability Evolver migration guide
- Self-Healing integration: `SEA_LEARNINGS_PATHS` to surface self-healing errors as proposals
- Cross-link with [openclaw-self-healing](https://github.com/Ramsbaby/openclaw-self-healing)
- Demo recording script + GIF
- Documentation: QUICKSTART, DETECTION-PATTERNS, ARCHITECTURE

### Philosophy
- **No silent self-modification. Ever.** Human approval is always required.
- Pure log analysis with shell + Python. No LLM API calls during analysis.
- False positive rate ~8% (prioritizing safety over recall).
- OpenClaw-specific (v1.0). Platform abstraction layer planned for v2.0.

[1.0.0]: https://github.com/Ramsbaby/openclaw-self-evolving/releases/tag/v1.0.0
