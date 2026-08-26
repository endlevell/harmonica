import QtQuick
import qs.Common

// Glassmorphism card: translucent surface, tinted border, subtle inner glow.
// Default children land inside a padded content area.
Rectangle {
    id: root

    default property alias content: contentContainer.data
    property color glassColor: Qt.rgba(Theme.surface.r, Theme.surface.g, Theme.surface.b, 0.4)
    property color borderColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.3)

    color: root.glassColor
    radius: Theme.radiusMd
    border.width: 1
    border.color: root.borderColor

    // Backdrop tint (simulated depth) — behind everything
    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.background
        opacity: 0.3
        z: -1
    }

    // Subtle inner glow, palette-derived
    Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: parent.radius - 1
        color: "transparent"
        border.width: 1
        border.color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.1)
    }

    // Padded content area — default children go here
    Item {
        id: contentContainer
        anchors.fill: parent
        anchors.margins: Theme.spaceMd
    }
}
