import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// LEFT page — Control Center:
// Date/Time widget · Bento quick toggles · Volume & Brightness sliders · Session actions
Item {
    id: page

    property bool dndActive: false
    property bool nightLight: false

    property var now: new Date()

    Timer {
        interval: 1000
        running: page.visible
        repeat: true
        onTriggered: page.now = new Date()
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
        anchors.leftMargin: Theme.spaceXl + 4
        anchors.rightMargin: Theme.spaceXl + 4
        anchors.topMargin: Theme.spaceMd - 2
        anchors.bottomMargin: Theme.spaceLg - 2
        spacing: Theme.spaceSm + 2

        // Header: Title + Session Action buttons ----------------------------
        RowLayout {
            Layout.fillWidth: true

            Text {
                text: "CONTROL CENTER"
                color: Theme.dimText
                font.pixelSize: Theme.fontXs - 1
                font.weight: Font.Bold
                font.letterSpacing: 2
                Layout.fillWidth: true
            }

            Row {
                spacing: Theme.spaceXs

                IconButton {
                    category: "actions"
                    iconName: "refresh"
                    iconSize: 13
                    pad: 3
                    onClicked: Quickshell.execDetached(["sh", "-c", "loginctl lock-session 2>/dev/null || hyprlock 2>/dev/null"])
                }

                IconButton {
                    category: "actions"
                    iconName: "close"
                    iconSize: 13
                    pad: 3
                    onClicked: Quickshell.execDetached(["sh", "-c", "systemctl poweroff 2>/dev/null || loginctl poweroff 2>/dev/null"])
                }
            }
        }

        // Date & Time Card ---------------------------------------------------
        Rectangle {
            Layout.fillWidth: true
            height: 64
            radius: Theme.radiusMd
            color: Theme.surface

            ColumnLayout {
                anchors.centerIn: parent
                spacing: 2

                Text {
                    text: formatTime()
                    color: Theme.foreground
                    font.pixelSize: Theme.fontLg + 6
                    font.weight: Font.Bold
                    font.family: "monospace"
                    Layout.alignment: Qt.AlignHCenter
                }

                Text {
                    text: formatDate()
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    font.weight: Font.Medium
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // Subtle animated gradient border
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.2)
            }
        }

        // 2x2 Bento Quick Toggles ------------------------------------------
        Grid {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: Theme.spaceSm + 2
            rowSpacing: Theme.spaceSm

            readonly property real itemW: (parent.width - columnSpacing) / 2

            // Wi-Fi Pill
            QuickPill {
                width: parent.itemW
                category: "status"
                iconName: Network.state === "wifi" ? "wifi" : "wifi-off"
                label: "Wi-Fi"
                statusText: Network.state === "wifi" ? (Network.ssid || "Connected") : "Disconnected"
                active: Network.state === "wifi"
                activeColor: Theme.primary
                onClicked: {
                    const next = Network.state === "disconnected" ? "on" : "off";
                    Quickshell.execDetached(["nmcli", "radio", "wifi", next]);
                }
            }

            // Bluetooth Pill
            QuickPill {
                width: parent.itemW
                category: "status"
                iconName: "bluetooth"
                label: "Bluetooth"
                statusText: BluetoothService.powered ? (BluetoothService.deviceName || "On") : "Off"
                active: BluetoothService.powered
                activeColor: Theme.colorNet
                onClicked: BluetoothService.togglePower()
            }

            // DND Pill
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

            // Airplane Mode Pill
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

        // Sliders Section --------------------------------------------------
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs + 2

            // Volume Slider
            Slider {
                Layout.fillWidth: true
                category: "media"
                iconName: AudioService.muted ? "pause" : "music-note"
                value: AudioService.volume
                activeColor: Theme.primary
                onMoved: val => AudioService.setVolume(val)
            }

            // Brightness Slider
            Slider {
                Layout.fillWidth: true
                category: "system"
                iconName: "temperature"
                value: BrightnessService.percent
                activeColor: Theme.warn
                onMoved: val => BrightnessService.setPercent(val)
            }
        }

        Item { Layout.fillHeight: true }

        // Quick Actions Row ------------------------------------------------
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.spaceXs

            IconButton {
                category: "system"
                iconName: "gear"
                iconSize: 14
                pad: Theme.spaceXs
                onClicked: Quickshell.execDetached(["sh", "-c", "hyprctl dispatch exec hyprland-settings || systemsettings"])
            }

            IconButton {
                category: "status"
                iconName: "wifi"
                iconSize: 14
                pad: Theme.spaceXs
                onClicked: Quickshell.execDetached(["sh", "-c", "nm-connection-editor || nmtui"])
            }

            Item { Layout.fillWidth: true }

            Text {
                text: "Quick Actions"
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                Layout.alignment: Qt.AlignVCenter
            }
        }
    }
}
