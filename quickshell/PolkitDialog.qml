import QtQuick
import Quickshell
import Quickshell.Services.Polkit

// Polkit authentication agent: the "enter your password to continue" dialog
// for virt-manager, gparted, pkexec, NetworkManager system connections etc.
// Without an agent those requests fail silently.
//
// A managed fullscreen window (bspwmrc rule on the title "qs-polkit"), not a
// PanelWindow: bspwm never gives keyboard focus to dock windows.
Scope {
    id: root

    PolkitAgent { id: agent }

    readonly property var flow: agent.flow
    property string _error: ""

    Connections {
        target: agent
        function onAuthenticationRequestStarted() { root._error = "" }
    }
    Connections {
        target: root.flow
        ignoreUnknownSignals: true
        function onAuthenticationFailed() { root._error = "Wrong password, try again" }
        function onAuthenticationSucceeded() { root._error = "" }
    }

    FloatingWindow {
        id: win
        visible: agent.isActive && root.flow !== null
        title: "qs-polkit"
        // no compositor: opaque dim backdrop instead of alpha
        color: Qt.darker(Colors.background, 1.4)

        onVisibleChanged: if (visible) { pw.text = ""; pw.forceActiveFocus() }

        MouseArea { anchors.fill: parent }   // swallow clicks outside the card

        Rectangle {
            id: card
            anchors.centerIn: parent
            width: 440
            height: col.implicitHeight + 48
            radius: 16
            color: Colors.background
            border.width: 1
            border.color: Qt.rgba(Colors.purple.r, Colors.purple.g, Colors.purple.b, 0.5)

            Column {
                id: col
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 24 }
                spacing: 14

                Row {
                    spacing: 12
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰌾"
                        font.family: Colors.font; font.pixelSize: 26
                        color: Colors.purple
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Authentication required"
                        font.family: Colors.font; font.pixelSize: 16; font.bold: true
                        color: Colors.foreground
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: root.flow ? root.flow.message : ""
                    font.family: Colors.font; font.pixelSize: 13
                    color: Colors.foreground
                }
                Text {
                    width: parent.width
                    elide: Text.ElideMiddle
                    visible: text !== ""
                    text: root.flow ? root.flow.actionId : ""
                    font.family: Colors.font; font.pixelSize: 10
                    color: Colors.muted
                }

                // identity: usually just the user (wheel) - a picker only when
                // polkit offers more than one
                Row {
                    visible: root.flow && root.flow.identities.length > 1
                    spacing: 6
                    Repeater {
                        model: root.flow ? root.flow.identities : []
                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool sel: root.flow && root.flow.selectedIdentity === modelData
                            height: 26; radius: 13
                            width: idTxt.implicitWidth + 20
                            color: sel ? Colors.purple : Qt.lighter(Colors.background, 1.35)
                            Text {
                                id: idTxt
                                anchors.centerIn: parent
                                text: modelData.displayName || modelData.string
                                font.family: Colors.font; font.pixelSize: 11
                                color: parent.sel ? Colors.background : Colors.foreground
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.flow.selectedIdentity = modelData
                            }
                        }
                    }
                }

                Text {
                    visible: root.flow && root.flow.identities.length === 1
                    text: root.flow && root.flow.selectedIdentity
                          ? "as " + (root.flow.selectedIdentity.displayName || root.flow.selectedIdentity.string) : ""
                    font.family: Colors.font; font.pixelSize: 11
                    color: Colors.muted
                }

                Rectangle {
                    width: parent.width; height: 44; radius: 10
                    color: Qt.lighter(Colors.background, 1.3)
                    border.width: 2
                    border.color: root._error !== "" ? Colors.red
                                : pw.activeFocus ? Colors.purple : "transparent"
                    TextInput {
                        id: pw
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true
                        echoMode: root.flow && root.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "●"
                        passwordMaskDelay: 0
                        font.family: Colors.font; font.pixelSize: 14
                        color: Colors.foreground
                        enabled: root.flow && root.flow.isResponseRequired
                        onAccepted: root.submit()
                        Keys.onEscapePressed: root.cancel()
                    }
                    Text {
                        anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                        visible: pw.text === ""
                        text: root.flow && root.flow.isResponseRequired
                              ? (root.flow.inputPrompt.replace(/:\s*$/, "") || "Password") : "Checking…"
                        font.family: Colors.font; font.pixelSize: 13
                        color: Colors.muted
                    }
                }

                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    readonly property string supp: root.flow ? root.flow.supplementaryMessage : ""
                    visible: text !== ""
                    text: root._error !== "" ? root._error : supp
                    font.family: Colors.font; font.pixelSize: 12
                    color: root._error !== "" || (root.flow && root.flow.supplementaryIsError)
                           ? Colors.red : Colors.muted
                }

                Row {
                    anchors.right: parent.right
                    spacing: 8
                    Repeater {
                        model: [
                            { label: "Cancel", primary: false },
                            { label: "Authenticate", primary: true }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            height: 32; radius: 8
                            width: btnTxt.implicitWidth + 28
                            color: modelData.primary ? Colors.purple
                                 : (btnMa.containsMouse ? Qt.lighter(Colors.background, 1.5) : Qt.lighter(Colors.background, 1.3))
                            Text {
                                id: btnTxt
                                anchors.centerIn: parent
                                text: modelData.label
                                font.family: Colors.font; font.pixelSize: 12; font.bold: modelData.primary
                                color: modelData.primary ? Colors.background : Colors.foreground
                            }
                            MouseArea {
                                id: btnMa
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: modelData.primary ? root.submit() : root.cancel()
                            }
                        }
                    }
                }
            }
        }
    }

    function submit() {
        if (!root.flow || !root.flow.isResponseRequired) return
        root._error = ""
        root.flow.submit(pw.text)
        pw.text = ""
    }
    function cancel() {
        if (root.flow) root.flow.cancelAuthenticationRequest()
        pw.text = ""
    }
}
