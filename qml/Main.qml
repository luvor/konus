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
    width: 1280; height: 760; visible: true; color: Theme.window
    flags: Qt.Window | Qt.FramelessWindowHint
    property bool showChrome: true
    property bool libraryOpen: true
    property string section: "Videos"
    property int volumeValue: player.volume
    property bool seeking: false
    function reveal() { showChrome = true; idle.restart(); if (!player.playing) idle.stop() }
    function fmt(ms) { let s=Math.floor(Math.max(0,ms)/1000); return Math.floor(s/60).toString().padStart(2,"0")+":"+(s%60).toString().padStart(2,"0") }
    Timer { id: idle; interval: 2500; onTriggered: if (player.playing) win.showChrome=false }
    Connections { target: player; function onPlayingChanged() { if (player.playing) idle.restart(); else win.reveal() } }
    FileDialog { id: picker; nameFilters: ["Video files (*.mp4 *.mkv *.mov *.avi *.webm *.m4v)", "All files (*)"]; onAccepted: player.open(selectedFile) }
    FolderListModel { id: files; folder: section === "Music" ? StandardPaths.writableLocation(StandardPaths.MusicLocation) : StandardPaths.writableLocation(StandardPaths.MoviesLocation); showDirs: false; nameFilters: section === "Music" ? ["*.mp3","*.flac","*.m4a","*.wav","*.ogg"] : ["*.mp4","*.mkv","*.mov","*.avi","*.webm","*.m4v"] }
    Shortcut { sequence: "Space"; onActivated: player.togglePause() }
    Shortcut { sequence: "Left"; onActivated: player.seek(Math.max(0,player.time-5000)) }
    Shortcut { sequence: "Right"; onActivated: player.seek(player.time+5000) }
    Shortcut { sequence: "Up"; onActivated: player.volume=Math.min(100,player.volume+5) }
    Shortcut { sequence: "Down"; onActivated: player.volume=Math.max(0,player.volume-5) }
    Shortcut { sequence: "M"; onActivated: player.muted=!player.muted }
    Shortcut { sequence: "F"; onActivated: win.visibility=win.visibility===Window.FullScreen?Window.Windowed:Window.FullScreen }
    Shortcut { sequence: "Escape"; onActivated: if(win.visibility===Window.FullScreen)win.visibility=Window.Windowed }
    Behavior on showChrome { NumberAnimation { duration: 180 } }
    DropArea { anchors.fill: parent; onDropped: if(drop.urls.length)player.open(drop.urls[0]) }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.NoButton; hoverEnabled: true; cursorShape: win.showChrome ? Qt.ArrowCursor : Qt.BlankCursor; onPositionChanged: win.reveal(); onWheel: { player.volume=Math.max(0,Math.min(100,player.volume+(wheel.angleDelta.y>0?5:-5))) } }
    ColumnLayout {
        anchors.fill: parent; spacing: 0
        Rectangle {
            Layout.fillWidth: true; Layout.preferredHeight: Theme.titleHeight; color: Theme.window
            visible: win.showChrome; opacity: win.showChrome?1:0
            RowLayout { anchors.fill: parent; anchors.leftMargin: 14; anchors.rightMargin: 10; spacing: 12
                Image { source: "qrc:/konus/assets/icons/cone.svg"; sourceSize: Qt.size(20, 24); Layout.preferredWidth: 20; Layout.preferredHeight: 24 }
                Text { text: "···"; color: Theme.muted; font.pixelSize: 18 }
                ToolButton { text: "◧"; onClicked: win.libraryOpen=!win.libraryOpen }
                Text { text: section + "  /"; color: Theme.muted; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                Text { text: player.title; color: Theme.text; font.pixelSize: 12 }
                Item { Layout.fillWidth: true }
                ToolButton { text: "—"; onClicked: win.showMinimized() }
                ToolButton { text: "□"; onClicked: win.visibility=win.visibility===Window.Maximized?Window.Windowed:Window.Maximized }
                ToolButton { text: "⛶"; onClicked: win.visibility=win.visibility===Window.FullScreen?Window.Windowed:Window.FullScreen }
                ToolButton { text: "×"; onClicked: win.close() }
            }
            MouseArea { anchors.fill: parent; z: -1; property point start; onPressed: start=Qt.point(mouse.x,mouse.y); onPositionChanged: if(pressed)win.startSystemMove(); onDoubleClicked: win.visibility=win.visibility===Window.Maximized?Window.Windowed:Window.Maximized }
        }
        RowLayout { Layout.fillWidth: true; Layout.fillHeight: true; spacing: 0
            Rectangle { Layout.fillHeight: true; Layout.preferredWidth: Theme.railWidth; color: Theme.rail
                Column { anchors.fill: parent; anchors.topMargin: 14; spacing: 7
                    Repeater { model: ["⌂","▣","♫","◉","☷","◴","＋"]; delegate: Item { width: Theme.railWidth; height: 42
                        Rectangle { visible: win.section===(["Home","Videos","Music","Network","Playlists","Recent","Add"])[index]; anchors.left: parent.left; width: 3; height: 30; anchors.verticalCenter: parent.verticalCenter; color: Theme.accent }
                        Text { anchors.centerIn: parent; text: modelData; color: index===1&&section==="Videos"||index===2&&section==="Music"?Theme.accent:Theme.muted; font.pixelSize: 20 }
                        MouseArea { anchors.fill: parent; onClicked: if(index===6)picker.open(); else {section=["Home","Videos","Music","Network","Playlists","Recent"][index];libraryOpen=true} }
                    } }
                }
            }
            Rectangle { visible: win.libraryOpen && win.showChrome; Layout.fillHeight: true; Layout.preferredWidth: visible?Theme.panelWidth:0; color: Theme.panel
                ColumnLayout { anchors.fill: parent; anchors.margins: 16; spacing: 12
                    RowLayout { Layout.fillWidth: true; Text { text:"‹   ›"; color:Theme.muted } Item {Layout.fillWidth:true} Text {text:"⌕";color:Theme.muted} }
                    Text { text:section; color:Theme.text; font.pixelSize:18; font.weight:Font.Medium }
                    RowLayout { Layout.fillWidth:true; Text {text:files.count+" items";color:Theme.muted;font.pixelSize:11} Item{Layout.fillWidth:true} Text{text:"⇅   ☷";color:Theme.muted} }
                    Repeater { model: files; delegate: Rectangle { Layout.fillWidth:true; height:40; color: itemMouse.containsMouse?"#252525":"transparent"; radius:3
                        Text { anchors.left:parent.left; anchors.leftMargin:9; anchors.verticalCenter:parent.verticalCenter; text:fileName; color:Theme.text; font.pixelSize:12; elide:Text.ElideRight; width:parent.width-18 }
                        MouseArea { id:itemMouse; anchors.fill:parent; hoverEnabled:true; onDoubleClicked:player.open(fileUrl); onClicked:player.open(fileUrl) }
                    } }
                    Item { Layout.fillHeight:true }
                }
            }
            Rectangle { Layout.fillWidth:true; Layout.fillHeight:true; color:Theme.video
                VideoOutput { id: output; anchors.fill:parent; fillMode:VideoOutput.PreserveAspectFit }
                MouseArea { anchors.fill:parent; acceptedButtons:Qt.LeftButton; onDoubleClicked:win.visibility=win.visibility===Window.FullScreen?Window.Windowed:Window.FullScreen }
            }
        }
        Rectangle { Layout.fillWidth:true; Layout.preferredHeight:68; color:Theme.window; visible:win.showChrome; opacity:win.showChrome?1:0
            ColumnLayout { anchors.fill:parent; anchors.leftMargin:18; anchors.rightMargin:18; spacing:0
                RowLayout { Layout.fillWidth:true; Layout.fillHeight:true; spacing:13
                    ToolButton { text:"|◀"; onClicked:player.seek(0) }
                    ToolButton { text:player.playing?"Ⅱ":"▶"; onClicked:player.togglePause(); background:Rectangle{color:Theme.accent;radius:4} }
                    ToolButton { text:"▶|"; onClicked:player.seek(player.length) }
                    Text { text:fmt(player.time);color:Theme.muted;font.pixelSize:11 }
                    Slider { id:seek; Layout.fillWidth:true; from:0;to:Math.max(1,player.length); value:player.time; onMoved:player.seek(value); background:Rectangle{ x:seek.leftPadding;y:seek.topPadding+seek.availableHeight/2-3;width:seek.availableWidth;height:6;radius:3;color:"#090909"; Rectangle{width:seek.visualPosition*parent.width;height:parent.height;color:Theme.accent;radius:3} } handle:Rectangle{width:10;height:10;radius:5;color:Theme.accent} }
                    Text { text:fmt(player.length);color:Theme.muted;font.pixelSize:11 }
                    Text { text:"◢";font.pixelSize:20;color:player.muted?Theme.muted:"#c6e356"; MouseArea{anchors.fill:parent;onWheel:player.volume=Math.max(0,Math.min(100,player.volume+(wheel.angleDelta.y>0?5:-5)));onClicked:player.muted=!player.muted} }
                    Slider { Layout.preferredWidth:80;from:0;to:100;value:player.volume;onMoved:player.volume=value }
                    Text { text:"♫";color:Theme.muted;MouseArea{anchors.fill:parent;onClicked:player.cycleAudioTrack()} }
                    Text { text:"▤";color:Theme.muted;MouseArea{anchors.fill:parent;onClicked:player.cycleSubtitle()} }
                    Text { text:"⚙";color:Theme.muted }
                    Text { text:"☷";color:Theme.muted;MouseArea{anchors.fill:parent;onClicked:win.libraryOpen=!win.libraryOpen} }
                }
            }
        }
    }
    Component.onCompleted: player.attachSink(output.videoSink)
}
