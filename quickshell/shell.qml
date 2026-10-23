//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
// Minimal shell for bspwm (X11): bar on every screen + app launcher.
import QtQuick
import Quickshell

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Launcher {}
}
