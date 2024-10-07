#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

alias ls='ls --color=auto'
alias ll='ls -lh'
alias grep='grep --color=auto'
alias ..='cd ..'
alias ...='cd .. && cd ..'

PS1='[\u@\h \W]\$ '

# git
GIT="git"
LOG="log --graph --oneline"
STATUS="status -s"

eval "$(fzf --bash)"
eval "$(zoxide init bash)"
