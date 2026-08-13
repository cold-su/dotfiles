#!/usr/bin/env bash
# ============================================================================
# quick_start.sh — 以符号链接方式快速部署本仓库中的 dotfiles
# 用法: ./quick_start.sh [--dry-run] [--uninstall] [--help]
# ============================================================================

# ============================================================================
# >>> 配置注册表 <<<
# ============================================================================
# 每行格式: "<仓库内相对路径>:<目标绝对路径>"
#   * 左侧:配置在仓库中的实际位置(相对于本仓库根目录)
#   * 右侧:符号链接的落点,必须位于 $HOME 下
# 示例:
#   ".bashrc:$HOME/.bashrc"
#   ".zshrc:$HOME/.zshrc"
#   ".config/nvim:$HOME/.config/nvim"
#   ".config/git/config:$HOME/.config/git/config"
# 步骤:1) 把配置文件放入本仓库  2) 在 LINKS 按预设注册  3) 运行 ./quick_start.sh
# ============================================================================
LINKS=(
  ".bashrc:$HOME/.bashrc"
  "rime-ice:$HOME/.local/share/fcitx5/rime"
  "mpv-config/portable_config:$HOME/.config/mpv"
  "nvim:$HOME/.config/nvim"
  ".gitconfig:$HOME/.gitconfig"
  "kitty:$HOME/.config/kitty"
)

# ============================================================================
# 以下为脚本逻辑,一般无需修改
# ============================================================================
set -euo pipefail

# 本仓库根目录(脚本所在目录,解析为物理路径)
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BACKUP_SUFFIX=".bak"
prog=${0##*/}

# --- 输出样式 ---------------------------------------------------------------
# 仅在终端(tty)上着色;遵循 NO_COLOR。
if [[ -t 1 ]] && [[ -z ${NO_COLOR:-} ]]; then
  c_reset=$'\033[0m'
  c_bold=$'\033[1m'
  c_dim=$'\033[2m'
  c_green=$'\033[32m'
  c_yellow=$'\033[33m'
  c_red=$'\033[31m'
else
  c_reset=''; c_bold=''; c_dim=''; c_green=''; c_yellow=''; c_red=''
fi

# --- locale 检测 ------------------------------------------------------------
# 优先级:SYNC_LANG(显式指定)> LANGUAGE > LC_ALL > LC_MESSAGES > LANG;
# 语言代码以 zh 开头(如 zh_CN.UTF-8、zh-TW)即用中文,其余默认英文。
lang=${SYNC_LANG:-}
if [[ -n "$lang" ]]; then
  [[ ${lang,,} == zh* ]] && lang=zh || lang=en
else
  lang=en
  for v in "${LANGUAGE:-}" "${LC_ALL:-}" "${LC_MESSAGES:-}" "${LANG:-}"; do
    if [[ -n "$v" && ${v,,} == zh* ]]; then
      lang=zh
      break
    fi
  done
fi

# 双语消息:$1=中文,$2=英文
L() { if [[ "$lang" == zh ]]; then printf '%s' "$1"; else printf '%s' "$2"; fi; }

# 全局消息:带 prog 前缀
msg()     { printf '%s\n' "${c_bold}${prog}${c_reset}: $*"; }
section() { printf '%s\n' "${c_bold}$*${c_reset}"; }
warn()    { printf '%s\n' "${c_bold}${prog}${c_reset}: ${c_yellow}$(L '警告' 'Warning')${c_reset}: $*" >&2; }
err()     { printf '%s\n' "${c_bold}${prog}${c_reset}: ${c_red}$(L '错误' 'Error')${c_reset}: $*" >&2; }
die()     { err "$*"; exit 1; }

# 条目级消息:标题行已标明当前条目,不再重复 prog 前缀
say()      { printf '%s\n' "$*"; }
say_skip() { printf '%s\n' "${c_yellow}$(L '跳过' 'Skipped')${c_reset}: $*"; }
say_ok()   { printf '%s\n' "${c_green}$(L '完成' 'Done')${c_reset} $*"; }

DRY_RUN=0
UNINSTALL=0

usage() {
  cat <<'EOF'
用法: ./quick_start.sh [选项]

把本仓库中的 dotfiles 以符号链接方式部署到用户目录($HOME)。

选项:
  -n, --dry-run     只打印将要执行的操作,不实际改动任何文件
  -u, --uninstall   移除本脚本创建的符号链接(保留 .bak 备份文件)
  -h, --help        显示本帮助

注册新配置:把配置文件放进本仓库,然后在 LINKS 数组中添加
  "仓库内相对路径:$HOME/目标路径"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)   DRY_RUN=1 ;;
    -u|--uninstall) UNINSTALL=1 ;;
    -h|--help)      usage; exit 0 ;;
    *) die "$(L '未知参数' 'Unknown argument'): $1（$(L '可用 --help 查看用法' 'use --help for usage')）" ;;
  esac
  shift
done

# 统一执行入口:dry-run 时只打印,不执行
run() {
  if (( DRY_RUN )); then
    printf '    [dry-run] %s\n' "$*"
  else
    "$@"
  fi
}

# 就近备份:把目标原样移动到同目录的 <名称>.bak
# .bak 已被占用时追加时间戳,绝不覆盖已有备份
backup() {
  local dst="$1" bak
  bak="${dst}${BACKUP_SUFFIX}"
  if [[ -e "$bak" || -L "$bak" ]]; then
    bak="${dst}${BACKUP_SUFFIX}.$(date +%Y%m%d%H%M%S)"
  fi
  say "$(L "备份 ${dst} -> ${bak}" "Backing up ${dst} -> ${bak}")"
  run mv -- "$dst" "$bak"
}

