# Save an image from the clipboard (X11 or Wayland) to a file.
#   clipsave              -> ~/Pictures/Screenshots/clip-<timestamp>.png
#   clipsave shot.png     -> ./shot.png
#   clipsave ~/foo/a.jpg  -> chooses matching type if the clipboard has it
function clipsave --description 'Save clipboard image to a file'
    if set -q WAYLAND_DISPLAY
        set -f types (wl-paste --list-types 2>/dev/null)
    else
        set -f types (xclip -selection clipboard -t TARGETS -o 2>/dev/null)
    end
    if not string match -qr '^image/' -- $types
        echo "clipsave: no image in clipboard (have: $types)" >&2
        return 1
    end

    set -l out $argv[1]
    if test -z "$out"
        set -l dir ~/Pictures/Screenshots
        mkdir -p $dir
        set out $dir/clip-(date +%Y%m%d-%H%M%S).png
    end

    # pick a clipboard type matching the target extension, else first image type
    set -l ext (string lower (path extension -- $out | string trim -c .))
    set -l want image/png
    switch $ext
        case jpg jpeg; set want image/jpeg
        case webp;     set want image/webp
        case '*';      set want image/png
    end
    if not contains -- $want $types
        set want (string match -r '^image/[^ ]+' -- $types | head -1)
    end

    if set -q WAYLAND_DISPLAY
        wl-paste --type $want > $out 2>/dev/null
    else
        xclip -selection clipboard -t $want -o > $out 2>/dev/null
    end
    if test $status -eq 0 -a -s $out
        echo $out
    else
        echo "clipsave: failed writing $out" >&2
        rm -f -- $out
        return 1
    end
end
