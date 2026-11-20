pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Slack on the bar, independent of its tray icon:
//   installed / running  from `command -v slack` / `pgrep -x slack`
//   unread               Slack notifications counted by dunst
//                        (dunst/slack-count -> $XDG_RUNTIME_DIR/slack-unread),
//                        reset when a Slack window gets focus or on click
QtObject {
    id: root

    property bool installed: false
    property bool running: false
    property int unread: 0
    property string lastFrom: ""

    readonly property string file: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/slack-unread"

    function reset() {
        if (root.unread === 0) return
        root.unread = 0
        Quickshell.execDetached(["sh", "-c", "printf '0\\t\\n' > \"$1\"", "sh", root.file])
    }
    function open() {
        root.reset()
        Quickshell.execDetached(["slack"])
    }

    // focusing Slack counts as reading it
    readonly property Connections _focus: Connections {
        target: Xmonad
        function onAppClassChanged() { if (Xmonad.appClass === "Slack") root.reset() }
    }

    readonly property Process _poll: Process {
        command: ["sh", "-c", "command -v slack >/dev/null && echo 1 || echo 0; pgrep -x slack >/dev/null && echo 1 || echo 0; cat \"$1\" 2>/dev/null", "sh", root.file]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.split("\n")
                root.installed = l[0] === "1"
                root.running = l[1] === "1"
                const f = (l[2] || "").split("\t")
                const n = parseInt(f[0])
                // a Slack window is focused right now: whatever arrived is read
                if (Xmonad.appClass === "Slack" && n > 0) { root.unread = n; root.reset(); return }
                root.unread = isNaN(n) ? 0 : n
                root.lastFrom = f[1] || ""
            }
        }
    }
    readonly property Timer _tick: Timer {
        interval: 1500; running: true; repeat: true
        onTriggered: { root._poll.running = false; root._poll.running = true }
    }
}