# 部署单个条目:仓库内文件 -> $HOME 下的符号链接
deploy() {
  local rel="$1" dst="$2"
  local src="$REPO_DIR/$rel"

  # 源文件必须存在于仓库中
  if [[ ! -e "$src" && ! -L "$src" ]]; then
    warn "$(L "跳过 '${rel}'：仓库中不存在该文件" "Skipping '${rel}': not found in the repo")"
    return 1
  fi
  # 目标必须位于 $HOME 下(规范化后检查,防止 .. 越界),全程不需要任何权限
  # 注意:只解析目录部分,不解析链接本身,否则已部署的链接会被误判为越界
  local norm_home norm_dst
  norm_home="$(realpath -m -- "$HOME")"
  norm_dst="$(realpath -m -- "$(dirname -- "$dst")")/$(basename -- "$dst")"
  if [[ "$norm_dst" != "$norm_home" && "$norm_dst" != "$norm_home"/* ]]; then
    warn "$(L "跳过 '${rel}'：目标 '${dst}' 不在 \$HOME 下，拒绝部署到系统路径" "Skipping '${rel}': target '${dst}' is outside \$HOME, refusing to deploy to system paths")"
    return 1
  fi

  # 确保目标目录存在
  local dst_dir
  dst_dir="$(dirname -- "$dst")"
  if [[ ! -d "$dst_dir" ]]; then
    say "$(L "创建目录 ${dst_dir}" "Creating directory ${dst_dir}")"
    run mkdir -p "$dst_dir"
  fi

  # 处理目标已被占用的情况
  if [[ -L "$dst" ]]; then
    local cur
    cur="$(readlink -- "$dst")"
    if [[ "$cur" == "$src" ]]; then
      say_skip "$(L "已部署：${dst} -> ${src}" "Already deployed: ${dst} -> ${src}")"
      return 0
    fi
    warn "$(L "目标 ${dst} 是符号链接但指向别处（${cur}），将备份后替换" "Target ${dst} is a symlink pointing elsewhere (${cur}); backing up and replacing")"
    backup "$dst"
  elif [[ -e "$dst" ]]; then
    warn "$(L "目标 ${dst} 已存在，按就近原则备份后替换" "Target ${dst} already exists; backing up before replacing")"
    backup "$dst"
  fi

  say_ok "$(L "链接 ${dst} -> ${src}" "Linked ${dst} -> ${src}")"
  run ln -s -- "$src" "$dst"
}

# 卸载:只移除指向本仓库的符号链接,备份文件原样保留
uninstall() {
  local removed=0
  for entry in "${LINKS[@]}"; do
    local rel="${entry%%:*}"
    local dst="${entry#*:}"
    local src="$REPO_DIR/$rel"
    if [[ -L "$dst" ]] && [[ "$(readlink -- "$dst")" == "$src" ]]; then
      say_ok "$(L "移除链接 ${dst}" "Removed link ${dst}")"
      run rm -- "$dst"
      (( removed += 1 ))
    else
      say_skip "$(L "${dst}（不存在或不是本脚本创建的链接）" "${dst} (missing or not created by this script)")"
    fi
  done
  if (( removed > 0 )); then
    say "$(L "已移除 ${removed} 个链接。原配置备份（.bak）保留在原处，确认后请手动清理。" "Removed ${removed} links. Original backups (.bak) are kept in place; clean them up manually after verification.")"
  fi
}

main() {
  # 严禁以 root 运行:所有操作都应在普通用户自己的目录下完成
  if (( EUID == 0 )); then
    die "$(L "请以普通用户运行本脚本（当前是 root）。它只操作 \$HOME，不需要也不允许任何权限。" "Run as a normal user (currently root). It only touches \$HOME and requires no privileges.")"
  fi

  if (( ${#LINKS[@]} == 0 )); then
    warn "$(L "配置注册表（LINKS）为空，没有可部署的配置。" "The LINKS registry is empty; nothing to deploy.")"
    say "$(L "添加新配置的步骤：" "To add a new config:")"
    say "  1. $(L "把配置文件放入本仓库（如 .bashrc）" "put the config file into this repo (e.g. .bashrc)")"
    say "  2. $(L "在 ${prog} 的 LINKS 数组中添加一行：" "add a line to the LINKS array in ${prog}:")"
    say '     ".bashrc:$HOME/.bashrc"'
    say "  3. $(L "重新运行 ${prog}" "re-run ${prog}")"
    exit 0
  fi

  if (( UNINSTALL )); then
    uninstall
    return 0
  fi

  msg "$(L "仓库目录：${REPO_DIR}" "Repo directory: ${REPO_DIR}")"
  msg "$(L "开始部署 ${#LINKS[@]} 项配置…" "Deploying ${#LINKS[@]} items…")"
  printf '\n'

  i=0
  for entry in "${LINKS[@]}"; do
    i=$((i + 1))
    if (( i > 1 )); then printf '\n'; fi
    section "[${i}/${#LINKS[@]}] ${entry%%:*}"
    deploy "${entry%%:*}" "${entry#*:}" || true
  done

  printf '\n'
  say_ok "$(L "共处理 ${#LINKS[@]} 项配置" "Processed ${#LINKS[@]} items")"
  if (( ! DRY_RUN )); then
    say "$(L "如需一键卸载全部链接：${prog} --uninstall" "To uninstall all links at once: ${prog} --uninstall")"
  fi
}

main
