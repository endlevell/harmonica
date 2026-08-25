import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// IDLE row: network icon · clock · battery.
Item {
    id: bar

    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: bar.now = new Date()
    }
    property date now: new Date()

    Icon {
        id: netIcon
        category: "status"
        name: Network.state === "ethernet" ? "ethernet" : Network.state === "wifi" ? "wifi" : "wifi-off"
        size: 15
        color: Network.state === "disconnected" ? Theme.dimText : Theme.foreground
        anchors.left: parent.left
        anchors.leftMargin: Theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter
    }

    Text {
        text: Qt.formatDateTime(bar.now, SettingsData.showSeconds ? "HH:mm:ss" : "HH:mm")
        color: Theme.foreground
        font.pixelSize: Theme.fontSm
        font.weight: Font.DemiBold
        font.family: "monospace"
        anchors.centerIn: parent
    }

    Row {
        spacing: Theme.spaceXs
        anchors.right: parent.right
        anchors.rightMargin: Theme.spaceMd
        anchors.verticalCenter: parent.verticalCenter

        Text {
            visible: Battery.present
            text: Battery.percentage + "%"
            color: Battery.charging ? Theme.primary : (Battery.percentage <= 20 ? Theme.danger : Theme.dimText)
            font.pixelSize: Theme.fontXs
            anchors.verticalCenter: parent.verticalCenter
        }

        Icon {
            category: "status"
            name: Battery.iconName
            size: 15
            color: Battery.charging ? Theme.primary : (Battery.present && Battery.percentage <= 20 ? Theme.danger : Theme.foreground)
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
