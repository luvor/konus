import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import QtMultimedia
import QtCore
import Konus

ApplicationWindow {
    id: win
    width: 1280
    height: 760
    minimumWidth: 960
    minimumHeight: 560
    visible: true
    color: Theme.window
    palette.toolTipBase: "#2b2b2b"
    palette.toolTipText: "#c8c8c8"
    palette.dark: "#3a3a3a"
    palette.mid: "#444444"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: player.title
    property bool showChrome: true
    property real chromeOpacity: showChrome ? 1 : 0
    readonly property bool chromePresent: showChrome || chromeOpacity > 0
    Behavior on chromeOpacity { NumberAnimation { duration: 150 } }
    function isChromeControl(item) {
        for (; item; item = item.parent) {
            if (!item.visible) return false
            if (item === titlebar || item === rail || item === libpanel || item === controlbar) return true
        }
        return false
    }
    readonly property bool chromeFocused: isChromeControl(activeFocusItem)
    onActiveFocusItemChanged: if (isChromeControl(activeFocusItem)) reveal()
    property bool libraryOpen: true
    property string section: "Videos"
    property bool seekPressed: false
    property bool volumePressed: false
    property int wheelRemainder: 0
    property real seekDisplay: -1
    property string searchText: ""
    property bool searchOpen: false
    onSearchOpenChanged: if (!searchOpen) {
        searchText = ""
        if (searchField.activeFocus) win.contentItem.forceActiveFocus()
    }
    property int beforeFullscreen: Window.Windowed
    function toggleFullscreen() {
        if (visibility === Window.FullScreen) {
            showNormal()
            // Qt restores a frameless macOS fullscreen window before it can maximize again.
            if (beforeFullscreen === Window.Maximized) Qt.callLater(win.showMaximized)
        }
        else { beforeFullscreen = visibility; visibility = Window.FullScreen }
    }
    property int fileRevision: 0
    readonly property bool chromeHovered: titleHover.hovered || railHover.hovered || panelHover.hovered || controlsHover.hovered
    function fmt(ms) {
        let s = Math.floor(Math.max(0, ms) / 1000)
        return Math.floor(s / 3600).toString().padStart(2, "0") + ":" + Math.floor(s / 60 % 60).toString().padStart(2, "0") + ":" + (s % 60).toString().padStart(2, "0")
    }
    function sameUrl(a, b) {
        const normalize = value => String(value).replace("file:///private/", "file:///")
        return normalize(a) === normalize(b)
    }
    function reveal() { showChrome = true; idle.restart() }
    readonly property int currentFileIndex: {
        const revision = fileRevision
        for (let i = 0; i < files.count; i++) if (sameUrl(files.get(i, "fileUrl"), player.currentUrl)) return i
        return -1
    }
    onCurrentFileIndexChanged: syncCurrentRow()
    function stepFile(delta) {
        for (let i = 0; i < files.count; i++) {
            if (sameUrl(files.get(i, "fileUrl"), player.currentUrl)) {
                const next = i + delta
                if (next >= 0 && next < files.count) player.open(files.get(next, "fileUrl"))
                return
            }
        }
    }
    function syncCurrentRow() {
        fileList.currentIndex = currentFileIndex
    }
    function notify(message, duration, error) {
        osd.error = error || false
        osd.text = message
        osd.opacity = 1
        osdTimer.interval = duration || 1500
        osdTimer.restart()
    }
    function wheelVolume(delta) {
        let total = wheelRemainder + delta
        let steps = Math.trunc(total / 120)
        wheelRemainder = total - steps * 120
        if (steps) { player.volume = Math.max(0, Math.min(100, player.volume + steps * 5)); notify("Volume " + player.volume + "%") }
    }
    function setMuted(muted) {
        player.muted = muted
        notify(muted ? "Muted" : "Unmuted")
    }
    Timer {
        id: idle
        interval: 2500
        onTriggered: {
            if (!player.playing || !player.hasVideo) return
            if (win.chromeHovered || win.chromeFocused || win.seekPressed || win.volumePressed) restart()
            else win.showChrome = false
        }
    }
    Timer { id: osdTimer; interval: 1500; onTriggered: osd.opacity = 0 }
    Connections {
        target: player
        function onPlayingChanged() {
            if (player.hasMedia) win.notify(player.playing ? "Playing" : "Paused")
            idle.restart()
        }
        function onEndReached() { win.stepFile(1) }
        function onHasVideoChanged() { win.reveal() }
        function onPlaybackError(message) { win.notify(message, 5000, true) }
        function onAudioTrackChanged(name) { win.notify(name) }
        function onSubtitleChanged(name) { win.notify(name) }
        function onCurrentUrlChanged() { win.syncCurrentRow() }
    }
    FileDialog {
        id: picker
        nameFilters: ["Media files (*.mp4 *.mkv *.mov *.avi *.webm *.m4v *.wmv *.flv *.ts *.m2ts *.mpg *.mpeg *.3gp *.ogv *.mp3 *.flac *.m4a *.wav *.ogg *.opus *.aac *.m4b *.aiff)", "All files (*)"]
        onAccepted: player.open(selectedFile)
    }
    FolderListModel {
        id: files
        folder: section === "Music" ? StandardPaths.writableLocation(StandardPaths.MusicLocation) : StandardPaths.writableLocation(StandardPaths.MoviesLocation)
        showDirs: false
        sortReversed: false
        caseSensitive: false
        sortCaseSensitive: false
        onCountChanged: win.syncCurrentRow()
        nameFilters: {
            const extensions = section === "Music" ? ["mp3", "flac", "m4a", "wav", "ogg", "opus", "aac", "m4b", "aiff"] : ["mp4", "mkv", "mov", "avi", "webm", "m4v", "wmv", "flv", "ts", "m2ts", "mpg", "mpeg", "3gp", "ogv"]
            const escaped = searchText.replace(/[\[\]*?]/g, "[$&]")
            return extensions.map(ext => searchText ? "*" + escaped + "*." + ext : "*." + ext)
        }
    }
    Connections {
        target: files
        function onDataChanged() { ++win.fileRevision }
        function onRowsInserted() { ++win.fileRevision }
        function onRowsRemoved() { ++win.fileRevision }
        function onRowsMoved() { ++win.fileRevision }
        function onLayoutChanged() { ++win.fileRevision }
        function onModelReset() { ++win.fileRevision }
    }
    Shortcut { sequences: [StandardKey.Open]; onActivated: picker.open() }
    Shortcut { sequence: "Space"; onActivated: playMouse.activate() }
    Shortcut { sequence: "Shift+Left"; onActivated: win.seekBy(-30000) }
    Shortcut { sequence: "Shift+Right"; onActivated: win.seekBy(30000) }
    function seekBy(delta) {
        if (player.length <= 0) return
        const time = Math.max(0, Math.min(player.length, player.time + delta))
        player.seek(time)
        notify((delta < 0 ? "" : "+") + (delta / 1000) + " s · " + fmt(time), 800)
    }
    Shortcut { sequence: "Left"; onActivated: if (!seekBarMouse.activeFocus && !fileList.activeFocus) win.seekBy(-5000) }
    Shortcut { sequence: "Right"; onActivated: if (!seekBarMouse.activeFocus && !fileList.activeFocus) win.seekBy(5000) }
    Shortcut { sequence: "Tab"; enabled: !win.showChrome; onActivated: { win.reveal(); sidebarIcon.forceActiveFocus(Qt.TabFocusReason) } }
    Shortcut { sequence: "Up"; enabled: !fileList.activeFocus && !volumeMouse.activeFocus; onActivated: { player.volume = Math.min(100, player.volume + 5); notify("Volume " + player.volume + "%") } }
    Shortcut { sequence: "Down"; enabled: !fileList.activeFocus && !volumeMouse.activeFocus; onActivated: { player.volume = Math.max(0, player.volume - 5); notify("Volume " + player.volume + "%") } }
    Shortcut { sequence: "M"; onActivated: { win.reveal(); win.setMuted(!player.muted) } }
    Shortcut { sequence: "F"; onActivated: { win.reveal(); win.toggleFullscreen() } }
    Shortcut { sequence: "Escape"; onActivated: { win.reveal(); if (searchOpen) { searchText = ""; searchOpen = false } else if (win.visibility === Window.FullScreen) win.toggleFullscreen() } }
    DropArea { id: dropArea; anchors.fill: parent; onDropped: if (drop.urls.length) player.open(drop.urls[0]) }
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: win.showChrome ? Qt.ArrowCursor : Qt.BlankCursor
        property point lastPointer: Qt.point(-1, -1)
        onPositionChanged: (mouse) => {
            if (win.showChrome || lastPointer.x < 0 || Math.hypot(mouse.x - lastPointer.x, mouse.y - lastPointer.y) >= 3) {
                lastPointer = Qt.point(mouse.x, mouse.y)
                win.reveal()
            }
        }
        onExited: idle.restart()
        onWheel: win.wheelVolume(wheel.angleDelta.y)
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: win.chromePresent || win.visibility === Window.FullScreen ? 0 : 10
        spacing: 0
        Rectangle {
            id: titlebar
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Theme.window
            visible: win.chromePresent
            opacity: win.chromeOpacity
            HoverHandler { id: titleHover }
            Image { x: 15; y: 8; width: 20; height: 25; source: "image://icons/cone/d37918"; sourceSize: Qt.size(40, 50) }
            Icon { x: 57; y: 18; name: "MoreHorizontal"; glyphWidth: 16; glyphHeight: 4; tooltip: "Not available yet"; accessibleName: "More options" }
            Icon {
                id: sidebarIcon
                x: 87; y: 4
                name: win.libraryOpen ? "SidebarLeft" : "SidebarLeftOutline"
                glyphWidth: 18; glyphHeight: 18
                interactive: true
                tint: "#8f8f8f"
                tooltip: "Toggle library"
                accessibleName: "Toggle library"
                onActivated: win.libraryOpen = !win.libraryOpen
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.libraryOpen = !win.libraryOpen }
            }
            Rectangle { x: 128; y: 10; width: 2; height: 20; color: "#303030" }
            Icon { x: 145; y: 11; name: "Folder01"; glyphWidth: 20; glyphHeight: 18 }
            Text { x: 173; y: 12; text: section; color: "#8f8f8f"; font.pixelSize: 14 }
            Repeater {
                model: ["MinusSign", "Maximize01", "FullScreen", "Cancel01"]
                delegate: Icon {
                    required property string modelData
                    required property int index
                    x: titlebar.width - 148 + index * 36; y: 4
                    name: modelData === "Maximize01" && win.visibility === Window.Maximized ? "Restore" : modelData === "FullScreen" && win.visibility === Window.FullScreen ? "ExitFullScreen" : modelData
                    size: modelData === "MinusSign" || modelData === "Cancel01" ? 18 : 14
                    tint: modelData === "MinusSign" ? "#727272" : modelData === "Cancel01" ? "#8f8f8f" : "#888888"
                    interactive: true
                    closeButton: modelData === "Cancel01"
                    accessibleName: modelData === "Cancel01" ? "Close" : modelData === "MinusSign" ? "Minimize" : modelData === "FullScreen" ? (win.visibility === Window.FullScreen ? "Exit fullscreen" : "Fullscreen") : (win.visibility === Window.Maximized ? "Restore" : "Maximize")
                    tooltip: accessibleName
                    onActivated: if (modelData === "Cancel01") win.close(); else if (modelData === "MinusSign") win.showMinimized(); else if (modelData === "FullScreen") win.toggleFullscreen(); else win.visibility = win.visibility === Window.Maximized ? Window.Windowed : Window.Maximized
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.activated()
                    }
                }
            }
            Text { anchors.centerIn: parent; anchors.verticalCenterOffset: 1; width: Math.min(300, parent.width - 600); text: player.title; color: "#8f8f8f"; font.pixelSize: 14; font.letterSpacing: -0.1; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
            MouseArea {
                anchors.fill: parent
                z: -1
                property point start
                property bool moved: false
                onPressed: { start = Qt.point(mouse.x, mouse.y); moved = false }
                onPositionChanged: if (pressed && !moved && Math.hypot(mouse.x - start.x, mouse.y - start.y) >= 4) { moved = true; win.startSystemMove() }
                onDoubleClicked: win.visibility = win.visibility === Window.Maximized ? Window.Windowed : Window.Maximized
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
            Rectangle {
                id: rail
                visible: win.chromePresent
                opacity: win.chromeOpacity
                Layout.fillHeight: true
                Layout.preferredWidth: visible ? 50 : 0
                color: Theme.rail
                HoverHandler { id: railHover }
                Column {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                            anchors.topMargin: 1
                    spacing: 0
                    Repeater {
                        model: ["Home01", "PlaySquare", "FolderMusic", "Broadcast", "Playlist01", "RecentClock", "Add01"]
                        delegate: Item {
                            required property string modelData
                            required property int index
                            width: 50
                            height: 46
                            Icon {
                                width: 50; height: 46
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: index === 4 ? 1 : 0
                                name: modelData
                                glyphWidth: [18, 20, 20, 22, 20, 18, 16][index]
                                glyphHeight: [18, 20, 20, 16, 14, 16, 16][index]
                                interactive: true
                                accessibleName: ["Home", "Videos", "Music", "Network", "Playlists", "Recent", "Add"][index]
                                tooltip: accessibleName
                                onActivated: if (index === 6) picker.open(); else { win.section = ["Home", "Videos", "Music", "Network", "Playlists", "Recent"][index]; win.libraryOpen = true }
                                tint: win.section === ["Home", "Videos", "Music", "Network", "Playlists", "Recent"][index] ? Theme.accent : railMouse.containsMouse ? "#b0b0b0" : index === 6 ? "#888888" : "#8f8f8f"
                                hoverTint: win.section === ["Home", "Videos", "Music", "Network", "Playlists", "Recent"][index] ? Theme.accent : "#b0b0b0"
                                MouseArea {
                                    id: railMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: if (index === 6) picker.open(); else { win.section = ["Home", "Videos", "Music", "Network", "Playlists", "Recent"][index]; win.libraryOpen = true }
                                }
                            }
                        }
                    }
                }
            }
            Rectangle {
                id: libpanel
                visible: win.chromePresent && win.libraryOpen
                opacity: win.chromeOpacity
                Layout.fillHeight: true
                    Layout.preferredWidth: visible ? Theme.panelWidth : 0
                color: Theme.panel
                HoverHandler { id: panelHover }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 20
                    anchors.rightMargin: 20
                    anchors.topMargin: 16
                    anchors.bottomMargin: 20
                    spacing: 0
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 32
                        Icon { x: 4; y: 10; name: "ArrowLeftStem"; glyphWidth: 16; glyphHeight: 12; tooltip: "Not available yet"; accessibleName: "Back" }
                        Icon { x: 40; y: 10; name: "ArrowRightStem"; glyphWidth: 16; glyphHeight: 12; tint: "#363535"; tooltip: "Not available yet"; accessibleName: "Forward" }
                        Text { x: 71; y: 7; text: section; color: "#8f8f8f"; font.pixelSize: 16 }
                        Icon { x: parent.width - 56; y: 14; name: "MoreHorizontal"; glyphWidth: 16; glyphHeight: 4; tint: Theme.muted; tooltip: "Not available yet"; accessibleName: "More options" }
                        Icon { x: parent.width - 20; y: 8; name: "LinkSquare01"; glyphWidth: 16; glyphHeight: 16; tint: Theme.muted; tooltip: "Not available yet"; accessibleName: "Pop out" }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 44
                        Layout.topMargin: 8
                        Text { x: 1; y: 12; text: files.count === 1 ? "1 item" : files.count + " items"; color: Theme.muted; font.pixelSize: 14; visible: section === "Videos" || section === "Music" }
                        Icon {
                            x: parent.width - 100; y: 4
                            name: "SortArrows"; glyphWidth: 20; glyphHeight: 16; interactive: true; tint: Theme.muted
                            tooltip: "Sort"; accessibleName: "Reverse sort order"
                            onActivated: files.sortReversed = !files.sortReversed
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: files.sortReversed = !files.sortReversed }
                        }
                        Icon { x: parent.width - 58; y: 12; name: "ListView"; glyphWidth: 20; glyphHeight: 16; tint: Theme.muted; tooltip: "Not available yet"; accessibleName: "List view" }
                        Icon {
                            x: parent.width - 27.5; y: 4.5
                            name: "Search01"; glyphWidth: 17; glyphHeight: 17; interactive: true; tint: Theme.muted; tooltip: "Search"; accessibleName: "Search files"
                            onActivated: { win.searchOpen = !win.searchOpen; if (win.searchOpen) searchField.forceActiveFocus(); else win.searchText = "" }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { win.searchOpen = !win.searchOpen; if (win.searchOpen) searchField.forceActiveFocus(); else win.searchText = "" } }
                        }
                    }
                    TextField {
                        id: searchField
                        Layout.fillWidth: true
                        Layout.preferredHeight: searchOpen ? 32 : 0
                        visible: searchOpen
                        text: win.searchText
                        placeholderText: "Filter files"
                        color: Theme.text
                        selectByMouse: true
                        onTextChanged: win.searchText = text
                        Keys.onEscapePressed: { win.searchText = ""; text = ""; win.searchOpen = false }
                        background: Rectangle { color: "#202020"; radius: 3; border.color: "#444444" }
                    }
                    Rectangle { Layout.fillWidth: true; height: 2; Layout.topMargin: 4; color: "#191919" }
                    Item {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 40
                        Layout.topMargin: 15
                        Rectangle { anchors.fill: parent; radius: 4; color: addMouse.containsMouse ? "#0dffffff" : "transparent"; border.width: addMouse.activeFocus ? 1 : 0; border.color: Theme.accent }
                        Icon { x: 8; anchors.verticalCenter: parent.verticalCenter; name: "Add01"; size: 16; tint: "#666666" }
                        Text { x: 42; anchors.verticalCenter: parent.verticalCenter; anchors.verticalCenterOffset: 1; text: "Add…"; color: Theme.muted; font.pixelSize: 14 }
                        MouseArea {
                            id: addMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            activeFocusOnTab: true
                            Accessible.role: Accessible.Button
                            Accessible.name: "Add files"
                            Accessible.onPressAction: picker.open()
                            Keys.onSpacePressed: picker.open()
                            Keys.onReturnPressed: picker.open()
                            Keys.onShortcutOverride: (event) => { if (event.key === Qt.Key_Space) event.accepted = true }
                            onClicked: picker.open()
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        ListView {
                            id: fileList
                            anchors.fill: parent
                            anchors.topMargin: 1
                            clip: true
                            visible: win.section === "Videos" || win.section === "Music"
                            model: files
                            spacing: 0
                            activeFocusOnTab: true
                            property bool keyboardFocus: false
                            onActiveFocusChanged: keyboardFocus = activeFocus
                            ScrollBar.vertical: ScrollBar {
                                id: libraryScroll
                                policy: ScrollBar.AsNeeded
                                visible: size < 1
                                palette.mid: "#444444"
                                contentItem: Rectangle {
                                    implicitWidth: 6
                                    radius: 3
                                    color: "#555555"
                                    opacity: libraryScroll.active || libraryScroll.hovered ? 1 : 0
                                    Behavior on opacity { NumberAnimation { duration: 150 } }
                                }
                            }
                            delegate: Rectangle {
                                required property string fileName
                                required property url fileUrl
                                required property int index
                                width: fileList.width
                                height: 42
                                color: rowMouse.containsMouse && index !== fileList.currentIndex ? "#0dffffff" : "transparent"
                                border.width: fileList.activeFocus && fileList.keyboardFocus && index === fileList.currentIndex ? 1 : 0
                                border.color: Theme.accent
                                Accessible.role: Accessible.ListItem
                                Accessible.name: fileName
                                Accessible.onPressAction: { fileList.currentIndex = index; player.open(fileUrl) }
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 5
                                    spacing: 14
                                    Icon { name: win.section === "Music" ? "MusicNote01" : "Video01"; glyphWidth: 22; glyphHeight: 18; transform: Translate { y: 1 } interactive: false; tint: win.sameUrl(fileUrl, player.currentUrl) ? Theme.accent : "#8f8f8f" }
                                    Text { Layout.fillWidth: true; text: fileName; color: win.sameUrl(fileUrl, player.currentUrl) ? Theme.accent : "#969696"; font.pixelSize: 14; elide: Text.ElideRight }
                                }
                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { fileList.currentIndex = index; fileList.focus = false; fileList.keyboardFocus = false; player.open(fileUrl) }
                                }
                            }
                            Keys.onUpPressed: { keyboardFocus = true; decrementCurrentIndex() }
                            Keys.onDownPressed: { keyboardFocus = true; incrementCurrentIndex() }
                            Keys.onReturnPressed: if (currentIndex >= 0) player.open(files.get(currentIndex, "fileUrl"))
                            Keys.onEnterPressed: if (currentIndex >= 0) player.open(files.get(currentIndex, "fileUrl"))
                        }
                        Text {
                            id: emptyLibraryText
                            anchors.centerIn: parent
                            visible: (section === "Videos" || section === "Music") && files.count === 0
                            text: searchText ? "No matches for \"" + searchText + "\"" : section === "Music" ? "No music in " + decodeURIComponent(files.folder.toString().replace(/\/$/, "").split("/").pop()) + ". Drop files or click Add…" : "No videos in " + decodeURIComponent(files.folder.toString().replace(/\/$/, "").split("/").pop()) + ". Drop files or click Add…"
                            color: Theme.muted
                            font.pixelSize: 14
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width - 24
                        }
                        Text { anchors.centerIn: parent; visible: section === "Home" || section === "Network" || section === "Playlists" || section === "Recent"; text: "Nothing here yet"; color: Theme.muted; font.pixelSize: 13 }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.bottomMargin: win.chromePresent ? 1 : 0
                Layout.rightMargin: win.chromePresent && win.visibility !== Window.FullScreen ? 10 : 0
                color: Theme.video
                            Rectangle {
                    anchors.fill: parent
                    color: Theme.video
                    Rectangle { anchors.fill: parent; anchors.margins: 2; color: "transparent"; border.width: dropArea.containsDrag ? 2 : 0; border.color: Theme.accent }
                    VideoOutput { id: output; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit }
                    Text { anchors.centerIn: parent; width: parent.width - 40; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle; visible: !player.hasVideo; text: player.currentUrl.toString() ? player.title : "Drop a video here or click Add"; color: Theme.text; font.pixelSize: 13 }
                    Repeater {
                        model: 4
                        delegate: Canvas {
                            required property int index
                            width: 8; height: 8; z: 2
                            visible: win.visibility !== Window.FullScreen && (!win.chromePresent || index < 2)
                            x: index < 2 ? parent.width - width : 0
                            y: index === 0 || index === 3 ? 0 : parent.height - height
                            rotation: index * 90
                            onPaint: {
                                const c = getContext("2d")
                                c.clearRect(0, 0, width, height)
                                c.fillStyle = Theme.window
                                c.beginPath(); c.moveTo(0, 0); c.lineTo(width, 0); c.lineTo(width, height)
                                c.arc(0, height, width, 0, -Math.PI / 2, true); c.closePath(); c.fill()
                            }
                        }
                    }
                    Rectangle {
                        id: osd
                        property string text: ""
                        property bool error: false
                        Accessible.role: Accessible.AlertMessage
                        Accessible.name: text
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 20
                        color: error ? "#e6381c19" : "#b3000000"
                        border.width: error ? 1 : 0
                        border.color: "#c42b1c"
                        radius: 18
                        opacity: 0
                        visible: opacity > 0
                        z: 3
                        width: Math.min(osdLabel.implicitWidth + 28, parent.width - 40)
                        height: 34
                        Text { id: osdLabel; anchors.centerIn: parent; width: parent.width - 28; horizontalAlignment: Text.AlignHCenter; elide: Text.ElideMiddle; text: osd.text; color: "white"; font.pixelSize: 13 }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: player.togglePause()
                        onDoubleClicked: { player.togglePause(); win.toggleFullscreen() }
                    }
                }
            }
        }
        Rectangle {
            id: controlbar
            Layout.fillWidth: true
            Layout.preferredHeight: 54
            color: Theme.control
            visible: win.chromePresent
            opacity: win.chromeOpacity
            HoverHandler { id: controlsHover }
            Item {
                anchors.fill: parent
                anchors.topMargin: -1
                Item {
                    x: 0; y: 0; width: 154; height: parent.height
                    Icon { x: 20.5; y: 12; name: "Previous"; glyphWidth: 11; glyphHeight: 12; interactive: true; enabled: win.currentFileIndex > 0; tint: "#8f8f8f"; accessibleName: "Previous file"; tooltip: "Previous"; onActivated: win.stepFile(-1); MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.stepFile(-1) } }
                    Rectangle {
                        x: 58; y: 14; width: 54; height: 28
                        border.width: playMouse.activeFocus ? 2 : 0
                        border.color: "#1a1a1a"
                        color: playMouse.pressed ? Qt.darker(Theme.accent, 1.2) : playMouse.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent
                        radius: 6
                        Icon { anchors.centerIn: parent; name: player.playing ? "Pause" : "Play"; size: 18; tint: "#1a1a1a"; interactive: false }
                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: player.playing ? "Pause" : "Play"
                            ToolTip {
                                visible: playMouse.containsMouse
                                delay: 600
                                text: player.playing ? "Pause" : "Play"
                                background: Rectangle { color: "#2b2b2b"; border.color: "#3a3a3a"; radius: 4 }
                            }
                            activeFocusOnTab: true
                            function activate() { if (!player.hasMedia && files.count) player.open(files.get(0, "fileUrl")); else if (!player.hasMedia) picker.open(); else player.togglePause() }
                            Accessible.onPressAction: activate()
                            Keys.onShortcutOverride: (event) => { if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) event.accepted = true }
                            Keys.onSpacePressed: activate()
                            Keys.onReturnPressed: activate()
                            Keys.onEnterPressed: activate()
                            onClicked: activate()
                        }
                    }
                    Icon { x: 120.5; y: 12; name: "Next"; glyphWidth: 11; glyphHeight: 12; interactive: true; enabled: win.currentFileIndex >= 0 && win.currentFileIndex < files.count - 1; tint: "#8f8f8f"; accessibleName: "Next file"; tooltip: "Next"; onActivated: win.stepFile(1); MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.stepFile(1) } }
                }
                Text { x: 177; y: 19; text: fmt(win.seekPressed ? player.length * seekBar.dragProgress : player.time); color: Theme.text; font.pixelSize: 15; font.letterSpacing: -0.3 }
                Item {
                    id: seekBar
                    x: 251; y: 13
                    width: Math.max(120, parent.width - 676); height: 30
                    readonly property real progress: player.length > 0 ? Math.max(0, Math.min(1, player.time / player.length)) : 0
                    property real dragProgress: progress
                    property real seekOrigin: 0
                    property real lastScrubProgress: -1
                    readonly property real displayedProgress: seekBarMouse.pressed ? dragProgress : win.seekDisplay >= 0 ? win.seekDisplay : progress
                    readonly property real thumbX: 5 + (width - 18) * displayedProgress
                    Rectangle {
                        x: 3; y: 1; width: parent.width - 6; height: 28
                        color: "#090909"; radius: 4
                        Rectangle { x: 2; y: 2; width: seekBar.thumbX - 5 + 4; height: 24; color: Theme.seekFill; radius: 4 }
                    }
                    Rectangle { x: seekBar.thumbX; y: 3; width: 8; height: 24; color: seekBarMouse.containsMouse || seekBarMouse.pressed ? Qt.lighter(Theme.accent, seekBarMouse.pressed ? 1.25 : 1.12) : Theme.accent; radius: 4 }
                    Rectangle { anchors.fill: parent; radius: 4; color: "transparent"; border.color: Theme.accent; border.width: seekBarMouse.activeFocus ? 1 : 0 }
                    MouseArea {
                        id: seekBarMouse
                        anchors.fill: parent
                        enabled: player.length > 0
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        activeFocusOnTab: true
                        Accessible.role: Accessible.Slider
                        Accessible.name: "Playback position"
                        readonly property real value: player.time
                        readonly property real minimumValue: 0
                        readonly property real maximumValue: player.length
                        readonly property real stepSize: 5000
                        Accessible.description: win.fmt(player.time) + " of " + win.fmt(player.length)
                        Accessible.onIncreaseAction: player.seek(Math.min(player.length, player.time + 5000))
                        Accessible.onDecreaseAction: player.seek(Math.max(0, player.time - 5000))
                        Keys.onShortcutOverride: (event) => { if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) event.accepted = true }
                        Keys.onLeftPressed: (event) => { win.seekBy(event.modifiers & Qt.ShiftModifier ? -30000 : -5000); event.accepted = true }
                        Keys.onRightPressed: (event) => { win.seekBy(event.modifiers & Qt.ShiftModifier ? 30000 : 5000); event.accepted = true }
                        onPressed: (mouse) => { focus = false; win.seekPressed = true; seekBar.seekOrigin = player.time; seekBar.lastScrubProgress = -1; seekScrub.start(); seekBar.dragProgress = Math.max(0, Math.min(1, (mouse.x - 9) / (width - 18))) }
                        onPositionChanged: (mouse) => { if (pressed) seekBar.dragProgress = Math.max(0, Math.min(1, (mouse.x - 9) / (width - 18))) }
                        onCanceled: { seekScrub.stop(); if (seekBar.lastScrubProgress >= 0) player.seek(seekBar.seekOrigin); win.seekPressed = false; win.seekDisplay = -1; idle.restart() }
                        onReleased: { seekScrub.stop(); player.seek(player.length * seekBar.dragProgress); win.seekDisplay = seekBar.dragProgress; seekRelease.restart(); win.seekPressed = false; idle.restart() }
                        ToolTip {
                            background: Rectangle { color: "#2b2b2b"; border.color: "#3a3a3a"; radius: 4 }
                            id: seekTooltip
                            visible: seekBarMouse.containsMouse && player.length > 0
                            x: Math.max(0, Math.min(seekBarMouse.width - implicitWidth, seekBarMouse.mouseX - implicitWidth / 2))
                            text: win.fmt(player.length * Math.max(0, Math.min(1, (seekBarMouse.mouseX - 9) / (seekBarMouse.width - 18))))
                        }
                    }
                    Timer {
                        id: seekScrub
                        interval: 100; repeat: true
                        onTriggered: if (seekBar.lastScrubProgress !== seekBar.dragProgress) {
                            player.seek(player.length * seekBar.dragProgress)
                            seekBar.lastScrubProgress = seekBar.dragProgress
                        }
                    }
                    Timer { id: seekRelease; interval: 300; onTriggered: win.seekDisplay = -1 }
                }
                Text { x: parent.width - 414; y: 19; text: fmt(player.length); color: "#8f8f8f"; font.pixelSize: 15; font.letterSpacing: -0.3 }
                Item {
                    x: parent.width - 328; width: 328; height: parent.height
                    Icon {
                        x: 1; y: 12
                        name: player.muted ? "VolumeOff" : "VolumeLow"; glyphWidth: 20; glyphHeight: 16; interactive: true; tint: "#8f8f8f"
                        onActivated: win.setMuted(!player.muted)
                        accessibleName: player.muted ? "Unmute" : "Mute"; tooltip: accessibleName
                        Accessible.role: Accessible.Button
                        MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: win.setMuted(!player.muted); onWheel: win.wheelVolume(wheel.angleDelta.y) }
                    }
                    Item {
                        id: volumeBar
                        x: 36; y: 14; width: 89; height: 28
                        Rectangle { anchors.fill: parent; radius: 4; color: "transparent"; border.color: Theme.accent; border.width: volumeMouse.activeFocus ? 1 : 0 }
                        Canvas {
                            anchors.fill: parent
                            property real level: player.volume / 100
                            property bool highlighted: volumeMouse.containsMouse || volumeMouse.pressed
                            onLevelChanged: requestPaint()
                            onHighlightedChanged: requestPaint()
                            onPaint: {
                                const c = getContext("2d"), w = width, h = height, x = 2 + (w - 4) * level, edge = h * 0.4
                                const top = p => (h - edge) / 2 * (1 - p / w)
                                c.clearRect(0, 0, w, h)
                                c.fillStyle = "#090909"
                                c.beginPath(); c.moveTo(0, (h-edge)/2); c.lineTo(0, (h+edge)/2); c.lineTo(w - 2, h - top(w - 2)); c.quadraticCurveTo(w, h, w, h - 2); c.lineTo(w, 2); c.quadraticCurveTo(w, 0, w - 2, top(w - 2)); c.closePath(); c.fill()
                                if (level <= 0) return
                                const gradient = c.createLinearGradient(2, 0, x, 0)
                                gradient.addColorStop(0, highlighted ? "#8cba24" : "#79a613")
                                gradient.addColorStop(1, highlighted ? "#99a625" : "#869313")
                                c.fillStyle = gradient
                                c.beginPath(); c.moveTo(4, top(4) + 2); c.lineTo(x, top(x) + 2); c.lineTo(x, h - top(x) - 2); c.lineTo(4, h - top(4) - 2)
                                c.quadraticCurveTo(2, h - top(2) - 2, 2, h - top(2) - 4)
                                c.lineTo(2, top(2) + 4); c.quadraticCurveTo(2, top(2) + 2, 4, top(4) + 2); c.closePath(); c.fill()
                            }
                        }
                        MouseArea {
                            id: volumeMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            activeFocusOnTab: true
                            hoverEnabled: true
                            Accessible.role: Accessible.Slider
                            Accessible.name: "Volume"
                            readonly property real value: player.volume
                            readonly property real minimumValue: 0
                            readonly property real maximumValue: 100
                            readonly property real stepSize: 5
                            Accessible.description: player.volume + "%"
                            Accessible.onIncreaseAction: player.volume = Math.min(100, player.volume + 5)
                            Accessible.onDecreaseAction: player.volume = Math.max(0, player.volume - 5)
                            Keys.onShortcutOverride: (event) => { if ([Qt.Key_Left, Qt.Key_Right, Qt.Key_Up, Qt.Key_Down].includes(event.key)) event.accepted = true }
                            function changeVolume(delta) { player.volume = Math.max(0, Math.min(100, player.volume + delta)); win.notify("Volume " + player.volume + "%") }
                            Keys.onLeftPressed: changeVolume(-5)
                            Keys.onRightPressed: changeVolume(5)
                            Keys.onDownPressed: changeVolume(-5)
                            Keys.onUpPressed: changeVolume(5)
                            onPressed: (mouse) => { focus = false; win.volumePressed = true; setLevel(mouse.x) }
                            onPositionChanged: (mouse) => { if (pressed) setLevel(mouse.x) }
                            onCanceled: { win.volumePressed = false; idle.restart() }
                            onReleased: { win.volumePressed = false; idle.restart() }
                            onWheel: win.wheelVolume(wheel.angleDelta.y)
                            function setLevel(x) { player.volume = Math.round(100 * Math.max(0, Math.min(1, x / width))); win.notify("Volume " + player.volume + "%") }
                        }
                    }
                    Icon { x: 143; y: 12; name: "AudioWave01"; glyphWidth: 18; glyphHeight: 20; tint: player.hasMedia ? "#727272" : "#4a4a4a"; enabled: player.hasMedia; interactive: true; accessibleName: "Audio track"; tooltip: "Audio track"; onActivated: player.cycleAudioTrack(); MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: player.cycleAudioTrack() } }
                    Icon { x: 185; y: 12; name: "Subtitle"; glyphWidth: 22; glyphHeight: 16; tint: player.hasMedia ? Theme.text : "#4a4a4a"; enabled: player.hasMedia; interactive: true; accessibleName: "Subtitles"; tooltip: "Subtitles"; onActivated: player.cycleSubtitle(); MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: player.cycleSubtitle() } }
                    Icon { x: 233; y: 18; name: "SettingsPlay"; glyphWidth: 20; glyphHeight: 20; interactive: false; tooltip: "Not available yet"; accessibleName: "Settings"; }
                    Icon { x: 277; y: 12; name: "ListBullets"; glyphWidth: 18; glyphHeight: 12; tint: "#727272"; interactive: true; tooltip: "Library"; accessibleName: "Toggle library"; onActivated: win.libraryOpen = !win.libraryOpen; MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.libraryOpen = !win.libraryOpen } }
                }
            }
        }
    }
    Repeater {
        model: ["left", "right", "top", "bottom", "topLeft", "topRight", "bottomLeft", "bottomRight"]
        delegate: Item {
            required property string modelData
            readonly property string edgeName: modelData.toLowerCase()
            readonly property bool edgeLeft: edgeName.includes("left")
            readonly property bool edgeRight: edgeName.includes("right")
            readonly property bool edgeTop: edgeName.includes("top")
            readonly property bool edgeBottom: edgeName.includes("bottom")
            readonly property bool corner: edgeLeft || edgeRight ? edgeTop || edgeBottom : false
            readonly property bool horizontal: (edgeLeft || edgeRight) && !corner
            readonly property bool vertical: (edgeTop || edgeBottom) && !corner
            visible: win.visibility === Window.Windowed
            z: 10
            x: edgeLeft ? 0 : edgeRight ? win.width - 6 : 6
            y: edgeTop ? 0 : edgeBottom ? win.height - 6 : 6
            width: corner || horizontal ? 6 : win.width - 12
            height: corner || vertical ? 6 : win.height - 12
            MouseArea {
                anchors.fill: parent
                cursorShape: parent.corner ? ((parent.edgeTop && parent.edgeLeft) || (parent.edgeBottom && parent.edgeRight) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor) : parent.horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
                property bool manualResize: false
                property point pressGlobal
                property rect pressGeometry
                onPressed: (mouse) => {
                    pressGlobal = mapToGlobal(mouse.x, mouse.y)
                    pressGeometry = Qt.rect(win.x, win.y, win.width, win.height)
                    let edges = 0
                    if (parent.edgeLeft) edges |= Qt.LeftEdge
                    if (parent.edgeRight) edges |= Qt.RightEdge
                    if (parent.edgeTop) edges |= Qt.TopEdge
                    if (parent.edgeBottom) edges |= Qt.BottomEdge
                    manualResize = !win.startSystemResize(edges)
                }
                onPositionChanged: (mouse) => {
                    if (!pressed || !manualResize) return
                    const global = mapToGlobal(mouse.x, mouse.y)
                    const dx = global.x - pressGlobal.x, dy = global.y - pressGlobal.y
                    const width = Math.max(win.minimumWidth, pressGeometry.width + (parent.edgeLeft ? -dx : parent.edgeRight ? dx : 0))
                    const height = Math.max(win.minimumHeight, pressGeometry.height + (parent.edgeTop ? -dy : parent.edgeBottom ? dy : 0))
                    win.width = width
                    win.height = height
                    win.x = parent.edgeLeft ? pressGeometry.x + pressGeometry.width - width : pressGeometry.x
                    win.y = parent.edgeTop ? pressGeometry.y + pressGeometry.height - height : pressGeometry.y
                }
                onReleased: manualResize = false
                onCanceled: manualResize = false
            }
        }
    }
    Component.onCompleted: player.attachSink(output.videoSink)
}
