import QtQuick
import qs.Common

// Small labeled pill button.
Rectangle {
    id: b

    signal clicked()

    property string label: ""
    property bool accent: false     // primary fill
    property bool danger: false     // destructive fill
    property bool enabled_: true

    width: lbl.implicitWidth + Theme.spaceMd * 2
    height: 24
    radius: Theme.radiusFull
    opacity: enabled_ ? 1 : 0.4
    color: m.containsMouse && enabled_ ? Qt.darker(baseCol, 1.15) : baseCol
    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    readonly property color baseCol: danger ? Theme.danger : accent ? Theme.primary : Theme.surfaceHover

    Text {
        font.family: Theme.fontText
        id: lbl
        anchors.centerIn: parent
        text: b.label
        color: b.danger || b.accent ? Theme.background : Theme.foreground
        font.pixelSize: Theme.fontXs + 1
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        enabled: b.enabled_
        cursorShape: b.enabled_ ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (b.enabled_) b.clicked()
    }
}
