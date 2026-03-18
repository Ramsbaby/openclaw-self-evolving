#!/usr/bin/env bash
# ============================================================
# generate-proposal.sh — OpenClaw Self-Evolving Agent v3.1
# Repo: https://github.com/Ramsbaby/openclaw-self-evolving
#
# Runs analyze-behavior.sh, generates AGENTS.md improvement
# proposals, and builds a human-readable report for approval.
#
# Usage:
#   bash generate-proposal.sh
#   ANALYSIS_DAYS=14 bash generate-proposal.sh
#   bash generate-proposal.sh --create-issue          # post to GitHub Issues
#   bash generate-proposal.sh --dry-run               # analyze only, no saves
#
# 변경 이력:
#   v3.1 (2026-03-18) — GitHub Issue 자동 생성 쫐가
#     - --create-issue / -i 플래그: 주간 제안을 GitHub Issue로 자동 등록
#     - create_github_issue(): gh CLI 래퍼, git remote 자동 감지
#     - EVOLVING_GITHUB_REPO 환경변수 또는 git remote 사용
#   v3.0 (2026-02-17) — 품질 비평 기반 전면 개선
#     - 도구 연속 재시도 분석 기반 제안 추가
#     - 반복 에러(같은 에러 N회) 기반 제안 추가
#     - violations 오탐 제거 (exec 명령 기반으로 개선된 분석 활용)
#     - Before를 실제 AGENTS.md에서 읽어 현재 상태 반영
#     - 제안 구체성 강화: 즉시 AGENTS.md에 복붙 가능한 수준
#     - UX 개선: 승인/거부 이모지 반응 안내
#   v2.0 (2026-02-17) — config.yaml 지원
#   v1.0 (2026-02-16) — 초기 버전
# ============================================================

# SECURITY MANIFEST:
# Environment variables accessed: SEA_DAYS, ANALYSIS_DAYS, SEA_ANALYSIS_JSON,
#   SEA_PROPOSALS_SAVE_DIR, SEA_EXPIRE_DAYS, SEA_VERBOSE, AGENTS_MD,
#   EVOLVING_GITHUB_REPO
# External endpoints called: GitHub API (gh CLI, only with --create-issue flag)
# Local files read:
#   <SEA_ANALYSIS_JSON>  (default: /tmp/self-evolving-analysis.json)
#   ~/openclaw/AGENTS.md
# Local files written:
#   <SKILL_DIR>/data/proposals/proposal_<timestamp>.json
#   <SKILL_DIR>/data/proposals/archive/  (expired proposals moved here)
#   /tmp/sea-gen-$$/, /tmp/sea-proposals-$$.json,
#   /tmp/sea-meta-$$.json, /tmp/sea-rpt-$$.py  (temp, auto-deleted)
# Network: GitHub API only when --create-issue flag is set

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$SCRIPT_DIR/lib/config-loader.sh" ]; then
  source "$SCRIPT_DIR/lib/config-loader.sh"
  sea_load_config 2>/dev/null || true
fi

ANALYSIS_DAYS="${SEA_DAYS:-${ANALYSIS_DAYS:-7}}"
ANALYSIS_JSON="${SEA_ANALYSIS_JSON:-/tmp/self-evolving-analysis.json}"
PROPOSAL_DIR="$SKILL_DIR/${SEA_PROPOSALS_SAVE_DIR:-data/proposals}"
REJECTION_LOG="$SKILL_DIR/data/rejected-proposals.json"
EXPIRE_DAYS="${SEA_EXPIRE_DAYS:-30}"
VERBOSE="${SEA_VERBOSE:-true}"
AGENTS_MD="${AGENTS_MD:-$HOME/openclaw/AGENTS.md}"

# --dry-run flag: analyze and print proposals, but do not save files or send notifications
# --create-issue / -i flag: post weekly proposal report as a GitHub Issue
DRY_RUN=false
CREATE_ISSUE=false
for arg in "$@"; do
  case "$arg" in
    --dry-run|-n) DRY_RUN=true ;;
    --create-issue|-i) CREATE_ISSUE=true ;;
  esac
done
[ "$DRY_RUN" = "true" ] && log "\ud83d\udd0d DRY RUN mode \u2014 no files will be modified, no notifications sent"
[ "$CREATE_ISSUE" = "true" ] && log "\ud83d\udc19 GitHub Issue \ubaa8\ub4dc \ud65c\uc131 \u2014 \uc81c\uc548\uc774 GitHub Issue\ub85c \ub4f1\ub85d\ub429\ub2c8\ub2e4"

mkdir -p "$PROPOSAL_DIR"
mkdir -p "$SKILL_DIR/data"

log() {
  [ "$VERBOSE" = "true" ] && echo "[$(date '+%H:%M:%S')] $*" >&2 || true
}

