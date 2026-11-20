pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Upcoming meetings (bin/next-meeting, Google Calendar's secret iCal
// address). The feed is re-read every 5 minutes (the script caches the
// download for 10); the countdown ticks every 20 s. Two minutes before a
// meeting starts a notification with its Meet link goes out.
QtObject {
    id: root

    property bool ok: false
    property var events: []        // [{ title, start, end, link }]
    property date now: new Date()

    // the meeting on now, else the next one
    readonly property var next: {
        const t = root.now.getTime()
        for (const e of root.events)
            if (new Date(e.end).getTime() > t) return e
        return null
    }
    readonly property bool ongoing: next !== null && new Date(next.start).getTime() <= now.getTime()
    readonly property int minutes: next === null ? 0
        : Math.ceil((new Date(next.start).getTime() - now.getTime()) / 60000)

    function open(e) {
        Quickshell.execDetached(["xdg-open", (e && e.link) ? e.link : "https://calendar.google.com"])
    }
    function refresh() { proc.running = false; proc.running = true }

    property var _notified: ({})
    function _remind() {
        const e = root.next
        if (!e || root.ongoing || root.minutes > 2) return
        const key = e.title + e.start
        if (root._notified[key]) return
        root._notified[key] = true
        Quickshell.execDetached(["notify-send", "-a", "calendar", "-u", "critical",
                                 "Za " + root.minutes + " min: " + e.title, e.link || ""])
    }

    readonly property Process proc: Process {
        command: ["next-meeting"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    root.ok = d.ok
                    if (d.ok) root.events = d.events
                } catch (e) { root.ok = false }
            }
        }
    }
    readonly property Timer feed: Timer {
        interval: 300000; running: true; repeat: true
        onTriggered: root.refresh()
    }
    readonly property Timer clock: Timer {
        interval: 20000; running: true; repeat: true
        onTriggered: { root.now = new Date(); root._remind() }
    }
}
