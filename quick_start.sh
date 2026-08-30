#!/usr/bin/env bash
# ============================================================================
# quick_start.sh — 以符号链接方式快速部署本仓库中的 dotfiles
# 用法: ./quick_start.sh [--dry-run] [--uninstall] [--help]
# ============================================================================

# ============================================================================
# >>> 配置注册表 <<<
# ============================================================================
# 每行格式: "<仓库内相对路径>:<目标绝对路径>"
#		* 左侧:配置在仓库中的实际位置(相对于本仓库根目录)
#		* 右侧:符号链接的落点,必须位于 $HOME 下
# 示例:
#		".bashrc:$HOME/.bashrc"
#		".zshrc:$HOME/.zshrc"
#		".config/nvim:$HOME/.config/nvim"
#		".config/git/config:$HOME/.config/git/config"
# 步骤:1) 把配置文件放入本仓库	2) 在 LINKS 按预设注册	3) 运行 ./quick_start.sh
# ============================================================================
LINKS=(
	".bashrc:$HOME/.bashrc"
	"rime-ice:$HOME/.local/share/fcitx5/rime"
	"mpv-config/portable_config:$HOME/.config/mpv"
	"nvim:$HOME/.config/nvim"
	".gitconfig:$HOME/.gitconfig"
	"kitty:$HOME/.config/kitty"
	"dolphinui.rc:$HOME/.local/share/kxmlgui5/dolphin/dolphinui.rc"
	".zshrc:$HOME/.zshrc"
	"sublime_text:$HOME/.config/sublime-text/Packages/User"
)

# ============================================================================
# 以下为脚本逻辑,一般无需修改
# ============================================================================
set -euo pipefail

# 本仓库根目录(脚本所在目录,解析为物理路径)
REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
BACKUP_SUFFIX=".bak"
prog=${0##*/}

# --- 输出函数 ---------------------------------------------------------------
# 简洁输出:只显示实际发生的操作,跳过项静默
info()		{ printf '%s\n' "$*"; }
warn()		{ printf '%s\n' "警告: $*" >&2; }
err()		{ printf '%s\n' "错误: $*" >&2; }
die()		{ err "$*"; exit 1; }
action()	{ printf '%s\n' "$*"; }   # 实际执行的操作描述

DRY_RUN=0
UNINSTALL=0

usage() {
	cat <<'EOF'
用法: ./quick_start.sh [选项]

把本仓库中的 dotfiles 以符号链接方式部署到用户目录($HOME)。

选项:
	-n, --dry-run			只打印将要执行的操作,不实际改动任何文件
	-u, --uninstall		移除本脚本创建的符号链接(保留 .bak 备份文件)
	-h, --help				显示本帮助

注册新配置:把配置文件放进本仓库,然后在 LINKS 数组中添加
	"仓库内相对路径:$HOME/目标路径"
EOF
}

while [[ $# -gt 0 ]]; do
	case "$1" in
		-n|--dry-run)		DRY_RUN=1 ;;
		-u|--uninstall) UNINSTALL=1 ;;
		-h|--help)			usage; exit 0 ;;
		*) die "未知参数: $1（使用 --help 查看用法）" ;;
	esac
	shift
done

# 执行命令:dry-run 时不执行
run() {
	if (( ! DRY_RUN )); then
		"$@"
	fi
}

# 就近备份:目标移动到同目录 <名称>.bak;若 .bak 已占用则追加时间戳
backup() {
	local dst="$1" bak
	bak="${dst}${BACKUP_SUFFIX}"
	if [[ -e "$bak" || -L "$bak" ]]; then
		bak="${dst}${BACKUP_SUFFIX}.$(date +%Y%m%d%H%M%S)"
	fi
	action "备份 ${dst} -> ${bak}"
	run mv -- "$dst" "$bak"
}

# 部署单个条目
deploy() {
	local rel="$1" dst="$2"
	local src="$REPO_DIR/$rel"

	# 源必须存在
	if [[ ! -e "$src" && ! -L "$src" ]]; then
		warn "跳过 '${rel}'：仓库中不存在该文件"
		return 1
	fi

	# 目标必须位于 $HOME 下(防止越界)
	local norm_home norm_dst
	norm_home="$(realpath -m -- "$HOME")"
	norm_dst="$(realpath -m -- "$(dirname -- "$dst")")/$(basename -- "$dst")"
	if [[ "$norm_dst" != "$norm_home" && "$norm_dst" != "$norm_home"/* ]]; then
		warn "跳过 '${rel}'：目标 '${dst}' 不在 \$HOME 下"
		return 1
	fi

	# 确保目标目录存在(不输出)
	local dst_dir
	dst_dir="$(dirname -- "$dst")"
	if [[ ! -d "$dst_dir" ]]; then
		run mkdir -p "$dst_dir"
	fi

	# 目标已是正确链接:静默跳过
	if [[ -L "$dst" ]]; then
		local cur
		cur="$(readlink -- "$dst")"
		if [[ "$cur" == "$src" ]]; then
			return 0
		fi
		# 指向别处:备份后替换
		backup "$dst"
	elif [[ -e "$dst" ]]; then
		# 存在普通文件/目录:备份后替换
		backup "$dst"
	fi

	# 执行链接
	action "链接 ${dst} -> ${src}"
	run ln -s -- "$src" "$dst"
}

uninstall() {
	local removed=0
	for entry in "${LINKS[@]}"; do
		local rel="${entry%%:*}"
		local dst="${entry#*:}"
		local src="$REPO_DIR/$rel"

		if [[ -L "$dst" ]] && [[ "$(readlink -- "$dst")" == "$src" ]]; then
			action "移除链接 ${dst}"
			run rm -- "$dst"

			# 查找最新备份并恢复
			local latest_bak
			latest_bak="$(ls -t "${dst}.bak"* 2>/dev/null | head -n1)"
			if [[ -n "$latest_bak" ]]; then
				action "从备份 ${latest_bak} 还原 ${dst}"
				run mv -- "$latest_bak" "$dst"
			else
				warn "未找到 ${dst} 的备份文件，无法还原"
			fi
			(( removed += 1 ))
		fi
	done

	if (( removed == 0 )); then
		info "没有可移除的链接"
	fi
}

main() {
	# 禁止 root 运行
	if (( EUID == 0 )); then
		die "请以普通用户运行本脚本（当前是 root）"
	fi

	if (( ${#LINKS[@]} == 0 )); then
		warn "配置注册表（LINKS）为空，没有可部署的配置。"
		info "添加新配置的步骤："
		info "  1. 把配置文件放入本仓库（如 .bashrc）"
		info "  2. 在 ${prog} 的 LINKS 数组中添加一行："
		info '     ".bashrc:$HOME/.bashrc"'
		info "  3. 重新运行 ${prog}"
		exit 0
	fi

	if (( UNINSTALL )); then
		uninstall
		exit 0
	fi

	info "开始部署 ${#LINKS[@]} 项配置..."
	local changed=0
	for entry in "${LINKS[@]}"; do
		# 保存当前输出流中是否有动作，以便统计
		before_lines=$( { deploy "${entry%%:*}" "${entry#*:}" || true; } 2>&1 | tee /dev/stderr | wc -l )
		if (( before_lines > 0 )); then
			changed=$((changed + 1))
		fi
	done

	info "完成：改动 ${changed} 项，跳过 $(( ${#LINKS[@]} - changed )) 项"
	if (( ! DRY_RUN )); then
		info "如需一键卸载全部链接：${prog} --uninstall"
	fi
}

main