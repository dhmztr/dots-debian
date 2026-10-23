import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// Vertical bar on the left, like the niri setup: clock on top, bspwm desktops
// in the middle, tray / battery at the bottom. No compositor is
// assumed, so the window is opaque (transparent pixels would show black).
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    anchors { left: true; top: true; bottom: true }
    margins { left: 8; top: 8; bottom: 8 }
    implicitWidth: 48
    color: Colors.surface

    // ---- top: clock (click: date) ------------------------------------------
    Item {
        id: clock
        anchors { top: parent.top; horizontalCenter: parent.horizontalCenter; topMargin: 10 }
        width: parent.width; height: 44
        property bool showDate: false
        property date now: new Date()
        Timer { interval: 1000; running: true; repeat: true; onTriggered: clock.now = new Date() }
        Column {
            anchors.centerIn: parent
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.now, clock.showDate ? "dd" : "hh")
                font { family: Colors.font; pixelSize: 16; bold: true }
                color: Colors.foreground
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.formatDateTime(clock.now, clock.showDate ? "MM" : "mm")
                font { family: Colors.font; pixelSize: 16; bold: true }
                color: Colors.purple
            }
        }
        MouseArea { anchors.fill: parent; onClicked: clock.showDate = !clock.showDate }
    }

    // ---- middle: bspwm desktops ---------------------------------------------
    Column {
        anchors.centerIn: parent
        spacing: 6
        Repeater {
            model: Bspwm.desktops(root.modelData.name)
            delegate: Item {
                required property var modelData
                width: root.width; height: 14
                Rectangle {
                    anchors.centerIn: parent
                    height: 8; radius: 4
                    width: modelData.focused ? 24 : 8
                    color: modelData.urgent ? Colors.red
                         : modelData.focused ? Colors.purple
                         : modelData.occupied ? Colors.foreground : Colors.muted
                    opacity: modelData.focused || modelData.occupied ? 1 : 0.45
                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Quickshell.execDetached(["bspc", "desktop", "-f",
                                                        modelData.monitor + ":^" + modelData.index])
                }
            }
        }
    }
    // scroll anywhere on the bar: previous / next desktop
    WheelHandler {
        onWheel: e => Quickshell.execDetached(["bspc", "desktop", "-f",
                                               e.angleDelta.y > 0 ? "prev.local" : "next.local"])
    }

    // ---- bottom: tray, battery ----------------------------------------------
    Column {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 10 }
        spacing: 10

        Repeater {
            model: SystemTray.items
            delegate: Item {
                id: trayItem
                required property SystemTrayItem modelData
                width: root.width; height: 26
                Image {
                    id: trayIcon
                    anchors.centerIn: parent
                    width: 20; height: 20
                    sourceSize { width: 40; height: 40 }
                    source: trayItem.modelData.icon
                    fillMode: Image.PreserveAspectFit
                }
                // app asks for attention (unread messages etc.): red dot.
                // Slack/Electron draw their own badge into the icon instead.
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
                            if (it.hasMenu) it.display(root, root.width + 4, p.y)
                        } else it.activate()
                    }
                    onWheel: wheel => trayItem.modelData.scroll(wheel.angleDelta.y, false)
                }
            }
        }

        // battery (hidden on machines without one)
        Item {
            id: bat
            visible: pct >= 0
            width: root.width; height: 36
            property int pct: -1
            property string status: ""
            readonly property color tint: status === "Charging" ? Colors.cyan
                                        : pct <= 15 ? Colors.red
                                        : pct <= 30 ? Colors.yellow : Colors.foreground
            Column {
                anchors.centerIn: parent
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: bat.status === "Charging" ? "󰂄"
                        : ["󰁺","󰁻","󰁼","󰁽","󰁾","󰁿","󰂀","󰂁","󰂂","󰁹"][Math.min(9, Math.floor(Math.max(0, bat.pct) / 10))]
                    font { family: Colors.font; pixelSize: 16 }
                    color: bat.tint
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: bat.pct + "%"
                    font { family: Colors.font; pixelSize: 9 }
                    color: bat.tint
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
    }
}
