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
    title: player.title
    property bool showChrome: true
    property bool libraryOpen: true
    property string section: "Videos"
    property bool seekPressed: false
    property bool volumePressed: false
    property int wheelRemainder: 0
    function fmt(ms) { let s=Math.floor(Math.max(0,ms)/1000); return Math.floor(s/3600).toString().padStart(2,"0")+":"+Math.floor(s/60%60).toString().padStart(2,"0")+":"+(s%60).toString().padStart(2,"0") }
    function reveal() { showChrome=true; idle.restart() }
    function stepFile(delta) { for(let i=0;i<files.count;i++) if(files.get(i,"fileName")===player.title) {let n=i+delta;if(n>=0&&n<files.count)player.open(files.get(n,"fileUrl"));return} }
    function notify(message,duration) { osd.text=message; osd.opacity=1; osdTimer.interval=duration||1500; osdTimer.restart() }
    function wheelVolume(delta) { let total=wheelRemainder+delta,steps=Math.trunc(total/120);wheelRemainder=total-steps*120;if(steps)player.volume=Math.max(0,Math.min(100,player.volume+steps*5)) }
    Timer { id: idle; interval:2500; onTriggered:if(player.playing&&!titleHover.hovered&&!railHover.hovered&&!panelHover.hovered&&!controlsHover.hovered&&!win.seekPressed&&!win.volumePressed)win.showChrome=false }
    Timer { id: osdTimer; interval:1500; onTriggered:osd.opacity=0 }
    Connections { target:player
        function onPlayingChanged(){if(player.playing)win.reveal();else win.reveal()}
        function onPlaybackError(message){win.notify(message,3000)}
        function onAudioTrackChanged(name){win.notify(name)}
        function onSubtitleChanged(name){win.notify(name)}
        function onVolumeChanged(){win.notify((player.muted?0:player.volume)+"%")}
    }
    FileDialog { id:picker; nameFilters:["Video files (*.mp4 *.mkv *.mov *.avi *.webm *.m4v)","All files (*)"];onAccepted:player.open(selectedFile) }
    FolderListModel { id:files; folder:section==="Music"?StandardPaths.writableLocation(StandardPaths.MusicLocation):StandardPaths.writableLocation(StandardPaths.MoviesLocation);showDirs:false;nameFilters:section==="Music"?["*.mp3","*.flac","*.m4a","*.wav","*.ogg"]:["*.mp4","*.mkv","*.mov","*.avi","*.webm","*.m4v"] }
    Shortcut { sequence:"Space";onActivated:{win.reveal();player.togglePause()} }
    Shortcut { sequence:"Left";onActivated:{win.reveal();player.seek(Math.max(0,player.time-5000))} }
    Shortcut { sequence:"Right";onActivated:{win.reveal();player.seek(player.time+5000)} }
    Shortcut { sequence:"Up";onActivated:{win.reveal();player.volume=Math.min(100,player.volume+5)} }
    Shortcut { sequence:"Down";onActivated:{win.reveal();player.volume=Math.max(0,player.volume-5)} }
    Shortcut { sequence:"M";onActivated:{win.reveal();player.muted=!player.muted} }
    Shortcut { sequence:"F";onActivated:{win.reveal();win.visibility=win.visibility===Window.FullScreen?Window.Windowed:Window.FullScreen} }
    Shortcut { sequence:"Escape";onActivated:{win.reveal();if(win.visibility===Window.FullScreen)win.visibility=Window.Windowed} }
    DropArea { anchors.fill:parent;onDropped:if(drop.urls.length)player.open(drop.urls[0]) }
    MouseArea { anchors.fill:parent;z:-1;acceptedButtons:Qt.NoButton;hoverEnabled:true;cursorShape:win.showChrome?Qt.ArrowCursor:Qt.BlankCursor;onPositionChanged:win.reveal();onWheel:win.wheelVolume(wheel.angleDelta.y) }
    ColumnLayout {
        anchors.fill:parent;spacing:0
        Rectangle {
            id:titlebar; Layout.fillWidth:true;Layout.preferredHeight:40;color:Theme.rail;visible:win.showChrome
            HoverHandler{id:titleHover}
            RowLayout { anchors.fill:parent;anchors.leftMargin:14;anchors.rightMargin:17;spacing:20
                Image { source:"qrc:/konus/assets/icons/cone.svg";sourceSize:Qt.size(18,22);Layout.preferredWidth:18;Layout.preferredHeight:22 }
                Icon { name:"MoreHorizontal";size:24;interactive:false }
                Icon { name:win.libraryOpen?"SidebarLeft":"SidebarLeftOutline";size:24;interactive:true;tint:win.libraryOpen?Theme.accent:Theme.muted;ToolTip.visible:sidebarMouse.containsMouse;ToolTip.delay:600;ToolTip.text:"Toggle library";MouseArea{id:sidebarMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:win.libraryOpen=!win.libraryOpen} }
                Rectangle { width:1;height:20;color:"#383838" }
                RowLayout { spacing:10;Icon { name:"Folder01";size:24;interactive:false } Text { text:section;color:"#9a9a9a";font.pixelSize:14 } }
                Item { Layout.fillWidth:true }
                Item { Layout.fillWidth:true }
                Repeater { model:["MinusSign","Maximize01","FullScreen","Cancel01"];delegate:Icon{required property string modelData;name:modelData==="Maximize01"&&win.visibility===Window.Maximized?"Restore":modelData;size:20;interactive:true;closeButton:modelData==="Cancel01";Layout.preferredWidth:32;Layout.preferredHeight:32;ToolTip.visible:windowMouse.containsMouse;ToolTip.delay:600;ToolTip.text:modelData==="Cancel01"?"Close":modelData==="MinusSign"?"Minimize":modelData==="FullScreen"?"Fullscreen":"Maximize";MouseArea{id:windowMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:if(modelData==="Cancel01")win.close();else if(modelData==="MinusSign")win.showMinimized();else win.visibility=modelData==="FullScreen"?(win.visibility===Window.FullScreen?Window.Windowed:Window.FullScreen):(win.visibility===Window.Maximized?Window.Windowed:Window.Maximized)}} }
            }
            Text { anchors.centerIn:parent;width:Math.min(300,parent.width-600);text:player.title;color:"#9a9a9a";font.pixelSize:13;elide:Text.ElideRight;horizontalAlignment:Text.AlignHCenter }
            MouseArea { anchors.fill:parent;z:-1;property point start;property bool moved:false;onPressed:{start=Qt.point(mouse.x,mouse.y);moved=false} onPositionChanged:if(pressed&&!moved&&Math.hypot(mouse.x-start.x,mouse.y-start.y)>=4){moved=true;win.startSystemMove()} onDoubleClicked:win.visibility=win.visibility===Window.Maximized?Window.Windowed:Window.Maximized }
        }
        RowLayout { Layout.fillWidth:true;Layout.fillHeight:true;spacing:0
            Rectangle { id:rail;visible:win.showChrome;Layout.fillHeight:true;Layout.preferredWidth:visible?52:0;color:Theme.rail
                HoverHandler{id:railHover}
                Column { anchors.horizontalCenter:parent.horizontalCenter;anchors.top:parent.top;anchors.topMargin:3;spacing:0
                    Repeater { model:["Home01","PlaySquare","FolderMusic","Broadcast","Playlist01","RecentClock","Add01"];delegate:Item{required property string modelData;required property int index;width:52;height:46;Icon{anchors.centerIn:parent;name:modelData;size:24;interactive:index!==0&&index!==3&&index!==4&&index!==5&&index!==6;tint:section===["Home","Videos","Music","Network","Playlists","Recent"][parent.index]||railMouse.containsMouse?Theme.accent:Theme.muted;MouseArea{id:railMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:if(index===6)picker.open();else{section=["Home","Videos","Music","Network","Playlists","Recent"][index];libraryOpen=true}}}ToolTip.visible:railMouse.containsMouse;ToolTip.delay:600;ToolTip.text:["Home","Videos","Music","Network","Playlists","Recent","Add"][index]} }
                }
            }
            Rectangle { id:libpanel;visible:win.showChrome&&win.libraryOpen;Layout.fillHeight:true;Layout.preferredWidth:visible?Theme.panelWidth:0;color:Theme.panel
                HoverHandler{id:panelHover}
                ColumnLayout { anchors.fill:parent;anchors.margins:20;spacing:0
                    RowLayout { Layout.fillWidth:true;Layout.preferredHeight:34;spacing:10
                        Icon{name:"ArrowLeftStem";size:24;interactive:false} Icon{name:"ArrowRightStem";size:24;interactive:false;tint:"#555555"}
                        Text{text:section;color:"#b7b7b7";font.pixelSize:16} Item{Layout.fillWidth:true}
                        Icon{name:"MoreHorizontal";size:24;interactive:false} Icon{name:"LinkSquare01";size:24;interactive:false}
                    }
                    RowLayout { Layout.fillWidth:true;Layout.preferredHeight:36;Layout.topMargin:9;spacing:12
                        Text{text:((section==="Videos"||section==="Music")?files.count:0)+" items";color:Theme.muted;font.pixelSize:14} Item{Layout.fillWidth:true}
                        Icon{name:"SortArrows";size:24;interactive:false} Icon{name:"ListBullets";size:24;interactive:false} Icon{name:"Search01";size:24;interactive:false}
                    }
                    Rectangle{Layout.fillWidth:true;height:1;Layout.topMargin:10;color:"#262626"}
                    Item { Layout.fillWidth:true;Layout.preferredHeight:40;Layout.topMargin:8
                        RowLayout{anchors.fill:parent;spacing:12;Icon{name:"Add01";size:18;interactive:false;tint:Theme.muted}Text{text:"Add…";color:Theme.muted;font.pixelSize:14}}
                        MouseArea{anchors.fill:parent;cursorShape:Qt.PointingHandCursor;onClicked:picker.open()}
                    }
                    Item { Layout.fillWidth:true;Layout.fillHeight:true
                    ListView { id:fileList;anchors.fill:parent;clip:true;visible:win.section==="Videos"||win.section==="Music";model:files;spacing:0;ScrollBar.vertical:ScrollBar{}
                        delegate:Rectangle { required property string fileName;required property url fileUrl;required property int index; width:fileList.width;height:42;color:rowMouse.containsMouse?"#ffffff0d":"transparent"
                            RowLayout{anchors.fill:parent;anchors.leftMargin:7;spacing:10
                                Icon{name:win.section==="Music"?"MusicNote01":"Video01";size:18;interactive:false;tint:Theme.muted}
                                Text{Layout.fillWidth:true;text:fileName;color:fileName===player.title?Theme.accent:Theme.text;font.pixelSize:14;elide:Text.ElideRight}
                            }
                            MouseArea{id:rowMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:player.open(fileUrl)}
                        }
                    }
                    Text { anchors.centerIn:parent;visible:win.section==="Home"||win.section==="Network"||win.section==="Playlists"||win.section==="Recent";text:"Nothing here yet";color:Theme.muted;font.pixelSize:13 }
                    }
                }
            }
            Rectangle { Layout.fillWidth:true;Layout.fillHeight:true;color:Theme.window
                Rectangle { anchors.fill:parent;anchors.rightMargin:win.showChrome?8:0;color:win.showChrome?Theme.video:"#1c1c1c"
                    VideoOutput{id:output;anchors.fill:parent;fillMode:VideoOutput.PreserveAspectFit}
                    Text{anchors.centerIn:parent;visible:!player.title||player.title==="Konus";text:"Drop a video or press +";color:Theme.muted;font.pixelSize:13}
                    Rectangle{id:osd;property string text:"";anchors.horizontalCenter:parent.horizontalCenter;anchors.top:parent.top;anchors.topMargin:20;color:"#000000b3";radius:18;opacity:0;visible:opacity>0;z:3;implicitWidth:osdLabel.implicitWidth+28;implicitHeight:34;Text{id:osdLabel;anchors.centerIn:parent;text:osd.text;color:"white";font.pixelSize:13}Behavior on opacity{NumberAnimation{duration:150}}}
                    MouseArea{anchors.fill:parent;acceptedButtons:Qt.LeftButton;onDoubleClicked:win.visibility=win.visibility===Window.FullScreen?Window.Windowed:Window.FullScreen}
                }
            }
        }
        Rectangle { id:controlbar;Layout.fillWidth:true;Layout.preferredHeight:56;color:Theme.control;visible:win.showChrome
            HoverHandler{id:controlsHover}
            RowLayout{anchors.fill:parent;anchors.leftMargin:28;anchors.rightMargin:24;spacing:24
                Icon{name:"Previous";size:24;interactive:true;Layout.preferredWidth:32;Layout.preferredHeight:32;ToolTip.visible:prevMouse.containsMouse;ToolTip.delay:600;ToolTip.text:"Previous";MouseArea{id:prevMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:win.stepFile(-1)}}
                Rectangle{Layout.preferredWidth:56;Layout.preferredHeight:32;color:playMouse.pressed?Qt.darker(Theme.accent,1.2):playMouse.containsMouse?Qt.lighter(Theme.accent,1.15):Theme.accent;radius:4;Icon{anchors.centerIn:parent;name:player.playing?"Pause":"Play";size:18;tint:"#1a1a1a";interactive:false}MouseArea{id:playMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:if(player.title==="Konus"&&files.count)player.open(files.get(0,"fileUrl"));else if(player.title==="Konus")picker.open();else player.togglePause()}}
                Icon{name:"Next";size:24;interactive:true;Layout.preferredWidth:32;Layout.preferredHeight:32;ToolTip.visible:nextMouse.containsMouse;ToolTip.delay:600;ToolTip.text:"Next";MouseArea{id:nextMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:win.stepFile(1)}}
                Text{Layout.preferredWidth:62;text:fmt(player.time);color:"#9a9a9a";font.pixelSize:14}
                Item{Layout.fillWidth:true;Layout.preferredHeight:28;id:seekBar;readonly property real progress:player.length>0?Math.max(0,Math.min(1,player.time/player.length)):0;property real dragProgress:progress
                    Rectangle{anchors.fill:parent;color:"#0b0b0b";radius:4;Rectangle{width:parent.width*(seekBarMouse.pressed?seekBar.dragProgress:seekBar.progress);height:parent.height;color:Theme.seekFill;radius:4}}
                    Rectangle{x:(parent.width-width)*(seekBarMouse.pressed?seekBar.dragProgress:seekBar.progress);width:6;height:28;color:Theme.accent;radius:3}
                    MouseArea {
                        id:seekBarMouse;anchors.fill:parent;enabled:player.length>0
                        onPressed: { win.seekPressed=true; seekBar.dragProgress=Math.max(0,Math.min(1,mouse.x/width)) }
                        onPositionChanged: { if(pressed) seekBar.dragProgress=Math.max(0,Math.min(1,mouse.x/width)) }
                        onReleased: { player.seek(player.length*seekBar.dragProgress); win.seekPressed=false;idle.restart() }
                    }
                }
                Text{text:fmt(player.length);color:"#9a9a9a";font.pixelSize:14}
                Icon{name:player.muted?"VolumeOff":"VolumeLow";size:24;interactive:true;Layout.preferredWidth:32;Layout.preferredHeight:32;ToolTip.visible:muteMouse.containsMouse;ToolTip.delay:600;ToolTip.text:player.muted?"Unmute":"Mute";MouseArea{id:muteMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:player.muted=!player.muted;onWheel:win.wheelVolume(wheel.angleDelta.y)}}
                Item{Layout.preferredWidth:90;Layout.preferredHeight:26
                    Canvas{anchors.fill:parent;property real level:player.muted?0:player.volume/100;onLevelChanged:requestPaint();onPaint:{let c=getContext("2d"),w=width,h=height,x=w*level,edge=h*0.22,half=edge/2+(h/2-edge/2)*level;c.clearRect(0,0,w,h);c.lineJoin="round";c.fillStyle="#0b0b0b";c.lineWidth=1;c.beginPath();c.moveTo(0,(h-edge)/2);c.lineTo(0,(h+edge)/2);c.lineTo(w,h);c.lineTo(w,0);c.closePath();c.fill();c.fillStyle="#8aa31a";c.beginPath();c.moveTo(0,(h-edge)/2);c.lineTo(0,(h+edge)/2);c.lineTo(x,h/2+half);c.lineTo(x,h/2-half);c.closePath();c.fill()}}
                    MouseArea {
                        anchors.fill:parent
                        onPressed: { win.volumePressed=true; setLevel(mouse.x) }
                        onPositionChanged: { if(pressed) setLevel(mouse.x) }
                        onReleased: { win.volumePressed=false;idle.restart() }
                        onWheel: win.wheelVolume(wheel.angleDelta.y)
                        function setLevel(x) { player.volume=Math.round(100*Math.max(0,Math.min(1,x/width))) }
                    }
                }
                Icon{name:"AudioWave01";size:24;interactive:true;Layout.preferredWidth:32;Layout.preferredHeight:32;ToolTip.visible:audioMouse.containsMouse;ToolTip.delay:600;ToolTip.text:"Audio track";MouseArea{id:audioMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:player.cycleAudioTrack()}}
                Icon{name:"Subtitle";size:24;interactive:true;Layout.preferredWidth:32;Layout.preferredHeight:32;ToolTip.visible:subMouse.containsMouse;ToolTip.delay:600;ToolTip.text:"Subtitles";MouseArea{id:subMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:player.cycleSubtitle()}}
                Icon{name:"SettingsPlay";size:24;interactive:false;Layout.preferredWidth:32;Layout.preferredHeight:32}
                Icon{name:"ListBullets";size:24;interactive:true;Layout.preferredWidth:32;Layout.preferredHeight:32;ToolTip.visible:queueMouse.containsMouse;ToolTip.delay:600;ToolTip.text:"Library";MouseArea{id:queueMouse;anchors.fill:parent;hoverEnabled:true;cursorShape:Qt.PointingHandCursor;onClicked:win.libraryOpen=!win.libraryOpen}}
            }
        }
    }
    Repeater { model:["left","right","top","bottom","topLeft","topRight","bottomLeft","bottomRight"];delegate:Item{required property string modelData;z:10;property bool horiz:modelData==="left"||modelData==="right";property bool vert:modelData==="top"||modelData==="bottom";x:modelData.includes("left")?0:modelData.includes("right")?win.width-6:6;y:modelData.includes("top")?0:modelData.includes("bottom")?win.height-6:6;width:horiz?6:modelData.includes("left")||modelData.includes("right")?6:win.width-12;height:vert?6:modelData.includes("top")||modelData.includes("bottom")?6:win.height-12;MouseArea{anchors.fill:parent;cursorShape:parent.modelData.includes("topLeft")||parent.modelData.includes("bottomRight")?Qt.SizeFDiagCursor:parent.modelData.includes("topRight")||parent.modelData.includes("bottomLeft")?Qt.SizeBDiagCursor:parent.horiz?Qt.SizeHorCursor:Qt.SizeVerCursor;onPressed:win.startSystemResize(parent.modelData.includes("left")?(parent.modelData.includes("top")?Qt.TopEdge|Qt.LeftEdge:parent.modelData.includes("bottom")?Qt.BottomEdge|Qt.LeftEdge:Qt.LeftEdge):parent.modelData.includes("right")?(parent.modelData.includes("top")?Qt.TopEdge|Qt.RightEdge:parent.modelData.includes("bottom")?Qt.BottomEdge|Qt.RightEdge:Qt.RightEdge):parent.modelData==="top"?Qt.TopEdge:Qt.BottomEdge)}} }
    Component.onCompleted:player.attachSink(output.videoSink)
}
