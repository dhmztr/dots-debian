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
    PolkitDialog {}

    // super+alt+w: reload the config in place. Killing the process instead
    // would drop the tray (StatusNotifierWatcher) and apps like Slack only
    // register their icon once, at startup.
    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(false) }
    }
}
