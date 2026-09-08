import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

// Bluetooth drill-down (island big card): power switch, discovery status,
// device rows with pair/connect/disconnect/forget. BlueZ via Quickshell,
// no bluetoothctl needed. Esc backs out.
Item {
    id: bm

    signal backRequested()

    property bool acquired: false

    function grabFocus(): void {
        if (!acquired) { acquired = true; BluetoothService.acquire(); }
    }
    function releaseView(): void {
        if (acquired) { acquired = false; BluetoothService.release(); }
    }

    Shortcut {
        sequence: "D"
        enabled: bm.enabled
        onActivated: BluetoothService.setDiscovering(!BluetoothService.discovering)
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spaceMd
        spacing: Theme.spaceSm

        // header ------------------------------------------------------
        Row {
            width: parent.width
            height: 36
            spacing: Theme.spaceSm

            IconButton {
                category: "actions"; iconName: "arrow-left"; iconSize: 13; pad: 4
                anchors.verticalCenter: parent.verticalCenter
                onClicked: bm.backRequested()
            }
            Column {
                id: titleCol
                spacing: 0
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: "Bluetooth"
                    color: Theme.foreground
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.Bold
                }
                Text {
                    text: !BluetoothService.present ? "No adapter"
                        : !BluetoothService.powered ? "Off"
                        : (BluetoothService.deviceName !== "" ? BluetoothService.deviceName : "On")
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    font.family: "monospace"
                }
            }
            Item {
                width: Math.max(0, parent.width - 21 - titleCol.implicitWidth - 52 - 30 - Theme.spaceSm * 4)
                height: 1
            }
            Text {
                text: "POWER"
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                anchors.verticalCenter: parent.verticalCenter
            }
            Toggle {
                checked: BluetoothService.powered
                enabled: BluetoothService.present
                anchors.verticalCenter: parent.verticalCenter
                onToggled: BluetoothService.togglePower()
            }
        }

        // status row ---------------------------------------------------
        Item {
            width: parent.width
            height: 20

            Row {
                spacing: Theme.spaceSm
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                Rectangle {
                    width: 7
                    height: 7
                    radius: Theme.radiusFull
                    color: BluetoothService.discovering ? Theme.colorNet : Theme.dimText
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        running: BluetoothService.discovering
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: !BluetoothService.present ? "No adapter found"
                        : !BluetoothService.powered ? "Radio off"
                        : BluetoothService.discovering ? "Scanning…" : "Idle"
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                text: BluetoothService.deviceCount + " DEVICES NEARBY"
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // device list --------------------------------------------------
        Flickable {
            width: parent.width
            height: parent.height - 36 - 20 - 24 - Theme.spaceMd * 2 - Theme.spaceSm * 3
            contentWidth: width
            contentHeight: btCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            opacity: BluetoothService.powered ? 1 : 0.45

            Column {
                id: btCol
                width: parent.width
                spacing: Theme.spaceXs

                Text {
                    visible: !BluetoothService.present
                    width: parent.width
                    text: "No Bluetooth adapter found on this machine."
                    color: Theme.dimText
                    font.pixelSize: Theme.fontSm
                    horizontalAlignment: Text.AlignHCenter
                }
                Text {
                    visible: BluetoothService.present && BluetoothService.deviceCount === 0
                    width: parent.width
                    text: BluetoothService.powered ? "No devices nearby — put one in pairing mode." : "Turn on power to scan."
                    color: Theme.dimText
                    font.pixelSize: Theme.fontSm
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                }

                Repeater {
                    model: BluetoothService.devices
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        property bool isConn: modelData.connected
                        property bool isBusy: modelData.pairing

                        width: btCol.width
                        height: 52
                        radius: Theme.radiusSm
                        color: hoverRow.containsMouse ? Theme.surfaceHover : Theme.surface
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }

                        Rectangle {
                            visible: isConn
                            width: 3
                            height: parent.height - Theme.spaceSm * 2
                            radius: 2
                            color: Theme.primary
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spaceXs
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: Theme.spaceSm + 5
                            anchors.rightMargin: Theme.spaceSm
                            spacing: Theme.spaceSm

                            Icon {
                                category: BluetoothService.glyphCat(modelData.icon)
                                name: BluetoothService.glyphFor(modelData.icon)
                                size: 15
                                color: isConn ? Theme.colorNet : Theme.dimText
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            Column {
                                width: parent.width - 15 - 150 - Theme.spaceSm * 2
                                spacing: 0
                                anchors.verticalCenter: parent.verticalCenter
                                Row {
                                    spacing: Theme.spaceXs
                                    Text {
                                        text: modelData.name || modelData.deviceName || modelData.address
                                        color: Theme.foreground
                                        font.pixelSize: Theme.fontSm
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, 150)
                                    }
                                    Rectangle {
                                        visible: isConn
                                        width: 6
                                        height: 6
                                        radius: 3
                                        color: Theme.colorOk
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                                Text {
                                    text: isConn ? "Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")
                                        : modelData.paired ? "Paired" : "Not paired"
                                    color: Theme.dimText
                                    font.pixelSize: Theme.fontXs
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                            Item {
                                width: 150
                                height: 22
                                anchors.verticalCenter: parent.verticalCenter
                                RowLayout {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    Text {
                                        visible: isConn && !hoverRow.containsMouse
                                        text: "Connected"
                                        color: Theme.colorOk
                                        font.pixelSize: Theme.fontXs
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Buttonish {
                                        visible: isConn && hoverRow.containsMouse
                                        label: "Disconnect"
                                        Layout.alignment: Qt.AlignVCenter
                                        onClicked: BluetoothService.disconnect(modelData.address)
                                    }
                                    Buttonish {
                                        visible: (isConn || modelData.paired) && hoverRow.containsMouse
                                        label: "Forget"
                                        danger: true
                                        Layout.alignment: Qt.AlignVCenter
                                        onClicked: BluetoothService.forget(modelData.address)
                                    }
                                    Rectangle {
                                        visible: isBusy
                                        Layout.preferredWidth: 12
                                        Layout.preferredHeight: 12
                                        Layout.alignment: Qt.AlignVCenter
                                        radius: 6
                                        color: Theme.primary
                                        SequentialAnimation on opacity {
                                            running: isBusy
                                            loops: Animation.Infinite
                                            NumberAnimation { to: 0.25; duration: 450; easing.type: Easing.InOutSine }
                                            NumberAnimation { to: 1.0; duration: 450; easing.type: Easing.InOutSine }
                                        }
                                    }
                                    Text {
                                        visible: !isConn && !isBusy && !modelData.paired
                                        text: "Pair"
                                        color: hoverRow.containsMouse ? Theme.foreground : Theme.dimText
                                        font.pixelSize: Theme.fontXs
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Text {
                                        visible: !isConn && !isBusy && modelData.paired
                                        text: "Connect"
                                        color: hoverRow.containsMouse ? Theme.foreground : Theme.dimText
                                        font.pixelSize: Theme.fontXs
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }
                            }
                        }

                        HoverHandler { id: hoverRow }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: BluetoothService.powered && !isBusy
                            onClicked: {
                                if (isConn) return;
                                if (modelData.paired) BluetoothService.connect(modelData.address);
                                else BluetoothService.pair(modelData.address);
                            }
                        }
                    }
                }
            }
        }

        // footer -----------------------------------------------------
        Item {
            width: parent.width
            height: 22
            Row {
                spacing: Theme.spaceSm
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: "DISCOVERABLE"
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    anchors.verticalCenter: parent.verticalCenter
                }
                Toggle {
                    checked: BluetoothService.present && BluetoothService.adapter.discoverable
                    enabled: BluetoothService.present && BluetoothService.powered
                    anchors.verticalCenter: parent.verticalCenter
                    onToggled: BluetoothService.setDiscovering(checked)
                }
            }
            Text {
                text: BluetoothService.present ? (BluetoothService.adapter.name || "adapter") : "no adapter"
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                font.family: "monospace"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
