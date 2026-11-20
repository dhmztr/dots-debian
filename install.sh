#!/usr/bin/env bash
# Links fish, wezterm, nvim, xmonad, picom and quickshell configs from this repo
# into ~/.config, the helper scripts into ~/.local/bin, and puts the nvim
# palette in ~/.cache/wal. Existing configs are moved to *.bak-<date>.
set -euo pipefail

repo="$(cd "$(dirname "$0")" && pwd)"
stamp="$(date +%Y%m%d-%H%M%S)"

link() { # link <repo path> <target>
    local src="$repo/$1" dst="$2"
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
        echo "ok      $dst"
        return
    fi
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mv "$dst" "$dst.bak-$stamp"
        echo "backup  $dst -> $dst.bak-$stamp"
    fi
    ln -s "$src" "$dst"
    echo "linked  $dst -> $src"
}

link fish    "$HOME/.config/fish"
link wezterm "$HOME/.config/wezterm"
link nvim    "$HOME/.config/nvim"
link xmonad     "$HOME/.config/xmonad"
link picom      "$HOME/.config/picom"
link quickshell "$HOME/.config/quickshell"
link dunst      "$HOME/.config/dunst"
link lazygit    "$HOME/.config/lazygit"
for f in "$repo"/bin/*; do
    link "bin/$(basename "$f")" "$HOME/.local/bin/$(basename "$f")"
done

# startx -> xmonad, unless ~/.xinitrc already exists
if [ ! -e "$HOME/.xinitrc" ]; then
    cp "$repo/xinitrc" "$HOME/.xinitrc"
    echo "copied  ~/.xinitrc"
else
    echo "kept    ~/.xinitrc (see xinitrc in the repo)"
    grep -q bspwm "$HOME/.xinitrc" &&
        echo "        it still starts bspwm: replace 'bspwm' with 'xmonad' in it"
fi

# compile the xmonad config now, so a typo shows up here and not as a
# black screen after startx (build output goes to ~/.cache/xmonad)
if command -v xmonad >/dev/null; then
    xmonad --recompile && echo "built   xmonad config" ||
        echo "xmonad --recompile failed, see the errors above"
fi

# git: delta as pager (git/delta.gitconfig), included from ~/.gitconfig
if ! git config --global --get-all include.path 2>/dev/null | grep -qx "$repo/git/delta.gitconfig"; then
    git config --global --add include.path "$repo/git/delta.gitconfig"
    echo "added   include of git/delta.gitconfig to ~/.gitconfig"
else
    echo "ok      ~/.gitconfig includes git/delta.gitconfig"
fi

# neopywal (nvim colorscheme) reads its palette from here
mkdir -p "$HOME/.cache/wal"
cp "$repo/wal/colors-wal.vim" "$HOME/.cache/wal/colors-wal.vim"
echo "copied  ~/.cache/wal/colors-wal.vim"

if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish || true)" ]; then
    echo
    echo "fish is not your login shell yet:  chsh -s \"\$(command -v fish)\""
fi