# ── Step 1: 행동 분석 실행 ────────────────────────────────────
run_analysis() {
  log "행동 분석 실행 중..."
  if ! bash "$SCRIPT_DIR/analyze-behavior.sh" "$ANALYSIS_JSON" >/dev/null 2>&1; then
    log "분석 실패, 기본 JSON 생성"
    python3 -c "
import json, datetime
fallback = {
  'meta': {'analysis_date': datetime.datetime.now().strftime('%Y-%m-%d'),
            'analysis_timestamp': datetime.datetime.now().isoformat(),
            'analysis_days': int('$ANALYSIS_DAYS'),
            'session_count': 0, 'version': '3.1.0'},
  'complaints': {'session_count': 0, 'total_complaint_hits': 0, 'patterns': []},
  'errors': {'cron_errors': [], 'log_errors': []},
  'violations': {'violations': []},
  'repeat_requests': [],
  'learnings': {'total_pending': 0, 'total_high_priority': 0, 'top_errors': [], 'top_learnings': [], 'feature_requests': []},
  'memory_md': {'exists': False, 'issue_count': 0},
  'retry_analysis': {'high_retry_tools': [], 'total_retry_events': 0, 'worst_streaks': []},
  'session_health': {'total_sessions': 0, 'heavy_sessions': 0, 'avg_compaction_per_session': 0},
  'previously_rejected': []
}
with open('$ANALYSIS_JSON', 'w') as f:
    json.dump(fallback, f, ensure_ascii=False, indent=2)
" 2>/dev/null || echo '{}' > "$ANALYSIS_JSON"
  fi
}

# ── Step 2: AGENTS.md 현재 상태 읽기 ──────────────────────
get_agents_md_section() {
  local section="$1"
  python3 -c "
import re
try:
    with open('$AGENTS_MD', encoding='utf-8') as f:
        content = f.read()
    # 섹션 추출
    pattern = rf'(## {re.escape(\"$section\")}.*?)(?=\n## |\Z)'
    m = re.search(pattern, content, re.DOTALL)
    if m:
        text = m.group(1)[:300]
        print(text.strip())
    else:
        print('(섹션 없음)')
except Exception as e:
    print(f'(읽기 실패: {e})')
" 2>/dev/null || echo "(읽기 실패)"
}

