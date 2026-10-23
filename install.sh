#!/usr/bin/env bash
# Links fish, ghostty, nvim, bspwm, sxhkd and quickshell configs from this repo
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
link ghostty "$HOME/.config/ghostty"
link nvim    "$HOME/.config/nvim"
link bspwm      "$HOME/.config/bspwm"
link sxhkd      "$HOME/.config/sxhkd"
link quickshell "$HOME/.config/quickshell"
link dunst      "$HOME/.config/dunst"
for f in "$repo"/bin/*; do
    link "bin/$(basename "$f")" "$HOME/.local/bin/$(basename "$f")"
done

# startx -> bspwm, unless ~/.xinitrc already exists
if [ ! -e "$HOME/.xinitrc" ]; then
    cp "$repo/xinitrc" "$HOME/.xinitrc"
    echo "copied  ~/.xinitrc"
else
    echo "kept    ~/.xinitrc (see xinitrc in the repo)"
fi

# neopywal (nvim colorscheme) reads its palette from here
mkdir -p "$HOME/.cache/wal"
cp "$repo/wal/colors-wal.vim" "$HOME/.cache/wal/colors-wal.vim"
echo "copied  ~/.cache/wal/colors-wal.vim"

if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish || true)" ]; then
    echo
    echo "fish is not your login shell yet:  chsh -s \"\$(command -v fish)\""
fi
