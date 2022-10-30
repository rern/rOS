#
# /etc/bash.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

#motdPS1='[\u@\h \W]\$ '
PS2='> '
PS3='> '
PS4='+ '

case ${TERM} in
  xterm*|rxvt*|Eterm|aterm|kterm|gnome*)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033]0;%s@%s:%s\007" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'

    ;;
  screen)
    PROMPT_COMMAND=${PROMPT_COMMAND:+$PROMPT_COMMAND; }'printf "\033_%s@%s:%s\033\\" "${USER}" "${HOSTNAME%%.*}" "${PWD/#$HOME/\~}"'
    ;;
esac

[ -r /usr/share/bash-completion/bash_completion   ] && . /usr/share/bash-completion/bash_completion

# set variable identifying the filesystem you work in (used in the prompt below)
fs_mode=$(mount | sed -n -e "s/^\/dev\/mmcblk0p2 on \/ .*(\(r[w|o]\).*/\1/p")
 
alias set_ro='mount -o remount,ro / ; fs_mode=$(mount | sed -n -e "s/^\/dev\/mmcblk0p2 on \/ .*(\(r[w|o]\).*/\1/p")'
alias set_rw='mount -o remount,rw / ; fs_mode=$(mount | sed -n -e "s/^\/dev\/mmcblk0p2 on \/ .*(\(r[w|o]\).*/\1/p")'

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
#export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'
 
# setup fancy prompt
#motdexport PS1='\[\033[01;32m\]\u@\h${fs_mode:+($fs_mode)}\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

PS1='\[\e[38;5;242m\]'$HOSTNAME'\[\e[0m\]\
:\
\[\e[36m\]\w\[\e[0m\]\
 \[\e[30m\e[46m\] \$ \[\e[0m\] '

. /srv/http/bash/common.sh
 
