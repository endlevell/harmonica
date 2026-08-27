import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// IDLE row — mathematically centered clock, distinct left/right zones:
//   wifi (left) · clock (exact center) · battery (right)
Item {
    id: bar

    readonly property int leftW: netIcon.width
    readonly property int rightW: battRow.implicitWidth
    readonly property int sidePad: Theme.spaceMd + 2
    readonly property int maxSideW: Math.max(leftW, rightW)
    readonly property int zoneGap: Theme.spaceLg + 2

    // Symmetrical pill width so clockLbl is at the dead center of the capsule
    readonly property int contentWidth: (maxSideW + zoneGap + sidePad) * 2 + clockLbl.implicitWidth

    // charging battery pulses between two pywal colors (gold ↔ foreground)
    property real chargeBlend: 0
    readonly property color battTint: Battery.charging
        ? Theme.mix(Theme.primary, Theme.foreground, chargeBlend)
        : !Battery.present ? Theme.dimText
        : Battery.percentage <= 25 ? Theme.danger
        : Battery.percentage <= 75 ? Theme.warn
        : Theme.colorOk

    // Idle bar permanently shows network state — register as a consumer
    // so the service polls from boot, not just when SystemPage mounts.
    Component.onCompleted: Network.acquire()
    Component.onDestruction: Network.release()

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

    // LEFT — network -------------------------------------------------------
    Icon {
        id: netIcon
        category: "status"
        name: Network.state === "ethernet" ? "ethernet" : Network.state === "wifi" ? "wifi" : "wifi-off"
        size: 15
        color: Network.state === "disconnected" ? Theme.dimText : Theme.colorNet
        anchors.left: parent.left
        anchors.leftMargin: bar.sidePad
        anchors.verticalCenter: parent.verticalCenter
    }

    // CENTER — clock (exact center of the pill) ------------------------------
    Text {
        id: clockLbl
        text: Qt.formatDateTime(bar.now, SettingsData.showSeconds ? "HH:mm:ss" : "HH:mm")
        color: Theme.foreground
        font.pixelSize: Theme.fontSm + 1
        font.weight: Font.DemiBold
        font.family: "monospace"
        anchors.centerIn: parent
    }

    // RIGHT — battery --------------------------------------------------------
    Row {
        id: battRow
        spacing: 3
        anchors.right: parent.right
        anchors.rightMargin: bar.sidePad
        anchors.verticalCenter: parent.verticalCenter

        Text {
            visible: Battery.present
            text: Battery.percentage + "%"
            color: Theme.dimText
            font.pixelSize: Theme.fontXs - 1
            font.weight: Font.Normal
            anchors.verticalCenter: parent.verticalCenter
        }

        Icon {
            category: "status"
            name: Battery.iconName
            size: 15
            color: bar.battTint
            anchors.verticalCenter: parent.verticalCenter

            Behavior on color { ColorAnimation { duration: Theme.durNormal } }
        }
    }
}
