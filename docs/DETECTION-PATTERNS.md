# 🔍 Detection Patterns

Detailed reference for all patterns the analyzer detects.

## 1. Tool Retry Loops

**What:** Same tool called 5+ times consecutively in a session.

**Why it matters:** Indicates the agent is confused or stuck in a loop. Wastes tokens and time.

**Detection:** `grep` for consecutive identical tool calls within 10-line windows.

**Example:**
```
[turn 12] exec: git status
[turn 13] exec: git status  
[turn 14] exec: git status   ← 3rd consecutive = flagged
```

**False positive prevention:** Ignores `session_status` and `memory_search` (naturally repeated).

---

## 2. Repeating Errors

**What:** Same error message appearing 5+ times across sessions.

**Why it matters:** An unfixed bug, not a fluke. Should be addressed in AGENTS.md or code.

**Detection:** Error line deduplication + frequency count across all analyzed sessions.

**Example:**
```
ERROR: "Ambiguous Discord recipient" × 7 sessions
→ Proposal: Add explicit channel targeting rule to AGENTS.md
```

---

## 3. User Frustration

**What:** Expressions indicating user dissatisfaction with agent responses.

**Detection keywords:** "다시", "또", "아까 말했잖아", "why again", "you already said", "wrong"

**Context filtering:** Only flagged when:
- User (not agent) is speaking
- Not inside a code block or quote
- Appears in direct conversation, not referenced content

**False positive rate:** ~8% (v5.0, down from 15% in v4)

---

## 4. AGENTS.md Violations

**What:** Rules defined in AGENTS.md being broken in actual exec commands.

**Detection:** Cross-references AGENTS.md rules with exec tool calls in sessions.

**Example:**
```
AGENTS.md rule: "git 직접 명령 금지, 반드시 git-sync.sh 사용"
Session exec:   "git add -A && git commit"  ← violation
```

**False positive prevention:** Only checks `exec` tool results, not conversation text discussing git.

---

## 5. Heavy Sessions

**What:** Sessions hitting >85% context window (compaction threshold).

**Why it matters:** Tasks causing heavy sessions should probably be delegated to sub-agents.

**Detection:** Looks for compaction markers in session metadata.

---

## 6. Unresolved Learnings

**What:** High-priority items in `.learnings/` directory not yet reflected in AGENTS.md.

**Detection:** Compares `.learnings/*.md` file contents against current AGENTS.md text.

**Example:**
```
.learnings/2026-02-15.md: "exec 실패 시 || true 추가 필요"
AGENTS.md: no matching rule found
→ Proposal: Add exec error handling rule
```

---

## Adding Custom Patterns

Edit `scripts/analyze-behavior.sh` and add a new function following this template:

```bash
detect_custom_pattern() {
    local session_file="$1"
    local count=0
    # Your detection logic here
    # Increment count for each match
    echo "$count"
}
```

Register it in the `PATTERNS` array at the top of the file.
