import QtQuick
Item {
    id: icon
    property string name
    property int size:18
    property color tint:"#9a9a9a"
    property color hoverTint: Qt.lighter(tint, 1.3)
    property bool interactive:false
    property bool closeButton:false
    width:interactive?Math.max(size,32):size;height:interactive?Math.max(size,32):size
    HoverHandler { id: hover;enabled:icon.interactive }
    TapHandler { id: tap;enabled:icon.interactive }
    Rectangle { anchors.fill:parent;radius:6;visible:icon.interactive&&(hover.hovered||tap.pressed);color:icon.closeButton&&hover.hovered?"#c42b1c":tap.pressed?"#ffffff24":"#ffffff14" }
    Image { anchors.centerIn:parent;width:icon.size;height:icon.size;source:"image://icons/"+icon.name+"/"+(icon.closeButton&&hover.hovered?"#ffffff":(hover.hovered?icon.hoverTint:icon.tint)).toString().slice(1);sourceSize:Qt.size(icon.size*2,icon.size*2) }
}
