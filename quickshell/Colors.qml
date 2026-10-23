pragma Singleton
import QtQuick

// Rosé Pine, same values as ghostty/config and wal/colors-wal.vim
QtObject {
    readonly property color background: "#191724"
    readonly property color surface:    "#1f1d2e"
    readonly property color foreground: "#e0def4"
    readonly property color muted:      "#6e6a86"
    readonly property color red:        "#eb6f92"
    readonly property color cyan:       "#9ccfd8"
    readonly property color yellow:     "#f6c177"
    readonly property color blue:       "#3986a6"
    readonly property color purple:     "#c4a7e7"
    readonly property color rose:       "#ebbcba"

    readonly property string font: "Iosevka Nerd Font"
}
