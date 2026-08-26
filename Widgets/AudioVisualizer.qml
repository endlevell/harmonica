import QtQuick
import qs.Common

// Audio visualizer bars that react to music playback.
// Animates with smooth, fluid motion to simulate audio waveforms.
Item {
    id: root

    property int barCount: 16
    property color barColor: Theme.primary
    property real intensity: 0.5      // 0..1, drives animation magnitude
    property bool active: false       // playing state

    implicitWidth: 200
    implicitHeight: 40

    readonly property real barWidth: (width / barCount) * 0.7
    readonly property real barSpacing: width / barCount

    Repeater {
        model: root.barCount

        Rectangle {
            required property int index

            readonly property real _phase: (root.index * Math.PI * 2) / root.barCount
            readonly property real _offset: _timer.t + _phase

            x: root.index * root.barSpacing + (root.barSpacing - root.barWidth) / 2
            width: root.barWidth
            height: root.height * (0.2 + 0.8 * Math.abs(Math.sin(_offset)) * root.intensity)
            radius: root.barWidth / 2
            color: root.barColor
            opacity: 0.6 + 0.4 * Math.abs(Math.sin(_offset + Math.PI / 4))

            anchors.bottom: parent.bottom

            Behavior on height {
                enabled: !root.active
                NumberAnimation {
                    duration: Theme.durNormal
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Theme.durFast
                }
            }
        }
    }

    // Continuous animation timer for wave motion
    QtObject {
        id: _timer
        property real t: 0
    }

    Timer {
        interval: 50
        running: root.active && root.visible
        repeat: true
        onTriggered: _timer.t = (_timer.t + 0.15) % (Math.PI * 2)
    }

    // Reset when not active
    onActiveChanged: {
        if (!active) _timer.t = 0
    }
}
