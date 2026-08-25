import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// RECORD SETTINGS big view: filename · format · quality · audio source,
// with Start/Stop and Back. Lives inside the island.
Item {
    id: st

    signal backRequested()

    function grabFocus(): void { Recorder.refreshAudioSources(); }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spaceMd
        spacing: Theme.spaceSm

        Row {
            width: parent.width
            spacing: Theme.spaceMd

            Text { text: "Screen recording"; color: Theme.dimText; font.pixelSize: Theme.fontXs; font.letterSpacing: 2; anchors.verticalCenter: parent.verticalCenter }
            Item { width: parent.width - backBtn.width - 140; height: 1 }
            IconButton {
                id: backBtn
                category: "actions"
                iconName: "close"
                iconSize: 13
                pad: 4
                onClicked: st.backRequested()
            }
        }

        // filename ---------------------------------------------------------
        Row {
            spacing: Theme.spaceMd
            width: parent.width

            Text { text: "Filename"; color: Theme.foreground; font.pixelSize: Theme.fontXs + 1; anchors.verticalCenter: parent.verticalCenter }

            Rectangle {
                width: 190
                height: 22
                radius: Theme.radiusXs
                color: Theme.surface
                anchors.verticalCenter: parent.verticalCenter

                TextInput {
                    anchors.fill: parent
                    anchors.leftMargin: Theme.spaceXs + 2
                    anchors.rightMargin: Theme.spaceXs + 2
                    text: SettingsData.recFilename
                    color: Theme.foreground
                    font.pixelSize: Theme.fontXs + 1
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    onTextChanged: if (text.trim() !== "") SettingsData.recFilename = text.replace(/[^\w-]/g, "")
                }
            }

            Text { text: "→ ~/Videos/harmonica"; color: Theme.outline; font.pixelSize: Theme.fontXs; anchors.verticalCenter: parent.verticalCenter }
        }

        // format -----------------------------------------------------------
        Row {
            spacing: Theme.spaceMd

            Text { text: "Format"; color: Theme.foreground; font.pixelSize: Theme.fontXs + 1; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: ["mp4", "mkv"]

                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    property bool on: SettingsData.recExt === modelData
                    width: segText.implicitWidth + Theme.spaceMd * 2
                    height: 20
                    radius: Theme.radiusFull
                    color: on ? Theme.primary : Theme.surface
                    Text {
                        id: segText
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: parent.on ? Theme.background : Theme.dimText
                        font.pixelSize: Theme.fontXs
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsData.recExt = parent.modelData
                    }
                }
            }
        }

        // quality ------------------------------------------------------------
        Row {
            spacing: Theme.spaceMd

            Text { text: "Quality"; color: Theme.foreground; font.pixelSize: Theme.fontXs + 1; anchors.verticalCenter: parent.verticalCenter }
            Repeater {
                model: ["low", "medium", "high"]

                delegate: Rectangle {
                    required property string modelData
                    required property int index
                    property bool on: SettingsData.recQuality === modelData
                    width: qText.implicitWidth + Theme.spaceMd * 2
                    height: 20
                    radius: Theme.radiusFull
                    color: on ? Theme.primary : Theme.surface
                    Text {
                        id: qText
                        anchors.centerIn: parent
                        text: parent.modelData
                        color: parent.on ? Theme.background : Theme.dimText
                        font.pixelSize: Theme.fontXs
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: SettingsData.recQuality = parent.modelData
                    }
                }
            }
        }

        // audio --------------------------------------------------------------
        Column {
            spacing: 4
            width: parent.width

            Row {
                spacing: Theme.spaceMd
                Text { text: "Audio"; color: Theme.foreground; font.pixelSize: Theme.fontXs + 1 }
                Text { text: "(single capture source)"; color: Theme.outline; font.pixelSize: Theme.fontXs; anchors.verticalCenter: parent.verticalCenter }
            }

            Flow {
                width: parent.width
                spacing: Theme.spaceSm

                // "none" chip
                Rectangle {
                    property bool on: SettingsData.recAudioSource === ""
                    width: noneTxt.implicitWidth + Theme.spaceMd * 2
                    height: 20
                    radius: Theme.radiusFull
                    color: on ? Theme.danger : Theme.surface
                    Text { id: noneTxt; anchors.centerIn: parent; text: "none"; color: parent.on ? Theme.background : Theme.dimText; font.pixelSize: Theme.fontXs }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: SettingsData.recAudioSource = "" }
                }

                Repeater {
                    model: Recorder.audioSources

                    delegate: Rectangle {
                        required property var modelData
                        property bool on: SettingsData.recAudioSource === modelData.name
                        width: aTxt.implicitWidth + Theme.spaceMd * 2
                        height: 20
                        radius: Theme.radiusFull
                        color: on ? Theme.success : Theme.surface
                        Text {
                            id: aTxt
                            anchors.centerIn: parent
                            text: modelData.desc !== "" ? modelData.desc : modelData.name
                            color: parent.on ? Theme.background : Theme.dimText
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideMiddle
                            width: Math.min(implicitWidth, 180)
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: SettingsData.recAudioSource = parent.modelData.name
                        }
                    }
                }
            }
        }

        Item { height: 1; width: 1 }

        // start / stop -------------------------------------------------------
        Row {
            spacing: Theme.spaceSm
            anchors.horizontalCenter: parent.horizontalCenter

            Buttonish {
                label: Recorder.active ? "Stop" : "Start"
                accent: !Recorder.active
                danger: Recorder.active
                onClicked: {
                    if (Recorder.active) Recorder.stop();
                    else Recorder.start();
                    st.backRequested();
                }
            }
        }
    }
}
