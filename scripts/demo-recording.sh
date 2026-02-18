#!/usr/bin/env bash
# demo-recording.sh — Self-Evolving AI Demo Simulation
# Simulates the full pipeline without affecting real services.

export TERM=${TERM:-xterm-256color}

# ─── Colors ───────────────────────────────────────────────────────────────────
RESET="\033[0m"
BOLD="\033[1m"
DIM="\033[2m"

BLACK="\033[30m"
RED="\033[31m"
GREEN="\033[32m"
YELLOW="\033[33m"
BLUE="\033[34m"
MAGENTA="\033[35m"
CYAN="\033[36m"
WHITE="\033[37m"

BG_BLACK="\033[40m"
BG_BLUE="\033[44m"
BG_MAGENTA="\033[45m"
BG_CYAN="\033[46m"

# ─── Helpers ──────────────────────────────────────────────────────────────────
typewriter() {
  local text="$1"
  local delay="${2:-0.03}"
  local i
  local len=${#text}
  for (( i=0; i<len; i++ )); do
    printf "%s" "${text:$i:1}"
    sleep "$delay"
  done
  printf "\n"
}

spinner() {
  local pid=$1
  local msg="$2"
  local frames=("⠋" "⠙" "⠹" "⠸" "⠼" "⠴" "⠦" "⠧" "⠇" "⠏")
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r  ${CYAN}${frames[$i]}${RESET}  %s" "$msg"
    i=$(( (i+1) % ${#frames[@]} ))
    sleep 0.1
  done
  printf "\r"
}

print_header() {
  echo ""
  echo -e "${BOLD}${BG_BLUE}${WHITE}  ╔══════════════════════════════════════════════════════════════════════╗  ${RESET}"
  echo -e "${BOLD}${BG_BLUE}${WHITE}  ║      🤖  OpenClaw Self-Evolving AI — Live Demo                      ║  ${RESET}"
  echo -e "${BOLD}${BG_BLUE}${WHITE}  ╚══════════════════════════════════════════════════════════════════════╝  ${RESET}"
  echo ""
}

print_phase() {
  local num="$1"
  local title="$2"
  local duration="$3"
  echo ""
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo -e "${BOLD}${YELLOW}  Phase ${num}: ${title}${RESET}${DIM}  (${duration})${RESET}"
  echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
  echo ""
}

# ─── Intro ────────────────────────────────────────────────────────────────────
clear
print_header
sleep 0.6

echo -e "${DIM}  Initializing self-evolving pipeline...${RESET}"
sleep 0.5
echo -e "${DIM}  Loading config.yaml ...${RESET}"
sleep 0.3
echo -e "${DIM}  Connecting to session store ...${RESET}"
sleep 0.4
echo -e "${GREEN}  ✓ Ready.${RESET}"
sleep 0.8

# ─── Phase 1: Log Collection ──────────────────────────────────────────────────
print_phase "1" "Log Collection" "3초"

(sleep 3) &
SPIN_PID=$!
spinner $SPIN_PID "Scanning session store..."
wait $SPIN_PID

typewriter "  📂 Scanning 967 session files..." 0.025
sleep 0.4
typewriter "  📂 Selected 30 most recent sessions (last 7 days)" 0.025
sleep 0.3

# Progress bar
printf "  ${DIM}Collecting logs: [${RESET}"
for i in $(seq 1 30); do
  printf "${GREEN}█${RESET}"
  sleep 0.04
done
printf "${DIM}]${RESET}\n"
sleep 0.3

echo -e "  ${GREEN}✅ Collected 12,847 lines of conversation logs${RESET}"
sleep 0.6

# ─── Phase 2: Pattern Detection ───────────────────────────────────────────────
print_phase "2" "Pattern Detection" "5초"

(sleep 5) &
SPIN_PID=$!
spinner $SPIN_PID "Analyzing patterns..."
wait $SPIN_PID

echo -e "  ${BLUE}🔍 Analyzing patterns...${RESET}"
sleep 0.5

echo -e "  ${YELLOW}⚠️  Found: Tool retry loop (grep 5+ times)${RESET}${DIM} — 8 occurrences${RESET}"
sleep 0.35
echo -e "  ${YELLOW}⚠️  Found: User frustration (\"다시 해봐\")${RESET}${DIM} — 4 occurrences${RESET}"
sleep 0.35
echo -e "  ${YELLOW}⚠️  Found: AGENTS.md violation (git direct call)${RESET}${DIM} — 13 occurrences${RESET}"
sleep 0.35
echo -e "  ${YELLOW}⚠️  Found: Heavy session (>85% context)${RESET}${DIM} — 6 occurrences${RESET}"
sleep 0.5
echo -e "  ${GREEN}✅ 4 patterns detected, 31 total occurrences${RESET}"
sleep 0.6

# ─── Phase 3: Proposal Generation ────────────────────────────────────────────
print_phase "3" "Proposal Generation" "4초"

(sleep 4) &
SPIN_PID=$!
spinner $SPIN_PID "Generating improvement proposals..."
wait $SPIN_PID

echo -e "  ${MAGENTA}📝 Generating improvement proposals...${RESET}"
sleep 0.6
echo ""

# Proposal box
echo -e "  ${BOLD}${WHITE}┌─────────────────────────────────────────────┐${RESET}"
echo -e "  ${BOLD}${WHITE}│${RESET}  ${RED}${BOLD}PROPOSAL #1 [HIGH]${RESET}                         ${BOLD}${WHITE}│${RESET}"
echo -e "  ${BOLD}${WHITE}│${RESET}  ${BOLD}Add retry-limit rule to AGENTS.md${RESET}          ${BOLD}${WHITE}│${RESET}"
echo -e "  ${BOLD}${WHITE}│${RESET}  ${DIM}Evidence: 8 tool retry loops detected${RESET}      ${BOLD}${WHITE}│${RESET}"
echo -e "  ${BOLD}${WHITE}│${RESET}  ${DIM}Suggested rule: \"Max 3 retries per tool\"${RESET}    ${BOLD}${WHITE}│${RESET}"
echo -e "  ${BOLD}${WHITE}├─────────────────────────────────────────────┤${RESET}"
echo -e "  ${BOLD}${WHITE}│${RESET}  ${YELLOW}${BOLD}PROPOSAL #2 [MEDIUM]${RESET}                        ${BOLD}${WHITE}│${RESET}"
echo -e "  ${BOLD}${WHITE}│${RESET}  ${BOLD}Strengthen git-sync.sh enforcement${RESET}         ${BOLD}${WHITE}│${RESET}"
echo -e "  ${BOLD}${WHITE}│${RESET}  ${DIM}Evidence: 13 direct git calls found${RESET}        ${BOLD}${WHITE}│${RESET}"
echo -e "  ${BOLD}${WHITE}│${RESET}  ${DIM}Suggested: Add pre-commit hook${RESET}              ${BOLD}${WHITE}│${RESET}"
echo -e "  ${BOLD}${WHITE}└─────────────────────────────────────────────┘${RESET}"
echo ""
sleep 0.8

# ─── Phase 4: Awaiting Approval ───────────────────────────────────────────────
print_phase "4" "Awaiting Approval" "—"

typewriter "  📣 Proposals sent to #jarvis-dev" 0.03
sleep 0.4
echo ""
echo -e "  ${GREEN}✅ = Approve all${RESET}  ${DIM}|${RESET}  ${BLUE}1️⃣-5️⃣ = Select${RESET}  ${DIM}|${RESET}  ${RED}❌ = Reject${RESET}"
echo ""
sleep 0.5

# Blinking wait indicator
for i in 1 2 3; do
  printf "\r  ${DIM}⏳ Waiting for human review...${RESET} ${YELLOW}(no auto-apply)${RESET}  "
  sleep 0.6
  printf "\r  ${DIM}⏳ Waiting for human review...${RESET} ${DIM}(no auto-apply)${RESET}  "
  sleep 0.6
done
echo ""
echo ""

echo -e "${BOLD}${BG_BLACK}${GREEN}  ✔ Demo complete. In production, the agent waits here for your approval.  ${RESET}"
echo ""
sleep 0.5

echo -e "${DIM}  ──────────────────────────────────────────────────────────────────────${RESET}"
echo -e "${DIM}  github.com/openclaw/self-evolving  •  Self-Evolving AI Agent v0.1.0${RESET}"
echo ""
