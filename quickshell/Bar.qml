import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// Top bar, one per screen: floating rounded "islands" on a transparent
// window (picom does the transparency; without a compositor the gaps
// between islands are black).
//   left:   launcher button, workspaces with the icons of their windows, layout
//   middle: the active window (icon + title)
//   right:  recording, Slack, volume, battery, tray, clock
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors { top: true; left: true; right: true }
    margins { top: 8; left: 10; right: 10 }
    implicitHeight: 38
    color: "transparent"

    // xmonad screen this bar sits on
    readonly property var xs: Xmonad.screenFor(modelData)
    readonly property bool focusedHere: xs !== null && xs.id === Xmonad.focusedScreen

    function tint(c, a) { return Qt.rgba(c.r, c.g, c.b, a) }

    // WM_CLASS -> icon path ("" when the icon theme has nothing)
    function iconFor(cls) {
        if (!cls) return ""
        const aliases = { "scratch-term": "utilities-terminal", "scratch-btop": "btop",
                          "keys": "preferences-desktop-keyboard-shortcuts" }
        for (const name of [aliases[cls], cls, cls.toLowerCase(), cls.split(".").pop().toLowerCase()]) {
            if (!name) continue
            const p = Quickshell.iconPath(name, true)
            if (p) return p
        }
        return ""
    }

    component Island: Rectangle {
        height: root.height
        radius: 12
        color: Colors.surface
        border { width: 1; color: Qt.rgba(1, 1, 1, 0.05) }
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    }
    component Glyph: Text {
        font { family: Colors.font; pixelSize: 16 }
        color: Colors.foreground
        verticalAlignment: Text.AlignVCenter
    }

    // scroll anywhere on the bar: previous / next workspace
    WheelHandler { onWheel: e => Xmonad.cycle(e.angleDelta.y > 0 ? -1 : 1) }

    // =========================================================================
    // left: launcher, workspaces, layout
    // =========================================================================
    Row {
        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
        spacing: 8

        // launcher
        Island {
            width: height
            Glyph {
                anchors.centerIn: parent
                text: "" // debian swirl
                color: logoMouse.containsMouse ? Colors.rose : Colors.purple
                font.pixelSize: 18
                Behavior on color { ColorAnimation { duration: 150 } }
            }
            MouseArea {
                id: logoMouse
                anchors.fill: parent
                hoverEnabled: true
                onClicked: Quickshell.execDetached(["quickshell", "ipc", "call", "launcher", "toggle"])
            }
        }

        // workspaces: a pill per workspace; the one on this screen is lit and
        // wider, occupied ones show the icons of their windows (up to 3), one
        // shown on another monitor gets an outline, urgent ones turn red
        Island {
            width: wsRow.implicitWidth + 12
            Row {
                id: wsRow
                anchors.centerIn: parent
                spacing: 4
                Repeater {
                    model: Xmonad.workspaces
                    delegate: Rectangle {
                        id: ws
                        required property var modelData
                        readonly property bool here: root.xs !== null && modelData.screen === root.xs.id
                        readonly property bool elsewhere: modelData.screen >= 0 && !here
                        readonly property bool occupied: modelData.apps.length > 0
                        readonly property var apps: {
                            const seen = []
                            for (const a of modelData.apps) if (!seen.includes(a)) seen.push(a)
                            return seen.slice(0, 3)
                        }

                        height: 26
                        radius: 9
                        width: content.implicitWidth + (here ? 20 : 12)
                        color: modelData.urgent ? root.tint(Colors.red, 0.25)
                             : here ? root.tint(Colors.purple, root.focusedHere ? 0.28 : 0.16)
                             : wsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                        border { width: elsewhere ? 1 : 0; color: root.tint(Colors.purple, 0.45) }
                        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                        Behavior on color { ColorAnimation { duration: 180 } }

                        Row {
                            id: content
                            anchors.centerIn: parent
                            spacing: 5
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: ws.modelData.name
                                font { family: Colors.font; pixelSize: 13; bold: ws.here }
                                color: ws.modelData.urgent ? Colors.red
                                     : ws.here ? Colors.purple
                                     : ws.occupied || ws.elsewhere ? Colors.foreground : Colors.muted
                                Behavior on color { ColorAnimation { duration: 180 } }
                            }
                            Repeater {
                                model: ws.apps
                                delegate: Item {
                                    id: app
                                    required property string modelData
                                    readonly property string icon: root.iconFor(modelData)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 16; height: 16
                                    Image {
                                        anchors.fill: parent
                                        visible: app.icon !== ""
                                        source: app.icon
                                        sourceSize { width: 32; height: 32 }
                                        smooth: true
                                    }
                                    // no icon in the theme: a dot instead
                                    Rectangle {
                                        visible: app.icon === ""
                                        anchors.centerIn: parent
                                        width: 6; height: 6; radius: 3
                                        color: Colors.foreground
                                    }
                                }
                            }
                        }
                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: Xmonad.view(ws.modelData.name)
                        }
                    }
                }
            }
        }

        // layout of this screen's workspace; left click: next (super+m),
        // right click: back to the first one (super+shift+space)
        Island {
            width: layoutRow.implicitWidth + 20
            Row {
                id: layoutRow
                anchors.centerIn: parent
                spacing: 6
                readonly property string name: root.xs ? root.xs.layout : ""
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ({ tall: "", wide: "", cols: "", full: "" })[layoutRow.name] || ""
                    font.pixelSize: 14
                    color: Colors.cyan
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: layoutRow.name
                    font { family: Colors.font; pixelSize: 12 }
                    color: Colors.muted
                }
            }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: m => Xmonad.key(m.button === Qt.RightButton ? "super+shift+space" : "super+m")
            }
        }
    }

    // =========================================================================
    // middle: the active window (icon + title), on the focused screen
    // =========================================================================
    Island {
        id: active
        anchors.centerIn: parent
        readonly property bool shown: root.focusedHere && Xmonad.title !== ""
        readonly property real maxW: root.width * 0.34
        width: shown ? Math.min(activeRow.implicitWidth + 28, maxW) : 0
        visible: width > 1
        opacity: shown ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: 180 } }
        clip: true
        Row {
            id: activeRow
            anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 14 }
            spacing: 8
            Image {
                id: activeIcon
                anchors.verticalCenter: parent.verticalCenter
                readonly property string icon: root.iconFor(Xmonad.appClass)
                visible: icon !== ""
                source: icon
                width: 18; height: 18
                sourceSize { width: 36; height: 36 }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Xmonad.title
                width: Math.min(implicitWidth, active.maxW - 28 - (activeIcon.visible ? 26 : 0))
                elide: Text.ElideRight
                font { family: Colors.font; pixelSize: 13 }
                color: Colors.foreground
            }
        }
    }

    // =========================================================================
    // right: recording, Slack, volume, battery, tray, clock
    // =========================================================================
    Row {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        spacing: 8

        // recording: pulsing red dot + time while screenrec runs; click stops
        Island {
            visible: RecState.active
            width: recRow.implicitWidth + 20
            color: root.tint(Colors.red, 0.18)
            Row {
                id: recRow
                anchors.centerIn: parent
                spacing: 6
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10; height: 10; radius: 5
                    color: Colors.red
                    SequentialAnimation on opacity {
                        running: RecState.active; loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 700; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1;    duration: 700; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: RecState.clock
                    font { family: Colors.font; pixelSize: 12 }
                    color: Colors.red
                }
            }
            MouseArea { anchors.fill: parent; onClicked: RecState.stop() }
        }

        // Slack: on the bar whenever it is installed, tray icon or not.
        // Badge = Slack notifications since Slack last had focus.
        Island {
            visible: Slack.installed
            width: slackRow.implicitWidth + 20
            color: Slack.unread > 0 ? root.tint(Colors.red, 0.14) : Colors.surface
            Behavior on color { ColorAnimation { duration: 200 } }
            Row {
                id: slackRow
                anchors.centerIn: parent
                spacing: 6
                Item {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 18; height: 18
                    Image {
                        id: slackIcon
                        anchors.fill: parent
                        readonly property string icon: Quickshell.iconPath("slack", true)
                        visible: icon !== ""
                        source: icon
                        sourceSize { width: 36; height: 36 }
                        opacity: Slack.running ? 1 : 0.4
                    }
                    Glyph {
                        anchors.centerIn: parent
                        visible: !slackIcon.visible
                        text: "\u{F04B1}" // md-slack
                        color: Slack.running ? Colors.foreground : Colors.muted
                    }
                }
                Rectangle {
                    id: badgeBox
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Slack.unread > 0
                    height: 18; radius: 9
                    width: Math.max(18, badge.implicitWidth + 10)
                    color: Colors.red
                    Text {
                        id: badge
                        anchors.centerIn: parent
                        text: Slack.unread > 99 ? "99+" : String(Slack.unread)
                        font { family: Colors.font; pixelSize: 11; bold: true }
                        color: Colors.background
                    }
                    // pop on every new message
                    SequentialAnimation {
                        id: pop
                        NumberAnimation { target: badgeBox; property: "scale"; from: 0.6; to: 1.15; duration: 160; easing.type: Easing.OutBack }
                        NumberAnimation { target: badgeBox; property: "scale"; to: 1; duration: 120 }
                    }
                    Connections {
                        target: Slack
                        function onUnreadChanged() { if (Slack.unread > 0) pop.restart() }
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                // start / bring up Slack (running `slack` again shows the open one)
                onClicked: Slack.open()
            }
        }

        // volume: scroll changes it, click mutes, right click opens pavucontrol
        Island {
            id: vol
            width: volRow.implicitWidth + 20
            property int level: -1
            property bool muted: false
            visible: level >= 0
            Row {
                id: volRow
                anchors.centerIn: parent
                spacing: 6
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: vol.muted ? "\u{F0581}" : vol.level > 60 ? "\u{F057E}" : vol.level > 20 ? "\u{F0580}" : "\u{F057F}"
                    color: vol.muted ? Colors.muted : Colors.rose
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: vol.level + "%"
                    font { family: Colors.font; pixelSize: 12 }
                    color: vol.muted ? Colors.muted : Colors.foreground
                }
            }
            function refresh() { volProc.running = false; volProc.running = true }
            Process {
                id: volProc
                command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                running: true
                // "Volume: 0.45" or "Volume: 0.45 [MUTED]"
                stdout: StdioCollector {
                    onStreamFinished: {
                        const m = this.text.match(/Volume:\s*([\d.]+)/)
                        if (m) {
                            vol.level = Math.round(parseFloat(m[1]) * 100)
                            vol.muted = this.text.includes("MUTED")
                        }
                    }
                }
            }
            Timer { interval: 2000; running: true; repeat: true; onTriggered: vol.refresh() }
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: m => {
                    if (m.button === Qt.RightButton) Quickshell.execDetached(["pavucontrol"])
                    else Quickshell.execDetached(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                    volDelay.restart()
                }
                onWheel: w => {
                    Quickshell.execDetached(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@",
                                             w.angleDelta.y > 0 ? "5%+" : "5%-"])
                    volDelay.restart()
                }
            }
            // read the new value once wpctl has applied it
            Timer { id: volDelay; interval: 120; onTriggered: vol.refresh() }
        }

        // battery (hidden on machines without one)
        Island {
            id: bat
            visible: pct >= 0
            width: batRow.implicitWidth + 20
            property int pct: -1
            property string status: ""
            readonly property color tintColor: status === "Charging" ? Colors.cyan
                                             : pct <= 15 ? Colors.red
                                             : pct <= 30 ? Colors.yellow : Colors.foreground
            Row {
                id: batRow
                anchors.centerIn: parent
                spacing: 6
                Glyph {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bat.status === "Charging" ? "\u{F0084}"
                        : ["\u{F007A}", "\u{F007B}", "\u{F007C}", "\u{F007D}", "\u{F007E}",
                           "\u{F007F}", "\u{F0080}", "\u{F0081}", "\u{F0082}", "\u{F0079}"][Math.min(9, Math.floor(Math.max(0, bat.pct) / 10))]
                    color: bat.tintColor
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: bat.pct + "%"
                    font { family: Colors.font; pixelSize: 12 }
                    color: bat.tintColor
                }
            }
            Process {
                id: batProc
                command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do cat \"$b/capacity\" \"$b/status\"; break; done 2>/dev/null"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        const l = this.text.trim().split("\n")
                        const p = parseInt(l[0])
                        if (!isNaN(p)) { bat.pct = p; bat.status = (l[1] || "").trim() }
                    }
                }
            }
            Timer { interval: 30000; running: true; repeat: true
                    onTriggered: { batProc.running = false; batProc.running = true } }
        }

        // tray (StatusNotifierItem)
        Island {
            visible: SystemTray.items.values.length > 0
            width: trayRow.implicitWidth + 16
            Row {
                id: trayRow
                anchors.centerIn: parent
                spacing: 8
                Repeater {
                    model: SystemTray.items
                    delegate: Item {
                        id: trayItem
                        required property SystemTrayItem modelData
                        width: 20; height: 20
                        Image {
                            id: trayIcon
                            anchors.fill: parent
                            sourceSize { width: 40; height: 40 }
                            source: trayItem.modelData.icon
                            fillMode: Image.PreserveAspectFit
                        }
                        // app asks for attention (unread messages etc.): red dot
                        Rectangle {
                            visible: trayItem.modelData.status === Status.NeedsAttention
                            anchors { right: trayIcon.right; top: trayIcon.top; margins: -2 }
                            width: 8; height: 8; radius: 4
                            color: Colors.red
                            border { width: 1; color: Colors.surface }
                        }
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                            onClicked: mouse => {
                                const it = trayItem.modelData
                                const p = mapToItem(null, 0, 0)
                                if (mouse.button === Qt.MiddleButton) it.secondaryActivate()
                                else if (mouse.button === Qt.RightButton || it.onlyMenu) {
                                    if (it.hasMenu) it.display(root, p.x, root.height + 6)
                                } else it.activate()
                            }
                            onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y, false)
                        }
                    }
                }
            }
        }

        // clock; click shows the date
        Island {
            id: clock
            width: clockText.implicitWidth + 24
            color: root.tint(Colors.purple, 0.16)
            property bool showDate: false
            property date now: new Date()
            Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
            Text {
                id: clockText
                anchors.centerIn: parent
                text: clock.showDate ? Qt.locale().toString(clock.now, "ddd d MMM")
                                     : Qt.formatDateTime(clock.now, "hh:mm")
                font { family: Colors.font; pixelSize: 14; bold: true }
                color: Colors.purple
            }
            MouseArea { anchors.fill: parent; onClicked: clock.showDate = !clock.showDate }
        }
    }
}
