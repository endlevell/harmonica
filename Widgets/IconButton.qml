import QtQuick
import qs.Common

// Round icon button with hover scale and press animations
Rectangle {
    id: btn

    signal clicked()

    property string category: "status"
    property string iconName: ""
    property int iconSize: 20
    property color iconColor: Theme.foreground
    property int pad: Theme.spaceSm
    property bool accent: false
    readonly property bool hovered: mouse.containsMouse

    implicitWidth: iconSize + pad * 2
    implicitHeight: iconSize + pad * 2
    radius: Theme.radiusFull
    color: mouse.containsMouse ? Theme.surfaceHover : (accent ? Theme.primary : "transparent")
    opacity: enabled ? 1 : 0.4

    scale: mouse.pressed ? 0.94 : (mouse.containsMouse ? 1.08 : 1.0)

    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.durNormal
            easing.type: Easing.OutCubic
        }
    }

    Icon {
        anchors.centerIn: parent
        size: btn.iconSize
        category: btn.category
        name: btn.iconName
        color: btn.accent ? Theme.background : btn.iconColor
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }
}
