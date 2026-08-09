#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

__ps1() {
    # default colors
    if test -n "${ZSH_VERSION}"; then
        local cr="%B%F{red}" cg="%B%F{green}" cy="%B%F{yellow}"
        local cb="%B%F{blue}" cm="%B%F{magenta}" cc="%B%F{cyan}"
        local cw="%B%F{white}" reset="%f%b"
        local u='%n' h='%m' w='%~' p='%#'
    else
        local cr='\[\e[01;31m\]' cg='\[\e[01;32m\]' cy='\[\e[01;33m\]'
        local cb='\[\e[01;34m\]' cm='\[\e[01;35m\]' cc='\[\e[01;36m\]'
        local cw='\[\e[01;37m\]' reset='\[\e[0m\]'
        local u='\u' h='\h' w='\w' p='\$'
    fi
    # main color (blue)
    local c="$cb"
    # root/user
    if [ $EUID -eq 0 ]; then
        local user="$cr$u$c"
        local prompt="$cr$p$c"
    else
        local user="$cg$u$c"
        local prompt="$cg$p$c"
    fi
    # ssh/local hostname
    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ]; then
        local host="$cy$h$c"
    else
        local host="$cg$h$c"
    fi
    # path
    local path="$cc$w$c"
    # git
    local git="$cm\$(git branch --show-current 2>/dev/null | sed 's/\(.*\)/ (\1)/')$c"
    # PS1
    echo "$c┌[$user@$host $path$git]"
    echo "$c╰─$prompt $reset"
}

PS1="$(__ps1)"
# export PS2="╰─> "
# PS1='\[\e[32m\]┌──(\[\e[94;1m\]\u\[\e[94m\]@\[\e[94m\]\h\[\e[0;32m\])-[\[\e[38;5;46;1m\]\w\[\e[0;32m\]] [\[\e[32m\]$?\[\e[32m\]]\n\[\e[32m\]╰─\[\e[94;1m\]\$\[\e[0m\]'
# PS1='\[\e[1m\][\u@\h \W]\$ \[\e[0m\]'
# PS1='\[\033[0;33m\][\u@\h \W]\[\033[0m\]\$ '
# PS1='[\u@\h \W]\$ '

alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias l='ls -alh'

export all_proxy="socks5://127.0.0.1:10808"
export http_proxy="http://127.0.0.1:10808"
export https_proxy="http://127.0.0.1:10808"

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
