import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history: super+v (`quickshell ipc call clipboard toggle`).
// Entries come from bin/cliphist (its daemon is started by xmonad's
// autostart). Type to filter, ↑/↓ to pick, Enter copies the entry back to
// the clipboard, Shift+Delete forgets it, Esc closes.
// A managed window so it gets keyboard focus; xmonad.hs makes it
// fullscreen (title "qs-clip").
FloatingWindow {
    id: root
    visible: false
    title: "qs-clip"
    color: Qt.rgba(0.04, 0.035, 0.07, 0.82)

    property var all: []
    property var shown: []
    function filter() {
        const q = search.text.trim().toLowerCase()
        root.shown = q === "" ? root.all : root.all.filter(e => e.preview.toLowerCase().includes(q))
        list.currentIndex = 0
    }
    function pick(i) {
        if (i < 0 || i >= root.shown.length) return
        Quickshell.execDetached(["cliphist", "copy", root.shown[i].id])
        root.visible = false
    }
    function forget(i) {
        if (i < 0 || i >= root.shown.length) return
        const id = root.shown[i].id
        Quickshell.execDetached(["cliphist", "delete", id])
        root.all = root.all.filter(e => e.id !== id)
        const keep = list.currentIndex
        root.filter()
        list.currentIndex = Math.min(keep, root.shown.length - 1)
    }

    Process {
        id: loader
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.all = JSON.parse(this.text) } catch (e) { root.all = [] }
                root.filter()
            }
        }
    }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.visible = !root.visible }
        function open(): void   { root.visible = true }
        function close(): void  { root.visible = false }
    }

    onVisibleChanged: {
        if (visible) {
            search.text = ""
            root.all = []; root.shown = []
            loader.running = false; loader.running = true
            search.forceActiveFocus()
        }
    }

    MouseArea { anchors.fill: parent; onClicked: root.visible = false }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 760)
        height: Math.min(parent.height - 120, 620)
        radius: 18
        color: Colors.background
        border { width: 1; color: Qt.rgba(Colors.purple.r, Colors.purple.g, Colors.purple.b, 0.35) }
        MouseArea { anchors.fill: parent }

        Column {
            anchors { fill: parent; margins: 20 }
            spacing: 14

            // header + search
            Rectangle {
                width: parent.width; height: 44
                radius: 10
                color: Colors.surface
                border { width: 2; color: search.activeFocus ? Colors.purple : "transparent" }
                Row {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        font { family: Colors.font; pixelSize: 16 }
                        color: Colors.purple
                    }
                    TextInput {
                        id: search
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 110
                        font { family: Colors.font; pixelSize: 14 }
                        color: Colors.foreground
                        selectionColor: Colors.purple
                        clip: true
                        onTextChanged: root.filter()
                        Keys.onEscapePressed: e => { root.visible = false; e.accepted = true }
                        Keys.onReturnPressed: e => { root.pick(list.currentIndex); e.accepted = true }
                        Keys.onEnterPressed: e => { root.pick(list.currentIndex); e.accepted = true }
                        Keys.onUpPressed: e => { list.decrementCurrentIndex(); e.accepted = true }
                        Keys.onDownPressed: e => { list.incrementCurrentIndex(); e.accepted = true }
                        Keys.onDeletePressed: e => {
                            if (e.modifiers & Qt.ShiftModifier) { root.forget(list.currentIndex); e.accepted = true }
                        }
                        Text {
                            visible: search.text === ""
                            text: "historia schowka"
                            font: search.font
                            color: Colors.muted
                        }
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.shown.length + " / " + root.all.length
                        font { family: Colors.font; pixelSize: 12 }
                        color: Colors.muted
                    }
                }
            }

            ListView {
                id: list
                width: parent.width
                height: parent.height - 44 - 14 - hint.height - 14
                clip: true
                spacing: 4
                model: root.shown
                highlightMoveDuration: 80
                boundsBehavior: Flickable.StopAtBounds
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool current: ListView.isCurrentItem
                    width: list.width
                    height: 44
                    radius: 10
                    color: current ? Qt.rgba(Colors.purple.r, Colors.purple.g, Colors.purple.b, 0.2)
                         : rowMouse.containsMouse ? Colors.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Text {
                        anchors { left: parent.left; right: meta.left; verticalCenter: parent.verticalCenter
                                  leftMargin: 14; rightMargin: 10 }
                        text: row.modelData.preview
                        elide: Text.ElideRight
                        font { family: Colors.font; pixelSize: 13 }
                        color: row.current ? Colors.foreground : Colors.rose
                    }
                    Text {
                        id: meta
                        anchors { right: parent.right; rightMargin: 14; verticalCenter: parent.verticalCenter }
                        text: row.modelData.lines > 1 ? row.modelData.lines + " linii" : row.modelData.chars + " zn."
                        font { family: Colors.font; pixelSize: 11 }
                        color: Colors.muted
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: root.pick(row.index)
                    }
                }
                Text {
                    anchors.centerIn: parent
                    visible: root.shown.length === 0
                    text: root.all.length === 0 ? "pusto: skopiuj coś (daemon: cliphist daemon)" : "nic nie pasuje"
                    font { family: Colors.font; pixelSize: 13 }
                    color: Colors.muted
                }
            }

            Text {
                id: hint
                text: "Enter kopiuje  ·  Shift+Del usuwa wpis  ·  Esc zamyka"
                font { family: Colors.font; pixelSize: 11 }
                color: Colors.muted
            }
        }
    }
}
