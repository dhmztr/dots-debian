#!/usr/bin/env bash
# Installs Maple Mono NF with some character variants frozen into the font,
# as the family "Maple Mono NF Patched":
#   cv04  upright `l` with a bottom bar (Consolas style) instead of the
#         right-hooked tail that reads like an `L` (else, elif, all ...)
#   cv35  italic `l` without the cursive loop; this also stops the italic
#         `el` / `ll` / `al` ... connected-stroke ligatures
# Freezing remaps the cmap, so it works everywhere (wezterm, quickshell,
# dunst), not only in apps that let you turn OpenType features on.
# Glyphs are also condensed horizontally (MAPLE_CONDENSE, default 0.88:
# 600 -> 528 units wide; Iosevka is 500), since the narrow/slim widths only
# exist in the unreleased v8. 1 keeps the original width.
# Re-run to update; it replaces ~/.local/share/fonts/maple-mono-patched.
set -euo pipefail

version="${MAPLE_VERSION:-v7.9}"
features="${MAPLE_FEATURES:-cv04,cv35}"
condense="${MAPLE_CONDENSE:-0.88}"
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

# condense horizontally, then rename family + PostScript names so it never
# clashes with a stock Maple Mono NF install
echo "condense  x$condense"
"$work/venv/bin/python" - "$condense" "$work"/out/*.ttf <<'EOF'
import sys
from fontTools.ttLib import TTFont

X_ATTRS = ("XCoordinate", "XPlacement", "XAdvance", "Coordinate")

def scale_ot(obj, f, seen):
    # x values in GPOS (anchors, placements, advances) and GDEF carets
    if obj is None or id(obj) in seen:
        return
    seen.add(id(obj))
    if isinstance(obj, list):
        for o in obj:
            scale_ot(o, f, seen)
        return
    if not hasattr(obj, "__dict__"):
        return
    for k, v in list(vars(obj).items()):
        if k in X_ATTRS and isinstance(v, int):
            setattr(obj, k, round(v * f))
        elif hasattr(v, "__dict__") or isinstance(v, list):
            scale_ot(v, f, seen)

def condense(font, f):
    glyf, hmtx = font["glyf"], font["hmtx"]
    order = font.getGlyphOrder()
    for name in order:
        g = glyf[name]
        if g.isComposite():
            for c in g.components:
                c.x = round(c.x * f)
        elif g.numberOfContours > 0:
            g.coordinates.scale((f, 1))
            g.coordinates.toInt()
        hmtx[name] = (round(hmtx[name][0] * f), hmtx[name][1])
    for name in order:  # bounds after all simple glyphs are scaled
        g = glyf[name]
        g.recalcBounds(glyf)
        hmtx[name] = (hmtx[name][0], getattr(g, "xMin", 0))
    if "GPOS" in font:
        scale_ot(font["GPOS"].table, f, set())
    if "GDEF" in font and font["GDEF"].table.LigCaretList:
        scale_ot(font["GDEF"].table.LigCaretList, f, set())
    font["OS/2"].xAvgCharWidth = round(font["OS/2"].xAvgCharWidth * f)
    font["hhea"].advanceWidthMax = max(a for a, _ in hmtx.metrics.values())
    for t in ("hdmx", "LTSH", "VDMX"):  # device metrics no longer valid
        if t in font:
            del font[t]

factor = float(sys.argv[1])
for path in sys.argv[2:]:
    font = TTFont(path)
    if factor != 1:
        condense(font, factor)
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
