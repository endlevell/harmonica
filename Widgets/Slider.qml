import QtQuick
import qs.Common
import qs.Widgets

// Modern flat slider with clean hover states
Rectangle {
    id: slider

    property real value: 0.5           // 0.0 .. 1.0
    property string category: "system"
    property string iconName: ""
    property color activeColor: Theme.primary
    property color trackColor: Theme.surfaceHover

    signal moved(real val)

    implicitWidth: 190
    implicitHeight: 32
    radius: Theme.radiusFull
    color: trackColor
    clip: true

    scale: dragArea.containsMouse ? 1.02 : 1.0

    Behavior on scale {
        NumberAnimation {
            duration: Theme.durNormal
            easing.type: Easing.OutCubic
        }
    }

    // Clean flat fill bar
    Rectangle {
        id: fillBar
        width: Math.max(slider.height, slider.value * slider.width)
        height: parent.height
        radius: Theme.radiusFull
        color: slider.activeColor

        Behavior on width {
            NumberAnimation {
                duration: Theme.durFast
                easing.type: Easing.OutCubic
            }
        }
    }

    // Icon + Label overlay
    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceSm + 2
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceXs + 2

        Icon {
            category: slider.category
            name: slider.iconName
            size: 14
            color: slider.value > 0.15 ? Theme.background : Theme.foreground
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Text {
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceSm + 4
        anchors.verticalCenter: parent.verticalCenter
        text: Math.round(slider.value * 100) + "%"
        color: slider.value > 0.85 ? Theme.background : Theme.foreground
        font.pixelSize: Theme.fontXs
        font.weight: Font.DemiBold
        font.family: Theme.fontMono
    }

    MouseArea {
        id: dragArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        function updateFromPos(mouseX) {
            const v = Math.max(0.0, Math.min(1.0, mouseX / slider.width));
            slider.value = v;
            slider.moved(v);
        }

        onPressed: mouse => updateFromPos(mouse.x)
        onPositionChanged: mouse => {
            if (pressed) updateFromPos(mouse.x);
        }
    }
}
