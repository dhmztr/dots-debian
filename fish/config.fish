# Disable greeting
set -U fish_greeting ""


# Debian ships some tools under other names: bat -> batcat, fd -> fdfind
if not command -q bat; and command -q batcat
    function bat --wraps batcat; batcat $argv; end
end
if not command -q fd; and command -q fdfind
    function fd --wraps fdfind; fdfind $argv; end
end

# Format man pages (through bat when available)
set -x MANROFFOPT -c
if command -q bat
    set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"
else if command -q batcat
    set -x MANPAGER "sh -c 'col -bx | batcat -l man -p'"
end

# Source fish_profile if exists
if test -f $HOME/.fish_profile
    source $HOME/.fish_profile
end

# PATH additions: user bins, cargo/go installs, neovim release tarball (/opt/nvim)
for p in $HOME/.local/bin $HOME/.cargo/bin $HOME/go/bin /opt/nvim/bin /opt/node/bin $HOME/.atuin/bin
    if test -d $p
        if not contains -- $p $PATH
            set -p PATH $p
        end
    end
end

#####################
### Key Bindings  ###
#####################
# Enable vim bindings
set -U fish_key_bindings fish_vi_key_bindings

# Always block cursor (disable cursor switching)
function fish_mode_prompt
    echo -n ''
end

# !! and !$ support
function __history_previous_command
    switch (commandline -t)
        case "!"
            commandline -t $history[1]
            commandline -f repaint
        case "*"
            commandline -i !
    end
end

function __history_previous_command_arguments
    switch (commandline -t)
        case "!"
            commandline -t ""
            commandline -f history-token-search-backward
        case "*"
            commandline -i '$'
    end
end

bind ! __history_previous_command
bind '$' __history_previous_command_arguments

##################
### Functions  ###
##################
# Better history
function fish_user_key_bindings
    # INSERT-mode shortcuts (while typing text)
    bind -M insert ! __history_previous_command
    bind -M insert '$' __history_previous_command_arguments

    # DEFAULT-mode shortcuts (command mode, after ESC)
    # Znak $ przenosi kursor na sam koniec linijki
    bind -M default '$' end-of-line
end
function history
    builtin history --show-time='%F %T '
end

function backup --argument filename
    cp $filename $filename.bak
end

# mkcd DIR
function mkcd
    mkdir -p $argv[1]; and cd $argv[1]
end

# Extract archives
function extract
    set file $argv[1]
    if test -f $file
        switch $file
            case '*.tar.bz2'
                tar xjf $file
            case '*.tar.gz'
                tar xzf $file
            case '*.bz2'
                bunzip2 $file
            case '*.rar'
                unrar x $file
            case '*.gz'
                gunzip $file
            case '*.tar'
                tar xvf $file
            case '*.tbz2'
                tar xjf $file
            case '*.tgz'
                tar xzf $file
            case '*.zip'
                unzip $file
            case '*.Z'
                uncompress $file
            case '*.7z'
                7z x $file
            case '*'
                echo "'$file' cannot be extracted via extract()"
        end
    else
        echo "'$file' is not a valid file"
    end
end

##################
### Aliases    ###
##################
# custom

alias up='sudo apt update; and sudo apt full-upgrade'
# ls replacements
if command -q eza
    alias ls='eza -al --color=always --group-directories-first --icons'
    alias la='eza -a --color=always --group-directories-first --icons'
    alias ll='eza -l --color=always --group-directories-first --icons'
    alias lt='eza -aT --color=always --group-directories-first --icons'
    alias l.='eza -a | grep -e "^\."'
end

# System helpers
alias grubup="sudo update-grub"
alias tarnow='tar -acf '
alias untar='tar -zxvf '
alias wget='wget -c '
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
# X11 (bspwm) uses xclip, a Wayland session wl-clipboard
if set -q WAYLAND_DISPLAY
    alias copy="wl-copy"
    alias paste="wl-paste"
else
    alias copy="xclip -selection clipboard"
    alias paste="xclip -selection clipboard -o"
end
if command -q bat; or command -q batcat
    alias cat='bat'
end

# Shortcuts
command -q journalctl; and alias jctl="journalctl -p 3 -xb"
alias ff='fastfetch'
alias q='exit'
alias h='history'
alias c='clear'

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gcl='git clone'
alias gl='git log --oneline'
alias gd='git diff'
alias gpush='git push'
alias gpull='git pull'

# System control
alias wifi='nmtui'
# systemctl only exists with systemd as init; plain poweroff works on any init
if command -q systemctl
    alias shutdown='systemctl poweroff'
else
    alias shutdown='sudo poweroff'
end
command -q dust; and alias du='dust'
if command -q zoxide
    zoxide init fish | source
    alias cd='z'
end
# atuin: SQLite shell history with fuzzy Ctrl-R search
command -q atuin; and atuin init fish | source

###################
### Environment ###
###################
set -gx SHELL_CONFIG_DIR $HOME/.config
set -gx EDITOR nvim
set -gx VISUAL nvim
set -gx SUDO_EDITOR nvim
set -gx GOPATH $HOME/go
set -gx CARGO_HOME $HOME/.cargo

###################
### Cargo #########
###################
# Size-optimized builds
alias cb='cargo build --release'
alias cr='cargo run --release'
# Tiny: max size shrink (opt-level=z, abort on panic - don't use for `cargo test`)
alias cbt "cargo build --release --config 'profile.release.opt-level=\"z\"' --config 'profile.release.panic=\"abort\"'"
alias ccl='cargo clean'
# lint every target (tests, examples, benches) with all features
alias clippy='cargo clippy --all-targets --all-features'
alias csize='cargo build --release; and du -sh target/release'
