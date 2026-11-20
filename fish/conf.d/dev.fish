# Development helpers: long-command notifications, a git worktree per task,
# the ticket number in commit messages, build caches.

# ---- notify when a long command finishes ------------------------------------
# Anything that ran longer than $notify_after_ms (default 30 s) sends a
# notification when it ends, unless this terminal window is the focused one
# (WINDOWID is set by wezterm; without it the notification always goes out).
# Interactive programs (editors, pagers, shells) never notify.
set -q notify_after_ms; or set -g notify_after_ms 30000
set -g __notify_skip nvim vim vi less man lazygit yazi btop htop ssh tig glow fish bash zellij

function __notify_long_command --on-event fish_postexec
    set -l status_code $status
    test "$CMD_DURATION" -ge $notify_after_ms; or return
    set -l cmd (string split -m1 ' ' -- $argv[1])[1]
    contains -- $cmd $__notify_skip; and return
    command -q notify-send; or return
    if set -q WINDOWID; and command -q xdotool
        test (xdotool getactivewindow 2>/dev/null) = "$WINDOWID"; and return
    end
    set -l secs (math -s0 $CMD_DURATION / 1000)
    set -l took (math -s0 $secs / 60)m(math -s0 $secs % 60)s
    if test $status_code -eq 0
        notify-send -a terminal "✓ done in $took" "$argv[1]"
    else
        notify-send -a terminal -u critical "✗ failed ($status_code) after $took" "$argv[1]"
    end
end

# ---- git worktree per task ----------------------------------------------------
# wt 108277 bookmark-cls  -> branch 108277-bookmark-cls in ../<repo>-108277,
#                            cd there, ticket hook installed
# wt 108277               -> same, branch "108277" (or an existing branch
#                            that starts with "108277-")
# wt                      -> list worktrees;  wt rm 108277 -> remove one
function wt --description 'git worktree per task: wt <ticket> [name] | wt rm <ticket> | wt'
    set -l top (git rev-parse --show-toplevel 2>/dev/null)
    or begin; echo "wt: not in a git repository" >&2; return 1; end
    # the main checkout, also when called from inside another worktree
    set -l main (dirname (git rev-parse --path-format=absolute --git-common-dir))
    set -l repo (basename $main)

    if test (count $argv) -eq 0
        git worktree list
        return
    end
    if test "$argv[1]" = rm
        set -l dir (dirname $main)/$repo-$argv[2]
        git -C $main worktree remove $dir; and echo "removed $dir"
        return
    end

    set -l ticket $argv[1]
    set -l dir (dirname $main)/$repo-$ticket
    if test -d $dir
        cd $dir
        return
    end
    set -l branch $ticket
    if test (count $argv) -ge 2
        set branch $ticket-(string join - $argv[2..-1])
    else
        # reuse an existing local branch for this ticket
        set -l existing (git -C $main branch --list "$ticket-*" --format='%(refname:short)')[1]
        test -n "$existing"; and set branch $existing
    end
    if git -C $main show-ref --verify --quiet refs/heads/$branch
        git -C $main worktree add $dir $branch; or return
    else
        git -C $main worktree add -b $branch $dir; or return
    end
    cd $dir
    ticket-hook
end

# ---- ticket number in commit messages -----------------------------------------
# ticket-hook: install a prepare-commit-msg hook in the current repository
# that starts every commit message with the number at the front of the branch
# name (108277-bookmark-cls -> "108277: "). Leaves existing hooks alone.
function ticket-hook --description 'prefix commit messages with the ticket number from the branch'
    set -l hooks (git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)/hooks
    or begin; echo "ticket-hook: not in a git repository" >&2; return 1; end
    set -l hook $hooks/prepare-commit-msg
    if test -e $hook
        grep -q 'dots-debian ticket hook' $hook; and return
        echo "ticket-hook: $hook already exists, not touching it" >&2
        return 1
    end
    mkdir -p $hooks
    printf '%s\n' '#!/bin/sh' \
        '# dots-debian ticket hook: "<number>-..." branch -> "<number>: " prefix' \
        'case "$2" in merge|squash|commit) exit 0 ;; esac' \
        'ticket=$(git symbolic-ref --short HEAD 2>/dev/null | grep -oE "^[0-9]+")' \
        '[ -n "$ticket" ] || exit 0' \
        'grep -qE "^$ticket[: ]" "$1" && exit 0' \
        'sed -i "1s/^/$ticket: /" "$1"' > $hook
    chmod +x $hook
    echo "ticket-hook: installed in $hook"
end

# ---- build caches and a faster linker -----------------------------------------
# sccache caches rustc (and C/C++ via CC wrappers) results across builds and
# worktrees; only set when it is installed
if command -q sccache; and not set -q RUSTC_WRAPPER
    set -gx RUSTC_WRAPPER sccache
end

# mold links Rust binaries several times faster than ld. Set through the
# linker (bin/cc-mold = cc -fuse-ld=mold), not RUSTFLAGS, so a project's own
# rustflags stay in effect.
if command -q mold; and command -q cc-mold; and not set -q CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER
    set -gx CARGO_TARGET_X86_64_UNKNOWN_LINUX_GNU_LINKER cc-mold
end

# ccache for C/C++ built with CMake (3.17+ reads these); for gn builds put
# cc_wrapper = "ccache" in args.gn instead
if command -q ccache
    set -q CMAKE_C_COMPILER_LAUNCHER; or set -gx CMAKE_C_COMPILER_LAUNCHER ccache
    set -q CMAKE_CXX_COMPILER_LAUNCHER; or set -gx CMAKE_CXX_COMPILER_LAUNCHER ccache
end
