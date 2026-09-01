#!/usr/bin/env bash
#
# sync.sh — 游戏存档同步工具
#
# 扫描本脚本所在目录下所有 *_saves 条目（真实目录或指向目录的软链接），
# 对其中每个 git 仓库依次执行：
#
#   1. 从 origin 拉取（fetch），并报告与远端分支的差异
#   2. 若仓库已是最新（与远端一致且无任何本地更改），直接跳到下一个
#   3. 同步：`git pull --rebase --autostash`
#   4. 暂存全部更改，含未追踪文件（`git add -A`）
#   5. 以脚本开始执行的时间作为提交信息提交
#   6. 立即推送；若没有需要提交的更改但本地存在未推送的提交，也直接推送
#   7. 结算统计：每个仓库处理完毕后，输出该仓库的文件总数，
#      以及本次新增/修改/删除/改名的文件数（开启 rename 检测）
#
# 退出码：全部仓库处理成功时为 0；
# 任一仓库失败、或未找到任何 *_saves 仓库时为 1。

set -uo pipefail

prog=${0##*/}

# --- 输出样式 ---------------------------------------------------------------
# 与 GNU 工具一致：仅在终端（tty）上着色；遵循 NO_COLOR。
if [[ -t 1 ]] && [[ -z ${NO_COLOR:-} ]]; then
    c_reset=$'\033[0m'
    c_bold=$'\033[1m'
    c_dim=$'\033[2m'
    c_green=$'\033[32m'
    c_yellow=$'\033[33m'
    c_red=$'\033[31m'
    # ls --color=auto 默认配色：目录=粗体蓝，软链接=粗体青
    c_dir=$'\033[1;34m'
    c_link=$'\033[1;36m'
else
    c_reset=''
    c_bold=''
    c_dim=''
    c_green=''
    c_yellow=''
    c_red=''
    c_dir=''
    c_link=''
fi

# 全局消息：带 prog 前缀
msg()     { printf '%s\n' "${c_bold}${prog}${c_reset}: $*"; }
section() { printf '%s\n' "${c_bold}$*${c_reset}"; }
warn()    { printf '%s\n' "${c_bold}${prog}${c_reset}: ${c_yellow}警告${c_reset}: $*" >&2; }
err()     { printf '%s\n' "${c_bold}${prog}${c_reset}: ${c_red}错误${c_reset}: $*" >&2; }

# 主循环内消息：高亮标题行已标明当前仓库，不再重复 prog/仓库名前缀
say()      { printf '%s\n' "$*"; }
say_skip() { printf '%s\n' "${c_yellow}跳过${c_reset}: $*"; }
say_ok()   { printf '%s\n' "${c_green}完成${c_reset} $*"; }
say_err()  { printf '%s\n' "${c_red}错误${c_reset}: $*" >&2; }

# 统计仓库中已跟踪文件的个数
count_files() { # $1=repo 目录
    local n
    n=$(git -C "$1" ls-files 2>/dev/null | wc -l)
    n=${n//[[:space:]]/}
    printf '%s' "$n"
}

# 仓库结算统计：共 N（差异 M），新增 A，修改 M，删除 D，改名 R
settle() { # $1=repo 目录  $2=新增数  $3=修改数  $4=删除数  $5=改名数
    local total added=${2:-0} modified=${3:-0} deleted=${4:-0} renamed=${5:-0} changed
    total=$(count_files "$1")
    changed=$(( added + modified + deleted + renamed ))
    say "共 ${total}（差异 ${changed}），新增 ${added}，修改 ${modified}，删除 ${deleted}，改名 ${renamed}"
}

if ! command -v git >/dev/null 2>&1; then
    err "PATH 中找不到 git"
    exit 1
fi

# --- 发现仓库 ---------------------------------------------------------------
base_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
stamp=$(date '+%F %T')   # 所有提交共用的时间戳：脚本开始执行的时间

msg "正在扫描 ${base_dir} 下的 *_saves 仓库（含软链接）"
mapfile -t found < <(
    find "${base_dir}" -maxdepth 1 \( -type d -o -type l \) -name '*_saves' 2>/dev/null | sort
)

# 只保留能解析为目录的条目（软链接会被跟随）；
# 对断链软链接或指向非目录的软链接给出警告
repos=()
for p in "${found[@]}"; do
    if [[ -d "$p" ]]; then
        repos+=("$p")
    else
        pname=$(basename -- "$p")
        if [[ -e "$p" ]]; then
            warn "${pname}：不是目录；已忽略"
        else
            warn "${pname}：断链软链接；已忽略"
        fi
    fi
done
unset found

if (( ${#repos[@]} == 0 )); then
    err "在 ${base_dir} 下未找到任何 *_saves 仓库"
    exit 1
fi

msg "找到 ${#repos[@]} 个仓库；提交信息：${stamp}"
for r in "${repos[@]}"; do
    if [[ -L "$r" ]]; then
        printf '  %s %s %s %s\n' \
            "${c_dim}•${c_reset}" \
            "${c_link}$(basename -- "$r")${c_reset}" \
            '->' \
            "$(readlink -- "$r")"
    else
        printf '  %s %s\n' "${c_dim}•${c_reset}" "${c_dir}$(basename -- "$r")${c_reset}"
    fi
done
printf '\n'

# --- 主循环 ----------------------------------------------------------------
n_ok=0
n_skip=0
n_fail=0
i=0

for repo in "${repos[@]}"; do
    i=$((i + 1))
    name=$(basename -- "$repo")
    if (( i > 1 )); then printf '\n'; fi
    section "[${i}/${#repos[@]}] ${name}"

    # 必须是 git 仓库
    if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
        say_skip "不是 git 仓库"
        n_skip=$((n_skip + 1))
        continue
    fi

    branch=$(git -C "$repo" symbolic-ref --short HEAD 2>/dev/null || printf 'master')
    upstream="origin/${branch}"

    # 1. 拉取并检查与远端的差异
    say "正在从 origin 拉取（fetch）"
    if ! git -C "$repo" fetch origin; then
        say_err "fetch 失败"
        say_err "或许 REMOTE 没有被命名为 origin"
        n_fail=$((n_fail + 1))
        continue
    fi

    counts=$(git -C "$repo" rev-list --left-right --count "${branch}...${upstream}" 2>/dev/null || printf '0 0')
    read -r ahead behind <<<"${counts}"
    if (( ahead == 0 && behind == 0 )); then
        say "${branch} 与 ${upstream} 一致"
    else
        say "${branch} 领先 ${ahead} 个提交，落后 ${behind} 个提交（相对 ${upstream}）"
    fi

    # 2. 已是最新（与远端一致且工作区无任何更改，含未追踪文件）→ 直接下一个
    if (( ahead == 0 && behind == 0 )) && [[ -z $(git -C "$repo" status --porcelain) ]]; then
        say "已是最新，跳过"
        n_skip=$((n_skip + 1))
        continue
    fi

    # 3. 与远端同步（未提交的更改会自动储藏，变基后重新应用）
    say "正在从远端同步（pull --rebase --autostash）"
    if ! git -C "$repo" pull --rebase --autostash origin "${branch}"; then
        say_err "pull/rebase 失败；请手动解决冲突后重新运行"
        n_fail=$((n_fail + 1))
        continue
    fi

    # 4. 暂存全部更改，含未追踪文件
    say "正在暂存全部更改（含未追踪文件）"
    if ! git -C "$repo" add -A; then
        say_err "git add -A 执行失败"
        n_fail=$((n_fail + 1))
        continue
    fi

    # 记录本次变更的文件数：新增/修改/删除/改名分别计数
    statuses=$(git -C "$repo" diff --cached --name-status)
    added=$(printf '%s\n' "${statuses}" | grep -c '^A' || true)
    modified=$(printf '%s\n' "${statuses}" | grep -c '^[MT]' || true)
    deleted=$(printf '%s\n' "${statuses}" | grep -c '^D' || true)
    renamed=$(printf '%s\n' "${statuses}" | grep -c '^R' || true)

    # 5. 以脚本开始时间提交；本次提交关闭签名
    if git -C "$repo" diff --cached --quiet; then
        settle "$repo" 0 0 0 0
        # 没有需要提交的更改：若本地还有未推送的提交则直接推送，否则跳过
        counts=$(git -C "$repo" rev-list --left-right --count "${branch}...${upstream}" 2>/dev/null || printf '0 0')
        read -r ahead behind <<<"${counts}"
        if (( ahead == 0 )); then
            say_skip "没有需要提交的更改"
            n_skip=$((n_skip + 1))
            continue
        fi
        say "没有新的本地更改，直接推送未推送的提交"
    else
        say "正在提交（信息：${stamp}，本次关闭 gpg 签名）"
        if ! git -C "$repo" commit --no-gpg-sign -m "${stamp}"; then
            say_err "提交失败"
            n_fail=$((n_fail + 1))
            continue
        fi
        settle "$repo" "$added" "$modified" "$deleted" "$renamed"
    fi

    # 6. 立即推送
    say "正在推送至 origin 的 ${branch} 分支"
    if ! git -C "$repo" push origin "${branch}"; then
        say_err "推送失败"
        n_fail=$((n_fail + 1))
        continue
    fi

    say_ok "$name"
    n_ok=$((n_ok + 1))
done

# --- 汇总 -------------------------------------------------------------------
printf '\n'
section "汇总"
msg "${n_ok} 个仓库同步成功，${n_skip} 个跳过，${n_fail} 个失败"
if (( n_fail > 0 )); then
    err "存在失败的仓库；请查看上方错误信息"
    exit 1
fi
exit 0