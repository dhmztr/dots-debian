import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

// Vertical bar on the left, like the niri setup: clock on top, bspwm desktops
// in the middle, tray / volume / battery at the bottom. No compositor is
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

    // ---- bottom: tray, volume, battery --------------------------------------
    Column {
        anchors { bottom: parent.bottom; horizontalCenter: parent.horizontalCenter; bottomMargin: 10 }
        spacing: 10

        Repeater {
            model: SystemTray.items
            delegate: Item {
                id: trayItem
                required property SystemTrayItem modelData
                width: root.width; height: 22
                Image {
                    anchors.centerIn: parent
                    width: 18; height: 18
                    sourceSize { width: 36; height: 36 }
                    source: trayItem.modelData.icon
                    fillMode: Image.PreserveAspectFit
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

        // volume: click mutes, scroll changes (wpctl, pipewire)
        Item {
            id: vol
            width: root.width; height: 36
            property int pct: -1
            property bool muted: false
            function refresh() { volProc.running = false; volProc.running = true }
            function run(args) { volSet.command = args; volSet.running = true }
            Column {
                anchors.centerIn: parent
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: vol.muted || vol.pct === 0 ? "󰝟" : vol.pct < 35 ? "󰕿" : vol.pct < 70 ? "󰖀" : "󰕾"
                    font { family: Colors.font; pixelSize: 16 }
                    color: vol.muted ? Colors.muted : Colors.cyan
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: vol.pct < 0 ? "?" : vol.pct + "%"
                    font { family: Colors.font; pixelSize: 9 }
                    color: Colors.muted
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: vol.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
                onWheel: wheel => vol.run(["wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@",
                                           wheel.angleDelta.y > 0 ? "5%+" : "5%-"])
            }
            // "Volume: 0.45" or "Volume: 0.45 [MUTED]"
            Process {
                id: volProc
                command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
                running: true
                stdout: StdioCollector {
                    onStreamFinished: {
                        const m = this.text.match(/([\d.]+)/)
                        if (m) vol.pct = Math.round(parseFloat(m[1]) * 100)
                        vol.muted = this.text.includes("MUTED")
                    }
                }
            }
            Process { id: volSet; onExited: vol.refresh() }
            // media keys change the volume outside the bar: poll
            Timer { interval: 2000; running: true; repeat: true; onTriggered: vol.refresh() }
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
