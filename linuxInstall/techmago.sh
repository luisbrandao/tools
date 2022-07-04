#!/bin/bash
# If not running interactively, don't do anything
[ -z "$PS1" ] && return

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize


# History control ==================================================================================
# don't put duplicate lines in the history. See bash(1) for more options
readonly HISTCONTROL=ignoredups

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
readonly HISTFILESIZE="20000"
readonly HISTSIZE="20000"

# registra a data juntamente com cada comando
HISTTIMEFORMAT="+%Y%m%d-%T "
readonly HISTFILE="${HOME}/.bash_history"

# append to the history file, don't overwrite it
shopt -s histappend
PROMPT_COMMAND='history -a'
export HISTTIMEFORMAT HISTFILE HISTFILESIZE HISTSIZE HISTCONTROL

# Colors ========================================================================================
color_prompt=yes
# Seta o terminal colorido
if [ "$color_prompt" = yes ]; then
  if [[ ${EUID} == 0 ]] ; then
    PS1='\[\033[1;38;5;9m\]\u@\h\[\033[01;34m\] \w \$\[\033[00m\] '
  else
    ink=10 #cor
    __git_branch='\[\033[1;38;5;${ink}m\]$(git branch 2> /dev/null | grep -e ^* | sed -E  s/^\\\\\*\ \(.+\)$/\(\\\\\1\)\ /)\[\033[01;34m\]'
    PS1="\[\033[1;38;5;${ink}m\]\u@\h\[\033[01;34m\] \w $__git_branch\$\[\033[00m\] "
  fi
else
  PS1='\u@\h:\w\$ '
fi
unset color_prompt

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# Aliases ========================================================================================
if [ -x /usr/bin/fortune ]; then
        echo "Fortune:"
        fortune
fi

# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

alias ll='ls -l'
alias la='ls -A'
alias vi='vim'
alias tm="tail -f /var/log/messages"
alias tapache="tail -f /var/log/httpd/*_log"
alias l="ls -laF --color=tty"
alias halt="echo 'use shutdown -h now!!!' ; shutdown -h now"
alias tsquid='tail -f /var/log/squid/access.log | perl -pe "s/^\d+\.\d+/localtime $&/e"'
alias compress='tar -I "pigz --best" -cvf'
alias extract="tar xvzf"
alias xcompress='tar -I "pxz --best" -cvf'
alias xextract="tar -Jxxvf"
alias ftpython='echo "Files will be avaliable at $(hostname -I) port 8000" ; ftpython'
alias pull_stage="hub pull-request -b stage -m"
alias pull_master="hub pull-request -b master -m"
alias tnginx="tail -f /var/log/nginx/*.log /var/log/nginx/*.err"
