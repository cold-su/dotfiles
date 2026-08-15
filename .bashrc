#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias grep='grep --color=auto'
alias l='ls -alh'
alias g='lazygit'
alias ls='ls --color=auto'

export all_proxy="socks5://127.0.0.1:10808"
export http_proxy="http://127.0.0.1:10808"
export https_proxy="http://127.0.0.1:10808"

# ============================================================
# Prompt
#
# 布局(两行式,长命令有整行输入空间):
#   ╭─ 12:34:56 user@host ~/path branch +6 -6 ?1 ↑1 [127]
#   ╰─ $
# 主题:Catppuccin Mocha(24 位真彩色,需终端支持 truecolor)
# 可调开关(修改后执行 reps1 立即生效):
#   PS1_TIME=0   不显示时间
#   PS1_GIT=0    不显示 git 状态(超大仓库可提速)
# ============================================================

# 上一条命令的退出码,由 PROMPT_COMMAND 捕获,渲染 PS1 时读取
__ps1_exit=0

__ps1_preexec() {
    __ps1_exit=$?
    # 终端标题
    # - tmux/screen:交给它们自己管理
    # - kitty:完全交给 kitty 的 shell integration 控制(提示符时显示 pwd,
    #   运行命令时显示命令名),bash 不插手,避免两个标题源互相覆盖而闪烁
    # - 其他终端:user@host: ~/path
    case "$TERM" in
        screen*|tmux*) : ;;
        *)
            if [ "$TERM" != xterm-kitty ] && [ -z "${KITTY_WINDOW_ID:-}" ] && [ -z "${KITTY_PID:-}" ]; then
                printf '\033]0;%s@%s: %s\007' "$USER" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"
            fi
            ;;
    esac
}
# 追加而非覆盖其他脚本设置的 PROMPT_COMMAND,并防止重复添加
case ";$PROMPT_COMMAND;" in
    *";__ps1_preexec;"*) ;;
    *) PROMPT_COMMAND="__ps1_preexec${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;;
esac

# 长路径只显示最后 n 级目录
PROMPT_DIRTRIM=12

# git 状态段:分支 +新增行 -删除行 ?未跟踪 ↑领先 ↓落后
# 分支名颜色随仓库状态变化:干净=绿,有改动=黄;非 git 仓库输出为空
__git_status() {
    [ "${PS1_GIT:-1}" = 1 ] || return 0
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

    # 注意:这些颜色会被 \$(__git_status) 命令替换进 PS1,此时 readline 已不再
    # 解析 \[ \],必须直接用其内部字节 \001(SOH)/\002(STX) 包裹真实 ESC 转义
    local c_clean=$'\001\e[01;38;2;166;227;161m\002'   # 干净分支(Green  #a6e3a1)
    local c_dirty=$'\001\e[01;38;2;249;226;175m\002'   # 有改动分支(Yellow #f9e2af)
    local c_add=$'\001\e[01;38;2;166;227;161m\002'     # + 新增行(Green  #a6e3a1)
    local c_del=$'\001\e[01;38;2;243;139;168m\002'     # - 删除行(Red    #f38ba8)
    local c_unt=$'\001\e[01;38;2;249;226;175m\002'     # ? 未追踪(Yellow #f9e2af)
    local c_up=$'\001\e[01;38;2;250;179;135m\002'      # ↑↓ 领先/落后(Peach  #fab387)
    local reset=$'\001\e[0m\002'

    local branch
    branch=$(git branch --show-current 2>/dev/null)
    [ -n "$branch" ] || branch=$(git rev-parse --short HEAD 2>/dev/null) # detached HEAD
    [ -n "$branch" ] || return 0

    # 相对 HEAD 的新增/删除行数(含已暂存与未暂存,二进制文件跳过)
    local added=0 deleted=0 untracked=0 a d line
    while IFS=$'\t' read -r a d _; do
        [ "$a" = '-' ] && continue
        added=$((added + a))
        deleted=$((deleted + d))
    done < <(git diff HEAD --numstat 2>/dev/null)
    # 未追踪文件数
    while IFS= read -r line; do
        [ "${line:0:1}" = '?' ] && untracked=$((untracked + 1))
    done < <(git status --porcelain 2>/dev/null)

    local c_br=$c_clean
    [ $((added + deleted + untracked)) -gt 0 ] && c_br=$c_dirty

    local out=" $c_br$branch$reset"
    [ "$added"     -gt 0 ] && out="$out $c_add+$added"
    [ "$deleted"   -gt 0 ] && out="$out $c_del-$deleted"
    [ "$untracked" -gt 0 ] && out="$out $c_unt?$untracked"

    # 与 upstream 的领先/落后
    local ahead=0 behind=0 counts
    counts=$(git rev-list --left-right --count @{upstream}...HEAD 2>/dev/null)
    if [ -n "$counts" ]; then
        set -- $counts
        behind=${1:-0}
        ahead=${2:-0}
        [ "$behind" -gt 0 ] && out="$out $c_up↓$behind"
        [ "$ahead"  -gt 0 ] && out="$out $c_up↑$ahead"
    fi

    printf '%s' "$out"
}

