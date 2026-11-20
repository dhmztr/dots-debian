import QtQuick
import Quickshell

// Drop-down list under a bar island (GitLab MRs, meetings). items:
// [{ title, detail, color, url }]; clicking a row opens its url. Closes when
// the pointer has been away from it for a moment, or on a second click on
// the island. A popup (override-redirect) so it stays above windows.
PopupWindow {
    id: root

    required property var bar          // the Bar (PanelWindow)
    required property Item anchorItem  // the island it hangs from
    property string heading: ""
    property var items: []
    signal opened()

    implicitWidth: 460
    implicitHeight: Math.min(col.implicitHeight + 24, 520)
    color: "transparent"

    anchor.window: bar
    // right edge under the island's right edge, kept on screen
    function place() {
        const p = anchorItem.mapToItem(null, 0, 0)
        anchor.rect.x = Math.max(0, p.x + anchorItem.width - implicitWidth)
        anchor.rect.y = bar.height + 6
    }
    onVisibleChanged: {
        if (visible) { place(); away.restart(); opened() }
    }

    Timer {
        id: away
        interval: 2500
        onTriggered: if (!hover.hovered) root.visible = false
    }
    HoverHandler {
        id: hover
        onHoveredChanged: if (!hovered) away.restart()
    }

    Rectangle {
        anchors.fill: parent
        radius: 14
        color: Colors.background
        border { width: 1; color: Qt.rgba(Colors.purple.r, Colors.purple.g, Colors.purple.b, 0.35) }

        Flickable {
            anchors { fill: parent; margins: 12 }
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: col
                width: parent.width
                spacing: 4
                Text {
                    text: root.heading
                    font { family: Colors.font; pixelSize: 13; bold: true }
                    color: Colors.purple
                    bottomPadding: 4
                }
                Text {
                    visible: root.items.length === 0
                    text: "pusto"
                    font { family: Colors.font; pixelSize: 12 }
                    color: Colors.muted
                }
                Repeater {
                    model: root.items
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        width: col.width
                        height: rowCol.implicitHeight + 12
                        radius: 8
                        color: rowMouse.containsMouse ? Colors.surface : "transparent"
                        Column {
                            id: rowCol
                            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter
                                      leftMargin: 10; rightMargin: 10 }
                            spacing: 2
                            Text {
                                width: parent.width
                                text: row.modelData.title
                                elide: Text.ElideRight
                                font { family: Colors.font; pixelSize: 13 }
                                color: row.modelData.color || Colors.foreground
                            }
                            Text {
                                width: parent.width
                                text: row.modelData.detail || ""
                                elide: Text.ElideRight
                                font { family: Colors.font; pixelSize: 11 }
                                color: Colors.muted
                            }
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                if (row.modelData.url) Quickshell.execDetached(["xdg-open", row.modelData.url])
                                root.visible = false
                            }
                        }
                    }
                }
            }
        }
    }
}
