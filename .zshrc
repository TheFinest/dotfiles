# Change color scheme
(cat ~/.cache/wal/sequences)

if command -v tmux &> /dev/null && [ -n "$PS1" ] && [[ ! "$TERM" =~ screen ]] && [[ ! "$TERM" =~ tmux ]] && [ -z "$TMUX" ]; then
  tmux new-session -A -s main
fi

# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="/home/thekeymaster/.oh-my-zsh"
export PATH=/home/thekeymaster/.nimble/bin:$PATH

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="gentoo"

# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in ~/.oh-my-zsh/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to automatically update without prompting.
# DISABLE_UPDATE_PROMPT="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS=true

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
 ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
 COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in ~/.oh-my-zsh/plugins/*
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
autoload -U colors && colors
autoload -U compinit && compinit
autoload -U promptinit && promptinit

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
 export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"

# Aliases
alias nas="sshfs thegatekeeper@10.0.0.162:Server/ Server/ -o reconnect,default_permissions,allow_other" 
alias mulitplesound="pacmd load-module module-combine-sink"
alias midi="sudo aconnect -i"
#alias anki="/home/thekeymaster/Git/anki/run > /dev/null" 
#alias ls='ls -has --color=always'
alias c='clear'
alias h='history'
alias school='cd ~/Server/School/Second\ Year/Second\ Semester/'
alias projects='cd ~/Server/Projects'
alias df='df -h'
alias lsd='ls -d */'
alias update='sudo emerge -auDN --with-bdeps=y @world'
alias yt-dl='yt-dlp --download-archive /home/thekeymaster/archive.txt -f bestvideo+bestaudio --merge-output-format mkv'
alias here='xfce4-terminal --working-directory=$PWD'
alias krita='openclose krita'
alias cmpv='openclose mpv'
alias sioyek='detach ~/sioyek/Sioyek-x86_64.AppImage'
alias vpn='cd /home/thekeymaster/Mullvad/mullvad_config_linux_ca_tor; sudo openvpn --config /home/thekeymaster/Mullvad/mullvad_config_linux_ca_tor/mullvad_ca_tor.conf'
alias vim='nvim'
alias dotfiles='git --work-tree=$HOME --git-dir=$HOME/dotfiles.git' 

# Functions
detach() {
    nohup $@ > /dev/null &
    disown
}

openclose() {
    nohup $@ > /dev/null &
    disown
    exit
}

cd() {
    builtin cd "$@" && ls;
}

tor() {
    temp=$PWD
    builtin cd /home/thekeymaster/TOR/tor-browser_en-US
    ./start-tor-browser.desktop
    builtin cd $temp
    exit
}

PROMPT='%(!.%{$fg_bold[red]%}.%{$fg_bold[green]%}%n)%{%b%F{green}%} [%D{%I:%M %p}] %{$fg_bold[blue]%}%(!.%1~.%~) $(git_prompt_info)%{$fg_bold[green]%}>%{$reset_color%} '

export EDITOR=code
export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/thekeymaster/.mujoco/mujoco210/bin
export LD_PRELOAD=/usr/lib64/libGLEW.so
stty -ixon
neofetch

conda_init() {
    __conda_setup="$('/home/thekeymaster/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
    eval "$__conda_setup"
}

: '
# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/thekeymaster/anaconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/thekeymaster/anaconda3/etc/profile.d/conda.sh" ]; then
        . "/home/thekeymaster/anaconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/thekeymaster/anaconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<
'

[ -f "/home/thekeymaster/.ghcup/env" ] && source "/home/thekeymaster/.ghcup/env" # ghcup-env

unalias gp
