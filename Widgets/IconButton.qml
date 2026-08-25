import QtQuick
import qs.Common

// Round hover-highlighting icon button.
Rectangle {
    id: btn

    signal clicked()

    property string category: "status"
    property string iconName: ""
    property int iconSize: 20
    property color iconColor: Theme.foreground
    property int pad: Theme.spaceSm
    property bool accent: false

    implicitWidth: iconSize + pad * 2
    implicitHeight: iconSize + pad * 2
    radius: Theme.radiusFull
    color: mouse.containsMouse ? Theme.surfaceHover : (accent ? Theme.primary : "transparent")
    opacity: enabled ? 1 : 0.4
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

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
