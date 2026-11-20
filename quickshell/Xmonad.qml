pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// xmonad state. xmonad.hs (barLog) publishes JSON in the _XMONAD_LOG root
// property on every change; `xprop -spy` prints one line per change:
//   _XMONAD_LOG(UTF8_STRING) = "{\"focusedScreen\":0,...}"
// xprop escapes " and \ with a backslash; everything else is ASCII (xmonad
// \u-escapes non-ASCII), so undoing that gives plain JSON.
QtObject {
    id: root

    property int focusedScreen: 0
    property string title: ""          // focused window
    property string appClass: ""       // its WM_CLASS
    // [{ id, x, y, w, h, ws, layout }]
    property var screens: []
    // [{ name, screen (-1 = hidden), urgent, apps: [class, ...] }]
    property var workspaces: []

    // xmonad screen shown on a Quickshell screen (matched by position)
    function screenFor(qsScreen) {
        for (const s of root.screens)
            if (s.x === qsScreen.x && s.y === qsScreen.y) return s
        return root.screens.length === 1 ? root.screens[0] : null
    }

    // workspaces are switched through EWMH (_NET_CURRENT_DESKTOP), which
    // xmonad's ewmh hook handles; index = position in the workspace list
    function view(name) {
        const i = root.workspaces.findIndex(w => w.name === name)
        if (i >= 0) Quickshell.execDetached(["xdotool", "set_desktop", String(i)])
    }
    function cycle(step) {
        const n = root.workspaces.length
        const cur = root.screens.find(s => s.id === root.focusedScreen)
        if (!n || !cur) return
        const i = root.workspaces.findIndex(w => w.name === cur.ws)
        Quickshell.execDetached(["xdotool", "set_desktop", String((i + step + n) % n)])
    }
    // keys go through xmonad's own bindings
    function key(combo) { Quickshell.execDetached(["xdotool", "key", combo]) }

    function _parse(line) {
        const at = line.indexOf(" = \"")
        if (at < 0) return   // "_XMONAD_LOG:  not found." before xmonad is up
        const body = line.slice(at + 4, line.lastIndexOf("\""))
        try {
            const d = JSON.parse(body.replace(/\\(.)/g, "$1"))
            root.focusedScreen = d.focusedScreen
            root.title = d.title
            root.appClass = d["class"]
            root.screens = d.screens
            root.workspaces = d.workspaces
        } catch (e) {
            console.warn("xmonad state: " + e)
        }
    }

    readonly property Process _spy: Process {
        command: ["xprop", "-root", "-spy", "_XMONAD_LOG"]
        running: true
        stdout: SplitParser { onRead: line => root._parse(line) }
        // X restarted / xprop missing: try again
        onExited: root._retry.start()
    }
    readonly property Timer _retry: Timer {
        interval: 2000
        onTriggered: root._spy.running = true
    }
}
