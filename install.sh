#!/usr/bin/env bash
# Links fish, ghostty and nvim configs from this repo into ~/.config and puts
# the nvim palette in ~/.cache/wal. Existing configs are moved to *.bak-<date>.
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

# neopywal (nvim colorscheme) reads its palette from here
mkdir -p "$HOME/.cache/wal"
cp "$repo/wal/colors-wal.vim" "$HOME/.cache/wal/colors-wal.vim"
echo "copied  ~/.cache/wal/colors-wal.vim"

if [ "$(getent passwd "$USER" | cut -d: -f7)" != "$(command -v fish || true)" ]; then
    echo
    echo "fish is not your login shell yet:  chsh -s \"\$(command -v fish)\""
fi
