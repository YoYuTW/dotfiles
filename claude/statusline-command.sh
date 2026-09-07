#!/bin/sh
# Claude Code statusline — p10k style
# Left: cwd + git branch  |  Right: model + context | 5h session | 7d weekly

input=$(cat)

# --- parse JSON fields ---
cwd=$(echo "$input" | jq -r '.workspace.current_dir // .cwd // ""')
model=$(echo "$input" | jq -r '.model.display_name // ""')
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')

# --- cwd: replace $HOME with ~ (POSIX; dash has no ${var/#pat/rep}) ---
home="$HOME"
case "$cwd" in
  "$home")   cwd_display="~" ;;
  "$home"/*) cwd_display="~${cwd#"$home"}" ;;
  *)         cwd_display="$cwd" ;;
esac

# --- git branch (skip lock to avoid blocking) ---
branch=""
if git -C "$cwd" --no-optional-locks rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(git -C "$cwd" --no-optional-locks symbolic-ref --short HEAD 2>/dev/null \
           || git -C "$cwd" --no-optional-locks rev-parse --short HEAD 2>/dev/null)
fi

# --- fetch Claude usage (cached 60s) ---
CACHE_FILE="${TMPDIR:-/tmp}/claude-usage.json"
CACHE_TTL=60
USAGE_JSON=""

if [ -f "$CACHE_FILE" ]; then
  NOW=$(date +%s)
  # GNU stat first (Linux), BSD stat second (macOS)
  MTIME=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)
  AGE=$(( NOW - MTIME ))
  if [ "$AGE" -lt "$CACHE_TTL" ]; then
    USAGE_JSON=$(cat "$CACHE_FILE")
  fi
fi

if [ -z "$USAGE_JSON" ]; then
  CREDS="$HOME/.claude/.credentials.json"
  TOKEN=""
  if [ -f "$CREDS" ]; then
    TOKEN=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS" 2>/dev/null)
  fi
  # macOS Keychain fallback
  if [ -z "$TOKEN" ] && command -v security >/dev/null 2>&1; then
    RAW=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null)
    if [ -n "$RAW" ]; then
      TOKEN=$(printf '%s' "$RAW" | jq -r '.claudeAiOauth.accessToken // empty' 2>/dev/null)
    fi
  fi
  if [ -n "$TOKEN" ]; then
    RESP=$(curl -sf --max-time 3 \
      -H "Authorization: Bearer $TOKEN" \
      -H "anthropic-beta: oauth-2025-04-20" \
      -H "Accept: application/json" \
      "https://api.anthropic.com/api/oauth/usage" 2>/dev/null)
    if [ -n "$RESP" ]; then
      printf '%s' "$RESP" > "$CACHE_FILE"
      USAGE_JSON="$RESP"
    fi
  fi
fi

# --- build bar (8 chars) ---
make_bar() {
  pct="$1"
  filled=$(( pct * 8 / 100 ))
  empty=$(( 8 - filled ))
  bar=""
  i=0
  while [ $i -lt $filled ]; do bar="${bar}█"; i=$(( i + 1 )); done
  i=0
  while [ $i -lt $empty  ]; do bar="${bar}░"; i=$(( i + 1 )); done
  printf '%s' "$bar"
}

# --- usage segments ---
session_str=""
weekly_str=""
if [ -n "$USAGE_JSON" ]; then
  s_pct=$(printf '%s' "$USAGE_JSON" | jq -r '.five_hour.utilization // empty' 2>/dev/null)
  w_pct=$(printf '%s' "$USAGE_JSON" | jq -r '.seven_day.utilization // empty' 2>/dev/null)
  if [ -n "$s_pct" ]; then
    s_int=$(printf "%.0f" "$s_pct")
    session_str="${s_int}% $(make_bar "$s_int")"
  fi
  if [ -n "$w_pct" ]; then
    w_int=$(printf "%.0f" "$w_pct")
    weekly_str="${w_int}% $(make_bar "$w_int")"
  fi
fi

# --- context bar ---
context_str=""
if [ -n "$used" ]; then
  used_int=$(printf "%.0f" "$used")
  filled=$(( used_int / 10 ))
  empty=$(( 10 - filled ))
  bar=""
  i=0
  while [ $i -lt $filled ]; do bar="${bar}█"; i=$(( i + 1 )); done
  i=0
  while [ $i -lt $empty  ]; do bar="${bar}░"; i=$(( i + 1 )); done
  context_str="${used_int}% ${bar}"
fi

# --- ANSI colours (real ESC bytes via printf) ---
RESET=$(printf '\033[0m')
BOLD=$(printf '\033[1m')
CYAN=$(printf '\033[36m')
YELLOW=$(printf '\033[33m')
GREEN=$(printf '\033[32m')
MAGENTA=$(printf '\033[35m')
BLUE=$(printf '\033[34m')
DIM=$(printf '\033[2m')
SEP="${DIM}|${RESET} "

# --- assemble left segment ---
left="${BOLD}${CYAN} ${cwd_display}${RESET}"
if [ -n "$branch" ]; then
  left="${left} ${DIM}|${RESET} ${GREEN} ${branch}${RESET}"
fi

# --- assemble right segment ---
right=""
append_right() {
  if [ -n "$right" ]; then right="${right} ${SEP}"; fi
  right="${right}$1"
}

[ -n "$model"       ] && append_right "${MAGENTA}${model}${RESET}"
[ -n "$context_str" ] && append_right "${YELLOW}ctx ${context_str}${RESET}"
[ -n "$session_str" ] && append_right "${GREEN}5h ${session_str}${RESET}"
[ -n "$weekly_str"  ] && append_right "${BLUE}7d ${weekly_str}${RESET}"

# --- get terminal width ---
cols=$(tput cols 2>/dev/null || echo 80)

# Strip ANSI to measure visible length
strip_ansi() {
  # literal ESC byte — \x1b is a GNU sed extension, BSD sed does not accept it
  printf '%s' "$1" | sed "s/$(printf '\033')\[[0-9;]*m//g"
}

left_visible=$(strip_ansi "$left")
right_visible=$(strip_ansi "$right")
left_len=${#left_visible}
right_len=${#right_visible}

pad=$(( cols - left_len - right_len - 2 ))
if [ $pad -lt 1 ]; then pad=1; fi

padding=$(printf "%${pad}s" "")

printf '%s%s%s\n' "$left" "$padding" "$right"
