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
    palette.toolTipText: "#e5e5e5"
    palette.mid: "#444444"
    flags: Qt.Window | Qt.FramelessWindowHint
    title: player.title
    property bool showChrome: true
    property bool libraryOpen: true
    property string section: "Videos"
    property bool seekPressed: false
    property bool volumePressed: false
    property int wheelRemainder: 0
    property real seekDisplay: -1
    property string searchText: ""
    property bool searchOpen: false
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
        for (let i = 0; i < files.count; i++) if (sameUrl(files.get(i, "fileUrl"), player.currentUrl)) { fileList.currentIndex = i; return }
    }
    function notify(message, duration) {
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
            if (!player.playing) return
            if (win.chromeHovered || win.seekPressed || win.volumePressed) restart()
            else win.showChrome = false
        }
    }
    Timer { id: osdTimer; interval: 1500; onTriggered: osd.opacity = 0 }
    Connections {
        target: player
        function onPlayingChanged() { win.reveal() }
        function onPlaybackError(message) { win.notify(message, 5000) }
        function onAudioTrackChanged(name) { win.notify(name) }
        function onSubtitleChanged(name) { win.notify(name) }
        function onCurrentUrlChanged() { win.syncCurrentRow() }
    }
    FileDialog {
        id: picker
        nameFilters: ["Video files (*.mp4 *.mkv *.mov *.avi *.webm *.m4v *.mp3 *.flac *.m4a *.wav *.ogg)", "All files (*)"]
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
            const extensions = section === "Music" ? ["mp3", "flac", "m4a", "wav", "ogg"] : ["mp4", "mkv", "mov", "avi", "webm", "m4v"]
            const escaped = searchText.replace(/[\[\]*?]/g, "[$&]")
            return extensions.map(ext => searchText ? "*" + escaped + "*." + ext : "*." + ext)
        }
    }
    Shortcut { sequence: "Space"; onActivated: { win.reveal(); player.togglePause() } }
    Shortcut { sequence: "Left"; onActivated: if (!seekBarMouse.activeFocus && !fileList.activeFocus) { player.seek(Math.max(0, player.time - 5000)); notify("-5 s · " + fmt(Math.max(0, player.time - 5000)), 800) } }
    Shortcut { sequence: "Right"; onActivated: if (!seekBarMouse.activeFocus && !fileList.activeFocus) { player.seek(player.time + 5000); notify("+5 s · " + fmt(player.time + 5000), 800) } }
    Shortcut { sequence: "Up"; enabled: !fileList.activeFocus && !volumeMouse.activeFocus; onActivated: { player.volume = Math.min(100, player.volume + 5); notify("Volume " + player.volume + "%") } }
    Shortcut { sequence: "Down"; enabled: !fileList.activeFocus && !volumeMouse.activeFocus; onActivated: { player.volume = Math.max(0, player.volume - 5); notify("Volume " + player.volume + "%") } }
    Shortcut { sequence: "M"; onActivated: { win.reveal(); win.setMuted(!player.muted) } }
    Shortcut { sequence: "F"; onActivated: { win.reveal(); win.visibility = win.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen } }
    Shortcut { sequence: "Escape"; onActivated: { win.reveal(); if (searchOpen) { searchText = ""; searchOpen = false } else if (win.visibility === Window.FullScreen) win.visibility = Window.Windowed } }
    DropArea { id: dropArea; anchors.fill: parent; onDropped: if (drop.urls.length) player.open(drop.urls[0]) }
    MouseArea {
        anchors.fill: parent
        z: -1
        acceptedButtons: Qt.NoButton
        hoverEnabled: true
        cursorShape: win.showChrome ? Qt.ArrowCursor : Qt.BlankCursor
        onPositionChanged: win.reveal()
        onExited: idle.restart()
        onWheel: win.wheelVolume(wheel.angleDelta.y)
    }
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: win.showChrome ? 0 : 10
        spacing: 0
        Rectangle {
            id: titlebar
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            color: Theme.window
            visible: win.showChrome
            HoverHandler { id: titleHover }
            Image { x: 16; y: 9; width: 18; height: 22; source: "image://icons/cone/d37918"; sourceSize: Qt.size(36, 44) }
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
                    name: modelData === "Maximize01" && win.visibility === Window.Maximized ? "Restore" : modelData
                    size: modelData === "MinusSign" || modelData === "Cancel01" ? 18 : 14
                    tint: modelData === "MinusSign" ? "#727272" : modelData === "Cancel01" ? "#8f8f8f" : "#888888"
                    interactive: true
                    closeButton: modelData === "Cancel01"
                    accessibleName: modelData === "Cancel01" ? "Close" : modelData === "MinusSign" ? "Minimize" : modelData === "FullScreen" ? "Fullscreen" : "Maximize"
                    tooltip: accessibleName
                    onActivated: if (modelData === "Cancel01") win.close(); else if (modelData === "MinusSign") win.showMinimized(); else win.visibility = modelData === "FullScreen" ? (win.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen) : (win.visibility === Window.Maximized ? Window.Windowed : Window.Maximized)
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: parent.activated()
                    }
                }
            }
            Text { anchors.centerIn: parent; width: Math.min(300, parent.width - 600); text: player.title; color: "#8f8f8f"; font.pixelSize: 13; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter }
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
                visible: win.showChrome
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
                            width: 52
                            height: 46
                            Icon {
                                anchors.centerIn: parent
                                anchors.verticalCenterOffset: index === 4 ? 1 : 0
                                name: modelData
                                glyphWidth: [18, 20, 20, 22, 20, 18, 16][index]
                                glyphHeight: [18, 20, 20, 16, 14, 16, 16][index]
                                interactive: true
                                accessibleName: ["Home", "Videos", "Music", "Network", "Playlists", "Recent", "Add"][index]
                                tooltip: accessibleName
                                onActivated: if (index === 6) picker.open(); else { win.section = ["Home", "Videos", "Music", "Network", "Playlists", "Recent"][index]; win.libraryOpen = true }
                                tint: (win.section === ["Home", "Videos", "Music", "Network", "Playlists"][index] || railMouse.containsMouse) ? Theme.accent : "#8f8f8f"
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
                visible: win.showChrome && win.libraryOpen
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
                        Layout.topMargin: 19
                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 7
                            spacing: 18
                            Icon { name: "Add01"; size: 18; interactive: false; tint: Theme.muted }
                            Text { Layout.fillWidth: true; text: "Add…"; color: Theme.muted; font.pixelSize: 14 }
                        }
                        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: picker.open() }
                    }
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        ListView {
                            id: fileList
                            anchors.fill: parent
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
                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 7
                                    spacing: 18
                                    Icon { name: win.section === "Music" ? "MusicNote01" : "Video01"; size: 18; interactive: false; tint: win.sameUrl(fileUrl, player.currentUrl) ? Theme.accent : Theme.muted }
                                    Text { Layout.fillWidth: true; text: fileName; color: win.sameUrl(fileUrl, player.currentUrl) ? Theme.accent : "#969696"; font.pixelSize: 14; elide: Text.ElideRight }
                                }
                                MouseArea {
                                    id: rowMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: { fileList.currentIndex = index; fileList.forceActiveFocus(Qt.MouseFocusReason); fileList.keyboardFocus = false; player.open(fileUrl) }
                                }
                            }
                            Keys.onUpPressed: { keyboardFocus = true; decrementCurrentIndex() }
                            Keys.onDownPressed: { keyboardFocus = true; incrementCurrentIndex() }
                            Keys.onReturnPressed: if (currentIndex >= 0) player.open(files.get(currentIndex, "fileUrl"))
                            Keys.onEnterPressed: if (currentIndex >= 0) player.open(files.get(currentIndex, "fileUrl"))
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: (section === "Videos" || section === "Music") && files.count === 0
                            text: searchText ? "No matches for \"" + searchText + "\"" : section === "Music" ? "No music in Music. Drop files or click Add…" : "No videos in Movies. Drop files or click Add…"
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
                Layout.rightMargin: win.showChrome ? 10 : 0
                color: Theme.video
                            Rectangle {
                    anchors.fill: parent
                    color: Theme.video
                    Rectangle { anchors.fill: parent; anchors.margins: 2; color: "transparent"; border.width: dropArea.containsDrag ? 2 : 0; border.color: Theme.accent }
                    VideoOutput { id: output; anchors.fill: parent; fillMode: VideoOutput.PreserveAspectFit }
                    Text { anchors.centerIn: parent; visible: !player.title || player.title === "Konus"; text: "Drop a video here or click Add"; color: "#a0a0a0"; font.pixelSize: 13 }
                    Rectangle {
                        id: osd
                        property string text: ""
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 20
                        color: "#b3000000"
                        radius: 18
                        opacity: 0
                        visible: opacity > 0
                        z: 3
                        width: osdLabel.implicitWidth + 28
                        height: 34
                        Text { id: osdLabel; anchors.centerIn: parent; text: osd.text; color: "white"; font.pixelSize: 13 }
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.LeftButton
                        onClicked: player.togglePause()
                        onDoubleClicked: { player.togglePause(); win.visibility = win.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen }
                    }
                }
            }
        }
        Rectangle {
            id: controlbar
            Layout.fillWidth: true
            Layout.preferredHeight: 55
            color: Theme.control
            visible: win.showChrome
            HoverHandler { id: controlsHover }
            Item {
                anchors.fill: parent
                Item {
                    x: 0; y: 0; width: 154; height: parent.height
                    Icon { x: 20.5; y: 12; name: "Previous"; glyphWidth: 11; glyphHeight: 12; interactive: true; tint: "#8f8f8f"; accessibleName: "Previous file"; tooltip: "Previous"; onActivated: win.stepFile(-1); MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.stepFile(-1) } }
                    Rectangle {
                        x: 58; y: 14; width: 54; height: 28
                        border.width: playMouse.activeFocus ? 2 : 0
                        border.color: "#1a1a1a"
                        color: playMouse.pressed ? Qt.darker(Theme.accent, 1.2) : playMouse.containsMouse ? Qt.lighter(Theme.accent, 1.15) : Theme.accent
                        radius: 4
                        Icon { anchors.centerIn: parent; name: player.playing ? "Pause" : "Play"; size: 18; tint: "#1a1a1a"; interactive: false }
                        MouseArea {
                            id: playMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: player.playing ? "Pause" : "Play"
                            ToolTip.visible: containsMouse
                            ToolTip.delay: 600
                            ToolTip.text: player.playing ? "Pause" : "Play"
                            activeFocusOnTab: true
                            function activate() { if (player.title === "Konus" && files.count) player.open(files.get(0, "fileUrl")); else if (player.title === "Konus") picker.open(); else player.togglePause() }
                            Accessible.onPressAction: activate()
                            Keys.onShortcutOverride: (event) => { if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) event.accepted = true }
                            Keys.onSpacePressed: activate()
                            Keys.onReturnPressed: activate()
                            Keys.onEnterPressed: activate()
                            onClicked: activate()
                        }
                    }
                    Icon { x: 120.5; y: 12; name: "Next"; glyphWidth: 11; glyphHeight: 12; interactive: true; tint: "#8f8f8f"; accessibleName: "Next file"; tooltip: "Next"; onActivated: win.stepFile(1); MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: win.stepFile(1) } }
                }
                Text { x: 177; y: 19; text: fmt(player.time); color: Theme.text; font.pixelSize: 15; font.letterSpacing: -0.3 }
                Item {
                    id: seekBar
                    x: 251; y: 13
                    width: Math.max(120, parent.width - 676); height: 30
                    readonly property real progress: player.length > 0 ? Math.max(0, Math.min(1, player.time / player.length)) : 0
                    property real dragProgress: progress
                    Accessible.role: Accessible.Slider
                    Accessible.name: "Playback position"
                    Accessible.description: win.fmt(player.time) + " of " + win.fmt(player.length)
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: 3
                        color: "#0b0b0b"
                        radius: 4
                        Rectangle { width: parent.width * (seekBarMouse.pressed ? seekBar.dragProgress : win.seekDisplay >= 0 ? win.seekDisplay : seekBar.progress); height: parent.height; color: Theme.seekFill; radius: 4 }
                    }
                    Rectangle { x: 3 + (parent.width - 14) * (seekBarMouse.pressed ? seekBar.dragProgress : win.seekDisplay >= 0 ? win.seekDisplay : seekBar.progress); y: 3; width: 8; height: 24; color: Theme.accent; radius: 3 }
                    MouseArea {
                        id: seekBarMouse
                        anchors.fill: parent
                        enabled: player.length > 0
                        cursorShape: Qt.PointingHandCursor
                        hoverEnabled: true
                        activeFocusOnTab: true
                        Accessible.onIncreaseAction: player.seek(Math.min(player.length, player.time + 5000))
                        Accessible.onDecreaseAction: player.seek(Math.max(0, player.time - 5000))
                        Keys.onShortcutOverride: (event) => { if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) event.accepted = true }
                        Keys.onLeftPressed: (event) => { player.seek(Math.max(0, player.time - 5000)); event.accepted = true }
                        Keys.onRightPressed: (event) => { player.seek(player.time + 5000); event.accepted = true }
                        onPressed: { forceActiveFocus(); win.seekPressed = true; seekBar.dragProgress = Math.max(0, Math.min(1, (mouse.x - 7) / (width - 14))) }
                        onPositionChanged: if (pressed) seekBar.dragProgress = Math.max(0, Math.min(1, (mouse.x - 7) / (width - 14)))
                        onReleased: { player.seek(player.length * seekBar.dragProgress); win.seekDisplay = seekBar.dragProgress; seekRelease.restart(); win.seekPressed = false; idle.restart() }
                        ToolTip.visible: containsMouse && player.length > 0
                        ToolTip.text: win.fmt(player.length * Math.max(0, Math.min(1, (mouseX - 7) / (width - 14))))
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
                        Accessible.role: Accessible.Slider
                        Accessible.name: "Volume"
                        Accessible.description: player.volume + "%"
                        Canvas {
                            anchors.fill: parent
                            property real level: player.volume / 100
                            onLevelChanged: requestPaint()
                            onPaint: {
                                let c = getContext("2d"), w = width, h = height, x = w * level, edge = h * 0.4, half = edge / 2 + (h / 2 - edge / 2) * level
                                c.clearRect(0, 0, w, h); c.lineJoin = "round"; c.fillStyle = "#0b0b0b"; c.lineWidth = 1
                                c.beginPath(); c.moveTo(0, (h-edge)/2); c.lineTo(0, (h+edge)/2); c.lineTo(w, h); c.lineTo(w, 0); c.closePath(); c.fill()
                                c.fillStyle = "#7aa613"; c.beginPath(); c.moveTo(0, (h-edge)/2); c.lineTo(0, (h+edge)/2); c.lineTo(x, h/2+half); c.lineTo(x, h/2-half); c.closePath(); c.fill()
                            }
                        }
                        MouseArea {
                            id: volumeMouse
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            activeFocusOnTab: true
                            Accessible.onIncreaseAction: player.volume = Math.min(100, player.volume + 5)
                            Accessible.onDecreaseAction: player.volume = Math.max(0, player.volume - 5)
                            Keys.onShortcutOverride: (event) => { if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) event.accepted = true }
                            Keys.onLeftPressed: (event) => { player.volume = Math.max(0, player.volume - 5); win.notify("Volume " + player.volume + "%"); event.accepted = true }
                            Keys.onRightPressed: (event) => { player.volume = Math.min(100, player.volume + 5); win.notify("Volume " + player.volume + "%"); event.accepted = true }
                            onPressed: { win.volumePressed = true; setLevel(mouse.x) }
                            onPositionChanged: if (pressed) setLevel(mouse.x)
                            onReleased: { win.volumePressed = false; idle.restart() }
                            onWheel: win.wheelVolume(wheel.angleDelta.y)
                            function setLevel(x) { player.volume = Math.round(100 * Math.max(0, Math.min(1, x / width))) }
                        }
                    }
                    Icon { x: 143; y: 12; name: "AudioWave01"; glyphWidth: 18; glyphHeight: 20; tint: "#727272"; interactive: true; accessibleName: "Audio track"; tooltip: "Audio track"; onActivated: player.cycleAudioTrack(); MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: player.cycleAudioTrack() } }
                    Icon { x: 185; y: 12; name: "Subtitle"; glyphWidth: 22; glyphHeight: 16; interactive: true; accessibleName: "Subtitles"; tooltip: "Subtitles"; onActivated: player.cycleSubtitle(); MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: player.cycleSubtitle() } }
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
            width: corner || vertical ? 6 : horizontal ? 6 : win.width - 12
            height: corner || horizontal ? 6 : vertical ? 6 : win.height - 12
            MouseArea {
                anchors.fill: parent
                cursorShape: parent.corner ? ((parent.edgeTop && parent.edgeLeft) || (parent.edgeBottom && parent.edgeRight) ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor) : parent.horizontal ? Qt.SizeHorCursor : Qt.SizeVerCursor
                onPressed: {
                    let edges = 0
                    if (parent.edgeLeft) edges |= Qt.LeftEdge
                    if (parent.edgeRight) edges |= Qt.RightEdge
                    if (parent.edgeTop) edges |= Qt.TopEdge
                    if (parent.edgeBottom) edges |= Qt.BottomEdge
                    win.startSystemResize(edges)
                }
            }
        }
    }
    Component.onCompleted: player.attachSink(output.videoSink)
}
