import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// RECORD SETTINGS: full recorder setup inside the island. Rows stagger in
// one after another; content taller than the view scrolls (old shell panel).
Item {
    id: st

    signal backRequested()
    property int settingsStage: 0
    readonly property int maxStage: 20

    function grabFocus(): void { Recorder.refreshAudioDevices(); }

    onEnabledChanged: {
        if (enabled) {
            settingsStage = 0;
            stagger.restart();
            Recorder.refreshAudioDevices();
        } else {
            stagger.stop();
        }
    }

    Timer {
        id: stagger
        interval: Theme.recStaggerMs
        repeat: true
        onTriggered: {
            if (st.settingsStage >= st.maxStage) stop();
            else st.settingsStage++;
        }
    }

    // ---- row primitives (stagger = index into the entrance order) ----
    component SectionLabel: Text {
        property int order: 0
        color: Theme.dimText
        font.pixelSize: Theme.fontXs
        font.letterSpacing: 2
        opacity: st.settingsStage > order ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.durFast; easing.type: Easing.OutCubic } }
    }

    component StaggerBox: Item {
        property int order: 0
        opacity: st.settingsStage > order ? 1 : 0
        y: st.settingsStage > order ? 0 : 10
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.durFast; easing.type: Easing.OutCubic } }
        Behavior on y {
            NumberAnimation {
                duration: Theme.reducedMotion ? 0 : Theme.durNormal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeDecel
            }
        }
    }

    component SegRow: Row {
        id: segRow
        width: parent ? parent.width : 0
        property int order: 0
        property string label: ""
        property var options: []
        property string value: ""
        signal picked(string v)
        spacing: Theme.spaceSm
        StaggerBox {
            order: segRow.order
            width: segRow.width
            height: 20
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.spaceSm
                Text {
                    width: 64
                    text: segRow.label
                    color: Theme.foreground
                    font.pixelSize: Theme.fontXs + 1
                    anchors.verticalCenter: parent.verticalCenter
                }
                Repeater {
                    model: segRow.options
                    delegate: Rectangle {
                        required property string modelData
                        property bool on: segRow.value === modelData
                        width: segText.implicitWidth + Theme.spaceMd
                        height: 20
                        radius: Theme.radiusFull
                        color: on ? Theme.primary : Theme.surface
                        Text {
                            id: segText
                            anchors.centerIn: parent
                            text: modelData
                            color: parent.on ? Theme.background : Theme.dimText
                            font.pixelSize: Theme.fontXs
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: segRow.picked(parent.modelData)
                        }
                    }
                }
            }
        }
    }

    component ToggleRow: Row {
        id: togRow
        width: parent ? parent.width : 0
        property int order: 0
        property string label: ""
        property bool checked: false
        signal flipped(bool v)
        spacing: Theme.spaceSm
        StaggerBox {
            order: togRow.order
            width: togRow.width
            height: 20
            Text {
                text: togRow.label
                color: Theme.foreground
                font.pixelSize: Theme.fontXs + 1
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            Toggle {
                checked: togRow.checked
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                onToggled: togRow.flipped(checked)
            }
        }
    }

    component DeviceRow: Row {
        id: devRow
        width: parent ? parent.width : 0
        property int order: 0
        property string label: ""
        property string iconName: "volume"
        property string iconCategory: "system"
        property var devices: []
        property string selected: ""
        property bool rowEnabled: true
        signal picked(string id)
        function labelFor(id: string): string {
            if (id === "") return "Default";
            for (const d of devices) if (d.name === id) return d.desc !== "" ? d.desc : d.name;
            return id;
        }
        function step(dir: int): void {
            const ids = [""].concat(devices.map(d => d.name));
            let i = ids.indexOf(selected);
            if (i < 0) i = 0;
            picked(ids[(i + dir + ids.length) % ids.length]);
        }
        spacing: Theme.spaceSm
        opacity: rowEnabled ? 1 : 0.45
        StaggerBox {
            order: devRow.order
            width: devRow.width
            height: 22
            Icon {
                category: devRow.iconCategory
                name: devRow.iconName
                size: 14
                color: Theme.dimText
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: devRow.label
                color: Theme.foreground
                font.pixelSize: Theme.fontXs + 1
                anchors.left: parent.left
                anchors.leftMargin: 20
                anchors.verticalCenter: parent.verticalCenter
            }
            Row {
                spacing: 2
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                IconButton {
                    category: "actions"; iconName: "arrow-left"; iconSize: 11; pad: 3
                    enabled: devRow.rowEnabled
                    onClicked: devRow.step(-1)
                }
                Text {
                    width: Math.min(devLbl.implicitWidth, 170)
                    id: devLbl
                    text: devRow.labelFor(devRow.selected)
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    elide: Text.ElideMiddle
                    horizontalAlignment: Text.AlignHCenter
                }
                IconButton {
                    category: "actions"; iconName: "arrow-right"; iconSize: 11; pad: 3
                    enabled: devRow.rowEnabled
                    onClicked: devRow.step(1)
                }
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.margins: Theme.spaceMd
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: body
            width: parent.width
            spacing: Theme.spaceSm

            Text {
                text: "Screen recording"
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                font.letterSpacing: 2
            }

            SectionLabel { text: "VIDEO"; order: 1 }
            SegRow {
                order: 2; label: "Resolution"; options: ["2160p", "1440p", "1080p", "720p"]
                value: SettingsData.recResolution; onPicked: v => SettingsData.recResolution = v
            }
            SegRow {
                order: 3; label: "FPS"; options: ["24", "30", "60", "120"]
                value: String(SettingsData.recFps); onPicked: v => SettingsData.recFps = Number(v)
            }
            SegRow {
                order: 4; label: "Format"; options: ["mkv", "mp4", "mov", "flv", "webm"]
                value: SettingsData.recExt; onPicked: v => SettingsData.recExt = v
            }

            SectionLabel { text: "CODEC"; order: 5 }
            SegRow {
                order: 6; label: "Video"; options: ["h264", "hevc", "av1", "vp9"]
                value: SettingsData.recVideoCodec; onPicked: v => SettingsData.recVideoCodec = v
            }
            SegRow {
                order: 7; label: "Audio"; options: ["aac", "opus", "flac"]
                value: SettingsData.recAudioCodec; onPicked: v => SettingsData.recAudioCodec = v
            }
            SegRow {
                order: 8; label: "Quality"; options: ["Low", "Medium", "High", "Lossless"]
                value: SettingsData.recQuality.charAt(0).toUpperCase() + SettingsData.recQuality.slice(1)
                onPicked: v => SettingsData.recQuality = v.toLowerCase()
            }

            SectionLabel { text: "CAPTURE"; order: 9 }
            SegRow {
                order: 10; label: "Target"; options: ["screen", "window"]
                value: SettingsData.recTarget; onPicked: v => SettingsData.recTarget = v
            }
            ToggleRow {
                order: 11; label: "System audio"; checked: SettingsData.recCaptureAudio
                onFlipped: v => SettingsData.recCaptureAudio = v
            }
            ToggleRow {
                order: 12; label: "Microphone"; checked: SettingsData.recCaptureMic
                onFlipped: v => SettingsData.recCaptureMic = v
            }
            ToggleRow {
                order: 13; label: "Show cursor"; checked: SettingsData.recShowCursor
                onFlipped: v => SettingsData.recShowCursor = v
            }
            DeviceRow {
                order: 14; label: "Output"; iconName: "volume"; iconCategory: "system"
                devices: Recorder.sinks; selected: SettingsData.recOutputDevice
                rowEnabled: SettingsData.recCaptureAudio
                onPicked: id => SettingsData.recOutputDevice = id
            }
            DeviceRow {
                order: 15; label: "Input"; iconName: "mic"; iconCategory: "system"
                devices: Recorder.sources; selected: SettingsData.recInputDevice
                rowEnabled: SettingsData.recCaptureMic
                onPicked: id => SettingsData.recInputDevice = id
            }

            SectionLabel { text: "OUTPUT"; order: 16 }
            StaggerBox {
                order: 17
                width: parent.width
                height: 22
                IconButton {
                    category: "system"; iconName: "folder"; iconSize: 13; pad: 4
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: Recorder.chooseSaveDir()
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 30
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: SettingsData.recOutDir
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    font.family: "monospace"
                    elide: Text.ElideMiddle
                }
            }
            Text {
                visible: Recorder.lastError !== ""
                text: Recorder.lastError
                color: Theme.danger
                font.pixelSize: Theme.fontXs
                width: parent.width
                wrapMode: Text.WordWrap
            }
            StaggerBox {
                order: 18
                width: parent.width
                height: 22
                Text {
                    text: "Filename"
                    color: Theme.foreground
                    font.pixelSize: Theme.fontXs + 1
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                }
                Rectangle {
                    width: 250
                    height: 22
                    radius: Theme.radiusXs
                    color: Theme.surface
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    TextInput {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceXs + 2
                        anchors.rightMargin: Theme.spaceXs + 2
                        text: SettingsData.recFilenameFormat
                        color: Theme.foreground
                        font.pixelSize: Theme.fontXs + 1
                        font.family: "monospace"
                        clip: true
                        verticalAlignment: TextInput.AlignVCenter
                        onTextChanged: if (text.trim() !== "") SettingsData.recFilenameFormat = text
                    }
                }
            }

            SectionLabel { text: "INTERFACE"; order: 19 }
            ToggleRow {
                order: 19; label: "Reduce motion"; checked: SettingsData.reduceMotion
                onFlipped: v => SettingsData.reduceMotion = v
            }

            StaggerBox {
                order: 20
                width: parent.width
                height: 30
                Row {
                    spacing: Theme.spaceSm
                    anchors.centerIn: parent
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
                    Buttonish {
                        label: "Back"
                        onClicked: st.backRequested()
                    }
                }
            }
        }
    }

    // header close sits above the scroll area
    IconButton {
        category: "actions"
        iconName: "close"
        iconSize: 13
        pad: 4
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceSm
        onClicked: st.backRequested()
    }
}