# ── Step 3: 개선안 생성 ──────────────────────────────────
generate_proposals() {
  log "개선안 생성 중..."

  # 분석 데이터와 AGENTS.md를 파일로 전달
  local tmp_dir="/tmp/sea-gen-$$"
  mkdir -p "$tmp_dir"
  cp "$ANALYSIS_JSON" "$tmp_dir/analysis.json" 2>/dev/null || echo '{}' > "$tmp_dir/analysis.json"

  # AGENTS.md 일부 추출
  python3 -c "
import json
try:
    with open('$AGENTS_MD', encoding='utf-8') as f:
        content = f.read()
    # 주요 섹션 목록 추출
    import re
    sections = re.findall(r'^## (.+)$', content, re.MULTILINE)
    print(json.dumps({'content_len': len(content), 'sections': sections[:20]}))
except Exception:
    print(json.dumps({'content_len': 0, 'sections': []}))
" 2>/dev/null > "$tmp_dir/agents_md_meta.json" || echo '{}' > "$tmp_dir/agents_md_meta.json"

  cat > "$tmp_dir/gen.py" << 'GEN_PY_EOF'
import json, re, os, sys
from datetime import datetime

analysis_json_path = sys.argv[1]
tmp_dir = sys.argv[2]
analysis_days = int(sys.argv[3])

try:
    with open(analysis_json_path, encoding='utf-8') as f:
        data = json.load(f)
except Exception:
    data = {}

proposals = []

# ── 제안 소스 1: 도구 연속 재시도 패턴 (v3.0 핵심 신호) ──
retry = data.get('retry_analysis', {})
high_retry = retry.get('high_retry_tools', [])
total_retry_events = retry.get('total_retry_events', 0)
worst_streaks = retry.get('worst_streaks', [])

if total_retry_events >= 5:
    top_tool = high_retry[0] if high_retry else {}
    tool_name = top_tool.get('tool', '')
    sessions_count = top_tool.get('sessions_with_streak', 0)
    tool_worst = [s for s in worst_streaks if s.get('tool') == tool_name]
    worst = tool_worst[0] if tool_worst else {}
    worst_streak_val = worst.get('streak', 0)

    tool_fixes = {
        'exec': (
            '## ⚡ exec 연속 재시도 방지\n'
            '같은 exec를 3회 이상 재시도하기 전에:\n'
            '1. 첫 번째 실패 시 에러 메시지를 사용자에게 보고\n'
            '2. 두 번째 시도는 방법을 변경해서 (다른 옵션/경로)\n'
            '3. 세 번째 실패 시 중단하고 수동 확인 요청\n'
            '이 패턴을 AGENTS.md "Exec 에러 노출 금지 규칙"에 추가'
        ),
        'process': (
            '## 🔄 process 폴링 최적화\n'
            'process(action=poll) 반복 대신:\n'
            '`exec`에 `yieldMs=30000` (30초 대기) 활용\n'
            '또는 `background=true` + 나중에 1회 poll로 대체'
        ),
        'browser': (
            '## 🌐 browser 재시도 최적화\n'
            'browser 연속 재시도 시 snapshot → act 패턴 확인:\n'
            '1. snapshot으로 현재 상태 확인 후 act\n'
            '2. 같은 selector 2회 실패 시 다른 방법 시도\n'
            '3. aria-ref (refs="aria") 사용으로 안정성 향상'
        ),
        'cron': (
            '## ⏰ cron 설정 재시도 방지\n'
            'cron 작업 실패 시 즉시 재시도 대신:\n'
            '1. 기존 크론 schedule 확인 (cron list)\n'
            '2. 충돌 크론 삭제 후 재등록\n'
            '3. 동일 이름 크론 2개 생성 금지'
        ),
    }
    fix_text = tool_fixes.get(tool_name, f'`{tool_name}` 도구 연속 재시도 원인 파악 필요')

    streak_note = f'최대 연속 호출: {worst_streak_val}회 (같은 도구 중단 없이 연속)' if worst_streak_val else ''
    proposals.append({
        'id': f'retry-{tool_name}-01',
        'source': 'retry_analysis',
        'title': f'`{tool_name}` 도구 연속 재시도 패턴 개선 ({sessions_count}개 세션 영향)',
        'severity': 'high' if total_retry_events >= 20 else 'medium',
        'evidence': (
            f'최근 {analysis_days}일간 `{tool_name}` 도구를 5회 이상 연속 호출한 세션: {sessions_count}개\n'
            + (f'{streak_note}\n' if streak_note else '') +
            f'쓸 재시도 이벤트: {total_retry_events}건\n'
            f'→ 5회 이상 동일 도구 연속 호출 = 실패 후 재시도 루프 가능성\n'
            f'→ read/write/edit/image 등 파일 I/O는 제외하고 집계한 수치'
        ),
        'before': f'연속 `{tool_name}` 재시도 시 규칙 없음 (무한 루프 가능)',
        'after': fix_text,
        'section': 'Exec 에러 노출 금지 규칙',
        'diff_type': 'agents_md_addition'
    })

# ── 제안 소스 2: 반복 에러 ──
errors = data.get('errors', {})
log_errors = errors.get('log_errors', [])

for log_err in log_errors:
    repeating = log_err.get('repeating_errors', [])
    high_repeat = [r for r in repeating if r.get('occurrences', 0) >= 5]
    if high_repeat:
        fname = log_err.get('file', '')
        worst_repeat = high_repeat[0]
        sig = worst_repeat.get('signature', '')[:60]
        occ = worst_repeat.get('occurrences', 0)

        proposals.append({
            'id': f'repeat-error-{fname.replace(".", "-")}',
            'source': 'repeating_log_errors',
            'title': f'[{fname}] 같은 에러 {occ}회 반복 → 미수정 버그 의심',
            'severity': 'high',
            'evidence': (
                f'`{fname}`에서 동일 에러 패턴이 {occ}회 반복:\n'
                f'에러 유형: `{sig}`\n'
                f'→ 한 번만 발생하면 일시적 오류, {occ}회 반복이면 구조적 버그\n'
                f'→ 지금 고치지 않으면 계속 누적됨'
            ),
            'before': f'`{fname}` 에러 발생 시 별도 조치 없음',
            'after': (
                f'## \ud83d\udd34 반복 에러 즉시 대응 프로토콜\n'
                f'동일 에러 5회 이상 반복 시:\n'
                f'1. 해당 크론/스크립트 실행 중단\n'
                f'2. 에러 원인 파악 후 수정\n'
                f'3. 수정 전까지 크론 비활성화\n'
                f'확인: `tail -50 ~/.openclaw/logs/{fname}`'
            ),
            'section': '크론/자동화 규칙',
            'diff_type': 'agents_md_addition'
        })
        break

# ── 제안 소스 3: 크론 에러 ──
cron_errors = errors.get('cron_errors', [])
persistent_errors = [e for e in cron_errors if e.get('consecutive_errors', 0) >= 2]
if persistent_errors:
    names = [e.get('name', '') for e in persistent_errors]
    name_list = ', '.join(f'`{n}`' for n in names[:3])
    proposals.append({
        'id': 'cron-persistent-error-01',
        'source': 'cron_errors',
        'title': f'연속 실패 크론 즉시 점검 필요: {name_list}',
        'severity': 'high',
        'evidence': (
            f'consecutiveErrors >= 2인 크론: {name_list}\n'
            f'→ 이건 단발 실패가 아닌 지속적 문제\n'
            f'→ 방치하면 크론 자동 비활성화될 수 있음'
        ),
        'before': '연속 실패 크론에 대한 자동 보고 규칙 없음',
        'after': (
            '## \ud83d\udd34 크론 연속 실패 대응\n'
            '다음 크론 즉시 점검 필요:\n' +
            '\n'.join(f'- `{e["name"]}`: {e["consecutive_errors"]}회 연속 실패' for e in persistent_errors[:3]) +
            '\n\n점검 방법:\n'
            '```bash\n'
            '# 에러 내용 확인\n'
            'cat ~/.openclaw/logs/<크론명>.log | tail -20\n'
            '# 재실행 테스트\n'
            'bash <크론 스크립트> 2>&1\n'
            '```'
        ),
        'section': '크론/자동화 규칙',
        'diff_type': 'action_required'
    })

# ── 제안 소스 4: AGENTS.md 위반 ──
violations_data = data.get('violations', {})
violations = violations_data.get('violations', []) if isinstance(violations_data, dict) else []
high_violations = [v for v in violations if v.get('severity') in ('high', 'medium')]

for v in high_violations[:2]:
    safe_id = re.sub(r'[^a-z0-9-]', '-', v.get('rule', 'unknown').lower())[:30]
    fix = v.get('fix', '')
    examples = v.get('examples', [])
    example_text = '\n'.join(f'  - `{e}`' for e in examples[:2]) if examples else '  (예시 없음)'

    proposals.append({
        'id': f'violation-{safe_id}',
        'source': 'agents_md_violation',
        'title': f'exec 명령에서 규칙 위반 감지: {v.get("rule", "")}',
        'severity': v.get('severity', 'medium'),
        'evidence': (
            f'최근 {analysis_days}일간 exec 명령에서 {v.get("hit_count")}회 위반:\n'
            f'{example_text}\n'
            f'→ 대화에서 "언급"이 아닌 실제 실행된 명령어 기준 (오탐 없음)'
        ),
        'before': v.get('rule', ''),
        'after': (
            f'## \u2705 올바른 방법\n'
            f'```bash\n'
            f'{fix}\n'
            f'```\n'
            f'AGENTS.md "Exec 에러 노출 금지 규칙" 섹션 필수 패턴 표 참조'
        ),
        'section': 'Exec 에러 노출 금지 규칙',
        'diff_type': 'agents_md_update'
    })

# ── 제안 소스 5: 세션 건강도 ──
session_health = data.get('session_health', {})
heavy_sessions = session_health.get('heavy_sessions', 0)
max_comp = session_health.get('max_compaction', 0)

if heavy_sessions >= 3 or max_comp >= 20:
    proposals.append({
        'id': 'session-health-01',
        'source': 'session_health',
        'title': f'과도하게 긴 세션 감지 ({heavy_sessions}개 세션, 최대 콤팩션 {max_comp}회)',
        'severity': 'low',
        'evidence': (
            f'콤팩션 5회 이상 발생한 세션: {heavy_sessions}개\n'
            f'최대 콤팩션 횟수: {max_comp}회 (1세션에서)\n'
            f'→ 콤팩션 = 컨텍스트 손실 위험 + 토큰 낙비\n'
            f'→ 복잡한 작업은 서브에이전트로 분리가 효과적'
        ),
        'before': '장시간 세션에 대한 분리 가이드 없음',
        'after': (
            '## \ud83d\udce6 서브에이전트 분리 기준\n'
            '다음 조건 중 하나라도 해당하면 서브에이전트 사용:\n'
            '- 예상 작업 시간 > 10분\n'
            '- 도구 호출 예상 > 20회\n'
            '- 메인 체널 컨텍스트 오염 우려\n'
            '→ `subagents` 도구로 spawn, 결과는 push-based 자동 보고'
        ),
        'section': '복잡한 배경 작업',
        'diff_type': 'agents_md_update'
    })

# ── 제안 소스 6: .learnings/ 미해결 고우선순위 ──
learnings = data.get('learnings', {})
high_priority = learnings.get('total_high_priority', 0)
if high_priority > 0:
    top_errors = learnings.get('top_errors', [])
    summaries = [e.get('summary', '')[:50] for e in top_errors[:2] if e.get('summary')]
    proposals.append({
        'id': 'learnings-high-priority-01',
        'source': 'learnings_integration',
        'title': f'.learnings/ 고우선순위 미해결 이슈 {high_priority}건',
        'severity': 'medium',
        'evidence': (
            f'self-improving-agent 기록 중 미해결 high/critical 이슈 {high_priority}건\n'
            f'예시: {"; ".join(summaries) if summaries else "자세한 내용은 .learnings/ 참조"}'
        ),
        'before': '미해결 .learnings/ 이슈가 AGENTS.md에 미반영',
        'after': (
            '## \ud83d\udcda .learnings/ 승격 프로토콜\n'
            '매주 일요일 heartbeat에서:\n'
            '```bash\n'
            'grep -r "Priority**: high" ~/openclaw/.learnings/ | head -10\n'
            '```\n'
            '→ high/critical 항목을 AGENTS.md 또는 SOUL.md로 즉시 승격'
        ),
        'section': 'Memory',
        'diff_type': 'agents_md_addition'
    })

# ── 실제 불만 패턴 ──
complaints = data.get('complaints', {})
total_hits = complaints.get('total_complaint_hits', 0)
if total_hits >= 3:
    patterns = complaints.get('patterns', [])
    examples = []
    for p in patterns[:3]:
        for ex in p.get('examples', [])[:1]:
            examples.append(f'"{ex[:40]}"')
    proposals.append({
        'id': 'real-complaint-01',
        'source': 'complaint_patterns',
        'title': f'실제 사용자 불만 표현 {total_hits}건 감지',
        'severity': 'high' if total_hits >= 5 else 'medium',
        'evidence': (
            f'최근 {analysis_days}일간 명확한 불만 표현 {total_hits}건\n'
            f'예시:\n' + '\n'.join(f'  - {e}' for e in examples[:3]) +
            '\n→ 단순 요청 표현("확인해줘")은 제외, 실제 재촉/반복 불만만 집계'
        ),
        'before': '반복 불만 발생 시 즉각 대응 규칙 없음',
        'after': (
            '## \ud83d\udd01 불만 감지 즉시 대응\n'
            '사용자가 반복/재촉 표현 사용 시:\n'
            '1. 현재 진행 상황 즉시 보고\n'
            '2. SESSION-STATE.md에 "왕 반복 딌는가" 기록\n'
            '3. 근본 원인 1문장으로 명시 후 해결 방법 제안\n'
            '4. 다음 분석에서 패턴 추적'
        ),
        'section': 'During Conversation',
        'diff_type': 'agents_md_addition'
    })

# ── 거부 기록 필터링 ──
previously_rejected = data.get('previously_rejected', [])
rejected_ids = set()
if isinstance(previously_rejected, list):
    for item in previously_rejected:
        if isinstance(item, dict):
            rejected_ids.add(item.get('id', ''))
        elif isinstance(item, str):
            rejected_ids.add(item)

proposals = [p for p in proposals if p.get('id') not in rejected_ids]

# 심각도 기준 정렬 (high → medium → low)
severity_order = {'high': 0, 'medium': 1, 'low': 2}
proposals.sort(key=lambda p: severity_order.get(p.get('severity', 'low'), 3))

if not proposals:
    proposals.append({
        'id': 'no-issues-found',
        'source': 'system',
        'title': '이번 주 발견된 개선 필요 사항 없음',
        'severity': 'info',
        'evidence': f'최근 {analysis_days}일 분석 결과 주요 패턴 없음',
        'before': 'N/A',
        'after': 'N/A',
        'section': 'N/A',
        'diff_type': 'none'
    })

print(json.dumps(proposals, ensure_ascii=False))
GEN_PY_EOF

  local result
  result="$(ANALYSIS_JSON_PATH="$ANALYSIS_JSON" python3 "$tmp_dir/gen.py" \
    "$ANALYSIS_JSON" "$tmp_dir" "$ANALYSIS_DAYS" 2>/dev/null || echo '[]')"

  rm -rf "$tmp_dir"
  echo "$result"
}

