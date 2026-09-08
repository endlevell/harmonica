import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// NOTIFICATION phase strip (bar height): bell circle left, centered
// title/body block right. Bell swings on arrival, queued items crossfade,
// overflow lines marquee on hover. Click body = default action, circle = dismiss.
Item {
    id: strip

    readonly property int bellBox: 28
    readonly property int textW: 190
    readonly property int ackW: 64
    readonly property int contentWidth: Theme.spaceMd * 2 + bellBox + Theme.spaceSm + textW + (Notifications.hasDefaultAction ? Theme.spaceSm + ackW + Theme.spaceMd : 0)
    property real swapOp: 1
    property real swapY: 0
    property string shownTitle: Notifications.title
    property string shownBody: Notifications.body
    property var cur: Notifications.current

    onCurChanged: if (cur) { swing.restart(); swapSeq.restart(); }
    // in-place sender updates: same object, new content — crossfade only
    Connections {
        target: Notifications
        function onRevisionChanged() { if (strip.cur) swapSeq.restart(); }
    }
    component MarqueeLine: Item {
        id: line
        property string text: ""
        property color color: Theme.foreground
        property int px: Theme.fontSm
        property int weight: Font.Normal
        width: strip.textW
        height: label.implicitHeight
        clip: true
        onTextChanged: label.x = 0
        Text {
            font.family: Theme.fontText
            id: label
            width: parent.width
            text: line.text
            color: line.color
            font.pixelSize: line.px
            font.weight: line.weight
            horizontalAlignment: line.over ? Text.AlignLeft : Text.AlignHCenter
            elide: scrollAnim.running ? Text.ElideNone : Text.ElideRight
            maximumLineCount: 1
        }
        readonly property bool over: label.implicitWidth > width + 1
        SequentialAnimation {
            id: scrollAnim
            loops: Animation.Infinite
            running: line.over && stripHover.hovered && strip.enabled
            alwaysRunToEnd: true
            PauseAnimation { duration: 500 }
            NumberAnimation {
                target: label
                property: "x"
                to: -(label.implicitWidth - line.width)
                duration: Math.max(900, (label.implicitWidth - line.width) * 22)
                easing.type: Easing.InOutCubic
            }
            PauseAnimation { duration: 500 }
            NumberAnimation { target: label; property: "x"; to: 0; duration: 350; easing.type: Easing.InOutCubic }
        }
    }

    // damped bell swing: -12 → +8 → -5 → 0 over Theme.durBellSwing
    SequentialAnimation {
        id: swing
        NumberAnimation { target: bellSwing; property: "rotation"; from: 0; to: -12; duration: Theme.durBellSwing * 0.17; easing.type: Easing.OutCubic }
        NumberAnimation { target: bellSwing; property: "rotation"; to: 8; duration: Theme.durBellSwing * 0.22; easing.type: Easing.InOutCubic }
        NumberAnimation { target: bellSwing; property: "rotation"; to: -5; duration: Theme.durBellSwing * 0.24; easing.type: Easing.InOutCubic }
        NumberAnimation { target: bellSwing; property: "rotation"; to: 0; duration: Theme.durBellSwing * 0.37; easing.type: Easing.InOutCubic }
    }

    // crossfade + rise between queued items (no jump cut)
    SequentialAnimation {
        id: swapSeq
        ParallelAnimation {
            NumberAnimation { target: strip; property: "swapOp"; to: 0; duration: 110; easing.type: Easing.InCubic }
            NumberAnimation { target: strip; property: "swapY"; to: 8; duration: 110; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                strip.shownTitle = Notifications.title;
                strip.shownBody = Notifications.body;
                strip.swapY = -8;
            }
        }
        ParallelAnimation {
            NumberAnimation { target: strip; property: "swapOp"; to: 1; duration: 200; easing.type: Easing.OutCubic }
            NumberAnimation { target: strip; property: "swapY"; to: 0; duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeDecel }
        }
    }

    // (arrival reaction lives on onCurChanged above — single trigger)

    HoverHandler { id: stripHover }

    Row {
        // bell · text · ack chip as one centered group
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Theme.spaceSm
        opacity: strip.swapOp
        y: strip.swapY

        Item {
            id: bellHit
            width: strip.bellBox
            height: strip.bellBox
            anchors.verticalCenter: parent.verticalCenter

            Item {
                id: bellSwing
                anchors.centerIn: parent
                width: 24
                height: 24
                transformOrigin: Item.Top
                Icon {
                    anchors.centerIn: parent
                    category: "status"
                    name: "bell"
                    size: 22
                    color: Theme.primary
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: strip.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.dismissCurrent()
            }
            Rectangle {
                visible: Notifications.count > 1
                width: 15
                height: 15
                radius: Theme.radiusFull
                color: Theme.foreground
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -4
                anchors.topMargin: -4
                Text {
                    font.family: Theme.fontText
                    anchors.centerIn: parent
                    text: Notifications.count
                    color: Theme.background
                    font.pixelSize: 9
                    font.weight: Font.DemiBold
                }
            }
        }

        Item {
            id: textHit
            width: strip.textW
            height: textCol.implicitHeight
            anchors.verticalCenter: parent.verticalCenter

            Column {
                id: textCol
                width: parent.width
                spacing: 1
                MarqueeLine { text: strip.shownTitle; color: Theme.foreground; px: Theme.fontSm + 1; weight: Font.DemiBold }
                MarqueeLine { text: strip.shownBody; color: Theme.dimText; px: Theme.fontXs; visible: strip.shownBody !== "" }
            }
            MouseArea {
                anchors.fill: parent
                enabled: strip.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.activateCurrent()
            }
        }
        Rectangle {
            width: strip.ackW
            height: 24
            radius: Theme.radiusFull
            color: ackMouse.containsMouse ? Theme.surfaceHover : Theme.surface
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifications.hasDefaultAction
            Behavior on color { ColorAnimation { duration: Theme.durFast } }
            Text {
                font.family: Theme.fontText
                anchors.centerIn: parent
                text: "ack"
                color: Theme.primary
                font.pixelSize: Theme.fontXs
                font.weight: Font.DemiBold
            }
            MouseArea {
                id: ackMouse
                anchors.fill: parent
                hoverEnabled: true
                enabled: strip.enabled
                cursorShape: Qt.PointingHandCursor
                onClicked: Notifications.activateCurrent()
            }
        }
    }
}
