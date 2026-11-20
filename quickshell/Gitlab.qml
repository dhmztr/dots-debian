pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Your GitLab merge requests (bin/gitlab-status, through glab), refreshed
// every 3 minutes and on demand. ok = false (glab missing / not logged in)
// hides the bar island.
QtObject {
    id: root

    property bool ok: false
    property string error: ""
    property var mine: []      // [{ title, url, ref, pipeline, merge, draft }]
    property var review: []    // [{ title, url, author }]

    // worst pipeline over your MRs: failed > running > success > none
    readonly property string state: {
        const st = root.mine.map(m => m.pipeline)
        if (st.some(s => s === "failed" || s === "canceled")) return "failed"
        if (st.some(s => ["running", "pending", "created", "preparing", "waiting_for_resource"].includes(s))) return "running"
        if (st.length && st.every(s => s === "success" || s === "skipped" || s === "manual")) return "success"
        return "none"
    }

    function refresh() { proc.running = false; proc.running = true }

    readonly property Process proc: Process {
        command: ["gitlab-status"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(this.text)
                    root.ok = d.ok
                    root.error = d.error || ""
                    if (d.ok) { root.mine = d.mine; root.review = d.review }
                } catch (e) { root.ok = false; root.error = String(e) }
            }
        }
    }
    readonly property Timer tick: Timer {
        interval: 180000; running: true; repeat: true
        onTriggered: root.refresh()
    }
}