# ── Step 4: 날짜 계산 ─────────────────────────────────
get_date_range() {
  python3 -c "
from datetime import datetime, timedelta
days = int('$ANALYSIS_DAYS')
today = datetime.now()
from_date = today - timedelta(days=days)
print(from_date.strftime('%Y-%m-%d'), today.strftime('%Y-%m-%d'))
" 2>/dev/null || echo "N/A $(date '+%Y-%m-%d')"
}

# ── Step 5: 리포트 생성 ───────────────────────────────
build_report() {
  local proposals_json="$1"

  local date_info date_from date_to
  date_info="$(get_date_range)"
  date_from="${date_info%% *}"
  date_to="${date_info##* }"

  local tmp_proposals="/tmp/sea-proposals-$$.json"
  local tmp_meta="/tmp/sea-meta-$$.json"
  echo "$proposals_json" > "$tmp_proposals"

  python3 -c "
import json, sys
try:
    with open('$ANALYSIS_JSON', encoding='utf-8') as f:
        d = json.load(f)
    meta = {
        'session_count': d.get('session_health', {}).get('total_sessions', 0),
        'total_hits': d.get('complaints', {}).get('total_complaint_hits', 0),
        'retry_events': d.get('retry_analysis', {}).get('total_retry_events', 0),
        'heavy_sessions': d.get('session_health', {}).get('heavy_sessions', 0),
        'date_from': '$date_from',
        'date_to': '$date_to'
    }
except Exception:
    meta = {'session_count': 0, 'total_hits': 0, 'retry_events': 0, 'heavy_sessions': 0,
            'date_from': '$date_from', 'date_to': '$date_to'}
print(json.dumps(meta))
" 2>/dev/null > "$tmp_meta" || echo '{"session_count":0,"total_hits":0,"retry_events":0,"heavy_sessions":0,"date_from":"N/A","date_to":"N/A"}' > "$tmp_meta"

  local tmp_rpt="/tmp/sea-rpt-$$.py"
  cat > "$tmp_rpt" << 'REPORT_PY_EOF'
import json, sys

proposals_path = sys.argv[1]
meta_path = sys.argv[2]

with open(proposals_path, encoding='utf-8') as f:
    proposals = json.load(f)
with open(meta_path, encoding='utf-8') as f:
    meta = json.load(f)

date_from = meta.get('date_from', 'N/A')
date_to = meta.get('date_to', 'N/A')
session_count = meta.get('session_count', 0)
total_hits = meta.get('total_hits', 0)
retry_events = meta.get('retry_events', 0)
heavy_sessions = meta.get('heavy_sessions', 0)

real_proposals = [p for p in proposals if p.get('id') != 'no-issues-found']
proposal_count = len(real_proposals)

source_emoji = {
    'retry_analysis': '\ud83d\udd01',
    'repeating_log_errors': '\ud83d\udc1b',
    'cron_errors': '\ud83d\udd34',
    'agents_md_violation': '\u26a0\ufe0f',
    'learnings_integration': '\ud83d\udcda',
    'complaint_patterns': '\ud83d\udcac',
    'session_health': '\ud83d\udce6',
    'system': '\u2139\ufe0f'
}

diff_type_label = {
    'agents_md_addition': '\ud83d\udcdd AGENTS.md \ucd94\uac00',
    'agents_md_update': '\u270f\ufe0f AGENTS.md \uc218\uc815',
    'action_required': '\ud83d\udea8 \uc989\uc2dc \uc870\uce58 \ud544\uc694',
    'none': ''
}

lines = []
lines.append("## \ud83e\uddac Self-Evolving Agent \uc8fc\uac04 \ubd84\uc11d \ub9ac\ud3ec\ud2b8 v3.1")
lines.append("")
lines.append(f"**\ubd84\uc11d \uae30\uac04:** {date_from} ~ {date_to}")
lines.append(f"**\ubd84\uc11d\ub41c \uc138\uc158:** {session_count}\uac1c")

if retry_events > 0:
    lines.append(f"**\ub3c4\uad6c \uc7ac\uc2dc\ub3c4 \uc774\ubca4\ud2b8:** {retry_events}\uac74 \u2190 \uc0c8\ub85c \uac10\uc9c0")
if total_hits > 0:
    lines.append(f"**\uc2e4\uc81c \ubd88\ub9cc \ud45c\ud604:** {total_hits}\uac74 (\uc77c\ubc18 \uc694\uccad \ud45c\ud604 \uc81c\uc678)")
if heavy_sessions > 0:
    lines.append(f"**\uacfc\ub3c4\ud55c \uc138\uc158:** {heavy_sessions}\uac1c (\ucf64\ud329\uc158 5\ud68c \uc774\uc0c1)")

lines.append(f"**\uac1c\uc120 \uc81c\uc548:** {proposal_count}\uac1c")
lines.append("")

if proposal_count == 0:
    lines.append("\u2705 **\uc774\ubc88 \uc8fc \ubc1c\uacac\ub41c \uac1c\uc120 \uc0ac\ud56d \uc5c6\uc74c**")
    lines.append("\ub2e4\uc74c \ubd84\uc11d \ub54c \ub2e4\uc2dc \ud655\uc778\ud569\ub2c8\ub2e4.")
else:
    lines.append("---")
    lines.append("")

    for i, p in enumerate(real_proposals, 1):
        sev_emoji = {'high': '\ud83d\udd34', 'medium': '\ud83d\udfe1', 'low': '\ud83d\udfe2'}.get(p.get('severity', 'low'), '\ud83d\udfe2')
        src_emoji = source_emoji.get(p.get('source', ''), '\ud83d\udccc')
        diff_label = diff_type_label.get(p.get('diff_type', ''), '')

        lines.append(f"### {src_emoji} \uc81c\uc548 #{i}: {p.get('title', '')}")
        lines.append("")
        lines.append(f"**\uc2ec\uac01\ub3c4:** {sev_emoji} {p.get('severity', '').upper()}  |  **\uc720\ud615:** {diff_label}")
        lines.append("")
        evidence = p.get('evidence', '')
        lines.append("> **\uadfc\uac70:**")
        for ev_line in evidence.split('\n'):
            lines.append(f"> {ev_line}" if ev_line else ">")
        lines.append("")
        lines.append("**Before (\ud604\uc7ac):**")
        lines.append("```")
        lines.append(p.get('before', ''))
        lines.append("```")
        lines.append("")
        lines.append("**After (\uc81c\uc548):**")
        lines.append("```")
        lines.append(p.get('after', ''))
        lines.append("```")
        lines.append("")
        if i < len(real_proposals):
            lines.append("---")
            lines.append("")

    lines.append("---")
    lines.append("")
    lines.append("### \u2705 \uc2b9\uc778 \ubc29\ubc95")
    lines.append("")
    lines.append("\uc774\ubaa8\uc9c0 \ubc18\uc751\uc73c\ub85c \ube60\ub974\uac8c \uc2b9\uc778/\uac70\ubd80:")
    lines.append("")
    lines.append("| \ubc18\uc751 | \uc758\ubbf8 |")
    lines.append("|------|------|")  
    lines.append("| \u2705 | \uc804\uccb4 \uc2b9\uc778 \u2192 AGENTS.md \uc790\ub3d9 \ubc18\uc601 + git commit |")
    lines.append("| 1\ufe0f\u20e3 ~ 5\ufe0f\u20e3 | \ud574\ub2f9 \ubc88\ud638 \uc81c\uc548\ub9cc \uc2b9\uc778 |")
    lines.append("| \u274c | \uc804\uccb4 \uac70\ubd80 (\ub313\uae00\ub85c \uc774\uc720 \ub0a8\uae30\uba74 \ub2e4\uc74c \ubd84\uc11d\uc5d0 \ubc18\uc601) |")
    lines.append("| \ud83d\udd04 | \uc218\uc815 \uc694\uccad (\ub313\uae00\ub85c \uc6d0\ud558\ub294 \ub0b4\uc6a9 \uba85\uc2dc) |")
    lines.append("")
    lines.append("> \uac70\ubd80 \uc774\uc720\ub294 \ub2e4\uc74c \ubd84\uc11d\uc5d0 \ubc18\uc601\ub429\ub2c8\ub2e4. \ud53c\ub4dc\ubc31\uc774 \uc788\uc73c\uba74 \uaf00 \ub0a8\uaca8\uc8fc\uc138\uc694.")

print('\n'.join(lines))
REPORT_PY_EOF

  python3 "$tmp_rpt" "$tmp_proposals" "$tmp_meta" 2>/dev/null || echo "(\ub9ac\ud3ec\ud2b8 \uc0dd\uc131 \uc2e4\ud328)"
  rm -f "$tmp_proposals" "$tmp_meta" "$tmp_rpt"
}

