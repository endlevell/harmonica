import QtQuick
import QtQuick.Layouts
import qs.Common
import qs.Services
import qs.Widgets

// Wi-Fi drill-down (island big card): radio switch, scan status, network
// rows with inline WPA expansion, hidden join, telemetry footer.
// Opened from the Wi-Fi pill or SUPER+W; Esc backs out (form first).
Item {
    id: wm

    signal backRequested()

    property string expandedSsid: ""    // row with open password form, "@hidden" for join form
    property bool showPass: false
    property string passText: ""
    property string joinSsid: ""
    property bool typing: false         // a text field holds focus (R shortcut guard)
    property real nowMs: 0
    property bool acquired: false

    function grabFocus(): void {
        if (!acquired) { acquired = true; Wifi.acquire(); }
        Wifi.refresh();
        Wifi.rescan();
    }
    function releaseView(): void {
        if (acquired) { acquired = false; Wifi.release(); }
        expandedSsid = "";
    }
    // Orchestra Escape chain: form first, else close the manager
    function tryEscape(): bool {
        if (expandedSsid !== "") { expandedSsid = ""; showPass = false; return true; }
        return false;
    }

    function agoText(): string {
        if (!Wifi.radio) return "Radio off";
        if (Wifi.scanning) return "Scanning…";
        if (Wifi.lastScanMs <= 0) return "Never scanned";
        const s = Math.max(0, Math.round((wm.nowMs - Wifi.lastScanMs) / 1000));
        return "Updated " + s + "s ago";
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
                onClicked: wm.backRequested()
            }
            Column {
                id: titleCol
                spacing: 0
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: "Wi-Fi"
                    color: Theme.foreground
                    font.pixelSize: Theme.fontMd
                    font.weight: Font.Bold
                }
                Text {
                    text: (Wifi.connectedSsid !== "" ? Wifi.connectedSsid : "Not connected") + (Wifi.ip !== "" ? " · " + Wifi.ip : "")
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    font.family: "monospace"
                }
            }
            Item {
                width: Math.max(0, parent.width - 21 - titleCol.implicitWidth - 46 - 30 - Theme.spaceSm * 4)
                height: 1
            }
            Text {
                text: "RADIO"
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                anchors.verticalCenter: parent.verticalCenter
            }
            Toggle {
                checked: Wifi.radio
                anchors.verticalCenter: parent.verticalCenter
                onToggled: Wifi.setRadio(checked)
            }
        }

        // status row (click = rescan) ----------------------------------
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
                    color: Wifi.scanning ? Theme.colorNet : Theme.dimText
                    anchors.verticalCenter: parent.verticalCenter
                    SequentialAnimation on opacity {
                        running: Wifi.scanning
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.25; duration: 600; easing.type: Easing.InOutSine }
                        NumberAnimation { to: 1.0; duration: 600; easing.type: Easing.InOutSine }
                    }
                }
                Text {
                    text: wm.agoText()
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text {
                text: Wifi.networks.length + " NETWORKS IN RANGE"
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                enabled: Wifi.radio
                onClicked: Wifi.rescan()
            }
        }

        // network list -------------------------------------------------
        Flickable {
            width: parent.width
            height: parent.height - 36 - 20 - 24 - Theme.spaceMd * 2 - Theme.spaceSm * 3
            contentWidth: width
            contentHeight: netCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            opacity: Wifi.radio ? 1 : 0.45

            Column {
                id: netCol
                width: parent.width
                spacing: Theme.spaceXs

                Repeater {
                    model: Wifi.networks
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        property bool isConn: modelData.inUse
                        property bool isBusy: Wifi.connecting === modelData.ssid
                        property bool expanded: wm.expandedSsid === modelData.ssid
                        property bool hasErr: Wifi.errorSsid === modelData.ssid

                        width: netCol.width
                        height: expanded ? 158 : 52
                        radius: Theme.radiusSm
                        color: hoverRow.containsMouse ? Theme.surfaceHover : Theme.surface
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                        Behavior on height {
                            NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.durNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeDecel }
                        }

                        // connected gold edge bar
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
                            id: rowLine
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.leftMargin: Theme.spaceSm + 5
                            anchors.rightMargin: Theme.spaceSm
                            anchors.topMargin: (52 - 22) / 2
                            spacing: Theme.spaceSm
                            height: 22

                            Icon {
                                category: "status"; name: "wifi"; size: 15
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
                                        text: modelData.ssid
                                        color: Theme.foreground
                                        font.pixelSize: Theme.fontSm
                                        font.weight: Font.DemiBold
                                        elide: Text.ElideRight
                                        width: Math.min(implicitWidth, 170)
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
                                    text: isConn ? "Connected · " + modelData.freq + " · " + modelData.security
                                        : modelData.security === "Open" ? "Open network" : modelData.security
                                    color: Theme.dimText
                                    font.pixelSize: Theme.fontXs
                                    elide: Text.ElideRight
                                    width: parent.width
                                }
                            }
                            Item {
                                width: 150
                                height: 22
                                RowLayout {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 4
                                    // right cluster swaps by state
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
                                        onClicked: Wifi.disconnect()
                                    }
                                    Buttonish {
                                        visible: isConn && hoverRow.containsMouse
                                        label: "Forget"
                                        danger: true
                                        Layout.alignment: Qt.AlignVCenter
                                        onClicked: Wifi.forget(modelData.ssid)
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
                                        visible: !isConn && !isBusy && modelData.security === "Open"
                                        text: "Connect"
                                        color: hoverRow.containsMouse ? Theme.foreground : Theme.dimText
                                        font.pixelSize: Theme.fontXs
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                    Icon {
                                        visible: !isConn && !isBusy && modelData.security !== "Open"
                                        category: "status"; name: "lock"; size: 12
                                        color: Theme.dimText
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }
                            }
                        }

                        // inline WPA form --------------------------------
                        Column {
                            visible: expanded
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.topMargin: 52
                            anchors.leftMargin: Theme.spaceSm + 5
                            anchors.rightMargin: Theme.spaceSm
                            spacing: 6

                            Rectangle {
                                width: parent.width
                                height: 30
                                radius: Theme.radiusXs
                                color: Theme.background
                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: Theme.spaceSm
                                    anchors.rightMargin: Theme.spaceXs
                                    spacing: Theme.spaceXs
                                    TextInput {
                                        id: passInput
                                        width: parent.width - 22 - Theme.spaceSm - Theme.spaceXs
                                        height: parent.height
                                        color: Theme.foreground
                                        font.pixelSize: Theme.fontSm
                                        font.family: "monospace"
                                        echoMode: wm.showPass ? TextInput.Normal : TextInput.Password
                                        clip: true
                                        verticalAlignment: TextInput.AlignVCenter
                                        onTextChanged: wm.passText = text
                                        onAccepted: Wifi.connect(modelData.ssid, wm.passText)
                                        onActiveFocusChanged: wm.typing = activeFocus
                                    }
                                    IconButton {
                                        category: "actions"
                                        iconName: wm.showPass ? "visibility-off" : "visibility"
                                        iconSize: 12
                                        pad: 3
                                        anchors.verticalCenter: parent.verticalCenter
                                        onClicked: wm.showPass = !wm.showPass
                                    }
                                }
                            }
                            Text {
                                visible: hasErr
                                text: Wifi.errorText
                                color: Theme.danger
                                font.pixelSize: Theme.fontXs
                                elide: Text.ElideRight
                                width: parent.width
                            }
                            Row {
                                spacing: Theme.spaceSm
                                anchors.right: parent.right
                                Buttonish {
                                    label: "Cancel"
                                    onClicked: wm.expandedSsid = ""
                                }
                                Buttonish {
                                    label: "Connect"
                                    accent: true
                                    onClicked: Wifi.connect(modelData.ssid, wm.passText)
                                }
                            }
                        }

                        HoverHandler { id: hoverRow }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            enabled: Wifi.radio && !isBusy
                            onClicked: {
                                if (isConn) return;
                                if (modelData.security === "Open") {
                                    Wifi.connect(modelData.ssid, "");
                                } else {
                                    wm.passText = "";
                                    wm.showPass = false;
                                    passInput.text = "";
                                    wm.expandedSsid = expanded ? "" : modelData.ssid;
                                    if (wm.expandedSsid !== "") passInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }

                // hidden join --------------------------------------------
                Rectangle {
                    width: netCol.width
                    height: joinOpen ? 132 : 30
                    radius: Theme.radiusSm
                    color: joinHover.containsMouse ? Theme.surfaceHover : Theme.surface
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    Behavior on height {
                        NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.durNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeDecel }
                    }
                    property bool joinOpen: wm.expandedSsid === "@hidden"

                    Column {
                        anchors.fill: parent
                        anchors.margins: Theme.spaceSm
                        spacing: 6
                        Text {
                            visible: !parent.parent.joinOpen
                            text: "+ Join hidden network…"
                            color: Theme.dimText
                            font.pixelSize: Theme.fontXs
                        }
                        TextInput {
                            visible: parent.parent.joinOpen
                            width: parent.width
                            height: 26
                            color: Theme.foreground
                            font.pixelSize: Theme.fontSm
                            font.family: "monospace"
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: wm.joinSsid = text
                            onAccepted: hiddenPass.forceActiveFocus()
                            onActiveFocusChanged: wm.typing = activeFocus
                            Text {
                                visible: parent.text === "" && !parent.activeFocus
                                text: "Network name (SSID)"
                                color: Theme.outline
                                font.pixelSize: Theme.fontXs
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        TextInput {
                            id: hiddenPass
                            visible: parent.parent.joinOpen
                            width: parent.width
                            height: 26
                            color: Theme.foreground
                            font.pixelSize: Theme.fontSm
                            font.family: "monospace"
                            echoMode: TextInput.Password
                            clip: true
                            verticalAlignment: TextInput.AlignVCenter
                            onTextChanged: wm.passText = text
                            onAccepted: Wifi.connect(wm.joinSsid, wm.passText)
                            onActiveFocusChanged: wm.typing = activeFocus
                        }
                        Row {
                            visible: parent.parent.joinOpen
                            spacing: Theme.spaceSm
                            anchors.right: parent.right
                            Buttonish {
                                label: "Cancel"
                                onClicked: wm.expandedSsid = ""
                            }
                            Buttonish {
                                label: "Connect"
                                accent: true
                                onClicked: Wifi.connect(wm.joinSsid, wm.passText)
                            }
                        }
                    }
                    HoverHandler { id: joinHover }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        enabled: Wifi.radio && !parent.joinOpen
                        onClicked: {
                            wm.joinSsid = "";
                            wm.passText = "";
                            wm.expandedSsid = "@hidden";
                        }
                    }
                }
            }
        }

        // footer -----------------------------------------------------
        Item {
            width: parent.width
            height: 22
            Text {
                text: (Wifi.iface !== "" ? Wifi.iface : "wlan0") + (Wifi.radio ? "" : " · radio off")
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                font.family: "monospace"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
