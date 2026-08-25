import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// Compact previewer strip shown while music plays and island is closed:
// album thumb left · title/artist center · mini controls right.
Item {
    id: strip

    readonly property int textW: Math.min(Math.max(titleTxt.implicitWidth, artistTxt.implicitWidth), 150)
    readonly property int ctlW: pauseBtn.width + nextBtn.width + Theme.spaceXs

    // exact pill width: side pads + art + gaps + text + controls
    readonly property int contentWidth: Theme.spaceMd * 2 + 22 + Theme.spaceSm * 2
        + textW + Theme.spaceSm + ctlW

    Rectangle {
        id: artBox
        width: 22
        height: 22
        radius: Theme.radiusXs
        color: Theme.surface
        clip: true
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter

        Image {
            anchors.fill: parent
            source: Mpris.artUrl
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: Mpris.artUrl !== ""
        }
        Icon {
            anchors.centerIn: parent
            visible: Mpris.artUrl === ""
            category: "media"
            name: "music-note"
            size: 12
            color: Theme.dimText
        }
    }

    Column {
        id: txtCol
        width: strip.textW
        spacing: 1
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter

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
            color: Theme.dimText
            font.pixelSize: 10
            elide: Text.ElideRight
        }
    }

    Row {
        id: ctlRow
        spacing: Theme.spaceXs
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter

        IconButton {
            id: pauseBtn
            category: "media"
            iconName: Mpris.playing ? "pause" : "play"
            iconSize: 13
            pad: 5
            enabled: Mpris.canPlay
            onClicked: Mpris.togglePlaying()
        }
        IconButton {
            id: nextBtn
            category: "media"
            iconName: "next"
            iconSize: 13
            pad: 5
            enabled: Mpris.canGoNext
            onClicked: Mpris.next()
        }
    }
}
