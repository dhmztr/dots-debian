import QtQuick
import Quickshell
import Quickshell.Io
import QtCore

// App launcher (super+r -> `quickshell ipc call launcher toggle`): apps from
// .desktop files, calculator ("2*21"), file search in ~ (fd / fdfind).
// Full-screen dim overlay; click outside or Esc closes it.
//
// A normal (managed) window rather than a PanelWindow: bspwm never gives
// keyboard focus to dock windows, so a panel would open with every key still
// going to the window behind it. bspwmrc makes this window fullscreen.
FloatingWindow {
    id: root
    visible: false
    title: "qs-launcher"
    // no compositor on plain X11: a translucent window would be black, so the
    // backdrop is an opaque dim colour instead of alpha
    color: Qt.darker(Colors.background, 1.4)

    property var    allApps: []
    property string activeCategory: "All"
    // plain path: StandardPaths returns a file:// URL, which made fd search a
    // non-existent "file:///home/..." dir (file results never appeared)
    readonly property string homeDir: Quickshell.env("HOME")

    // launch counts for ranking; explicit file, the shell has no QSettings
    // organization name to derive a default location from
    Settings {
        id: appUsage
        location: "file://" + root.homeDir + "/.local/state/quickshell/launcher.ini"
        category: "QuickshellLauncher"
        property string usageData: "{}"
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.visible = !root.visible }
        function open(): void   { root.visible = true }
        function close(): void  { root.visible = false }
    }

    readonly property Process _appLoader: Process {
        command: ["sh","-c","python3 ~/.config/quickshell/scripts/qs-apps.py"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.allApps = JSON.parse(this.text).map(a => ({
                        name: a.n, genericName: a.g || "", icon: a.i || "",
                        exec: a.e || "", desktopId: a.d,
                        categories: a.c || [],
                        source: a.s || "native"
                    }))
                    if (root.visible) root.filterApps(searchInput.text)
                } catch(e) {}
            }
        }
    }

    onVisibleChanged: {
        if (visible) {
            _appLoader.running = false; _appLoader.running = true
            searchInput.text = ""
            root.activeCategory = "All"
            resultsList.currentIndex = 0
            filterApps("")
            searchInput.forceActiveFocus()
        }
    }

    function parseArithmetic(expr) {
        let pos = 0
        const input = expr.trim()
        function peek() { while (pos < input.length && /\s/.test(input[pos])) pos++; return input[pos] }
        function parseNumber() {
            while (pos < input.length && /\s/.test(input[pos])) pos++
            let start = pos
            while (pos < input.length && /[0-9.]/.test(input[pos])) pos++
            const num = parseFloat(input.substring(start, pos))
            // "5+" used to evaluate as 5 + null = 5
            if (isNaN(num)) throw new Error("Expected number")
            return num
        }
        function parseFactor() {
            while (pos < input.length && /\s/.test(input[pos])) pos++
            if (input[pos] === '(') { pos++; const r = parseExpr(); while (pos < input.length && /\s/.test(input[pos])) pos++; if (input[pos] !== ')') throw new Error("Missing )"); pos++; return r }
            if (input[pos] === '-') { pos++; return -parseFactor() }
            return parseNumber()
        }
        function parsePower() {
            let result = parseFactor()
            while (pos < input.length && /\s/.test(input[pos])) pos++
            if (input[pos] === '^') { pos++; result = Math.pow(result, parseFactor()) }
            return result
        }
        function parseTerm() {
            let result = parsePower()
            while (pos < input.length) {
                while (pos < input.length && /\s/.test(input[pos])) pos++
                if (input[pos] === '*') { pos++; result *= parsePower() }
                else if (input[pos] === '/') { pos++; result /= parsePower() }
                else if (input[pos] === '%') { pos++; result %= parsePower() }
                else break
            }
            return result
        }
        function parseExpr() {
            let result = parseTerm()
            while (pos < input.length) {
                while (pos < input.length && /\s/.test(input[pos])) pos++
                if (input[pos] === '+') { pos++; result += parseTerm() }
                else if (input[pos] === '-') { pos++; result -= parseTerm() }
                else break
            }
            return result
        }
        const result = parseExpr()
        while (pos < input.length && /\s/.test(input[pos])) pos++
        if (pos !== input.length) throw new Error("Unexpected")
        return result
    }

    function filterApps(query) {
        combinedModel.clear()
        const q = query.toLowerCase().trim()

        let usage = {}
        try { usage = JSON.parse(appUsage.usageData || "{}") } catch(e) {}

        // relevance: name prefix > word start in name > substring > generic name
        function score(a) {
            if (q === "") return 1
            const n = a.name.toLowerCase()
            if (n.startsWith(q)) return 4
            if (n.includes(" " + q) || n.includes("-" + q)) return 3
            if (n.includes(q)) return 2
            return a.genericName.toLowerCase().includes(q) ? 1 : 0
        }
        let hits = []
        for (const a of allApps) {
            if (root.activeCategory !== "All" && !(a.categories || []).includes(root.activeCategory)) continue
            const sc = score(a)
            if (sc > 0) hits.push({ app: a, sc: sc, use: usage[a.desktopId] || 0 })
        }
        hits.sort((x, y) => (y.sc - x.sc) || (y.use - x.use))
        hits = hits.map(h => h.app)
        hits = hits.slice(0, q === "" ? 8 : 6)

        hits.forEach((a, i) => {
            const ic = a.icon
            combinedModel.append({
                label: a.name, sub: a.genericName,
                // quickshell has no image://theme provider (every themed icon
                // failed to load); iconPath() maps to its image://icon provider
                iconSrc: ic && ic.includes("/") ? "file://" + ic
                       : Quickshell.iconPath(ic || "application-x-executable", "application-x-executable"),
                kind: "app", appIdx: allApps.indexOf(a),
                desktopId: a.desktopId,
                exec: a.exec,
                source: a.source
            })
        })

        // Calculator mode
        const mathMatch = q.match(/^[\d\s\+\-\*\/\.\(\)%^]+$/)
        if (mathMatch && q.match(/[\+\-\*\/%^]/)) {
            try {
                const result = parseArithmetic(q)
                if (typeof result === 'number' && isFinite(result)) {
                    combinedModel.insert(0, {
                        label: "= " + (Number.isInteger(result) ? result : result.toFixed(6).replace(/\.?0+$/, "")),
                        sub: q, iconSrc: Quickshell.iconPath("accessories-calculator", "application-x-executable"),
                        kind: "calc", appIdx: -1, desktopId: "", exec: ""
                    })
                }
            } catch(_) {}
        }

        // file search is debounced: fd walks $HOME on every run, and each
        // keystroke used to kill and respawn it
        root._fdSerial++
        if (q.length >= 2) _fdDebounce.restart()
        else _fdDebounce.stop()
        resultsList.currentIndex = 0
    }

    // Split a desktop Exec string into argv per the XDG spec: honour "…"/'…'
    // quoting, drop field codes (%f %u …), strip flatpak forwarding wrappers.
    function _parseExec(exec) {
        const args = []
        let cur = ""
        let quote = ""
        let has = false
        for (let i = 0; i < exec.length; i++) {
            const ch = exec[i]
            if (quote) {
                if (ch === quote) quote = ""
                else if (ch === "\\" && quote === '"' && i + 1 < exec.length) { i++; cur += exec[i] }
                else cur += ch
            } else if (ch === '"' || ch === "'") {
                quote = ch; has = true
            } else if (ch === " " || ch === "\t") {
                if (has) { args.push(cur); cur = ""; has = false }
            } else {
                cur += ch; has = true
            }
        }
        if (has) args.push(cur)
        return args.filter(a => {
            if (a === "--file-forwarding") return false
            if (/^%[uUfFdDnNickvm]$/.test(a)) return false  // bare field codes
            return true
        }).map(a => a.replace(/%[uUfFdDnNickvm]/g, "").replace(/%%/g, "%"))
          .filter(a => a !== "")
          // `app -- %u` with the field code removed leaves a bare trailing `--`,
          // which some apps (Sober) reject as their only argument
          .filter((a, i, arr) => !(a === "--" && i === arr.length - 1))
    }

    function launchItem(idx) {
        if (idx < 0 || idx >= combinedModel.count) return
        const item = combinedModel.get(idx)

        if (item.kind === "calc") {
            // Copy result to clipboard - content via stdin, never in shell string
            launchProc.command = ["setsid", "-f", "sh", "-c", "printf '%s' \"$1\" | xclip -selection clipboard", "_", item.label.slice(2)]
            launchProc.running = false; launchProc.running = true
            root.visible = false
            return
        }
        if (item.kind === "app") {
            let usage = {}
            try { usage = JSON.parse(appUsage.usageData || "{}") } catch(e) {}
            usage[item.desktopId] = (usage[item.desktopId] || 0) + 1
            appUsage.usageData = JSON.stringify(usage)

            // Parse the desktop Exec into an argv array (XDG spec quoting) - never
            // through `sh -c`, so a crafted .desktop file can't inject shell.
            const argv = root._parseExec(item.exec)
            if (argv.length > 0) {
                // setsid -f detaches so SIGTERM on launchProc doesn't reach the app
                launchProc.command = ["setsid", "-f"].concat(argv)
                launchProc.running = false; launchProc.running = true
            }
        } else {
            launchProc.command = ["setsid", "-f", "xdg-open", item.filePath]
            launchProc.running = false; launchProc.running = true
        }
        root.visible = false
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.visible = false
    }

    Rectangle {
        anchors.centerIn: parent
        width: 580; height: 540
        color: Colors.background
        radius: 12
        MouseArea { anchors.fill: parent }

        Column {
            anchors { fill: parent; margins: 14 }
            spacing: 8

            // ── Category chips ────────────────────────────────────────
            Row {
                width: parent.width
                spacing: 4
                clip: true

                Repeater {
                    model: ["All","Internet","Dev","Media","Games","System","Office"]
                    delegate: Rectangle {
                        height: 24; radius: 12
                        width: chipLbl.implicitWidth + 18
                        color: root.activeCategory === modelData ? Colors.purple
                             : Qt.lighter(Colors.background, 1.35)
                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            id: chipLbl
                            anchors.centerIn: parent
                            text: modelData
                            font.family: "Iosevka Nerd Font"; font.pixelSize: 11
                            color: root.activeCategory === modelData ? Colors.background : Colors.foreground
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                root.activeCategory = modelData
                                filterApps(searchInput.text)
                            }
                        }
                    }
                }
            }

            // ── Search box ────────────────────────────────────────────
            Rectangle {
                width: parent.width; height: 46
                radius: 10
                color: Qt.lighter(Colors.background, 1.3)
                border.color: searchInput.activeFocus ? Colors.purple : "transparent"
                border.width: 2
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Row {
                    anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\uF002"
                        font.family: "Iosevka Nerd Font"; font.pixelSize: 14
                        color: Colors.muted
                    }
                    TextInput {
                        id: searchInput
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 34
                        font.pixelSize: 14; font.family: "Iosevka Nerd Font"
                        color: Colors.foreground
                        selectionColor: Colors.purple
                        onTextChanged: filterApps(text)
                        Keys.onUpPressed:     function(event) { resultsList.currentIndex = Math.max(0, resultsList.currentIndex - 1); event.accepted = true }
                        Keys.onDownPressed:   function(event) { resultsList.currentIndex = Math.min(resultsList.count - 1, resultsList.currentIndex + 1); event.accepted = true }
                        Keys.onReturnPressed: function(event) { launchItem(resultsList.currentIndex); event.accepted = true }
                        Keys.onEnterPressed:  function(event) { launchItem(resultsList.currentIndex); event.accepted = true }
                        Keys.onEscapePressed: function(event) { root.visible = false; event.accepted = true }
                    }
                }
            }

            // ── Results ───────────────────────────────────────────────
            ListView {
                id: resultsList
                width: parent.width
                height: parent.height - 24 - 8 - 46 - 8
                clip: true; model: combinedModel; spacing: 2; currentIndex: 0
                delegate: Rectangle {
                    required property int index
                    required property var modelData
                    width: resultsList.width; height: 50; radius: 8
                    color: resultsList.currentIndex === index ? Colors.purple
                         : (itemMa.containsMouse ? Qt.lighter(Colors.background, 1.4) : "transparent")
                    Behavior on color { ColorAnimation { duration: 100 } }
                    Row {
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        spacing: 12
                        Image {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28; height: 28; smooth: true; mipmap: true
                            source: modelData.iconSrc || ""
                            fillMode: Image.PreserveAspectFit
                            onStatusChanged: if (status === Image.Error) source = ""
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter; spacing: 2
                            Row {
                                spacing: 6
                                Text {
                                    text: modelData.label || ""
                                    font.pixelSize: 13; font.family: "Iosevka Nerd Font"
                                    color: resultsList.currentIndex === index ? Colors.background : Colors.foreground
                                }
                                // flatpak badge - small pill so user knows what'll run
                                Rectangle {
                                    visible: modelData.source === "flatpak"
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: fpText.implicitWidth + 10; height: 14; radius: 7
                                    color: Qt.rgba(Colors.rose.r, Colors.rose.g, Colors.rose.b, 0.22)
                                    Text {
                                        id: fpText
                                        anchors.centerIn: parent
                                        text: "FLATPAK"
                                        font.pixelSize: 8; font.family: "Iosevka Nerd Font"; font.bold: true
                                        color: Colors.rose
                                    }
                                }
                            }
                            Text {
                                text: modelData.sub || ""; font.pixelSize: 11
                                color: resultsList.currentIndex === index ? Qt.lighter(Colors.background,1.6) : Colors.muted
                                visible: (modelData.sub || "") !== ""
                            }
                        }
                    }
                    MouseArea {
                        id: itemMa; anchors.fill: parent; hoverEnabled: true
                        onClicked: launchItem(index)
                        onEntered: resultsList.currentIndex = index
                    }
                }
            }
        }
    }

    ListModel { id: combinedModel }

    property int _fdSerial: 0
    Timer {
        id: _fdDebounce
        interval: 180
        onTriggered: {
            const q = searchInput.text.toLowerCase().trim()
            if (q.length < 2) return
            // serial first so output of a superseded search is ignored;
            // --fixed-strings: queries like "c++" are not valid regexes;
            // `--` keeps a query starting with "-" from being read as a flag
            // Debian names the binary fdfind
            fdProc.command = ["sh", "-c", 'printf "%s\\n" "$1"; shift; f=$(command -v fd || command -v fdfind) || exit 0; exec "$f" "$@"', "_",
                              String(root._fdSerial), "--max-depth", "4", "--type", "f",
                              "--fixed-strings", "--", q, root.homeDir]
            fdProc.running = false
            fdProc.running = true
        }
    }

    readonly property Process fdProc: Process {
        id: fdProc
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.split("\n")
                if (parseInt(lines[0]) !== root._fdSerial) return
                for (let i = combinedModel.count - 1; i >= 0; i--)
                    if (combinedModel.get(i).kind === "file") combinedModel.remove(i)
                const iconMap = {
                    "png":"image-x-generic","jpg":"image-x-generic","jpeg":"image-x-generic",
                    "mp3":"audio-x-generic","flac":"audio-x-generic","mp4":"video-x-generic",
                    "mkv":"video-x-generic","pdf":"application-pdf",
                    "md":"text-x-generic","txt":"text-plain","zip":"package-x-generic"
                }
                lines.slice(1).filter(Boolean).slice(0, 5).forEach(path => {
                    const name = path.split("/").pop()
                    const ext  = name.includes(".") ? name.split(".").pop().toLowerCase() : ""
                    combinedModel.append({
                        label: name, sub: path.startsWith(root.homeDir + "/") ? "~" + path.slice(root.homeDir.length) : path,
                        iconSrc: Quickshell.iconPath(iconMap[ext] || (ext ? "text-x-generic" : "folder"), "text-x-generic"),
                        kind: "file", appIdx: -1, filePath: path
                    })
                })
            }
        }
    }

    Process { id: launchProc; running: false }
}
