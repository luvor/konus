import QtQuick
import QtQuick.Controls

Item {
    id: icon
    property string name
    property int size: 18
    property color tint: "#9a9a9a"
    property color hoverTint: Qt.lighter(tint, 1.3)
    property bool interactive: false
    property bool closeButton: false
    property string tooltip: ""
    property string accessibleName: tooltip
    signal activated()
    width: interactive ? Math.max(size, 32) : size
    height: interactive ? Math.max(size, 32) : size
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName || name
    Accessible.ignored: !interactive
    Accessible.onPressAction: icon.activated()
    activeFocusOnTab: interactive
    Keys.onSpacePressed: { activated(); event.accepted = true }
    Keys.onReturnPressed: { activated(); event.accepted = true }
    Keys.onEnterPressed: { activated(); event.accepted = true }

    HoverHandler { id: hover; enabled: icon.interactive || icon.tooltip.length > 0 }
    TapHandler { id: tap; enabled: icon.interactive }
    ToolTip.visible: icon.tooltip.length > 0 && hover.hovered
    ToolTip.delay: 600
    ToolTip.text: icon.tooltip
    Rectangle {
        anchors.fill: parent
        radius: 6
        visible: icon.interactive && (hover.hovered || tap.pressed)
        color: icon.closeButton && hover.hovered ? "#c42b1c" : tap.pressed ? "#ffffff24" : "#ffffff14"
    }
    Rectangle { anchors.fill: parent; radius: 6; color: "transparent"; border.width: icon.activeFocus ? 1 : 0; border.color: Theme.accent }
    Image {
        anchors.centerIn: parent
        width: icon.size
        height: icon.size
        source: "image://icons/" + icon.name + "/" + (icon.closeButton && hover.hovered ? "#ffffff" : (hover.hovered && icon.interactive ? icon.hoverTint : icon.tint)).toString().slice(1)
        sourceSize: Qt.size(icon.size * 2, icon.size * 2)
    }
}
