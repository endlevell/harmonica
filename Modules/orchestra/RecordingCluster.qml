import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// RECORDING pill: full controls while hovered, compact timer + dot with a
// slow breathing width while the cursor stays away (old shell compact mode).
Item {
    id: cl

    readonly property int fullW: 300
    readonly property int compactW: 150
    readonly property int baseW: compact ? compactW : fullW
    readonly property int contentWidth: baseW + 4
    readonly property bool compact: Recorder.active && debounced && !hovered

    property bool hovered: false
    property bool debounced: false
    property real breath: 0              // ±2px inner width oscillation

    function formatDuration(seconds: int): string {
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    Connections {
        target: Recorder
        function onActiveChanged() { debounce.restart(); }
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            cl.hovered = hovered;
            debounce.restart();
        }
    }

    Timer {
        id: debounce
        interval: Theme.recCompactDebounceMs
        repeat: false
        onTriggered: cl.debounced = Recorder.active && !cl.hovered
    }

    SequentialAnimation {
        id: breathe
        running: cl.compact && Recorder.state === "recording" && !Theme.reducedMotion
        loops: Animation.Infinite
        NumberAnimation { target: cl; property: "breath"; to: 2; duration: Theme.reducedMotion ? 0 : Theme.recBreathMs / 2; easing.type: Easing.InOutSine }
        NumberAnimation { target: cl; property: "breath"; to: -2; duration: Theme.reducedMotion ? 0 : Theme.recBreathMs / 2; easing.type: Easing.InOutSine }
    }
    onCompactChanged: if (!compact) breath = 0

    // island-sized box; inner content breathes inside fixed +4 headroom
    Item {
        anchors.centerIn: parent
        width: cl.baseW + cl.breath
        height: parent.height

        // ---- full: dot · elapsed · controls, waveform beneath ----
        Item {
            anchors.fill: parent
            opacity: cl.compact ? 0 : 1
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.durFast; easing.type: Easing.OutCubic } }

            Rectangle {
                id: dot
                width: 9
                height: 9
                radius: Theme.radiusFull
                color: Recorder.state === "paused" ? Theme.colorPause : Theme.colorRecord
                anchors.left: parent.left
                anchors.leftMargin: Theme.spaceMd
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    running: Recorder.state === "recording"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 620; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
                }
                opacity: Recorder.state === "paused" ? 0.85 : 1
            }

            Text {
                text: cl.formatDuration(Recorder.elapsedSecs)
                color: Recorder.state === "paused" ? Theme.dimText : Theme.foreground
                font.pixelSize: Theme.fontSm
                font.weight: Font.DemiBold
                font.family: Theme.fontMono
                anchors.centerIn: parent
            }

            WaveLoop {
                width: parent.width - Theme.spaceLg * 2
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 3
                running: Recorder.state === "recording"
            }

            Row {
                spacing: Theme.spaceXs
                anchors.right: parent.right
                anchors.rightMargin: Theme.spaceMd
                anchors.verticalCenter: parent.verticalCenter

                IconButton {
                    category: "media"
                    iconName: Recorder.state === "paused" ? "play" : "pause"
                    iconSize: 13
                    pad: 4
                    onClicked: Recorder.pauseToggle()
                }
                IconButton {
                    category: "media"
                    iconName: "stop"
                    iconSize: 13
                    pad: 4
                    onClicked: Recorder.stop()
                }
                IconButton {
                    category: "system"
                    iconName: "gear"
                    iconSize: 13
                    pad: 4
                    onClicked: win.openRecordSettings()
                }
            }
        }

        // ---- compact: timer + tiny dot ----
        Row {
            anchors.centerIn: parent
            spacing: Theme.spaceSm
            opacity: cl.compact ? 1 : 0
            visible: opacity > 0.01
            Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.durFast; easing.type: Easing.OutCubic } }

            Rectangle {
                width: 7
                height: 7
                radius: Theme.radiusFull
                color: Theme.colorRecord
                anchors.verticalCenter: parent.verticalCenter

                SequentialAnimation on opacity {
                    running: Recorder.state === "recording"
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.15; duration: 620; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
                }
            }

            Text {
                text: cl.formatDuration(Recorder.elapsedSecs)
                color: Theme.foreground
                font.pixelSize: Theme.fontSm
                font.weight: Font.DemiBold
                font.family: Theme.fontMono
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