__ps1() {
    # Catppuccin Mocha 调色板
    local dim='\[\e[38;2;108;112;134m\]'      # 框架/分隔符(Overlay0 #6c7086)
    local ct='\[\e[38;2;166;173;200m\]'       # 时间(Subtext0 #a6adc8)
    local cr='\[\e[01;38;2;243;139;168m\]'    # root / 错误(Red  #f38ba8)
    local cg='\[\e[01;38;2;166;227;161m\]'    # 用户 / 本地主机(Green #a6e3a1)
    local cy='\[\e[01;38;2;250;179;135m\]'    # SSH 主机(Peach #fab387)
    local cb='\[\e[01;38;2;137;180;250m\]'    # 路径(Blue  #89b4fa)
    local reset='\[\e[0m\]'

    # 时间(零 fork,用 \D strftime)
    local time=''
    [ "${PS1_TIME:-1}" = 1 ] && time="$ct\D{%H:%M:%S}$reset "

    # user(root 红 / 普通绿)
    local user
    [ $EUID -eq 0 ] && user="$cr\\u" || user="$cg\\u"
    # host(SSH 黄 / 本地绿)
    local host
    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ]; then
        host="$cy\\h"
    else
        host="$cg\\h"
    fi

    # 第一行:信息行
    printf '%s\n' "$dim╭─ $time$user$dim@$host$dim $cb\\w$reset\$(__git_status)"
    # 第二行:输入行(root 红 # / 普通绿 $)
    local prompt
    [ $EUID -eq 0 ] && prompt="$cr\\$" || prompt="$cg\\$"
    printf '%s' "$dim╰─$reset $prompt$reset "
}

PS1="$(__ps1)"
# 修改 PS1_TIME/PS1_GIT 等开关后重新生成提示符
reps1() { PS1="$(__ps1)"; }
# 续行提示符(多行命令)
export PS2="\[\e[38;2;108;112;134m\]… \[\e[0m\]"


# export PATH="$HOME/.cargo/bin:$PATH"


# # Mingw-w64 交叉编译配置
# export PKG_CONFIG_PATH="/usr/x86_64-w64-mingw32/lib/pkgconfig:$PKG_CONFIG_PATH"
# export PKG_CONFIG_ALLOW_CROSS=1
# export PKG_CONFIG_SYSROOT_DIR="/usr/x86_64-w64-mingw32"
# export CARGO_TARGET_X86_64_PC_WINDOWS_GNU_LINKER=x86_64-w64-mingw32-gcc

# 设置所有需要的环境变量
# export MINGW_PREFIX=/usr/x86_64-w64-mingw32
# export MSYSTEM_PREFIX=$MINGW_PREFIX
# export X86_64_PC_WINDOWS_GNU_MINGW_PREFIX=$MINGW_PREFIX
# export X86_64_PC_WINDOWS_GNU_MSYSTEM_PREFIX=$MINGW_PREFIX

# pkg-config 配置
# export PKG_CONFIG_ALLOW_CROSS=1
# export PKG_CONFIG_PATH=$MINGW_PREFIX/lib/pkgconfig

# 添加到 PATH
# export PATH=$MINGW_PREFIX/bin:$PATHexport PATH="$HOME/.local/bin:$PATH"

export PATH="$HOME/.local/bin:$PATH"

# opencode
export PATH="$HOME/.opencode/bin:$PATH"