# ── Step 6: 제안 파일 저장 ────────────────────────────
save_proposal() {
  local proposals_json="$1"
  local ts
  ts="$(date '+%Y%m%d_%H%M%S')"
  local proposal_file="$PROPOSAL_DIR/proposal_${ts}.json"
  local tmp_file="/tmp/sea-save-$$.json"
  echo "$proposals_json" > "$tmp_file"

  python3 -c "
import json, os
from datetime import datetime

with open('$tmp_file', encoding='utf-8') as f:
    proposals = json.load(f)

with open('$ANALYSIS_JSON', encoding='utf-8') as f:
    analysis = json.load(f)

output = {
    'created_at': datetime.now().isoformat(),
    'status': 'awaiting_approval',
    'analysis_days': int('$ANALYSIS_DAYS'),
    'proposals': proposals,
    'analysis_summary': {
        'session_count': analysis.get('session_health', {}).get('total_sessions', 0),
        'total_complaint_hits': analysis.get('complaints', {}).get('total_complaint_hits', 0),
        'retry_events': analysis.get('retry_analysis', {}).get('total_retry_events', 0),
        'heavy_sessions': analysis.get('session_health', {}).get('heavy_sessions', 0)
    }
}

with open('$proposal_file', 'w', encoding='utf-8') as f:
    json.dump(output, f, ensure_ascii=False, indent=2)

print('$proposal_file')
" 2>/dev/null || true

  rm -f "$tmp_file"
}

