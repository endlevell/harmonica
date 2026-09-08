import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

// RIGHT page — music player. Album art framed by a progress ring, track meta
// centered beneath, one clear control row. Composed, calm, not sprawling.
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

    // ---- empty state -------------------------------------------------------
    Column {
        anchors.centerIn: parent
        visible: !Mpris.hasPlayer
        spacing: Theme.spaceMd

        Icon {
            category: "media"; name: "music-note"; size: 40
            color: Theme.outline; opacity: 0.6
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "Nothing playing"
            color: Theme.dimText
            font.pixelSize: Theme.fontMd
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ---- player ------------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        anchors.topMargin: Theme.spaceMd
        anchors.bottomMargin: Theme.spaceMd
        visible: Mpris.hasPlayer
        spacing: Theme.spaceSm

        // Album art + progress ring ------------------------------------------
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 124
            Layout.preferredHeight: 124

            ProgressRing {
                anchors.fill: parent
                value: page.progress
                ringColor: Theme.primary
                lineWidth: 3
            }

            Rectangle {
                anchors.centerIn: parent
                width: 108
                height: 108
                radius: Theme.radiusFull
                color: Theme.surface
                clip: true

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
                    category: "media"; name: "music-note"
                    size: 30; color: Theme.outline
                }

                // dim slightly while paused for a subtle live/idle cue
                Rectangle {
                    anchors.fill: parent
                    color: Theme.background
                    opacity: Mpris.playing ? 0 : 0.35
                    Behavior on opacity { NumberAnimation { duration: Theme.durNormal } }
                }
            }
        }

        // Title + artist -----------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spaceXl
            Layout.rightMargin: Theme.spaceXl
            spacing: 1

            Text {
                text: Mpris.title || "Unknown title"
                color: Theme.foreground
                font.family: Theme.fontDisplay
                font.pixelSize: Theme.fontMd
                font.weight: Font.Bold
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
            Text {
                visible: Mpris.artist !== ""
                text: Mpris.artist
                color: Theme.primary
                font.pixelSize: Theme.fontSm
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
            }
        }

        // Time row -----------------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Theme.spaceXl
            Layout.rightMargin: Theme.spaceXl

            Text {
                text: page.fmtTime(Mpris.positionSecs)
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                font.family: Theme.fontMono
            }
            Item { Layout.fillWidth: true }
            Text {
                text: Math.round(page.progress * 100) + "%"
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                font.family: Theme.fontMono
            }
            Item { Layout.fillWidth: true }
            Text {
                text: page.fmtTime(Mpris.lengthSecs)
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                font.family: Theme.fontMono
            }
        }

        Item { Layout.fillHeight: true }

        // Controls -----------------------------------------------------------
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.spaceMd
            spacing: Theme.spaceXl

            IconButton {
                category: "media"; iconName: "prev"; iconSize: 20
                pad: Theme.spaceSm
                enabled: Mpris.canGoPrevious
                onClicked: Mpris.previous()
                Layout.alignment: Qt.AlignVCenter
            }

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                width: 46; height: 46
                radius: Theme.radiusFull
                color: playHover.hovered ? Qt.lighter(Theme.primary, 1.12) : Theme.primary
                Behavior on color { ColorAnimation { duration: Theme.durFast } }

                Icon {
                    anchors.centerIn: parent
                    category: "media"
                    name: Mpris.playing ? "pause" : "play"
                    size: 20
                    color: Theme.background
                }

                HoverHandler { id: playHover }
                TapHandler {
                    enabled: Mpris.canPlay
                    onTapped: Mpris.togglePlaying()
                }
            }

            IconButton {
                category: "media"; iconName: "next"; iconSize: 20
                pad: Theme.spaceSm
                enabled: Mpris.canGoNext
                onClicked: Mpris.next()
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
