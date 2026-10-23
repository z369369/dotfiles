# ~/.bashrc: executed by bash(1) for non-login shells.
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# update the values of Terminal LINES and COLUMNS.
shopt -s checkwinsize

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
	# We have color support; assume it's compliant with Ecma-48
	# (ISO/IEC-6429). (Lack of such support is extremely rare, and such
	# a case would tend to support setf rather than setaf.)
	color_prompt=yes
    else
	color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias ll='ls -alF'
    alias la='ls -A'
    alias l='ls -CF'
    
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

ripfzf() {
    # 검색어 인자 확인 (1글자 이상)
    if [[ -z "$1" || ${#1} -lt 1 ]]; then
        echo "검색어(1글자 이상)를 입력하세요."
        return 1
    fi

    local query="$1"

    # rg 옵션 설명
    # --hidden 제외(숨김파일 무시)
    # --glob '!.git/*' : .git 무시 (속도 개선)
    # --glob '!*' : 숨김파일 제외를 위해 이미 --hidden 을 쓰지 않음
    # -n : 줄번호
    # -H : 파일명 표시
    # --color always : fzf preview용
    rg --no-hidden \
       --glob '!.git/*' \
       -n -H --color=always "$query" |
    fzf --layout=reverse --ansi \
        --preview "batcat --style=plain --color=always {1} --line-range {2}: {2}" \
        --delimiter : \
        --preview-window=right:60% \
        --bind "enter:become(micro {1} +{2})"
}

pw() {
    apg -a 1 -m 16 -x 16 -n 10 -M NCLS -E '1ilI0oOQ8B!"'\''()*%&+,-./:;<=>?[\\]^`{|}~'
}

# 1. Create Snapshot (Usage: screate "comments")
tcreate() {
    local comment="${1:-manual_snapshot}"
    cat ~/.key | sudo -S snapper -c root create --description "$comment"
    if [ $? -eq 0 ]; then
        sudo update-grub
        echo -e "\e[32msnapper create & sudo update-grub executed.\e[0m"
    fi
}


# 3. Remove Snapshot (Usage: sremove <number>)
tremove() {
    if [ -z "$1" ]; then
        echo -e "\e[31mError: Please specify snapshot number to delete. (e.g., sremove 12)\e[0m"
        return 1
    fi
    cat ~/.key | sudo -S snapper -c root delete "$1"
    if [ $? -eq 0 ]; then
        sudo update-grub
        echo -e "\e[32msnapper delete #$1 & sudo update-grub executed.\e[0m"
    fi
}

# 4. Restore Snapshot (Usage: srestore <number>)
trestore() {
    if [ -z "$1" ]; then
        echo -e "\e[31mError: Please specify snapshot number to restore. (e.g., srestore 12)\e[0m"
        return 1
    fi
    echo -e "\e[33mRestoring system state to Snapshot #$1...\e[0m"
    cat ~/.key | sudo -S snapper -c root undochange "$1"..0
}

backup_etc() {
    local target_dir="${1:-/media/lwh/lwh_backup/Backup/etc}"
    local today=$(date +%Y%m%d)
    
    if [ ! -d "$target_dir" ]; then
        echo "경로가 존재하지 않아 디렉토리를 생성합니다: $target_dir"
        sudo mkdir -p "$target_dir"
    fi

    echo "백업을 시작합니다: $target_dir/etc_$today.tar"
    sudo tar -cvf "$target_dir/etc_$today.tar" /etc
	
    echo "created : $target_dir/etc_$today.tar"
}

aupdate() {
    /home/lwh/.local/bin/gupdate
    flatpak update -y
    sudo -S apt update < ~/.key
    sudo -S apt upgrade < ~/.key
}

alias rm='trash-put'
alias tl='trash-list'
alias trs='trash-restore'

alias aclean='flatpak uninstall --unused -y && cat ~/.key | sudo -S apt autoremove --purge && sudo apt clean'

alias bat='batcat --style=plain'
alias bslist='find ~/.local/bin -maxdepth 1 -type f -executable | sort -r | fzf'
alias c='clear'
alias cat='batcat --style=plain'

alias df='pydf'
alias du='ncdu -x'
alias ee='mousepad'
alias gedit='mousepad'
alias fe='fastfetch --logo none'
alias free='free -m'
alias frepair='flatpak repair --user'
alias fupdate='flatpak update -y'
#alias ls='eza'
alias myip='curl ifconfig.me;echo ""'
alias nano='micro'

alias r="source ~/.bashrc && echo 'bashrc reloaded..' "
alias reboot='cat ~/.key | sudo -S reboot'
alias shutdown='cat ~/.key | sudo -S systemctl poweroff -i '
alias syslog='cat ~/.key | sudo -S batcat --style=plain /var/log/syslog'

# 2. List Snapshots (root & home)
alias tlist='cat ~/.key | sudo -S snapper --iso -c root list'

alias slist='systemctl list-unit-files --state=enabled'
alias top='htop'
alias vi='micro'

alias vinit='rm -rf .venv | python3 -m venv .venv'
alias venv='rm -rf .venv | python3 -m venv .venv'
alias vin='source ./.venv/bin/activate'
alias vout='deactivate'

alias fixhangul='export GTK_IM_MODULE=fcitx; export QT_IM_MODULE=fcitx; export XMODIFIERS=@im=fcitx; killall fcitx5 fcitx 2>/dev/null; fcitx5 -d -r > /dev/null 2>&1 & echo "한글 입력기(Fcitx5)를 재시작했습니다."' 
# -----------------------------------------------------

#export FZF_DEFAULT_COMMAND="fdfind -t f --hidden --follow --exclude '.git'"
export FZF_DEFAULT_COMMAND="fdfind -t f "
export FZF_DEFAULT_OPTS="--preview 'batcat --style=plain --color=always {}' 
--preview-window right:60%
--bind 'ctrl-/:toggle-preview'
--bind 'ctrl-e:execute(code {})'
--bind 'ctrl-g:execute(gedit {})'
--bind 'enter:become(micro {1} +{2})'
"

bind -x '"\C-f": fzf --layout=reverse'
bind -x '"\C-r": ripfzf " "'


#/home/lwh/.local/bin/check_debian_eol_curl.sh

export PATH="$HOME/opt/node/node-v24.13.0-linux-x64/bin:$HOME/.local/bin:$PATH"

export EDITOR='micro'
export VISUAL='micro'

# Added by LM Studio CLI (lms)
export PATH="$PATH:/home/lwh/.lmstudio/bin"
# End of LM Studio CLI section

rm -f ~/.bash_history-*.tmp
rm -rf /home/lwh/.config/google-chrome-backup-crashrecovery-*

export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion


