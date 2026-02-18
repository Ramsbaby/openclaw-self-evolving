# Detection Patterns — OpenClaw Self-Evolving Agent

> Detailed reference for every pattern the analyzer detects, including detection criteria, real examples, and false positive prevention.

---

## Overview

The analyzer (`scripts/analyze-behavior.sh`) scans session `.jsonl` files and cron logs across a configurable window (default: last 7 days). It produces a structured JSON result in six categories, described below.

Each pattern has:
- **What it detects** — the signal and why it matters
- **Detection criteria** — exact thresholds and logic
- **Real example** — what a flagged case looks like in the raw data
- **False positive prevention** — how the analyzer avoids noise

---

## Pattern 1: Tool Retry Loops

### What it detects

When the agent calls the same *action* tool five or more times consecutively within a single session without switching to a different approach. This is a strong signal that the agent is confused, the tool is failing silently, or the environment is in an unexpected state.

### Detection criteria

- **Excluded tools:** `read`, `write`, `edit`, `image`, `tts`, `canvas`
  (Sequential file I/O is a normal pattern — reading 10 files in a row is not a retry loop.)
- **Threshold — session-level:** 5+ consecutive calls to the same action tool = 1 "retry event"
- **Threshold — worst streak:** 10+ consecutive calls = recorded in `worst_streaks`
- **Aggregation:** Count of sessions where a streak was detected, per tool name

```json
// Example entry in retry_analysis output
{
  "high_retry_tools": [
    { "tool": "exec", "sessions_with_streak": 3 }
  ],
  "total_retry_events": 7,
  "worst_streaks": [
    { "tool": "exec", "streak": 23 }
  ]
}
```

### Real example

An agent runs `exec` to check if a service is running, gets no output, retries the same command with no change, and loops 23 times before giving up. In the session `.jsonl`:

```json
{"type":"message","message":{"role":"assistant","content":[{"type":"toolCall","name":"exec","arguments":"{\"command\":\"systemctl status myapp\"}"}]}}
{"type":"message","message":{"role":"assistant","content":[{"type":"toolCall","name":"exec","arguments":"{\"command\":\"systemctl status myapp\"}"}]}}
// ... repeated 21 more times
```

### False positive prevention

- File I/O tools (`read`, `write`, `edit`) are fully excluded. Reading 30 source files one by one is not a retry loop.
- The streak must be *consecutive*. An `exec` call followed by a `process` call resets the counter, so interleaved tool use is never flagged.
- Only *action* tools are counted — tools that interact with external state (exec, browser, process, cron).

### Proposal generated

```
`exec` 도구 연속 재시도 패턴 개선 (3개 세션 영향)

After:
## ⚡ exec 연속 재시도 방지
같은 exec를 3회 이상 재시도하기 전에:
1. 첫 번째 실패 시 에러 메시지를 사용자에게 보고
2. 두 번째 시도는 방법을 변경해서 (다른 옵션/경로)
3. 세 번째 실패 시 중단하고 수동 확인 요청
```

---

## Pattern 2: Repeating Errors

### What it detects

When the same error message (same signature, ignoring timestamps and numbers) appears 3 or more times in the same log file. A single error might be a transient failure; the same error repeated many times is an unfixed bug.

### Detection criteria

- **Sources:** Log files listed in `config.yaml → analysis.log_files`
  (defaults: `cron-catchup.log`, `heartbeat-cron.log`, `context-monitor.log`, `metrics-cron.log`)
- **Error pattern matching:** Regex `(?i)(?:error|failed|exception|traceback|panic|fatal)[^\n]{0,150}`
- **Signature normalization:** Timestamps (`2026-02-18`, `09:01:23`) and all numbers are replaced with `N` before grouping
- **Threshold:** 3+ occurrences of the same normalized signature within the same file = flagged
- **Severity trigger for proposals:** 5+ occurrences

