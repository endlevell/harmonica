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
        iconSize: 18
        opacity: 0.7
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: Theme.spaceXs
        onClicked: nav.prevPage()
    }

    IconButton {
        id: right
        visible: nav.showRight
        category: "actions"
        iconName: "arrow-right"
        iconSize: 18
        opacity: 0.7
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.rightMargin: Theme.spaceXs
        onClicked: nav.nextPage()
    }
}
