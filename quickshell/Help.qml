import QtQuick
import Quickshell
import Quickshell.Io

// Key overview: super+s (`quickshell ipc call help toggle`). Type to filter,
// Esc / super+s / click outside closes. Keep `sections` in sync with myKeys
// in xmonad/xmonad.hs.
//
// A managed window (not a panel) so it gets keyboard focus; xmonad.hs makes
// it fullscreen (title "qs-help").
FloatingWindow {
    id: root
    visible: false
    title: "qs-help"
    color: Qt.rgba(0.04, 0.035, 0.07, 0.82)

    // keys: alternatives for the same action; "+" joins a combo
    readonly property var sections: [
        { name: "Aplikacje", icon: "", items: [
            { keys: ["super+Return"], desc: "terminal (wezterm)" },
            { keys: ["super+q"], desc: "przeglądarka" },
            { keys: ["super+r"], desc: "launcher: aplikacje, okna, kalkulator, pliki" },
            { keys: ["super+n"], desc: "nowe okno wezterma w tym samym katalogu" },
            { keys: ["super+shift+n"], desc: "Slack (przełącz albo uruchom)" },
            { keys: ["super+`", "super+'"], desc: "terminal scratchpad (wysuwa / chowa)" },
            { keys: ["super+b"], desc: "btop scratchpad" },
            { keys: ["super+s"], desc: "ta pomoc" }
        ] },
        { name: "Okna", icon: "", items: [
            { keys: ["super+shift+c"], desc: "zamknij" },
            { keys: ["super+t"], desc: "pływające / z powrotem w kafelkach" },
            { keys: ["super+f"], desc: "pełny ekran (chowa pasek)" },
            { keys: ["super+shift+Return"], desc: "na miejsce mastera" },
            { keys: ["super+u"], desc: "okno, które woła o uwagę" },
            { keys: ["super+[", "super+]"], desc: "węższy / szerszy master" },
            { keys: ["super+shift+[", "super+shift+]"], desc: "niższe / wyższe okno w stosie" },
            { keys: ["super+=", "super+-"], desc: "więcej / mniej okien w masterze" }
        ] },
        { name: "Fokus i przenoszenie", icon: "", items: [
            { keys: ["super+h", "super+l", "super+←→↑↓"], desc: "fokus okna w tym kierunku" },
            { keys: ["super+shift+h", "super+shift+l", "super+shift+←→↑↓"], desc: "zamień z sąsiadem" },
            { keys: ["super+ctrl+h/l/k/j"], desc: "fokus monitora" },
            { keys: ["super+shift+ctrl+h/l/k/j"], desc: "okno na monitor" },
            { keys: ["mysz"], desc: "fokus idzie za kursorem, też na pusty monitor" }
        ] },
        { name: "Workspace'y", icon: "", items: [
            { keys: ["super+1…9"], desc: "pokaż (ten sam drugi raz: poprzedni)" },
            { keys: ["super+shift+1…9"], desc: "przenieś okno" },
            { keys: ["super+k", "super+j"], desc: "poprzedni / następny" },
            { keys: ["super+shift+k", "super+shift+j"], desc: "przenieś okno i idź za nim" },
            { keys: ["super+Tab"], desc: "ostatni" },
            { keys: ["super+scroll"], desc: "przewijanie (scroll na pasku też)" }
        ] },
        { name: "Layouty", icon: "", items: [
            { keys: ["super+m", "super+space"], desc: "następny: tall → wide → cols → full" },
            { keys: ["super+shift+space"], desc: "z powrotem tall" },
            { keys: ["super+g"], desc: "odstępy między oknami on/off" }
        ] },
        { name: "Zrzuty i nagrywanie", icon: "", items: [
            { keys: ["super+shift+s", "Print"], desc: "zrzut obszaru (plik + schowek)" },
            { keys: ["super+ctrl+shift+s"], desc: "zrzut z adnotacją (flameshot)" },
            { keys: ["super+ctrl+s"], desc: "zrzut okna" },
            { keys: ["super+shift+r"], desc: "nagraj obszar (drugi raz: stop)" },
            { keys: ["super+ctrl+r"], desc: "nagraj monitor pod kursorem" },
            { keys: ["super+alt+r"], desc: "nagraj obszar z dźwiękiem" },
            { keys: ["super+shift+t"], desc: "OCR obszaru do schowka" },
            { keys: ["super+p"], desc: "pipeta koloru" },
            { keys: ["super+."], desc: "emoji" }
        ] },
        { name: "System", icon: "", items: [
            { keys: ["super+alt+w"], desc: "przeładuj: monitory, xmonad, pasek" },
            { keys: ["super+alt+l"], desc: "blokada ekranu" },
            { keys: ["super+alt+t"], desc: "touchpad on/off" },
            { keys: ["super+shift+a"], desc: "mikrofon na głośniki (loopback)" },
            { keys: ["super+shift+e"], desc: "wyloguj" }
        ] },
        { name: "Mysz", icon: "", items: [
            { keys: ["super+lewy"], desc: "przesuń okno (robi je pływającym)" },
            { keys: ["super+prawy"], desc: "zmień rozmiar" }
        ] }
    ]

    property string query: ""
    function matches(item) {
        const q = root.query.trim().toLowerCase()
        if (q === "") return true
        return item.desc.toLowerCase().includes(q) || item.keys.join(" ").toLowerCase().includes(q)
    }
    // "super+shift+Return" -> ["super", "shift", "⏎"]; "super++" style keys
    // do not occur, so splitting on "+" is safe
    function chips(combo) {
        const pretty = { "Return": "⏎", "space": "space", "Tab": "⇥ tab", "Print": "PrtSc" }
        return combo.split("+").map(k => pretty[k] || k)
    }

    IpcHandler {
        target: "help"
        function toggle(): void { root.visible = !root.visible }
        function open(): void   { root.visible = true }
        function close(): void  { root.visible = false }
    }

    onVisibleChanged: {
        if (visible) {
            search.text = ""
            flick.contentY = 0
            search.forceActiveFocus()
            card.opacity = 0; card.scale = 0.97
            appear.restart()
        }
    }
    ParallelAnimation {
        id: appear
        NumberAnimation { target: card; property: "opacity"; to: 1; duration: 160; easing.type: Easing.OutCubic }
        NumberAnimation { target: card; property: "scale"; to: 1; duration: 200; easing.type: Easing.OutCubic }
    }

    // click outside the card closes
    MouseArea { anchors.fill: parent; onClicked: root.visible = false }

    Rectangle {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 80, 1320)
        height: Math.min(parent.height - 80, header.height + flow.implicitHeight + 64)
        radius: 18
        color: Colors.background
        border { width: 1; color: Qt.rgba(Colors.purple.r, Colors.purple.g, Colors.purple.b, 0.35) }
        MouseArea { anchors.fill: parent }   // clicks inside do not close

        // ---- header: title + search -----------------------------------------
        Item {
            id: header
            anchors { top: parent.top; left: parent.left; right: parent.right; margins: 24 }
            height: 46
            Row {
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                spacing: 12
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: ""
                    font { family: Colors.font; pixelSize: 24 }
                    color: Colors.purple
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Skróty"
                    font { family: Colors.font; pixelSize: 22; bold: true }
                    color: Colors.foreground
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "xmonad"
                    font { family: Colors.font; pixelSize: 13 }
                    color: Colors.muted
                }
            }
            Rectangle {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                width: Math.min(360, parent.width * 0.4); height: 40
                radius: 10
                color: Colors.surface
                border { width: 2; color: search.activeFocus ? Colors.purple : "transparent" }
                Row {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: ""
                        font { family: Colors.font; pixelSize: 14 }
                        color: Colors.muted
                    }
                    TextInput {
                        id: search
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 30
                        font { family: Colors.font; pixelSize: 14 }
                        color: Colors.foreground
                        selectionColor: Colors.purple
                        clip: true
                        onTextChanged: root.query = text
                        Keys.onEscapePressed: e => { root.visible = false; e.accepted = true }
                        Keys.onUpPressed: e => { flick.contentY = Math.max(0, flick.contentY - 60); e.accepted = true }
                        Keys.onDownPressed: e => {
                            flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + 60)
                            e.accepted = true
                        }
                        Text {
                            visible: search.text === ""
                            text: "szukaj: zrzut, monitor, layout…"
                            font: search.font
                            color: Colors.muted
                        }
                    }
                }
            }
        }

        // ---- sections ---------------------------------------------------------
        Flickable {
            id: flick
            anchors { top: header.bottom; left: parent.left; right: parent.right; bottom: parent.bottom
                      topMargin: 18; leftMargin: 24; rightMargin: 24; bottomMargin: 20 }
            contentHeight: flow.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Flow {
                id: flow
                width: flick.width
                spacing: 14
                readonly property int columns: width > 1100 ? 3 : width > 700 ? 2 : 1
                readonly property real colWidth: (width - spacing * (columns - 1)) / columns

                Repeater {
                    model: root.sections
                    delegate: Rectangle {
                        id: section
                        required property var modelData
                        readonly property var shown: modelData.items.filter(i => root.matches(i))
                        visible: shown.length > 0
                        width: flow.colWidth
                        height: sectionCol.implicitHeight + 28
                        radius: 14
                        color: Colors.surface

                        Column {
                            id: sectionCol
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                            spacing: 8
                            Row {
                                spacing: 8
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: section.modelData.icon
                                    font { family: Colors.font; pixelSize: 15 }
                                    color: Colors.purple
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: section.modelData.name
                                    font { family: Colors.font; pixelSize: 15; bold: true }
                                    color: Colors.foreground
                                }
                            }
                            Repeater {
                                model: section.shown
                                delegate: Item {
                                    id: entry
                                    required property var modelData
                                    width: sectionCol.width
                                    height: Math.max(keyFlow.implicitHeight, descText.implicitHeight) + 4
                                    Flow {
                                        id: keyFlow
                                        width: entry.width * 0.5
                                        spacing: 4
                                        Repeater {
                                            model: entry.modelData.keys
                                            delegate: Row {
                                                id: combo
                                                required property string modelData
                                                required property int index
                                                spacing: 3
                                                Text {
                                                    visible: combo.index > 0
                                                    anchors.verticalCenter: parent.verticalCenter
                                                    text: "/"
                                                    font { family: Colors.font; pixelSize: 12 }
                                                    color: Colors.muted
                                                }
                                                Repeater {
                                                    model: root.chips(combo.modelData)
                                                    delegate: Rectangle {
                                                        required property string modelData
                                                        height: 22; radius: 6
                                                        width: chip.implicitWidth + 12
                                                        color: modelData === "super" ? Qt.rgba(Colors.purple.r, Colors.purple.g, Colors.purple.b, 0.22)
                                                                                     : Qt.lighter(Colors.background, 1.5)
                                                        Text {
                                                            id: chip
                                                            anchors.centerIn: parent
                                                            text: parent.modelData
                                                            font { family: Colors.font; pixelSize: 12 }
                                                            color: parent.modelData === "super" ? Colors.purple : Colors.foreground
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        id: descText
                                        anchors { left: keyFlow.right; leftMargin: 10; right: parent.right; top: parent.top; topMargin: 2 }
                                        text: entry.modelData.desc
                                        wrapMode: Text.WordWrap
                                        font { family: Colors.font; pixelSize: 13 }
                                        color: Colors.muted
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // nothing matches the search
        Text {
            anchors.centerIn: flick
            visible: root.sections.every(s => !s.items.some(i => root.matches(i)))
            text: "nic nie pasuje do „" + root.query + "”"
            font { family: Colors.font; pixelSize: 14 }
            color: Colors.muted
        }
    }
}
