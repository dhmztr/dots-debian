#!/usr/bin/env bash
# Installs Maple Mono NF with some character variants frozen into the font,
# as the family "Maple Mono NF Patched":
#   cv04  upright `l` with a bottom bar (Consolas style) instead of the
#         right-hooked tail that reads like an `L` (else, elif, all ...)
#   cv35  italic `l` without the cursive loop; this also stops the italic
#         `el` / `ll` / `al` ... connected-stroke ligatures
# Freezing remaps the cmap, so it works everywhere (ghostty, quickshell,
# dunst), not only in apps that let you turn OpenType features on.
# Re-run to update; it replaces ~/.local/share/fonts/maple-mono-patched.
set -euo pipefail

version="${MAPLE_VERSION:-v7.9}"
features="${MAPLE_FEATURES:-cv04,cv35}"
url="https://github.com/subframe7536/maple-font/releases/download/$version/MapleMono-NF-unhinted.zip"
dest="$HOME/.local/share/fonts/maple-mono-patched"

for cmd in curl unzip python3 fc-cache; do
    command -v "$cmd" >/dev/null || { echo "missing: $cmd" >&2; exit 1; }
done

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

echo "download  Maple Mono NF $version"
curl -fsSL -o "$work/maple.zip" "$url"
unzip -q "$work/maple.zip" -d "$work/src"

echo "venv      opentype-feature-freezer"
python3 -m venv "$work/venv"
"$work/venv/bin/pip" install -q opentype-feature-freezer

mkdir -p "$work/out"
for f in "$work"/src/MapleMono-NF-*.ttf; do
    name="$(basename "$f" | sed 's/^MapleMono-NF-/MapleMono-NF-Patched-/')"
    "$work/venv/bin/pyftfeatfreeze" -f "$features" "$f" "$work/out/$name" 2>/dev/null
    echo "patched   $name"
done

# rename family + PostScript names so it never clashes with a stock
# Maple Mono NF install
"$work/venv/bin/python" - "$work"/out/*.ttf <<'EOF'
import sys
from fontTools.ttLib import TTFont
for path in sys.argv[1:]:
    font = TTFont(path)
    for rec in font["name"].names:
        s = rec.toUnicode()
        s = s.replace("Maple Mono NF", "Maple Mono NF Patched")
        s = s.replace("MapleMono-NF", "MapleMono-NF-Patched")
        rec.string = s
    font.save(path)
EOF

rm -rf "$dest"
mkdir -p "$dest"
cp "$work"/out/*.ttf "$work/src/LICENSE.txt" "$dest/"
fc-cache -f "$dest"
echo "installed $dest"
fc-list : family | grep -m1 'Maple Mono NF Patched' || {
    echo "fontconfig does not see 'Maple Mono NF Patched'" >&2
    exit 1
}
