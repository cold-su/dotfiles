#!/usr/bin/env bash
# 遍历当前目录下的 git 仓库：git add -A -> 以当前时间 commit -> push（并行）
# 用法: $0 [-j 并行数]（默认 4）
set -u

cd "$(dirname "$0")" || exit 1

PARALLEL=4
while getopts "j:h" opt; do
  case "$opt" in
    j) PARALLEL="$OPTARG" ;;
    h) echo "用法: $0 [-j 并行数]"; exit 0 ;;
    *) echo "用法: $0 [-j 并行数]"; exit 1 ;;
  esac
done
case "$PARALLEL" in
  ''|*[!0-9]*) echo "错误: 并行数必须是数字"; exit 1 ;;
esac

process_repo() {
  local dir="$1"
  local name="${dir%/}"
  local out result="" line
  local need_push=0

  # fetch（失败不阻断，push 会再报错）
  git -C "$dir" fetch >/dev/null 2>&1 || result+="fetch 失败; "

  # add
  git -C "$dir" add -A

  # commit
  if git -C "$dir" diff --cached --quiet; then
    if git -C "$dir" rev-parse --verify -q HEAD >/dev/null 2>&1; then
      line=$(git -C "$dir" status -sb | head -1)
      case "$line" in
        *ahead*)  need_push=1; result+="有未推送提交; " ;;  # 手动 commit 过，未推送
        *"..."*)  result+="无变更" ;;                        # 有 upstream 且不领先
        *)        need_push=1; result+="无 upstream; " ;;    # 无 upstream，尝试推送
      esac
    else
      result+="无变更(无提交)"
    fi
  elif git -C "$dir" -c commit.gpgsign=false commit -m "$(date '+%Y-%m-%d %H:%M:%S')" >/dev/null 2>&1; then
    result+="已提交; "
    need_push=1
  else
    result+="commit 失败; "
  fi

  # push（先普通 push，失败时尝试设置新 upstream；失败不中断其他仓库）
  if [ "$need_push" -eq 1 ]; then
    if out=$(git -C "$dir" -c push.gpgsign=false push 2>&1); then
      result+="push 完成"
    elif out=$(git -C "$dir" -c push.gpgsign=false push -u origin HEAD 2>&1); then
      result+="push 完成(设置新上游)"
    else
      result+="push 失败: $(printf '%s\n' "$out" | head -1)"
    fi
  fi

  printf '[%s] %s\n' "$name" "$result"
}

# 并行执行，控制并发数
running=0
for dir in */; do
  [ -d "$dir/.git" ] || continue
  process_repo "$dir" &
  running=$((running + 1))
  if [ "$running" -ge "$PARALLEL" ]; then
    wait -n
    running=$((running - 1))
  fi
done
wait
