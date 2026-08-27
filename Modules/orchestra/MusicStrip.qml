import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// Compact music strip shown while audio plays and the island is collapsed.
// Album art framed by a progress ring (the arc IS the progress bar),
// a slim equalizer, title/artist, and prev / play / next controls.
// Flat, pywal-accented — no chrome (DESIGN §11).
Item {
    id: strip

    readonly property int ringSize: 28
    readonly property int artSize: 22
    readonly property int eqW: 14
    readonly property int eqH: 16
    readonly property real progress: Mpris.lengthSecs > 0
        ? Mpris.positionSecs / Mpris.lengthSecs : 0

    readonly property int textW: Math.min(
        Math.max(titleTxt.implicitWidth, artistTxt.visible ? artistTxt.implicitWidth : 0),
        130)

    readonly property int ctlW: prevBtn.width + playBtn.width + nextBtn.width + Theme.spaceXs * 2

    // exact pill width: pads + ring + eq + text + controls + gaps
    readonly property int contentWidth: Theme.spaceMd * 2
        + ringSize + Theme.spaceSm
        + eqW + Theme.spaceSm
        + textW + Theme.spaceSm
        + ctlW

    Row {
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter
        spacing: Theme.spaceSm

        // album art framed by a progress ring
        Item {
            width: strip.ringSize
            height: strip.ringSize
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
                id: artClip
                anchors.centerIn: parent
                width: strip.artSize
                height: strip.artSize
                radius: strip.artSize / 2
                color: Theme.surface
                clip: true

                Image {
                    id: artImg
                    anchors.fill: parent
                    source: Mpris.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: Mpris.artUrl !== "" && status !== Image.Error
                }
                // fallback disc with a note glyph
                Icon {
                    anchors.centerIn: parent
                    visible: !artImg.visible
                    category: "media"; name: "music-note"
                    size: 11; color: Theme.primary
                }
            }

            ProgressRing {
                anchors.fill: parent
                value: strip.progress
                ringColor: Theme.primary
                lineWidth: 2.5
            }
        }

        // slim equalizer — animates only while playing
        AudioVisualizer {
            width: strip.eqW
            height: strip.eqH
            anchors.verticalCenter: parent.verticalCenter
            barCount: 3
            active: Mpris.playing
            intensity: 0.7
            barColor: Theme.primary
        }

        // title / artist
        Column {
            width: strip.textW
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter

            Text {
                id: titleTxt
                width: parent.width
                text: Mpris.title || "—"
                color: Theme.foreground
                font.pixelSize: Theme.fontXs
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                id: artistTxt
                width: parent.width
                visible: Mpris.artist !== ""
                text: Mpris.artist
                color: Theme.primary
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
    }

    // prev · play (accent) · next
    Row {
        spacing: Theme.spaceXs
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter

        IconButton {
            id: prevBtn
            category: "media"
            iconName: "prev"
            iconSize: 11
            pad: 3
            enabled: Mpris.canGoPrevious
            onClicked: Mpris.previous()
        }
        IconButton {
            id: playBtn
            category: "media"
            iconName: Mpris.playing ? "pause" : "play"
            iconSize: 12
            pad: 5
            accent: true
            enabled: Mpris.canPlay
            onClicked: Mpris.togglePlaying()
        }
        IconButton {
            id: nextBtn
            category: "media"
            iconName: "next"
            iconSize: 11
            pad: 3
            enabled: Mpris.canGoNext
            onClicked: Mpris.next()
        }
    }
}
