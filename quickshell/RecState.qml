pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen recording indicator state. `screenrec` reports start/stop over IPC
// (`quickshell ipc call rec started <file>` / `rec stopped`); on shell start
// its pid file is checked once, so a restart mid-recording keeps the dot.
QtObject {
    id: root

    property bool active: false
    property real startedAt: 0      // ms since epoch
    property int elapsed: 0         // seconds, ticks only while recording

    readonly property string clock: {
        const m = Math.floor(elapsed / 60), s = elapsed % 60
        return m + ":" + (s < 10 ? "0" : "") + s
    }

    // the same command as the keybinding: a second run stops and saves
    function stop() { _stopProc.running = false; _stopProc.running = true }

    readonly property IpcHandler _ipc: IpcHandler {
        target: "rec"
        function started(file: string): void {
            root.startedAt = Date.now()
            root.elapsed = 0
            root.active = true
        }
        function stopped(): void { root.active = false; root.elapsed = 0 }
    }

    readonly property Timer _tick: Timer {
        interval: 1000; repeat: true; running: root.active
        onTriggered: root.elapsed = Math.round((Date.now() - root.startedAt) / 1000)
    }

    readonly property Process _stopProc: Process { command: ["screenrec"] }

    readonly property Process _check: Process {
        running: true
        command: ["sh", "-c", 'r="${XDG_RUNTIME_DIR:-/tmp}/screenrec-$(id -u)"; [ -f "$r.pid" ] && kill -0 "$(cat "$r.pid")" 2>/dev/null && stat -c %Y "$r.pid"']
        stdout: StdioCollector {
            onStreamFinished: {
                const t = parseInt(this.text.trim())
                if (isNaN(t)) return
                root.startedAt = t * 1000
                root.elapsed = Math.round((Date.now() - root.startedAt) / 1000)
                root.active = true
            }
        }
    }
}
