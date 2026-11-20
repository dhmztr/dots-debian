pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Focus mode = dunst paused (super+d or a click on the bar icon). While on,
// notifications queue up silently; `waiting` counts them, they all show up
// when focus mode ends.
QtObject {
    id: root

    property bool paused: false
    property int waiting: 0

    function toggle() {
        Quickshell.execDetached(["dunstctl", "set-paused", "toggle"])
        root.paused = !root.paused
        delay.restart()
    }

    readonly property Process proc: Process {
        command: ["sh", "-c", "dunstctl is-paused 2>/dev/null; dunstctl count waiting 2>/dev/null"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                const l = this.text.trim().split("\n")
                root.paused = l[0] === "true"
                root.waiting = parseInt(l[1]) || 0
            }
        }
    }
    readonly property Timer tick: Timer {
        interval: 2000; running: true; repeat: true
        onTriggered: { root.proc.running = false; root.proc.running = true }
    }
    readonly property Timer delay: Timer {
        interval: 300
        onTriggered: { root.proc.running = false; root.proc.running = true }
    }
}
