import QtQuick
import Quickshell

// Layout pop-up: xmonad's layout keys (layoutOsd in xmonad.hs) call
// `quickshell ipc call osd layout <name>` (handled in shell.qml); this shows
// the new layout in the middle of the focused screen for a moment.
// Click-through and outside the struts, so it never moves windows.
PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    readonly property var xs: Xmonad.screenFor(modelData)
    readonly property bool mine: xs !== null && xs.id === Xmonad.focusedScreen

    readonly property var layouts: [
        { name: "tall", icon: "", desc: "master po lewej" },
        { name: "wide", icon: "", desc: "master na górze" },
        { name: "cols", icon: "", desc: "master na środku" },
        { name: "full", icon: "", desc: "jedno okno" }
    ]
    readonly property var current: layouts.find(l => l.name === Osd.layout) || layouts[0]

    property bool shown: false
    Connections {
        target: Osd
        function onSerialChanged() {
            if (!root.mine) return
            root.shown = true
            hide.restart()
        }
    }
    Timer { id: hide; interval: 1100; onTriggered: root.shown = false }

    visible: shown || box.opacity > 0
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    margins {
        top: Math.round((modelData.height - implicitHeight) / 2)
        left: Math.round((modelData.width - implicitWidth) / 2)
    }
    implicitWidth: 300
    implicitHeight: 150
    color: "transparent"
    mask: Region {}

    Rectangle {
        id: box
        anchors.fill: parent
        radius: 20
        color: Colors.background
        border { width: 1; color: Qt.rgba(Colors.purple.r, Colors.purple.g, Colors.purple.b, 0.4) }
        opacity: root.shown ? 1 : 0
        scale: root.shown ? 1 : 0.92
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack } }

        Column {
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.current.icon
                font { family: Colors.font; pixelSize: 40 }
                color: Colors.purple
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.current.name
                font { family: Colors.font; pixelSize: 20; bold: true }
                color: Colors.foreground
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.current.desc
                font { family: Colors.font; pixelSize: 12 }
                color: Colors.muted
            }
            // all layouts, current one lit
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 6
                topPadding: 4
                Repeater {
                    model: root.layouts
                    delegate: Rectangle {
                        required property var modelData
                        readonly property bool on: modelData.name === root.current.name
                        height: 6; radius: 3
                        width: on ? 22 : 6
                        color: on ? Colors.purple : Colors.muted
                        Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    }
                }
            }
        }
    }
}
