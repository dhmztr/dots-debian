# Modern CLI tool integrations + aliases.
# conf.d loads before config.fish, so atuin (config.fish) reclaims Ctrl-R after
# fzf's keybindings are installed here.

# ── shell integrations (guarded so a missing binary is silent) ──
if command -q fzf
    fzf --fish | source          # Ctrl-T files, Alt-C cd (Ctrl-R goes to atuin)
end
if command -q direnv
    direnv hook fish | source     # auto-load .envrc per directory
end

# ── aliases (only the syntax-compatible ones shadow originals) ──
# each only when the tool is installed, so a missing one keeps the original command
function __alias_if --argument-names name tool
    command -q $tool; and alias $name "$argv[3..-1]"
end
__alias_if df    duf     duf        # disk usage
__alias_if dig   doggo   doggo      # DNS lookup
__alias_if http  xh      xh         # HTTP client
__alias_if help  tldr    tldr       # cheat-sheet man pages
__alias_if loc   tokei   tokei      # count lines of code
__alias_if unpack ouch   ouch d     # extract any archive
__alias_if pack  ouch    ouch c     # compress to any archive
__alias_if j     just    just       # command runner
__alias_if zj    zellij  zellij     # terminal multiplexer
__alias_if pp    procs   procs      # processes (ps kept native)
__alias_if gp    gping   gping      # ping with a graph
__alias_if f     fzf     fzf        # fuzzy finder
functions -e __alias_if

# ── yazi: cd into the directory you quit in ──
function y --wraps yazi --description "yazi, cd on exit"
    set -l tmp (mktemp -t yazi-cwd.XXXXXX)
    yazi $argv --cwd-file="$tmp"
    if set -l cwd (command cat -- "$tmp"); and test -n "$cwd"; and test "$cwd" != "$PWD"
        builtin cd -- "$cwd"
    end
    rm -f -- "$tmp"
end

# ── broot: navigate and cd on exit ──
function br --wraps broot --description "broot, cd on exit"
    set -l cmd_file (mktemp)
    if broot --outcmd "$cmd_file" $argv
        read --local --null cmd <"$cmd_file"
        rm -f "$cmd_file"
        eval "$cmd"
    else
        set -l code $status
        rm -f "$cmd_file"
        return $code
    end
end