```json
// Example entry in log_errors output
{
  "file": "heartbeat-cron.log",
  "error_count": 18,
  "unique_errors": 4,
  "repeating_errors": [
    {
      "signature": "Error: ENOENT: no such file or directory, open '/Users/.../session.jsonl'",
      "occurrences": 12
    }
  ]
}
```

### Real example

A cron script references a session path that was renamed. Every heartbeat run fails with the same `ENOENT` error. Over 7 days: 12 occurrences of the identical error.

```
[2026-02-11 09:00:01] Error: ENOENT: no such file or directory, open '/Users/ramsbaby/.openclaw/agents/main/sessions/session-abc123.jsonl'
[2026-02-12 09:00:01] Error: ENOENT: no such file or directory, open '/Users/ramsbaby/.openclaw/agents/main/sessions/session-abc123.jsonl'
// ... 10 more days
```

### False positive prevention

- **Per-file isolation:** Error signatures are counted *within* a single log file. The same error in two different log files is tracked separately, not aggregated across files.
- **Signature normalization:** Line numbers, session IDs, and timestamps vary per run; normalizing to `N` prevents the same error from appearing as "unique" each time.
- **Minimum threshold:** Single occurrences are never reported — the pattern must repeat at least 3 times to appear in the data, and 5+ to generate a proposal.

### Proposal generated

```
[heartbeat-cron.log] 같은 에러 12회 반복 → 미수정 버그 의심

After:
## 🔴 반복 에러 즉시 대응 프로토콜
동일 에러 5회 이상 반복 시:
1. 해당 크론/스크립트 실행 중단
2. 에러 원인 파악 후 수정
3. 수정 전까지 크론 비활성화
확인: `tail -50 ~/.openclaw/logs/heartbeat-cron.log`
```

---

## Pattern 3: User Frustration

### What it detects

User messages that contain explicit frustration signals — repetition complaints, recollection failures, and re-prompting expressions. These indicate the agent is repeating mistakes the user has already corrected.

### Detection criteria

- **Source:** All `user` role messages across analyzed sessions
- **Default complaint patterns (Korean):**
  ```
  말했잖아, 했잖아, 이미 말했, 왜 또, 몇 번, 또?,
  기억 못, 저번에도, 왜 자꾸, 또 그러네, 안 되잖아,
  또 하네, 다시 해야, 다시 또
  ```
- **Sentence-level deduplication:** The same sentence is only counted once, even if the exact wording appears in multiple sessions
- **Minimum length filter:** Sentences shorter than 5 characters are skipped (prevents punctuation-only matches)
- **Proposal threshold:** 3+ total complaint hits across the analysis window

```json
// Example entry in complaints output
{
  "total_complaint_hits": 7,
  "patterns": [
    {
      "pattern": "말했잖아",
      "count": 3,
      "examples": ["저번에도 말했잖아, rm -rf 쓰지 말라고", "말했잖아 git-sync.sh 써야 한다고"]
    }
  ]
}
```

### Real example

The user has told the agent multiple times not to use `rm -rf` directly. The agent keeps doing it. User messages across different sessions:

```
"저번에도 말했잖아, rm 쓰지 말라고. trash 써."
"왜 또 rm -rf 써? 몇 번을 말해야 해?"
"말했잖아 git 직접 쓰지 말라고."
```

Three occurrences of `말했잖아` → flagged.

### False positive prevention

- **Excluded generic verbs:** The pattern list is specifically chosen to exclude common task-request phrases. Words like `확인해줘`, `진행해줘`, `해봐` are *not* in the complaint pattern list.
- **Configurable patterns:** You can replace the default Korean patterns with patterns suited to your language/style in `config.yaml`:
  ```yaml
  complaint_patterns:
    - "you said that already"
    - "I told you"
    - "stop doing that"
  ```
- **Sentence deduplication:** The same complaint phrased identically in two sessions counts as one hit.

### Proposal generated

