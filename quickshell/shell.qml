//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
// Minimal shell for bspwm (X11): bar on every screen, app launcher, polkit agent.
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Launcher {}
    // polkit agent (password dialog). Needs quickshell built with polkit
    // (README 0.1); loaded by file so that on an older build only this part
    // fails ("module Quickshell.Services.Polkit is not installed") and the
    // bar and launcher still come up
    LazyLoader {
        active: true
        source: Qt.resolvedUrl("PolkitDialog.qml")
    }

    // super+alt+w: reload the config in place. Killing the process instead
    // would drop the tray (StatusNotifierWatcher) and apps like Slack only
    // register their icon once, at startup.
    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(false) }
    }
}
