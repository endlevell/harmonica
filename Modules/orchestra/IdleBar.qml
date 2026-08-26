import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// IDLE row — three discrete zones laid out in a single Row:
//   [left pad] wifi [spacer] clock [spacer] battery [right pad]
// Layout guarantees the three zones NEVER collide, regardless of text width.
Item {
    id: bar

    readonly property int sidePad: Theme.spaceMd + 2
    readonly property int zoneGap: Theme.spaceXl + 4
    readonly property int contentWidth: sidePad * 2
        + netIcon.width + zoneGap + clockLbl.implicitWidth + zoneGap + battRow.implicitWidth

    // charging battery pulses between two pywal colors (gold ↔ foreground)
    property real chargeBlend: 0
    readonly property color battTint: Battery.charging
        ? Theme.mix(Theme.primary, Theme.foreground, chargeBlend)
        : !Battery.present ? Theme.dimText
        : Battery.percentage <= 25 ? Theme.danger
        : Battery.percentage <= 75 ? Theme.warn
        : Theme.colorOk

    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: bar.now = new Date()
    }
    property date now: new Date()

    SequentialAnimation on chargeBlend {
        running: Battery.charging && bar.visible
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 800; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 800; easing.type: Easing.InOutSine }
    }

    Row {
        anchors.centerIn: parent
        spacing: 0

        // LEFT — network (pywal cyan/bright accent) ------------------------
        Icon {
            id: netIcon
            category: "status"
            name: Network.state === "ethernet" ? "ethernet" : Network.state === "wifi" ? "wifi" : "wifi-off"
            size: 16
            color: Network.state === "disconnected" ? Theme.dimText : Theme.colorNet
            anchors.verticalCenter: parent.verticalCenter
        }

        Item { width: bar.zoneGap; height: 1 }

        // CENTER — clock (fontLg semibold) -----------------------------------
        Text {
            id: clockLbl
            text: Qt.formatDateTime(bar.now, SettingsData.showSeconds ? "HH:mm:ss" : "HH:mm")
            color: Theme.foreground
            font.pixelSize: Theme.fontLg - 3
            font.weight: Font.DemiBold
            font.family: "monospace"
            anchors.verticalCenter: parent.verticalCenter
        }

        Item { width: bar.zoneGap; height: 1 }

        // RIGHT — battery % (fontSm dim) + icon (state-tinted) ---------------
        Row {
            id: battRow
            spacing: Theme.spaceXs + 2
            anchors.verticalCenter: parent.verticalCenter

            Text {
                visible: Battery.present
                text: Battery.percentage + "%"
                color: Theme.dimText
                font.pixelSize: Theme.fontXs + 1
                font.weight: Font.Normal
                anchors.verticalCenter: parent.verticalCenter
            }

            Icon {
                category: "status"
                name: Battery.iconName
                size: 16
                color: bar.battTint
                anchors.verticalCenter: parent.verticalCenter

                Behavior on color { ColorAnimation { duration: Theme.durNormal } }
            }
        }
    }
}
