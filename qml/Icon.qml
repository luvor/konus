import QtQuick
Item {
    property string name
    property int size:18
    property color tint:"#9a9a9a"
    width:size;height:size
    Image { anchors.fill:parent;source:"qrc:/konus/assets/icons/"+name+".svg";sourceSize:Qt.size(parent.size*2,parent.size*2) }
}
