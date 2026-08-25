import QtQuick
import qs.Common

// Rounded toggle switch.
Rectangle {
    id: t

    signal toggled()

    property bool checked: false

    implicitWidth: 40
    implicitHeight: 22
    radius: Theme.radiusFull
    color: checked ? Theme.primary : Theme.surfaceHover
    border.color: checked ? Theme.primary : Theme.outline
    border.width: 1
    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Behavior on border.color { ColorAnimation { duration: Theme.durFast } }

    Rectangle {
        id: handle
        width: 16
        height: 16
        radius: Theme.radiusFull
        color: t.checked ? Theme.background : Theme.foreground
        y: (parent.height - height) / 2
        x: t.checked ? parent.width - width - 3 : 3
        Behavior on x { NumberAnimation { duration: Theme.durNormal; easing.bezierCurve: Theme.easeSpatial; easing.type: Easing.BezierSpline } }
        Behavior on color { ColorAnimation { duration: Theme.durFast } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            t.checked = !t.checked;
            t.toggled();
        }
    }
}
