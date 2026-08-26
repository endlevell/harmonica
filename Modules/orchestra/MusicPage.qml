import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

// RIGHT page — Apple-widget style player. Empty state when no Mpris player.
Item {
    id: page

    function fmtTime(s: real): string {
        if (s <= 0) return "0:00";
        const m = Math.floor(s / 60);
        const sec = Math.floor(s % 60);
        return m + ":" + (sec < 10 ? "0" : "") + sec;
    }
    readonly property real progress: (Mpris.lengthSecs > 0 && Mpris.positionSecs >= 0)
        ? Math.min(1, Mpris.positionSecs / Mpris.lengthSecs) : 0

    // empty state ------------------------------------------------------
    Column {
        anchors.centerIn: parent
        visible: !Mpris.hasPlayer
        spacing: Theme.spaceSm

        Icon { category: "media"; name: "music-note"; size: 26; color: Theme.outline; anchors.horizontalCenter: parent.horizontalCenter }
        Text {
            text: "Nothing playing"
            color: Theme.dimText
            font.pixelSize: Theme.fontSm
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // player -----------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceXl + 4
        anchors.rightMargin: Theme.spaceXl + 4
        anchors.topMargin: Theme.spaceMd
        anchors.bottomMargin: Theme.spaceLg
        visible: Mpris.hasPlayer
        spacing: Theme.spaceSm

        Row {
            spacing: Theme.spaceLg
            Layout.fillWidth: true

            Rectangle {
                width: 64
                height: 64
                radius: Theme.radiusSm
                color: Theme.surface
                clip: true
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
                    size: 20
                    color: Theme.outline
                }
            }

            Column {
                spacing: Theme.spaceXs
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 64 - Theme.spaceLg

                Text {
                    width: parent.width
                    text: Mpris.title || "—"
                    color: Theme.foreground
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: Mpris.artist || ""
                    color: Theme.dimText
                    font.pixelSize: Theme.fontSm
                    elide: Text.ElideRight
                }
            }
        }

        // progress -------------------------------------------------------
        Column {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            Rectangle {
                width: parent.width
                height: 3
                radius: Theme.radiusFull
                color: Theme.surfaceHover

                Rectangle {
                    width: Math.max(0, Math.min(1, page.progress)) * parent.width
                    height: parent.height
                    radius: Theme.radiusFull
                    color: Theme.primary
                    Behavior on width { NumberAnimation { duration: 450; easing.type: Easing.Linear } }
                }
            }

            RowLayout {
                width: parent.width

                Text { text: fmtTime(Mpris.positionSecs); color: Theme.dimText; font.pixelSize: 10 }
                Item { Layout.fillWidth: true; height: 1 }
                Text { text: fmtTime(Mpris.lengthSecs); color: Theme.dimText; font.pixelSize: 10 }
            }
        }

        // controls ---------------------------------------------------------
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spaceLg

            IconButton {
                category: "media"
                iconName: "prev"
                iconSize: 17
                enabled: Mpris.canGoPrevious
                onClicked: Mpris.previous()
                Layout.alignment: Qt.AlignVCenter
            }
            IconButton {
                category: "media"
                iconName: Mpris.playing ? "pause" : "play"
                iconSize: 20
                pad: Theme.spaceSm
                accent: true
                enabled: Mpris.canPlay
                onClicked: Mpris.togglePlaying()
            }
            IconButton {
                category: "media"
                iconName: "next"
                iconSize: 17
                enabled: Mpris.canGoNext
                onClicked: Mpris.next()
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