```
실제 사용자 불만 표현 7건 감지

After:
## 🔁 불만 감지 즉시 대응
사용자가 반복/재촉 표현 사용 시:
1. 현재 진행 상황 즉시 보고
2. SESSION-STATE.md에 "왜 반복 됐는가" 기록
3. 근본 원인 1문장으로 명시 후 해결 방법 제안
```

---

## Pattern 4: AGENTS.md Violations

### What it detects

Actual violations of the rules defined in `AGENTS.md`, detected by scanning the raw shell commands that were passed to the `exec` tool — not the agent's conversational text.

### Detection criteria

Built-in violation rules (with minimum hit counts to reduce noise):

| Rule | Pattern | Min hits | Severity |
|------|---------|----------|----------|
| git 직접 명령 (git-sync.sh 우회) | `git (pull\|push\|fetch)` | 1 | high |
| rm 직접 사용 (trash 사용 필요) | `rm -rf?` | 2 | medium |
| curl 실패 핸들링 누락 | `curl https?://...` without `-f`/`-s` | 3 | low |

```json
// Example entry in violations output
{
  "violations": [
    {
      "rule": "git 직접 명령 (git-sync.sh 우회)",
      "pattern": "\\bgit\\s+(?:pull|push|fetch)\\b",
      "hit_count": 4,
      "severity": "high",
      "examples": ["git pull origin main", "git push"],
      "fix": "bash ~/openclaw/scripts/git-sync.sh"
    }
  ]
}
```

### Real example

The agent bypassed `git-sync.sh` and ran `git push` directly 4 times over the week:

```bash
# Extracted from exec tool calls in session .jsonl files
git pull origin main
git push
git push origin main
git fetch --all
```

All four are flagged as `high` severity violations.

### False positive prevention

**This is the most important improvement in v3.0.**

Previous versions scanned the agent's *entire response text* for violation patterns. This caused massive false positive rates — the agent might *mention* `rm -rf` in an explanation ("don't use `rm -rf`") and get flagged for it.

v3.0 scans **only the `command` field of `exec` tool calls** — the actual shell commands the agent executed. If the agent talks about `git push` in text but only called `git-sync.sh` in practice, no violation is reported.

Additionally:
- **Per-rule minimum hit counts** prevent one-time accidents from generating proposals. The `rm` rule requires 2+ hits; the `curl` rule requires 3+.
- **Examples are extracted** so you can verify the violations are real before acting on the proposal.

### Proposal generated

```
exec 명령에서 규칙 위반 감지: git 직접 명령 (git-sync.sh 우회)

Evidence:
최근 7일간 exec 명령에서 4회 위반:
  - `git pull origin main`
  - `git push`
→ 대화에서 "언급"이 아닌 실제 실행된 명령어 기준 (오탐 없음)

After:
## ✅ 올바른 방법
```bash
bash ~/openclaw/scripts/git-sync.sh
```
```

---

## Pattern 5: Heavy Sessions

### What it detects

Sessions that triggered context compaction 5 or more times, indicating tasks that were too large for a single session and would have benefited from sub-agent delegation.

### Detection criteria

- **Compaction events:** Counted by `{"type":"compaction"}` entries in session `.jsonl` files
- **Heavy session threshold:** 5+ compaction events in a single session file
- **Proposal triggers:**
  - 3+ heavy sessions across the analysis window, **or**
  - Maximum compaction count ≥ 20 in a single session

```json
// Example entry in session_health output
{
  "total_sessions": 42,
  "heavy_sessions": 5,
  "avg_compaction_per_session": 1.8,
  "max_compaction": 31,
  "avg_msg_count": 47.3
}
```

### Real example

A session where the agent was tasked with rewriting a large module, running tests, and committing changes — all without using sub-agents. The session required 31 context compactions, meaning critical early context was repeatedly discarded.

```json
{"type":"compaction","summary":"...context compressed..."}
{"type":"compaction","summary":"...context compressed..."}
// ... 29 more
```

### False positive prevention

