---
name: Feature Request
about: Propose a new detection pattern, notification channel, config option, or other improvement
title: "[FEATURE] "
labels: enhancement
assignees: ""
---

## Summary

A clear, one-sentence description of the feature you'd like to see.

---

## Problem / Motivation

What problem does this solve? What situation are you in where the current tool falls short?

> Example: "I have multiple agents in separate directories, and the analyzer only scans one `agents_dir` at a time. I want to scan all of them in a single run."

---

## Proposed Solution

Describe the behavior you'd like. Be as specific as you can.

> Example: "Add an `agents_dirs` (plural) list in `config.yaml` that accepts multiple paths. The analyzer should union the session files from all directories before applying the max_sessions limit."

---

## Alternative Approaches Considered

Have you thought of other ways to address this? Why did you prefer the proposed solution?

---

## Detection Pattern Requests (fill in if applicable)

If you're requesting a new detection pattern, please provide:

**What signal should be detected?**

> Example: "Agent calling `message` tool inside a cron job (which causes double-delivery)."

**Detection criteria:**

> Example: "Any session file that contains a `toolCall` with `name == 'message'` AND is associated with a cron agent label."

**Real example from your logs (redact personal data):**

```json
{
  "type": "message",
  "message": {
    "role": "assistant",
    "content": [{ "type": "toolCall", "name": "message", ... }]
  }
}
```

**How should false positives be prevented?**

> Example: "Only flag this when the session was initiated by a cron trigger (not a user interaction)."

---

## Scope

Which script(s) would this affect?

- [ ] `scripts/analyze-behavior.sh` — new detection pattern
- [ ] `scripts/generate-proposal.sh` — new proposal type or report format
- [ ] `scripts/setup-wizard.sh` — setup/install improvement
- [ ] `scripts/lib/config-loader.sh` — new config option
- [ ] `config.yaml.example` — documentation update
- [ ] Other: ___

---

## Priority / Impact

How important is this to you?

- [ ] 🔴 High — blocks me from using the tool effectively
- [ ] 🟡 Medium — would meaningfully improve my workflow
- [ ] 🟢 Low — nice to have

---

## Additional Context

Anything else that would help: links, related issues, example configs, etc.
