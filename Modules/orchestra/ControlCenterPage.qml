import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// Control Center with modern flat design + live interactive components
Item {
    id: page

    property bool dndActive: false
    property bool nightLight: false
    property var now: new Date()
    // volume + bluetooth pollers run only while this page is mounted
    Component.onCompleted: { AudioService.acquire(); BluetoothService.acquire(); }
    Component.onDestruction: { AudioService.release(); BluetoothService.release(); }

    // Live network speed tracking for sparkline
    property var downHistory: []
    property var upHistory: []
    readonly property int historyLen: 20

    Timer {
        interval: 1000
        running: page.visible
        repeat: true
        onTriggered: {
            page.now = new Date();
            
            // Update network sparklines
            const down = Network.downKBs / 1024;  // Convert to MB/s
            const up = Network.upKBs / 1024;
            
            page.downHistory.push(Math.min(1, down / 10));  // Normalize to 0-1 (10MB/s = 1.0)
            page.upHistory.push(Math.min(1, up / 10));
            
            if (page.downHistory.length > historyLen) page.downHistory.shift();
            if (page.upHistory.length > historyLen) page.upHistory.shift();
        }
    }

    function formatDate(): string {
        const days = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
        const months = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"];
        return days[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate();
    }

    function formatTime(): string {
        const h = now.getHours();
        const m = now.getMinutes();
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceLg
        anchors.rightMargin: Theme.spaceLg
        anchors.topMargin: Theme.spaceSm
        anchors.bottomMargin: Theme.spaceMd
        spacing: Theme.spaceSm

        // Header: live clock + date · session actions
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceMd

            ColumnLayout {
                spacing: 0

                Text {
                    text: formatTime()
                    color: Theme.foreground
                    font.pixelSize: Theme.fontXl
                    font.weight: Font.Bold
                    font.letterSpacing: -1
                }
                Text {
                    text: formatDate()
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    font.weight: Font.Medium
                }
            }

            Item { Layout.fillWidth: true }

            IconButton {
                category: "actions"
                iconName: "refresh"
                iconSize: 15
                pad: Theme.spaceSm
                onClicked: Quickshell.execDetached(["sh", "-c", "loginctl lock-session 2>/dev/null || hyprlock 2>/dev/null"])
            }
            IconButton {
                category: "actions"
                iconName: "power"
                iconSize: 15
                pad: Theme.spaceSm
                iconColor: Theme.danger
                onClicked: Quickshell.execDetached(["sh", "-c", "systemctl poweroff 2>/dev/null || loginctl poweroff 2>/dev/null"])
            }
        }

        // Live Stats Row — Battery + Network speeds with sparklines
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceSm

            // Battery Card
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: Theme.radiusSm
                color: Theme.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceSm

                    Icon {
                        category: "status"
                        name: Battery.iconName
                        size: 16
                        color: Battery.percentage / 100 > 20 ? Theme.colorOk : Theme.danger
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        Text {
                            text: Math.round(Battery.percentage / 100 * 100) + "%"
                            color: Theme.foreground
                            font.pixelSize: Theme.fontSm
                            font.weight: Font.Bold
                        }
                        Text {
                            text: Battery.charging ? "Charging" : "Battery"
                            color: Theme.dimText
                            font.pixelSize: 9
                        }
                    }

                    // Battery level indicator — mini gauge or charging pulse
                    Item {
                        width: 20
                        height: 20

                        // Charging pulse (only when charging)
                        Rectangle {
                            visible: Battery.charging
                            anchors.centerIn: parent
                            width: 6
                            height: 6
                            radius: 3
                            color: Theme.colorOk
                            
                            SequentialAnimation on opacity {
                                running: Battery.charging
                                loops: Animation.Infinite
                                NumberAnimation { from: 1.0; to: 0.3; duration: 800 }
                                NumberAnimation { from: 0.3; to: 1.0; duration: 800 }
                            }
                        }

                        // Mini circular gauge (when not charging)
                        CircularGauge {
                            visible: !Battery.charging
                            anchors.fill: parent
                            value: Battery.percentage / 100
                            gaugeColor: Battery.percentage / 100 > 0.2 ? Theme.colorOk : Theme.danger
                            trackColor: Qt.rgba(0, 0, 0, 0.1)
                            lineWidth: 2
                            valueText: ""
                            label: ""
                        }
                    }
                }
            }

            // Network Down Speed with sparkline
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: Theme.radiusSm
                color: Theme.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceSm

                    Icon {
                        category: "status"
                        name: "wifi"
                        size: 14
                        color: Theme.colorOk
                        rotation: 180  // Point down
                    }

                    ColumnLayout {
                        spacing: 0

                        Text {
                            text: (Network.downKBs / 1024).toFixed(1) + " MB/s"
                            color: Theme.foreground
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.Bold
                            font.family: "monospace"
                        }
                        Text {
                            text: "Download"
                            color: Theme.dimText
                            font.pixelSize: 8
                        }
                    }

                    Sparkline {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 16
                        dataPoints: page.downHistory
                        lineColor: Theme.colorOk
                    }
                }
            }

            // Network Up Speed with sparkline
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                radius: Theme.radiusSm
                color: Theme.surface

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Theme.spaceSm
                    spacing: Theme.spaceSm

                    Icon {
                        category: "status"
                        name: "wifi"
                        size: 14
                        color: Theme.warn
                    }

                    ColumnLayout {
                        spacing: 0

                        Text {
                            text: (Network.upKBs / 1024).toFixed(1) + " MB/s"
                            color: Theme.foreground
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.Bold
                            font.family: "monospace"
                        }
                        Text {
                            text: "Upload"
                            color: Theme.dimText
                            font.pixelSize: 8
                        }
                    }

                    Sparkline {
                        Layout.preferredWidth: 40
                        Layout.preferredHeight: 16
                        dataPoints: page.upHistory
                        lineColor: Theme.warn
                    }
                }
            }
        }

        // 2x2 Bento Quick Toggles
        Grid {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spaceXs + 2
            rowSpacing: Theme.spaceXs + 2

            readonly property real itemW: (parent.width - columnSpacing) / 2

            QuickPill {
                width: parent.itemW
                category: "status"
                iconName: Network.state === "wifi" ? "wifi" : "wifi-off"
                label: "Wi-Fi"
                statusText: Network.state === "wifi" ? (Network.ssid || "Connected") : "Disconnected"
                active: Network.state === "wifi"
                activeColor: Theme.primary
                onClicked: win.openWifi()
            }

            QuickPill {
                width: parent.itemW
                category: "status"
                iconName: "bluetooth"
                label: "Bluetooth"
                statusText: BluetoothService.powered ? (BluetoothService.deviceName || "On") : "Off"
                active: BluetoothService.powered
                activeColor: Theme.colorNet
                onClicked: win.openBluetooth()
            }

            QuickPill {
                width: parent.itemW
                category: "system"
                iconName: "gear"
                label: "Do Not Disturb"
                statusText: page.dndActive ? "Muted" : "Off"
                active: page.dndActive
                activeColor: Theme.warn
                onClicked: page.dndActive = !page.dndActive
            }

            QuickPill {
                width: parent.itemW
                category: "status"
                iconName: "airplane"
                label: "Airplane Mode"
                statusText: "Off"
                active: false
                activeColor: Theme.danger
                onClicked: Quickshell.execDetached(["rfkill", "toggle", "all"])
            }
        }

        // Sliders Section
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                category: "media"
                iconName: AudioService.muted ? "pause" : "music-note"
                value: AudioService.volume
                activeColor: Theme.primary
                onMoved: val => AudioService.setVolume(val)
            }

            Slider {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                category: "status"
                iconName: "brightness"
                value: BrightnessService.percent
                activeColor: Theme.warn
                onMoved: val => BrightnessService.setPercent(val)
            }
        }
    }
}
