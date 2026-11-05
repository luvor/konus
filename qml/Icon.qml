import QtQuick
import QtQuick.Controls

Item {
    id: icon
    property string name
    property int size: 18
    property real glyphWidth: size
    property real glyphHeight: size
    property real glyphOffsetX: 0
    property color tint: "#8f8f8f"
    property color hoverTint: Qt.lighter(tint, 1.3)
    property bool interactive: false
    property bool closeButton: false
    property string tooltip: ""
    property string accessibleName: tooltip
    signal activated()
    width: interactive ? Math.max(glyphWidth, 32) : glyphWidth
    height: interactive ? Math.max(glyphHeight, 32) : glyphHeight
    Accessible.role: Accessible.Button
    Accessible.name: accessibleName || name
    Accessible.ignored: !interactive
    Accessible.onPressAction: icon.activated()
    activeFocusOnTab: interactive
    Keys.onSpacePressed: (event) => { activated(); event.accepted = true }
    Keys.onReturnPressed: (event) => { activated(); event.accepted = true }
    Keys.onEnterPressed: (event) => { activated(); event.accepted = true }
    Keys.onShortcutOverride: (event) => { if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) event.accepted = true }

    HoverHandler { id: hover; enabled: icon.interactive || icon.tooltip.length > 0 }
    TapHandler { id: tap; enabled: icon.interactive }
    ToolTip.visible: icon.tooltip.length > 0 && hover.hovered
    ToolTip.delay: 600
    ToolTip.text: icon.tooltip
    Rectangle {
        anchors.fill: parent
        radius: 6
        visible: icon.interactive && (hover.hovered || tap.pressed)
        color: icon.closeButton && hover.hovered ? "#c42b1c" : tap.pressed ? "#24ffffff" : "#14ffffff"
    }
    Rectangle { anchors.fill: parent; radius: 6; color: "transparent"; border.width: icon.activeFocus ? 1 : 0; border.color: Theme.accent }
    Image {
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: icon.glyphOffsetX
        width: icon.glyphWidth
        height: icon.glyphHeight
        source: "image://icons/" + icon.name + "/" + (icon.closeButton && hover.hovered ? "#ffffff" : (hover.hovered && icon.interactive ? icon.hoverTint : icon.tint)).toString().slice(1)
        sourceSize: Qt.size(icon.glyphWidth * 2, icon.glyphHeight * 2)
    }
}
