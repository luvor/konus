import QtQuick
Item {
    id: icon
    property string name
    property int size:18
    property color tint:"#9a9a9a"
    property color hoverTint: Qt.lighter(tint, 1.3)
    width:size;height:size
    HoverHandler { id: hover }
    Image { anchors.fill:parent;source:"image://icons/"+icon.name+"/"+(hover.hovered?icon.hoverTint:icon.tint).toString().slice(1);sourceSize:Qt.size(icon.size*2,icon.size*2) }
}