- **Threshold is generous:** 5 compactions per session is a high bar. Normal sessions with a few tool calls will have 0–2 compactions.
- **Both conditions required for proposals:** Either 3+ heavy sessions in the window OR a single session with 20+ compactions. A single unusually long session on its own won't generate a high-severity proposal.
- **No proposal if healthy:** If all sessions are lightweight, this analysis produces no output.

### Proposal generated

```
과도하게 긴 세션 감지 (5개 세션, 최대 컴팩션 31회)

After:
## 📦 서브에이전트 분리 기준
다음 조건 중 하나라도 해당하면 서브에이전트 사용:
- 예상 작업 시간 > 10분
- 도구 호출 예상 > 20회
- 메인 채널 컨텍스트 오염 우려
→ `subagents` 도구로 spawn, 결과는 push-based 자동 보고
```

---

## Pattern 6: Unresolved Learnings

### What it detects

High-priority items recorded in the `.learnings/` directory (by a connected self-improving agent) that have not yet been promoted to `AGENTS.md` or acted upon.

### Detection criteria

- **Sources:** Files in directories listed in `config.yaml → analysis.learnings_paths`
  (defaults: `openclaw/.learnings`, `.openclaw/.learnings`)
- **Files scanned:** `ERRORS.md`, `LEARNINGS.md`, `FEATURE_REQUESTS.md`
- **Entry format:** Entries with `**Status**: pending` or `**Status**: in_progress`
- **High-priority count:** Entries containing `**Priority**: high` or `**Priority**: critical`
- **Proposal trigger:** 1+ high/critical pending entry

```json
// Example entry in learnings output
{
  "total_pending": 8,
  "total_high_priority": 3,
  "top_errors": [
    {
      "id": "ERR-20260211-abc123",
      "status": "pending",
      "summary": "exec tool silently swallows non-zero exit codes in pty mode"
    }
  ]
}
```

### Real example

Three weeks ago, the agent encountered a bug where `exec` with `pty=true` silently ignored non-zero exit codes. It was logged in `ERRORS.md` as `high` priority. It has remained `pending` and was never promoted to `AGENTS.md` as a rule.

```markdown
## [ERR-20260211-abc123] exec pty exit code bug
**Status**: pending
**Priority**: high
### Summary
exec tool silently swallows non-zero exit codes in pty mode
```

### False positive prevention

- **Status filter:** Only `pending` and `in_progress` items are counted. `resolved` and `archived` entries are ignored.
- **Priority filter:** Proposals are only generated for `high` or `critical` priority items. Low-priority learnings accumulate without generating noise.
- **Graceful missing directory:** If the `.learnings/` directory doesn't exist (e.g., not using a self-improving companion), this analysis silently produces zero results.

### Proposal generated

```
.learnings/ 고우선순위 미해결 이슈 3건

After:
## 📚 .learnings/ 승격 프로토콜
매주 일요일 heartbeat에서:
```bash
grep -r "Priority**: high" ~/openclaw/.learnings/ | head -10
```
→ high/critical 항목을 AGENTS.md 또는 SOUL.md로 즉시 승격
```

---

## Tuning the Analyzer

All thresholds are configurable in `config.yaml`:

```yaml
# config.yaml

# Minimum repeat count before a "repeat request" is flagged
repeat_min: 3                # default 3

# Complaint patterns (replace defaults with your own language/style)
complaint_patterns:
  - "말했잖아"
  - "왜 또"
  # add more...

# Log files to scan for repeating errors
log_files:
  - "cron-catchup.log"
  - "heartbeat-cron.log"
  - "context-monitor.log"
  - "metrics-cron.log"
  # add your own...

# Paths to scan for .learnings/ entries
learnings_paths:
  - "openclaw/.learnings"
  - ".openclaw/.learnings"
```

To add a **custom violation rule**, see the **Extension Points** section in [ARCHITECTURE.md](ARCHITECTURE.md).
