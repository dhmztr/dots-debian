pragma Singleton
import QtQuick

// Last layout change announced by xmonad (see LayoutOsd.qml). serial bumps on
// every call so pressing the same key twice still shows the pop-up.
QtObject {
    property string layout: ""
    property int serial: 0
    function showLayout(name) { layout = name; serial++ }
}
