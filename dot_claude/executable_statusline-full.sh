#!/usr/bin/env bash

input=$(cat)

# 提取資料
MODEL=$(echo "$input" | jq -r '.model.display_name // "?"')
PROJECT_DIR=$(echo "$input" | jq -r '.workspace.project_dir // .workspace.current_dir // "."')
CUR=$(basename "$PROJECT_DIR")
BRANCH=""
if git -C "$PROJECT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  BRANCH_NAME=$(git -C "$PROJECT_DIR" branch --show-current 2>/dev/null)
  if [ -n "$BRANCH_NAME" ]; then
    BRANCH="🌿${BRANCH_NAME}"
  fi
fi

# cost & 時間（ms → HH:MM:SS）
COST_USD=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')

CACHE_FILE="/tmp/usd_twd_rate.json"
CACHE_TTL=$((60 * 60)) # 1 小時

fetch_rate() {
  curl -s https://open.er-api.com/v6/latest/USD |
    jq -r '.time_last_update_unix, .rates.TWD' 2>/dev/null |
    awk 'NR==1{ts=$1} NR==2{rate=$1} END{if(rate!="null" && rate!="") print ts, rate}'
}

# 如果有 cache 且沒過期，直接用
if [[ -f "$CACHE_FILE" ]]; then
  read -r CACHE_TS CACHE_RATE <"$CACHE_FILE"
  NOW=$(date +%s)
  if ((NOW - CACHE_TS < CACHE_TTL)); then
    RATE_TWD=$CACHE_RATE
  fi
fi

# 若沒有 cache 或 cache 過期 → 抓新的
if [[ -z "$RATE_TWD" ]]; then
  if DATA=$(fetch_rate); then
    RATE_TWD=$(echo "$DATA" | awk '{print $2}')
    TS=$(echo "$DATA" | awk '{print $1}')
    echo "$TS $RATE_TWD" >"$CACHE_FILE"
  fi
fi

# 顯示結果
if [[ "$RATE_TWD" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
  COST_TWD=$(awk "BEGIN { printf \"%.2f\", $COST_USD * $RATE_TWD }")
  COST_USD_FMT=$(awk "BEGIN { printf \"%.2f\", $COST_USD }")
  COST_DISPLAY="NT$COST_TWD (~\$$COST_USD_FMT)"
else
  COST_DISPLAY="$(awk "BEGIN { printf \"%.2f\", $COST_USD }") USD" # fallback
fi

DUR_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')

total_seconds=$((DUR_MS / 1000))
s=$((total_seconds % 60))
m=$(((total_seconds / 60) % 60))
h=$((total_seconds / 3600))

# 格式化成 HH:MM:SS
DUR_FMT=$(printf "%02d:%02d:%02d" "$h" "$m" "$s")

# token 使用量（如果有的話）
TOK_IN=$(echo "$input" | jq -r '.usage.input_tokens // empty')
TOK_OUT=$(echo "$input" | jq -r '.usage.output_tokens // empty')
TOK_TOTAL=""
if [ -n "$TOK_IN" ] && [ -n "$TOK_OUT" ]; then
  TOK_TOTAL=$((TOK_IN + TOK_OUT))
fi

# 系統時間（顯示年-月-日 HH:MM:SS）
SYS_TIME=$(date +"%Y-%m-%d %H:%M:%S")

# 暗色背景顏色 ANSI codes
FG_MODEL="\033[38;5;81m"    # 淡青
FG_PROJECT="\033[38;5;75m"  # 青綠偏藍
FG_BRANCH="\033[38;5;142m"  # 橙黃色
FG_COST="\033[38;5;208m"    # 橙色
FG_TOKEN="\033[38;5;141m"   # 粉紫色
FG_TIME="\033[38;5;33m"     # 深藍 / 青藍亮色
FG_SYSDATE="\033[38;5;246m" # 較淡的灰白色，用來顯示系統時間
RESET="\033[0m"

# 組 status line 一行出的格式
# emojis: 🤖 model | 📦 project/branch | 💰 cost | 🔢 tokens | ⏱ time
# 省略空欄位盡可能讓畫面乾淨
printf "${FG_MODEL}🤖 %s${RESET}" "$MODEL"
printf " | ${FG_PROJECT}📦 %s${RESET}" "$CUR"
if [ -n "$BRANCH" ]; then
  printf "${FG_BRANCH}/%s${RESET}" "$BRANCH"
fi
printf " | ${FG_COST}💰 %s${RESET}" "$COST_DISPLAY"
if [ -n "$TOK_TOTAL" ]; then
  printf " | ${FG_TOKEN}🔢 %d tot${RESET}" "$TOK_TOTAL"
fi
printf " | ${FG_TIME}⏱ %s${RESET}" "$DUR_FMT"
printf " | ${FG_SYSDATE}📅 %s${RESET}" "$SYS_TIME"
