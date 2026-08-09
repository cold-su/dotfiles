#!/usr/bin/env bash
# ============================================================================
# quick_start.sh — 以符号链接方式快速部署本仓库中的 dotfiles
# 用法: ./quick_start.sh [--dry-run] [--uninstall] [--help]
# ============================================================================

# ============================================================================
# >>> 配置注册表 —— 以后新增配置只需在下面添加一行 <<<
# ============================================================================
# 每行格式: "<仓库内相对路径>:<目标绝对路径>"
#   * 左侧:配置在仓库中的实际位置(相对于本仓库根目录)
#   * 右侧:符号链接的落点,必须位于 $HOME 下
# 示例:
#   ".bashrc:$HOME/.bashrc"
#   ".zshrc:$HOME/.zshrc"
#   ".config/nvim:$HOME/.config/nvim"
#   ".config/git/config:$HOME/.config/git/config"
# 步骤:1) 把配置文件放入本仓库  2) 在这里加一行  3) 重新运行 ./quick_start.sh
# ============================================================================
LINKS=(
  # 在此处注册你的配置,例如:
  # ".bashrc:$HOME/.bashrc"
  "oh-my-rime:$HOME/.local/share/fcitx5/rime"
  "bashrc:$HOME/.bashrc"
  "mpv:$HOME/.config/mpv"
)

# ============================================================================
# 以下为脚本逻辑,一般无需修改
# ============================================================================
set -euo pipefail

# 本仓库根目录(脚本所在目录,解析为物理路径)
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BACKUP_SUFFIX=".bak"

# ---- 输出着色(管道/重定向时自动禁用) --------------------------------------
if [[ -t 1 ]]; then
  C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'; C_RESET=$'\033[0m'
else
  C_GREEN=''; C_YELLOW=''; C_RED=''; C_RESET=''
fi
say()  { printf '%s==>%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
die()  { printf '%s[!]%s %s\n' "$C_RED" "$C_RESET" "$*" >&2; exit 1; }

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

注册新配置:把配置文件放进本仓库,然后在 LINKS 数组中添加一行
  "仓库内相对路径:$HOME/目标路径"
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -n|--dry-run)   DRY_RUN=1 ;;
    -u|--uninstall) UNINSTALL=1 ;;
    -h|--help)      usage; exit 0 ;;
    *) die "未知参数: $1(可用 --help 查看用法)" ;;
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
  say "备份 $dst -> $bak"
  run mv -- "$dst" "$bak"
}

# 部署单个条目:仓库内文件 -> $HOME 下的符号链接
deploy() {
  local rel="$1" dst="$2"
  local src="$REPO_DIR/$rel"

  # 源文件必须存在于仓库中
  if [[ ! -e "$src" && ! -L "$src" ]]; then
    warn "跳过 '$rel':仓库中不存在该文件"
    return 1
  fi
  # 目标必须位于 $HOME 下(规范化后检查,防止 .. 越界),全程不需要任何权限
  # 注意:只解析目录部分,不解析链接本身,否则已部署的链接会被误判为越界
  local norm_home norm_dst
  norm_home="$(realpath -m -- "$HOME")"
  norm_dst="$(realpath -m -- "$(dirname -- "$dst")")/$(basename -- "$dst")"
  if [[ "$norm_dst" != "$norm_home" && "$norm_dst" != "$norm_home"/* ]]; then
    warn "跳过 '$rel':目标 '$dst' 不在 \$HOME 下,拒绝部署到系统路径"
    return 1
  fi

  # 确保目标目录存在
  local dst_dir
  dst_dir="$(dirname -- "$dst")"
  if [[ ! -d "$dst_dir" ]]; then
    say "创建目录 $dst_dir"
    run mkdir -p "$dst_dir"
  fi

  # 处理目标已被占用的情况
  if [[ -L "$dst" ]]; then
    local cur
    cur="$(readlink -- "$dst")"
    if [[ "$cur" == "$src" ]]; then
      echo "已部署,跳过: $dst -> $src"
      return 0
    fi
    warn "目标 $dst 是符号链接但指向别处($cur),将备份后替换"
    backup "$dst"
  elif [[ -e "$dst" ]]; then
    warn "目标 $dst 已存在,按就近原则备份后替换"
    backup "$dst"
  fi

  say "链接 $dst -> $src"
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
      say "移除链接 $dst"
      run rm -- "$dst"
      (( removed += 1 ))
    else
      echo "跳过 $dst(不存在或不是本脚本创建的链接)"
    fi
  done
  if (( removed > 0 )); then
    echo "已移除 $removed 个链接。原配置备份(.bak)保留在原处,确认后请手动清理。"
  fi
}

main() {
  # 严禁以 root 运行:所有操作都应在普通用户自己的目录下完成
  if (( EUID == 0 )); then
    die "请以普通用户运行本脚本(当前是 root)。它只操作 \$HOME,不需要也不允许任何权限。"
  fi

  if (( ${#LINKS[@]} == 0 )); then
    warn "配置注册表(LINKS)为空,没有可部署的配置。"
    echo "添加新配置的步骤:"
    echo "  1. 把配置文件放入本仓库(如 .bashrc)"
    echo "  2. 在 quick_start.sh 的 LINKS 数组中添加一行:"
    echo '     ".bashrc:$HOME/.bashrc"'
    echo "  3. 重新运行 $0"
    exit 0
  fi

  if (( UNINSTALL )); then
    uninstall
    return 0
  fi

  echo "仓库目录: $REPO_DIR"
  echo "开始部署 $((${#LINKS[@]})) 项配置..."
  echo
  for entry in "${LINKS[@]}"; do
    deploy "${entry%%:*}" "${entry#*:}" || true
  done
  echo
  # say "完成。如有备份,备份文件会以 ${BACKUP_SUFFIX} 结尾,确认新配置正常后可手动删除。"
  say "完成。"
  if (( ! DRY_RUN )); then
    echo "如需一键卸载全部链接: $0 --uninstall"
  fi
}

main
