import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// Lock screen content (one per output surface): ambient clock + media,
Item {
    id: lock
    anchors.fill: parent
    focus: true

    property date now: new Date()
    property bool showPass: false

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: lock.now = new Date()
    }

    function fmtClock(): string {
        const h = now.getHours(), m = now.getMinutes();
        return (h < 10 ? "0" : "") + h + ":" + (m < 10 ? "0" : "") + m;
    }
    function fmtDate(): string {
        const days = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];
        const months = ["JANUARY", "FEBRUARY", "MARCH", "APRIL", "MAY", "JUNE", "JULY", "AUGUST", "SEPTEMBER", "OCTOBER", "NOVEMBER", "DECEMBER"];
        return days[now.getDay()] + ", " + months[now.getMonth()] + " " + now.getDate();
    }

    // dimmed wallpaper (lock dim parallels the picker exception)
    Image {
        anchors.fill: parent
        source: Theme.wallpaper !== "" ? "file://" + Theme.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
    }
    Rectangle {
        anchors.fill: parent
        color: Theme.overlayDim
    }

    // wake on any key (first printable also seeds the password field)
    Keys.onPressed: e => {
        if (Lock.state !== "ambient") return;
        Lock.wake();
        if (e.text !== "" && e.text >= " " && passInput) {
            passInput.forceActiveFocus();
            passInput.text = e.text;
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: Lock.state === "ambient"
        onClicked: Lock.wake()
    }

    // header ----------------------------------------------------------
    Text {
        text: "● HARMONICA // " + Lock.state.toUpperCase()
        color: Theme.dimText
        font.pixelSize: Theme.fontXs
        font.family: "monospace"
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: Theme.spaceLg
    }
    Row {
        spacing: Theme.spaceXs
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Theme.spaceLg
        Text {
            text: Battery.present ? Battery.percentage + "%" : ""
            color: Theme.dimText
            font.pixelSize: Theme.fontXs
            font.family: "monospace"
            anchors.verticalCenter: parent.verticalCenter
        }
        Icon {
            category: "status"
            name: Battery.iconName
            size: 14
            color: Theme.dimText
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    // clock ------------------------------------------------------------
    Column {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: Lock.state === "ambient" ? -120 : -190
        spacing: Theme.spaceSm
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.durNormal; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeDecel }
        }

        Text {
            text: lock.fmtClock()
            color: Theme.foreground
            font.pixelSize: Theme.fontHero
            font.weight: Font.Bold
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: lock.fmtDate()
            color: Theme.dimText
            font.pixelSize: Theme.fontSm
            font.letterSpacing: 4
            horizontalAlignment: Text.AlignHCenter
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // auth block ---------------------------------------------------------
    Column {
        visible: Lock.state !== "ambient"
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 60
        spacing: Theme.spaceSm
        opacity: Lock.state === "auth" ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.durFast } }

        Rectangle {
            width: 72
            height: 72
            radius: 36
            color: Theme.surface
            anchors.horizontalCenter: parent.horizontalCenter
            Text {
                anchors.centerIn: parent
                text: Lock.userName.length > 0 ? Lock.userName.charAt(0).toUpperCase() : "?"
                color: Theme.dimText
                font.pixelSize: 28
                font.weight: Font.DemiBold
            }
        }
        Text {
            text: Lock.userName
            color: Theme.foreground
            font.pixelSize: Theme.fontSm
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Item {
            id: passWrap
            width: 320
            height: 44
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Theme.surface
            }
            Row {
                anchors.fill: parent
                anchors.leftMargin: Theme.spaceMd
                anchors.rightMargin: Theme.spaceSm
                spacing: Theme.spaceSm
                TextInput {
                    id: passInput
                    width: parent.width - 30 - Theme.spaceSm
                    height: parent.height
                    color: Theme.foreground
                    font.pixelSize: Theme.fontMd
                    font.family: "monospace"
                    echoMode: lock.showPass ? TextInput.Normal : TextInput.Password
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    cursorVisible: activeFocus
                    onAccepted: { Lock.submit(text); }
                    Keys.onEscapePressed: Lock.backToAmbient()
                }
                IconButton {
                    category: "actions"
                    iconName: lock.showPass ? "visibility-off" : "visibility"
                    iconSize: 14
                    pad: 4
                    anchors.verticalCenter: parent.verticalCenter
                    onClicked: lock.showPass = !lock.showPass
                }
            }

            // damped shake on failure
            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: passWrap; property: "x"; to: -18; duration: Theme.durFast / 2; easing.type: Easing.OutCubic }
                NumberAnimation { target: passWrap; property: "x"; to: 18; duration: Theme.durFast / 2; easing.type: Easing.InOutCubic }
                NumberAnimation { target: passWrap; property: "x"; to: -10; duration: Theme.durFast / 2; easing.type: Easing.InOutCubic }
                NumberAnimation { target: passWrap; property: "x"; to: 10; duration: Theme.durFast / 2; easing.type: Easing.InOutCubic }
                NumberAnimation { target: passWrap; property: "x"; to: 0; duration: Theme.durFast / 2; easing.type: Easing.OutCubic }
            }
            Connections {
                target: Lock
                function onErrorTextChanged() {
                    if (Lock.errorText !== "") {
                        passInput.text = "";
                        passInput.forceActiveFocus();
                        if (!Theme.reducedMotion) shakeAnim.restart();
                    }
                }
            }
        }

        Text {
            visible: Lock.errorText !== ""
            text: Lock.errorText
            color: Theme.danger
            font.pixelSize: Theme.fontSm
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            visible: Lock.errorText === "" && !Lock.checking
            text: "press Enter to unlock"
            color: Theme.dimText
            font.pixelSize: Theme.fontXs
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            visible: Lock.checking
            text: "checking…"
            color: Theme.dimText
            font.pixelSize: Theme.fontXs
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // ambient media strip --------------------------------------------------
    Rectangle {
        visible: Lock.state === "ambient"
        width: 300
        height: 64
        radius: Theme.radiusMd
        color: Theme.surface
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48

        Row {
            anchors.fill: parent
            anchors.margins: Theme.spaceSm
            spacing: Theme.spaceSm

            Rectangle {
                width: 48
                height: 48
                radius: Theme.radiusSm
                color: Theme.background
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                Image {
                    anchors.fill: parent
                    source: Mpris.artUrl !== "" ? Mpris.artUrl : "file://" + Paths.shellDir + "/assets/images/lock-art.png"
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }
            Column {
                width: parent.width - 48 - 90 - Theme.spaceSm * 2
                spacing: 2
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    width: parent.width
                    text: Mpris.title || "Austerity Economy"
                    color: Theme.foreground
                    font.pixelSize: Theme.fontSm
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: Mpris.artist || "K Civil"
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    elide: Text.ElideRight
                }
                Rectangle {
                    width: parent.width
                    height: 2
                    radius: 1
                    color: Theme.background
                    Rectangle {
                        width: parent.width * (Mpris.lengthSecs > 0 ? Math.min(1, Mpris.positionSecs / Mpris.lengthSecs) : 0.43)
                        height: parent.height
                        radius: 1
                        color: Theme.primary
                    }
                }
            }
            Row {
                spacing: Theme.spaceMd
                anchors.verticalCenter: parent.verticalCenter
                IconButton {
                    category: "media"; iconName: "prev"; iconSize: 13; pad: 3
                    enabled: Mpris.canGoPrevious
                    onClicked: Mpris.previous()
                }
                IconButton {
                    category: "media"; iconName: Mpris.playing ? "pause" : "play"; iconSize: 13; pad: 3
                    enabled: Mpris.canPlay
                    onClicked: Mpris.togglePlaying()
                }
                IconButton {
                    category: "media"; iconName: "next"; iconSize: 13; pad: 3
                    enabled: Mpris.canGoNext
                    onClicked: Mpris.next()
                }
            }
        }
    }

    Item {
        anchors.fill: parent
        visible: irisRing.visible
        Rectangle {
            id: dimFade
            anchors.fill: parent
            color: Theme.background
            opacity: Lock.state === "unlocking" ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: Theme.reducedMotion ? 0 : Theme.durIris; easing.type: Easing.OutCubic } }
        }
        Item {
            id: irisRing
            visible: Lock.state === "unlocking"
            width: 120
            height: 120
            anchors.centerIn: parent
            // flat ring (two discs, no border props): expands + fades
            Rectangle {
                anchors.centerIn: parent
                width: 120
                height: 120
                radius: 60
                color: Theme.primary
            }
            Rectangle {
                anchors.centerIn: parent
                width: 116
                height: 116
                radius: 58
                color: Theme.background
            }
            NumberAnimation on scale {
                running: Lock.state === "unlocking"
                from: 0.2
                to: 6.0
                duration: Theme.reducedMotion ? 0 : Theme.durIris
                easing.type: Easing.OutCubic
            }
            NumberAnimation on opacity {
                running: Lock.state === "unlocking"
                from: 1
                to: 0
                duration: Theme.reducedMotion ? 0 : Theme.durIris
                easing.type: Easing.OutCubic
            }
        }
    }

    // footer ------------------------------------------------------------
    Text {
        text: Lock.userName + " · logged in"
        color: Theme.dimText
        font.pixelSize: Theme.fontXs
        font.family: "monospace"
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spaceLg
    }
    RowLayout {
        spacing: Theme.spaceSm
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Theme.spaceLg
        Text {
            text: "Restart"
            color: Theme.dimText
            font.pixelSize: Theme.fontXs
            Layout.alignment: Qt.AlignVCenter
        }
        IconButton {
            category: "actions"; iconName: "power"; iconSize: 12; pad: 4
            Layout.alignment: Qt.AlignVCenter
            onClicked: Quickshell.execDetached(["sh", "-c", "systemctl reboot 2>/dev/null || loginctl reboot 2>/dev/null || true"])
        }
        Text {
            text: "Cancel"
            color: Theme.dimText
            font.pixelSize: Theme.fontXs
            Layout.alignment: Qt.AlignVCenter
        }
        IconButton {
            category: "actions"; iconName: "close"; iconSize: 12; pad: 4
            Layout.alignment: Qt.AlignVCenter
            onClicked: Lock.backToAmbient()
        }
    }
}
