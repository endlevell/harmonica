import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

// RIGHT page — Immersive music player with glassmorphism, large album art,
// audio visualizer, and fluid controls. Bold, beautiful, emotionally engaging.
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

    // Empty state --------------------------------------------------------
    Column {
        anchors.centerIn: parent
        visible: !Mpris.hasPlayer
        spacing: Theme.spaceMd

        Icon {
            category: "media"
            name: "music-note"
            size: 48
            color: Theme.outline
            anchors.horizontalCenter: parent.horizontalCenter
            opacity: 0.5
        }
        Text {
            text: "No music playing"
            color: Theme.dimText
            font.pixelSize: Theme.fontMd
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // Player UI ----------------------------------------------------------
    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceLg
        anchors.rightMargin: Theme.spaceLg
        anchors.topMargin: Theme.spaceMd
        anchors.bottomMargin: Theme.spaceLg
        visible: Mpris.hasPlayer
        spacing: Theme.spaceSm

        Item { Layout.fillHeight: true; Layout.preferredHeight: 8 }

        // Album Art Glass Card with Glow ---------------------------------
        GlassMorphCard {
            Layout.fillWidth: true
            Layout.preferredHeight: 140
            Layout.alignment: Qt.AlignHCenter

            RowLayout {
                anchors.fill: parent
                spacing: Theme.spaceMd

                // Large Album Art
                Rectangle {
                    Layout.preferredWidth: 112
                    Layout.preferredHeight: 112
                    Layout.alignment: Qt.AlignVCenter
                    radius: Theme.radiusMd
                    color: Theme.surface
                    clip: true

                    // Outer glow effect
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: parent.radius + 4
                        color: "transparent"
                        border.width: 12
                        border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.15)
                        z: -1
                    }

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
                        size: 36
                        color: Theme.outline
                    }

                    // Rotating border on playing
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: "transparent"
                        border.width: 2
                        border.color: Theme.primary
                        opacity: Mpris.playing ? 0.6 : 0
                        visible: Mpris.artUrl !== ""

                        Behavior on opacity {
                            NumberAnimation { duration: Theme.durNormal }
                        }
                    }
                }

                // Track Info Column
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: Theme.spaceXs

                    Text {
                        text: Mpris.title
                        color: Theme.foreground
                        font.pixelSize: Theme.fontLg
                        font.weight: Font.Bold
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        wrapMode: Text.Wrap
                    }

                    Text {
                        visible: Mpris.artist !== ""
                        text: Mpris.artist
                        color: Theme.dimText
                        font.pixelSize: Theme.fontSm
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    Item { Layout.preferredHeight: 4 }

                    // Now Playing indicator
                    Row {
                        spacing: Theme.spaceXs
                        visible: Mpris.playing

                        PulseRing {
                            width: 8
                            height: 8
                            ringColor: Theme.colorOk
                            active: true
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Text {
                            text: "Now Playing"
                            color: Theme.colorOk
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.Medium
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                }
            }
        }

        Item { Layout.preferredHeight: Theme.spaceXs }

        // Audio Visualizer -----------------------------------------------
        AudioVisualizer {
            Layout.fillWidth: true
            Layout.preferredHeight: 38
            active: Mpris.playing
            intensity: 0.7
            barColor: Theme.primary
        }

        Item { Layout.preferredHeight: Theme.spaceXs }

        // Progress Bar with Time -----------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            // Progress bar
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
                radius: Theme.radiusFull
                color: Theme.surface

                Rectangle {
                    width: parent.width * page.progress
                    height: parent.height
                    radius: parent.radius
                    color: Theme.primary

                    Behavior on width {
                        enabled: page.visible
                        NumberAnimation {
                            duration: 500
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                // Progress knob
                Rectangle {
                    x: (parent.width * page.progress) - width / 2
                    anchors.verticalCenter: parent.verticalCenter
                    width: 10
                    height: 10
                    radius: Theme.radiusFull
                    color: Theme.primary
                    visible: page.progress > 0

                    Behavior on x {
                        enabled: page.visible
                        NumberAnimation {
                            duration: 500
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            // Time labels
            Row {
                Layout.fillWidth: true

                Text {
                    text: fmtTime(Mpris.positionSecs)
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    font.family: "monospace"
                    width: parent.width / 2
                }

                Text {
                    text: fmtTime(Mpris.lengthSecs)
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    font.family: "monospace"
                    width: parent.width / 2
                    horizontalAlignment: Text.AlignRight
                }
            }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 4 }

        // Playback Controls ----------------------------------------------
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: Theme.spaceLg

            IconButton {
                category: "media"
                iconName: "prev"
                iconSize: 18
                pad: Theme.spaceSm
                enabled: Mpris.canGoPrevious
                onClicked: Mpris.previous()
            }

            // Large Play/Pause button
            Rectangle {
                width: 52
                height: 52
                radius: Theme.radiusFull
                color: Theme.primary

                Icon {
                    anchors.centerIn: parent
                    category: "media"
                    name: Mpris.playing ? "pause" : "play"
                    size: 22
                    color: Theme.background
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: Mpris.canPlay
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Mpris.togglePlaying()
                }

                // Pulse effect on playing
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width + 8
                    height: parent.height + 8
                    radius: Theme.radiusFull
                    color: "transparent"
                    border.width: 2
                    border.color: Theme.primary
                    opacity: 0
                    visible: Mpris.playing

                    SequentialAnimation on opacity {
                        running: Mpris.playing && page.visible
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 0.5
                            to: 0
                            duration: 1500
                            easing.type: Easing.OutCubic
                        }
                    }

                    SequentialAnimation on scale {
                        running: Mpris.playing && page.visible
                        loops: Animation.Infinite

                        NumberAnimation {
                            from: 1
                            to: 1.3
                            duration: 1500
                            easing.type: Easing.OutCubic
                        }
                    }
                }
            }

            IconButton {
                category: "media"
                iconName: "next"
                iconSize: 18
                pad: Theme.spaceSm
                enabled: Mpris.canGoNext
                onClicked: Mpris.next()
            }
        }

        Item { Layout.fillHeight: true; Layout.preferredHeight: 8 }
    }
}
