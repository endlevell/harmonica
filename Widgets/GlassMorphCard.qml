import QtQuick
import QtQuick.Effects
import qs.Common

// Glassmorphism card with blur, transparency, and subtle gradient border.
// Creates depth and immersion for hero content.
Rectangle {
    id: root

    property alias contentItem: contentContainer.children
    property color glassColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.4)
    property color borderColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)

    color: root.glassColor
    radius: Theme.radiusMd
    border.width: 1
    border.color: root.borderColor

    // Subtle inner glow
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.1)
    }

    // Content container
    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: Theme.spaceMd
    }

    // Backdrop blur effect (simulated with layered opacity)
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.background
        opacity: 0.3
        z: -1
    }
}
