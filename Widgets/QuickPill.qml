import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Widgets

// Modern flat quick toggle with clean hover states
Rectangle {
    id: pill

    property string category: "status"
    property string iconName: ""
    property string label: ""
    property string statusText: ""
    property bool active: false
    property color activeColor: Theme.primary

    signal clicked()

    implicitWidth: 180
    implicitHeight: 40
    radius: Theme.radiusMd - 2
    color: active ? activeColor : (mouse.containsMouse ? Theme.surfaceHover : Theme.surface)

    scale: mouse.pressed ? 0.98 : (mouse.containsMouse ? 1.03 : 1.0)

    Behavior on color { ColorAnimation { duration: Theme.durFast } }
    Behavior on scale {
        NumberAnimation {
            duration: Theme.durNormal
            easing.type: Easing.OutCubic
        }
    }

    // Subtle shadow for depth (no gradient)
    layer.enabled: pill.active
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: 0.35
        shadowOpacity: 0.2
        shadowColor: Theme.shadow
        shadowVerticalOffset: 2
        shadowHorizontalOffset: 0
    }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceSm + 2
        anchors.rightMargin: Theme.spaceSm + 2
        spacing: Theme.spaceSm

        // Icon disc
        Rectangle {
            width: 26
            height: 26
            radius: Theme.radiusFull
            color: pill.active ? Theme.background : Theme.surfaceHover
            anchors.verticalCenter: parent.verticalCenter

            Icon {
                category: pill.category
                name: pill.iconName
                size: 14
                color: pill.active ? pill.activeColor : Theme.foreground
                anchors.centerIn: parent
            }
        }

        // Text stack
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            width: parent.width - 34

            Text {
                text: pill.label
                color: pill.active ? Theme.background : Theme.foreground
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontXs + 1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                font.family: Theme.fontText
                text: pill.statusText
                color: pill.active ? Qt.rgba(0, 0, 0, 0.6) : Theme.dimText
                font.pixelSize: 10
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