# ── Step 7: 만료 제안 아카이브 ───────────────────────
archive_expired_proposals() {
  local archive_dir="$PROPOSAL_DIR/archive"
  mkdir -p "$archive_dir"
  python3 -c "
import os, json, shutil
from datetime import datetime, timedelta
proposal_dir = '$PROPOSAL_DIR'
archive_dir = '$archive_dir'
expire_days = int('$EXPIRE_DAYS')
cutoff = datetime.now() - timedelta(days=expire_days)
moved = 0
for fname in os.listdir(proposal_dir):
    if not fname.endswith('.json') or fname.startswith('.'): continue
    fpath = os.path.join(proposal_dir, fname)
    if not os.path.isfile(fpath): continue
    try:
        mtime = datetime.fromtimestamp(os.path.getmtime(fpath))
        if mtime < cutoff:
            shutil.move(fpath, os.path.join(archive_dir, fname))
            moved += 1
    except: pass
if moved > 0: print(f'{moved}\uac1c \ub9cc\ub8cc \uc81c\uc548 \uc544\uce74\uc774\ube0c \uc644\ub8cc')
" 2>/dev/null || true
}

# ── Step 8: GitHub Issue 생성 (--create-issue 플래그) ────────────
create_github_issue() {
  local report="$1"

  # GitHub 레포 결정: EVOLVING_GITHUB_REPO 환경변수 또는 git remote
  local github_repo="${EVOLVING_GITHUB_REPO:-}"
  if [ -z "$github_repo" ]; then
    github_repo=$(git -C "$SKILL_DIR" remote get-url origin 2>/dev/null \
      | sed 's|.*github\.com[:/]\(.*\)\.git$|\1|;s|.*github\.com[:/]\(.*\)$|\1|' || echo "")
  fi

  if [ -z "$github_repo" ]; then
    log "⚠\ufe0f  EVOLVING_GITHUB_REPO not set and git remote not detected \u2014 skipping issue creation"
    log "   Set EVOLVING_GITHUB_REPO=owner/repo in your environment to enable this feature"
    return 0
  fi

  if ! command -v gh &>/dev/null; then
    log "⚠\ufe0f  gh CLI not found \u2014 skipping issue creation"
    log "   Install: https://cli.github.com"
    return 0
  fi

  # gh 인증 확인
  if ! gh auth status &>/dev/null; then
    log "⚠\ufe0f  gh CLI not authenticated \u2014 skipping issue creation"
    log "   Run: gh auth login"
    return 0
  fi

  local ts
  ts=$(date '+%Y-%m-%d')
  local title="\ud83e\uddac Self-Evolving Weekly Proposal \u2014 ${ts}"

  log "GitHub Issue \uc0dd\uc131 \uc911 (${github_repo})..."

  # \ub808\uc774\ube14 \uc0ac\uc804 \uc0dd\uc131 (\uc774\ubbf8 \uc874\uc7ac\ud574\ub3c4 \uc5d0\ub7ec \ubb34\uc2dc)
  gh label create "self-evolving" --color "0052cc" --description "Auto-generated by openclaw-self-evolving" \
    --repo "$github_repo" 2>/dev/null || true
  gh label create "automated"    --color "e4e669" --description "Automated issue" \
    --repo "$github_repo" 2>/dev/null || true

  local issue_url
  issue_url=$(gh issue create \
    --repo "$github_repo" \
    --title "$title" \
    --label "self-evolving,automated" \
    --body "$report" 2>/dev/null || echo "")

  if [ -n "$issue_url" ]; then
    log "\u2705 Issue \uc0dd\uc131 \uc644\ub8cc: $issue_url"
    echo "$issue_url"
  else
    log "⚠\ufe0f  Issue \uc0dd\uc131 \uc2e4\ud328 (gh auth status \ud655\uc778 \ud544\uc694)"
  fi
}

