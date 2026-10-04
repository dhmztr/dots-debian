# Render markdown in glow instead of dumping raw text.
# `cat file.md` and `open file.md` pipe through glow; everything else is normal.

function _is_md --argument-names path
    command -q glow; and test -f "$path"; and string match -qr '(?i)\.(md|markdown)$' -- "$path"
end

function cat --wraps cat --description "cat, but render .md with glow"
    if test (count $argv) -eq 1; and _is_md "$argv[1]"
        glow "$argv[1]"
    else
        command cat $argv
    end
end

function open --wraps xdg-open --description "open files; render .md with glow"
    if test (count $argv) -eq 1; and _is_md "$argv[1]"
        glow "$argv[1]"
    else
        xdg-open $argv
    end
end
