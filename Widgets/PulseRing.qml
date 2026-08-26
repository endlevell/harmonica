import QtQuick
import qs.Common

// Animated pulsing ring indicator for active states.
// Smooth, organic motion for status feedback.
Item {
    id: root

    property color ringColor: Theme.primary
    property bool active: false
    property real pulseScale: 1.4

    implicitWidth: 12
    implicitHeight: 12

    // Inner dot
    Rectangle {
        id: innerDot
        anchors.centerIn: parent
        width: root.width * 0.5
        height: root.height * 0.5
        radius: width / 2
        color: root.ringColor
    }

    // Pulse ring
    Rectangle {
        id: pulseRing
        anchors.centerIn: parent
        width: root.width
        height: root.height
        radius: width / 2
        color: "transparent"
        border.width: 2
        border.color: root.ringColor
        opacity: 0

        SequentialAnimation on scale {
            running: root.active && root.visible
            loops: Animation.Infinite

            NumberAnimation {
                from: 1
                to: root.pulseScale
                duration: 1200
                easing.type: Easing.OutCubic
            }
            PauseAnimation { duration: 100 }
        }

        SequentialAnimation on opacity {
            running: root.active && root.visible
            loops: Animation.Infinite

            NumberAnimation {
                from: 0.7
                to: 0
                duration: 1200
                easing.type: Easing.OutCubic
            }
            PauseAnimation { duration: 100 }
        }
    }
}
