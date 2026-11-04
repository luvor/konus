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
    function reveal() { showChrome=true; idle.restart(); if (!player.playing) idle.stop() }
    function fmt(ms) { let s=Math.floor(Math.max(0,ms)/1000); return Math.floor(s/3600).toString().padStart(2,"0")+":"+Math.floor(s/60%60).toString().padStart(2,"0")+":"+(s%60).toString().padStart(2,"0") }
    function stepFile(delta) { for(let i=0;i<files.count;i++) if(files.get(i,"fileName")===player.title) {let n=i+delta;if(n>=0&&n<files.count)player.open(files.get(n,"fileURL"));return} }
    Timer { id: idle; interval:2500; onTriggered:if(player.playing)win.showChrome=false }
    Connections { target:player; function onPlayingChanged(){if(player.playing)idle.restart();else win.reveal()} }
    FileDialog { id:picker; nameFilters:["Video files (*.mp4 *.mkv *.mov *.avi *.webm *.m4v)","All files (*)"];onAccepted:player.open(selectedFile) }
    FolderListModel { id:files; folder:section==="Music"?StandardPaths.writableLocation(StandardPaths.MusicLocation):StandardPaths.writableLocation(StandardPaths.MoviesLocation);showDirs:false;nameFilters:section==="Music"?["*.mp3","*.flac","*.m4a","*.wav","*.ogg"]:["*.mp4","*.mkv","*.mov","*.avi","*.webm","*.m4v"] }
    Shortcut { sequence:"Space";onActivated:player.togglePause() }
    Shortcut { sequence:"Left";onActivated:player.seek(Math.max(0,player.time-5000)) }
    Shortcut { sequence:"Right";onActivated:player.seek(player.time+5000) }
    Shortcut { sequence:"Up";onActivated:player.volume=Math.min(100,player.volume+5) }
    Shortcut { sequence:"Down";onActivated:player.volume=Math.max(0,player.volume-5) }
    Shortcut { sequence:"M";onActivated:player.muted=!player.muted }
    Shortcut { sequence:"F";onActivated:win.visibility=win.visibility===Window.FullScreen?Window.Windowed:Window.FullScreen }
    Shortcut { sequence:"Escape";onActivated:if(win.visibility===Window.FullScreen)win.visibility=Window.Windowed }
    Behavior on showChrome { NumberAnimation { duration:180 } }
    DropArea { anchors.fill:parent;onDropped:if(drop.urls.length)player.open(drop.urls[0]) }
    MouseArea { anchors.fill:parent;acceptedButtons:Qt.NoButton;hoverEnabled:true;cursorShape:win.showChrome?Qt.ArrowCursor:Qt.BlankCursor;onPositionChanged:win.reveal();onWheel:player.volume=Math.max(0,Math.min(100,player.volume+(wheel.angleDelta.y>0?5:-5))) }
    ColumnLayout {
        anchors.fill:parent;spacing:0
        Rectangle {
            Layout.fillWidth:true;Layout.preferredHeight:40;color:"#1c1c1c";visible:win.showChrome;opacity:visible?1:0
            RowLayout { anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:10;spacing:10
                Image { source:"qrc:/konus/assets/icons/cone.svg";sourceSize:Qt.size(18,22);Layout.preferredWidth:18;Layout.preferredHeight:22 }
                Icon { name:"MoreHorizontal";size:18 }
                Icon { name:"SidebarLeft";size:18;MouseArea{anchors.fill:parent;onClicked:win.libraryOpen=!win.libraryOpen} }
                Rectangle { width:1;height:20;color:"#383838" }
                Icon { name:"Folder01";size:18 }
                Text { text:section;color:"#9a9a9a";font.pixelSize:14 }
                Item { Layout.fillWidth:true }
                Text { text:player.title;color:"#9a9a9a";font.pixelSize:13 }
                Item { Layout.fillWidth:true }
                Repeater { model:["MinusSign","Maximize01","FullScreen","Cancel01"];delegate:Icon{required property string modelData;name:modelData==="Maximize01"&&win.visibility===Window.Maximized?"Restore":modelData;size:16;MouseArea{anchors.fill:parent;onClicked:if(modelData==="Cancel01")win.close();else if(modelData==="MinusSign")win.showMinimized();else win.visibility=modelData==="FullScreen"?(win.visibility===Window.FullScreen?Window.Windowed:Window.FullScreen):(win.visibility===Window.Maximized?Window.Windowed:Window.Maximized)}} }
            }
            MouseArea { anchors.fill:parent;z:-1;onPressed:win.startSystemMove();onDoubleClicked:win.visibility=win.visibility===Window.Maximized?Window.Windowed:Window.Maximized }
        }
        RowLayout { Layout.fillWidth:true;Layout.fillHeight:true;spacing:0
            Rectangle { visible:win.showChrome;Layout.fillHeight:true;Layout.preferredWidth:visible?52:0;color:"#1c1c1c"
                Column { anchors.horizontalCenter:parent.horizontalCenter;anchors.top:parent.top;anchors.topMargin:8;spacing:0
                    Repeater { model:["Home01","PlaySquare","FolderMusic","Broadcast","Playlist01","RecentClock","Add01"];delegate:Item{required property string modelData;required property int index;width:52;height:41;Icon{anchors.centerIn:parent;name:modelData;size:20;tint:section===["Home","Videos","Music","Network","Playlists","Recent"][parent.index]||railMouse.containsMouse?Theme.accent:Theme.muted;hoverTint:Theme.accent}MouseArea{id:railMouse;anchors.fill:parent;hoverEnabled:true;onClicked:if(index===6)picker.open();else{section=["Home","Videos","Music","Network","Playlists","Recent"][index];libraryOpen=true}}} }
                }
            }
            Rectangle { visible:win.showChrome&&win.libraryOpen;Layout.fillHeight:true;Layout.preferredWidth:visible?Theme.panelWidth:0;color:"#111111"
                ColumnLayout { anchors.fill:parent;anchors.margins:14;spacing:0
                    RowLayout { Layout.fillWidth:true;Layout.preferredHeight:34;spacing:10
                        Icon{name:"ArrowLeftStem";size:18}
                        Icon{name:"ArrowRightStem";size:18;tint:"#555555"}
                        Text{text:section;color:"#b7b7b7";font.pixelSize:16}
                        Item{Layout.fillWidth:true}
                        Icon{name:"MoreHorizontal";size:18}
                        Icon{name:"LinkSquare01";size:18}
                    }
                    RowLayout { Layout.fillWidth:true;Layout.preferredHeight:36;spacing:12
                        Text{text:files.count+" items";color:Theme.muted;font.pixelSize:12}
                        Item{Layout.fillWidth:true}
                        Icon{name:"SortArrows";size:18}
                        Icon{name:"ListBullets";size:18}
                        Icon{name:"Search01";size:18}
                    }
                    Rectangle{Layout.fillWidth:true;height:1;color:"#262626"}
                    RowLayout{Layout.fillWidth:true;Layout.preferredHeight:40;spacing:12;Icon{name:"Add01";size:18;tint:Theme.muted}Text{text:"Add…";color:Theme.muted;font.pixelSize:13}}
                    Repeater { model:files;delegate:Rectangle{required property string fileName;required property url fileURL;Layout.fillWidth:true;height:40;color:rowMouse.containsMouse?"#252525":"transparent";radius:3;RowLayout{anchors.fill:parent;anchors.leftMargin:7;spacing:10;Icon{name:win.section==="Music"?"MusicNote01":"Video01";size:18;tint:Theme.muted}Text{Layout.fillWidth:true;text:fileName;color:Theme.text;font.pixelSize:12;elide:Text.ElideRight}}MouseArea{id:rowMouse;anchors.fill:parent;hoverEnabled:true;onClicked:player.open(fileURL)}} }
                    Item{Layout.fillHeight:true}
                }
            }
            Rectangle { Layout.fillWidth:true;Layout.fillHeight:true;color:Theme.video
                VideoOutput{id:output;anchors.fill:parent;fillMode:VideoOutput.PreserveAspectFit}
                MouseArea{anchors.fill:parent;acceptedButtons:Qt.LeftButton;onDoubleClicked:win.visibility=win.visibility===Window.FullScreen?Window.Windowed:Window.FullScreen}
            }
        }
        Rectangle { Layout.fillWidth:true;Layout.preferredHeight:44;color:"#161616";visible:win.showChrome;opacity:visible?1:0
            RowLayout{anchors.fill:parent;anchors.leftMargin:28;anchors.rightMargin:24;spacing:14
                Icon{name:"Previous";size:16;MouseArea{anchors.fill:parent;onClicked:win.stepFile(-1)}}
                Rectangle{Layout.preferredWidth:56;Layout.preferredHeight:28;color:playMouse.containsMouse?Qt.lighter(Theme.accent,1.15):Theme.accent;radius:4;Icon{anchors.centerIn:parent;name:player.playing?"Pause":"Play";size:16;tint:"#1a1a1a"}MouseArea{id:playMouse;anchors.fill:parent;hoverEnabled:true;onClicked:player.togglePause()}}
                Icon{name:"Next";size:16;MouseArea{anchors.fill:parent;onClicked:win.stepFile(1)}}
                Text{Layout.preferredWidth:64;text:fmt(player.time);color:"#9a9a9a";font.pixelSize:12}
                Item{Layout.fillWidth:true;Layout.preferredHeight:22
                    id: seekBar
                    readonly property real progress:player.length>0?Math.max(0,Math.min(1,player.time/player.length)):0
                    Rectangle{anchors.fill:parent;color:"#0b0b0b";radius:4;Rectangle{width:parent.width*seekBar.progress;height:parent.height;color:"#4a2a0c";radius:4}}
                    Rectangle{x:(parent.width-width)*seekBar.progress;width:6;height:22;color:Theme.accent;radius:3}
                    MouseArea{anchors.fill:parent;enabled:player.length>0;onPressed:seekAt(mouse.x);onPositionChanged:if(pressed)seekAt(mouse.x);function seekAt(x){player.seek(player.length*Math.max(0,Math.min(1,x/width)))} }
                }
                Text{text:fmt(player.length);color:"#9a9a9a";font.pixelSize:12}
                Icon{name:"VolumeLow";size:18;tint:player.muted?Theme.muted:"#b5b5b5";MouseArea{anchors.fill:parent;onClicked:player.muted=!player.muted;onWheel:player.volume=Math.max(0,Math.min(100,player.volume+(wheel.angleDelta.y>0?5:-5)))} }
                Item{Layout.preferredWidth:90;Layout.preferredHeight:22
                    Canvas{anchors.fill:parent;property real level:player.muted?0:player.volume/100;onLevelChanged:requestPaint();onPaint:{let c=getContext("2d"),w=width,h=height,x=w*level,edge=h/3,half=edge/2+(h/2-edge/2)*level;c.clearRect(0,0,w,h);c.lineJoin="round";c.fillStyle="#0b0b0b";c.strokeStyle=c.fillStyle;c.lineWidth=2;c.beginPath();c.moveTo(0,(h-edge)/2);c.lineTo(0,(h+edge)/2);c.lineTo(w,h);c.lineTo(w,0);c.closePath();c.fill();c.stroke();c.fillStyle="#8aa31a";c.strokeStyle=c.fillStyle;c.beginPath();c.moveTo(0,(h-edge)/2);c.lineTo(0,(h+edge)/2);c.lineTo(x,h/2+half);c.lineTo(x,h/2-half);c.closePath();c.fill();c.stroke()}}
                    MouseArea{anchors.fill:parent;onPressed:setLevel(mouse.x);onPositionChanged:if(pressed)setLevel(mouse.x);onWheel:player.volume=Math.max(0,Math.min(100,player.volume+(wheel.angleDelta.y>0?5:-5)));function setLevel(x){player.volume=Math.round(100*Math.max(0,Math.min(1,x/width)))} }
                }
                Icon{name:"AudioWave01";size:18;MouseArea{anchors.fill:parent;onClicked:player.cycleAudioTrack()}}
                Icon{name:"Subtitle";size:18;MouseArea{anchors.fill:parent;onClicked:player.cycleSubtitle()}}
                Icon{name:"SettingsPlay";size:18}
                Icon{name:"ListBullets";size:18;MouseArea{anchors.fill:parent;onClicked:win.libraryOpen=!win.libraryOpen}}
            }
        }
    }
    Component.onCompleted:player.attachSink(output.videoSink)
}
