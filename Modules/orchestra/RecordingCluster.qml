import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// RECORDING collapsed view: pulsing red dot · elapsed · waveform beneath,
// controls right (pause/resume · stop · settings gear).
Item {
    id: cl

    // pulsing red dot ----------------------------------------------------
    Rectangle {
        id: dot
        width: 9
        height: 9
        radius: Theme.radiusFull
        color: Theme.danger
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter

        SequentialAnimation on opacity {
            running: Recorder.state === "recording"
            loops: Animation.Infinite
            NumberAnimation { to: 0.15; duration: 620; easing.type: Easing.InOutSine }
            NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
        }
        opacity: Recorder.state === "paused" ? 0.38 : 1
    }

    // elapsed ------------------------------------------------------------
    Text {
        text: Qt.formatTime(new Date(Recorder.elapsedSecs * 1000), "mm:ss")
        color: Recorder.state === "paused" ? Theme.dimText : Theme.foreground
        font.pixelSize: Theme.fontSm
        font.weight: Font.DemiBold
        font.family: "monospace"
        anchors.centerIn: parent
    }

    // waveform strip beneath ----------------------------------------------
    WaveLoop {
        width: parent.width - Theme.spaceLg * 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 3
        running: Recorder.state === "recording"
    }

    // controls -------------------------------------------------------------
    Row {
        spacing: Theme.spaceXs
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter

        IconButton {
            category: "record"
            iconName: Recorder.state === "paused" ? "play" : "pause"
            iconSize: 13
            pad: 4
            onClicked: Recorder.pauseToggle()
        }
        IconButton {
            category: "record"
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
