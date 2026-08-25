import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Widgets

// The island. One PanelWindow living in discrete phases:
//   idle (bar) ⇄ panel (3 pages). Music/record morphs arrive in later phases.
// Full-width window; only the pill accepts input (mask). Expansion overlays —
// exclusive zone stays fixed so windows below never jump.
PanelWindow {
    id: win

    required property var modelData
    readonly property ShellScreen screenRef: modelData as ShellScreen
    readonly property bool expanded: phase === "panel"
    property string phase: "idle"

    screen: screenRef
    anchors { top: true; left: true; right: true }
    margins { top: Theme.spaceSm }
    color: "transparent"
    implicitHeight: expanded ? Theme.panelH : Theme.barH
    exclusiveZone: Theme.barH + Theme.spaceSm * 2

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.durNormal; easing.bezierCurve: Theme.easeSpatial; easing.type: Easing.BezierSpline }
    }

    WlrLayershell.namespace: "harmonica:island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region { item: pill }

    // content column, centered horizontally
    Item {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(win.screen.width - Theme.spaceLg * 2, Theme.panelW)
        height: parent.height

        // the island surface: pill when idle, rounded card when open
        Rectangle {
            id: pill
            anchors.fill: parent
            radius: win.expanded ? Theme.radiusLg : height / 2
            color: Theme.scrim
            border.width: 1
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.5)
            clip: true
            Behavior on radius { NumberAnimation { duration: Theme.durNormal; easing.bezierCurve: Theme.easeSpatial; easing.type: Easing.BezierSpline } }
        }

        IdleBar {
            anchors.fill: parent
            visible: !win.expanded
            opacity: win.expanded ? 0 : 1
            enabled: !win.expanded
            Behavior on opacity { NumberAnimation { duration: Theme.durFast } }
        }

        PanelPages {
            anchors.fill: parent
            visible: win.expanded
            opacity: win.expanded ? 1 : 0
            enabled: win.expanded
        }
    }

    MouseArea {
        id: interaction
        anchors.fill: content
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: win.expanded ? Qt.ArrowCursor : Qt.PointingHandCursor
        onClicked: if (!win.expanded) win.phase = "panel"
        onContainsMouseChanged: {
            if (containsMouse) {
                closeDelay.stop();
                if (!win.expanded) win.phase = "panel";
            } else {
                closeDelay.restart();
            }
        }
    }

    Timer {
        id: closeDelay
        interval: 450
        onTriggered: if (!interaction.containsMouse) win.phase = "idle"
    }

    Shortcut {
        sequence: "Escape"
        enabled: win.expanded
        onActivated: win.phase = "idle"
    }
}
