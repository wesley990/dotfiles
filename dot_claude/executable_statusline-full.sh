#!/usr/bin/env bash

input=$(cat)

# 抽資料
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

# cost & 時間 (ms → s 小數秒)
COST=$(echo "$input" | jq -r '.cost.total_cost_usd // 0')
DUR_MS=$(echo "$input" | jq -r '.cost.total_duration_ms // 0')
SEC=$((DUR_MS / 1000))
MS_REM=$((DUR_MS % 1000))
DUR_FMT=$(printf "%d.%03ds" "$SEC" "$MS_REM")

# token usage，如果有的話
TOK_IN=$(echo "$input" | jq -r '.usage.input_tokens // empty')
TOK_OUT=$(echo "$input" | jq -r '.usage.output_tokens // empty')
TOK_TOTAL=""
if [ -n "$TOK_IN" ] && [ -n "$TOK_OUT" ]; then
  TOK_TOTAL=$((TOK_IN + TOK_OUT))
fi

# 暗色背景顏色 ANSI codes
FG_MODEL="\033[38;5;81m"   # 淡青
FG_PROJECT="\033[38;5;75m" # 青綠偏藍
FG_BRANCH="\033[38;5;142m" # 橙黃色
FG_COST="\033[38;5;208m"   # 橙色
FG_TOKEN="\033[38;5;141m"  # 粉紫色
FG_TIME="\033[38;5;33m"    # 深藍 / 青藍亮色
RESET="\033[0m"

# 組 status line 一行出的格式
# emojis: 🤖 model | 📦 project/branch | 💰 cost | 🔢 tokens | ⏱ time
# 省略空欄位盡可能讓畫面乾淨

printf "${FG_MODEL}🤖 %s${RESET}" "$MODEL"
printf " | ${FG_PROJECT}📦 %s${RESET}" "$CUR"
if [ -n "$BRANCH" ]; then
  printf "${FG_BRANCH}/%s${RESET}" "$BRANCH"
fi
printf " | ${FG_COST}💰 $%.4f${RESET}" "$COST"
if [ -n "$TOK_TOTAL" ]; then
  printf " | ${FG_TOKEN}🔢 %d tot${RESET}" "$TOK_TOTAL"
fi
printf " | ${FG_TIME}⏱ %s${RESET}" "$DUR_FMT"
