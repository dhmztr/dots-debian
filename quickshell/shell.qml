//@ pragma UseQApplication
//@ pragma IconTheme Papirus-Dark
// Shell for xmonad (X11): top bar on every screen, app launcher, key
// overview (super+s) and the layout pop-up.
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }
    Launcher {}
    Help {}
    Clipboard {}

    // xmonad's layout keys: `quickshell ipc call osd layout <name>`
    IpcHandler {
        target: "osd"
        function layout(name: string): void { Osd.showLayout(name) }
    }

    // super+alt+w: reload the config in place. Killing the process instead
    // would drop the tray (StatusNotifierWatcher) and apps like Slack only
    // register their icon once, at startup.
    IpcHandler {
        target: "shell"
        function reload(): void { Quickshell.reload(false) }
    }
}
