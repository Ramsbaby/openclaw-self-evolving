#!/usr/bin/env bash
# ============================================================
# session-logger.sh — Structured JSONL event logger
# OpenClaw Self-Evolving Agent
#
# Records per-session metrics in JSONL format for precise
# daily analysis by analyze-behavior.sh.
#
# Usage (sourced library):
#   source session-logger.sh
#   log_event "session_start" '{"model":"claude-opus-4","task":"deploy","agent_name":"infra"}'
#   log_event "tool_call"     '{"tool_name":"exec","count":3}'
#   log_event "session_end"   '{"exit_code":0,"duration_sec":42,"tokens_in":1200,"tokens_out":800,"cost_usd":0.0031}'
#   log_event "error"         '{"type":"timeout","message":"exec timed out","recoverable":true}'
#   log_event "recovery"      '{"trigger":"timeout","method":"retry","success":true}'
#
# Usage (standalone CLI):
#   session-logger.sh log session_start '{"model":"claude-opus-4","task":"deploy","agent_name":"infra"}'
#
# Event types:
#   session_start  — {model, task, agent_name}
#   session_end    — {exit_code, duration_sec, tokens_in, tokens_out, cost_usd}
#   tool_call      — {tool_name, count}  (aggregated per session)
#   error          — {type, message, recoverable}
#   recovery       — {trigger, method, success}
#
# Output file: $OPENCLAW_LOGS_DIR/sessions.jsonl
#   (default: ~/.openclaw/logs/sessions.jsonl)
#
# 변경 이력:
#   v1.0 (2026-03-11) — 초기 버전. analyze-behavior.sh JSONL 연동.
# ============================================================

# SECURITY MANIFEST:
# Environment variables accessed: OPENCLAW_LOGS_DIR, OPENCLAW_SESSION_ID
# External endpoints called: None
# Local files written:
#   $OPENCLAW_LOGS_DIR/sessions.jsonl  (append-only)

set -euo pipefail

LOGS_DIR="${OPENCLAW_LOGS_DIR:-$HOME/.openclaw/logs}"
SESSIONS_JSONL="$LOGS_DIR/sessions.jsonl"

mkdir -p "$LOGS_DIR"

# ── Core logging function ────────────────────────────────────
# log_event <event_type> [data_json]
# Appends one JSONL line: {"ts":"...","event":"...","session_id":"...","data":{...}}
log_event() {
    local event_type="$1"
    local data_json="${2:-{}}"
    local ts
    local session_id

    ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    session_id="${OPENCLAW_SESSION_ID:-}"

    # Validate data_json is valid JSON (non-empty check only; full parse via python if available)
    if [[ -z "$data_json" ]]; then
        data_json="{}"
    fi

    printf '{"ts":"%s","event":"%s","session_id":"%s","data":%s}\n' \
        "$ts" \
        "$event_type" \
        "$session_id" \
        "$data_json" \
        >> "$SESSIONS_JSONL"
}

# ── Convenience wrappers ─────────────────────────────────────

# log_session_start <model> <task> <agent_name>
log_session_start() {
    local model="${1:-unknown}"
    local task="${2:-unknown}"
    local agent_name="${3:-unknown}"
    log_event "session_start" \
        "{\"model\":\"$model\",\"task\":\"$task\",\"agent_name\":\"$agent_name\"}"
}

# log_session_end <exit_code> <duration_sec> <tokens_in> <tokens_out> <cost_usd>
log_session_end() {
    local exit_code="${1:-0}"
    local duration_sec="${2:-0}"
    local tokens_in="${3:-0}"
    local tokens_out="${4:-0}"
    local cost_usd="${5:-0}"
    log_event "session_end" \
        "{\"exit_code\":$exit_code,\"duration_sec\":$duration_sec,\"tokens_in\":$tokens_in,\"tokens_out\":$tokens_out,\"cost_usd\":$cost_usd}"
}

# log_tool_call <tool_name> <count>
log_tool_call() {
    local tool_name="${1:-unknown}"
    local count="${2:-1}"
    log_event "tool_call" \
        "{\"tool_name\":\"$tool_name\",\"count\":$count}"
}

# log_error <type> <message> <recoverable:true|false>
log_error() {
    local error_type="${1:-unknown}"
    # Escape double quotes in message for valid JSON
    local message
    message=$(printf '%s' "${2:-}" | sed 's/"/\\"/g')
    local recoverable="${3:-false}"
    log_event "error" \
        "{\"type\":\"$error_type\",\"message\":\"$message\",\"recoverable\":$recoverable}"
}

# log_recovery <trigger> <method> <success:true|false>
log_recovery() {
    local trigger="${1:-unknown}"
    local method="${2:-unknown}"
    local success="${3:-false}"
    log_event "recovery" \
        "{\"trigger\":\"$trigger\",\"method\":\"$method\",\"success\":$success}"
}

# ── Standalone CLI entrypoint ────────────────────────────────
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-}" in
        log)
            # session-logger.sh log <event_type> [json_data]
            if [[ $# -lt 2 ]]; then
                echo "Usage: session-logger.sh log <event_type> [json_data]" >&2
                exit 1
            fi
            log_event "${2}" "${3:-{}}"
            ;;
        *)
            echo "Usage: session-logger.sh log <event_type> [json_data]" >&2
            echo ""                                                          >&2
            echo "Event types: session_start, session_end, tool_call, error, recovery" >&2
            echo ""                                                          >&2
            echo "Examples:" >&2
            echo "  session-logger.sh log session_start '{\"model\":\"claude-opus-4\",\"task\":\"deploy\",\"agent_name\":\"infra\"}'" >&2
            echo "  session-logger.sh log session_end   '{\"exit_code\":0,\"duration_sec\":42,\"tokens_in\":1200,\"tokens_out\":800,\"cost_usd\":0.003}'" >&2
            echo "  session-logger.sh log error         '{\"type\":\"timeout\",\"message\":\"exec timed out\",\"recoverable\":true}'" >&2
            exit 1
            ;;
    esac
fi
