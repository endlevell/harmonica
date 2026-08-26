import QtQuick
import qs.Common
import qs.Widgets

// Bento-style quick toggle pill:
// Icon circle left · Title + Subtitle right · Active highlight
Rectangle {
    id: pill

    property string category: "status"
    property string iconName: ""
    property string label: ""
    property string statusText: ""
    property bool active: false
    property color activeColor: Theme.primary

    signal clicked()

    implicitWidth: 180
    implicitHeight: 40
    radius: Theme.radiusMd - 2
    color: active ? activeColor : (mouse.containsMouse ? Theme.surfaceHover : Theme.surface)

    Behavior on color { ColorAnimation { duration: Theme.durFast } }

    Row {
        anchors.fill: parent
        anchors.leftMargin: Theme.spaceSm + 2
        anchors.rightMargin: Theme.spaceSm + 2
        spacing: Theme.spaceSm

        // Icon disc
        Rectangle {
            width: 26
            height: 26
            radius: Theme.radiusFull
            color: pill.active ? Theme.background : Theme.surfaceHover
            anchors.verticalCenter: parent.verticalCenter

            Icon {
                category: pill.category
                name: pill.iconName
                size: 14
                color: pill.active ? pill.activeColor : Theme.foreground
                anchors.centerIn: parent
            }
        }

        // Text stack
        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1
            width: parent.width - 34

            Text {
                text: pill.label
                color: pill.active ? Theme.background : Theme.foreground
                font.pixelSize: Theme.fontXs + 1
                font.weight: Font.DemiBold
                elide: Text.ElideRight
                width: parent.width
            }

            Text {
                text: pill.statusText
                color: pill.active ? Qt.darker(Theme.background, 1.25) : Theme.dimText
                font.pixelSize: 10
                elide: Text.ElideRight
                width: parent.width
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.clicked()
    }
}
