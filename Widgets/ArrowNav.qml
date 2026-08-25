import QtQuick
import qs.Common

// Chevron pair on the island's edges — signals + performs page navigation.
Item {
    id: nav

    signal prevPage()
    signal nextPage()

    property bool showLeft: true
    property bool showRight: true

    anchors.fill: parent

    IconButton {
        id: left
        visible: nav.showLeft
        category: "actions"
        iconName: "arrow-left"
        iconSize: 14
        pad: 5
        opacity: 0.8
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spaceXs + 2
        onClicked: nav.prevPage()
    }

    IconButton {
        id: right
        visible: nav.showRight
        category: "actions"
        iconName: "arrow-right"
        iconSize: 14
        pad: 5
        opacity: 0.8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.spaceXs + 2
        onClicked: nav.nextPage()
    }
}