# ── \uba54\uc778 ──────────────────────────────────────────────────────
log "=== generate-proposal.sh v3.1 \uc2dc\uc791 ==="

main() {
  log "=== generate-proposal.sh v3.1 \uc2dc\uc791 ==="

  run_analysis

  local proposals_json
  proposals_json="$(generate_proposals 2>/dev/null || echo '[]')"

  if [ -z "$proposals_json" ] || [ "$proposals_json" = "[]" ] || [ "$proposals_json" = "null" ]; then
    proposals_json='[{"id":"no-issues-found","source":"system","title":"\uc774\ubc88 \uc8fc \ubc1c\uacac\ub41c \uac1c\uc120 \ud544\uc694 \uc0ac\ud56d \uc5c6\uc74c","severity":"info","evidence":"\ubd84\uc11d \uacb0\uacfc \uc8fc\uc694 \ud328\ud134 \uc5c6\uc74c","before":"N/A","after":"N/A","section":"N/A","diff_type":"none"}]'
  fi

  if [ "$DRY_RUN" = "true" ]; then
    log "\ud83d\udd0d [DRY RUN] Proposals (not saved, not sent):"
    echo "$proposals_json" | python3 -c "
import sys, json
proposals = json.load(sys.stdin)
for i, p in enumerate(proposals, 1):
    print(f'  [{i}] [{p.get(\"severity\",\"?\").upper()}] {p.get(\"title\",\"\")}')
    print(f'       Evidence: {p.get(\"evidence\",\"\")[:120]}')
    print()
" 2>/dev/null || echo "$proposals_json"
    log "=== generate-proposal.sh v3.1 \uc644\ub8cc (dry run) ==="
    return 0
  fi

  local saved_file
  saved_file="$(save_proposal "$proposals_json" 2>/dev/null || echo "")"
  [ -n "$saved_file" ] && log "\uc81c\uc548 \uc800\uc7a5: $saved_file"

  archive_expired_proposals 2>/dev/null || true

  # \ub9ac\ud3ec\ud2b8 \uc0dd\uc131 \ud6c4 \ud45c\uc900\ucd9c\ub825 + GitHub Issue \uc120\ud0dd\uc801 \ub4f1\ub85d
  local report
  report="$(build_report "$proposals_json")"
  echo "$report"

  if [ "$CREATE_ISSUE" = "true" ]; then
    create_github_issue "$report"
  fi

  log "=== generate-proposal.sh v3.1 \uc644\ub8cc ==="
}

main "$@"
