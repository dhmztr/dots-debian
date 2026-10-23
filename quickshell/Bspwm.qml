pragma Singleton
import QtQuick
import Quickshell.Io

// Desktop state from one long-lived `bspc subscribe report`. A report line
// looks like  WMeDP-1:o1:O2:f3:LT:TF:G:mHDMI-1:F1:...
//   M/m = monitor (focused/not), O/o occupied, F/f free, U/u urgent desktop;
//   upper case = focused on that monitor. L/T/G are layout/state flags.
QtObject {
    id: root

    // monitor name -> [{ monitor, index, name, focused, occupied, urgent }]
    property var monitors: ({})

    function desktops(monitorName) {
        const m = root.monitors
        if (m[monitorName]) return m[monitorName]
        // Qt and bspwm disagree on the name (single screen, Xvfb, ...)
        const keys = Object.keys(m)
        return keys.length === 1 ? m[keys[0]] : []
    }

    function _parse(line) {
        if (!line.startsWith("W")) return
        const out = {}
        let cur = null, curName = ""
        for (const item of line.slice(1).split(":")) {
            const k = item[0], v = item.slice(1)
            if (k === "M" || k === "m") {
                cur = out[v] = []
                curName = v
            } else if (cur && "OoFfUu".includes(k)) {
                cur.push({
                    monitor: curName,
                    index: cur.length + 1,
                    name: v,
                    focused: k === "O" || k === "F" || k === "U",
                    occupied: k === "O" || k === "o" || k === "U" || k === "u",
                    urgent: k === "U" || k === "u"
                })
            }
        }
        root.monitors = out
    }

    readonly property Process _sub: Process {
        command: ["bspc", "subscribe", "report"]
        running: true
        stdout: SplitParser { onRead: line => root._parse(line) }
        // bspwm restarted / not up yet: reconnect
        onExited: root._retry.start()
    }
    readonly property Timer _retry: Timer {
        interval: 1000
        onTriggered: root._sub.running = true
    }
}
