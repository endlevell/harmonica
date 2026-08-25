import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

// The island. One PanelWindow living in discrete phases:
//   idle (bar) ⇄ panel (3 pages). Music/record morphs arrive in later phases.
// Full-width window; only the pill accepts input (mask). Expansion overlays —
// exclusive zone stays fixed so windows below never jump.
PanelWindow {
    id: win

    required property var modelData
    readonly property ShellScreen screenRef: modelData as ShellScreen
    readonly property bool expanded: hoverOpen
    property bool hoverOpen: false
    readonly property string basePhase: Mpris.playing ? "music" : "idle"
    readonly property bool musicVisible: basePhase === "music"
    readonly property string phase: hoverOpen ? "panel" : basePhase
    onPhaseChanged: islandBody.trigger(1)   // signature twitch on every phase change

    screen: screenRef
    anchors { top: true; left: true; right: true }
    margins { top: Theme.spaceXs }
    color: "transparent"
    implicitHeight: expanded ? Theme.panelH : Theme.barH
    exclusiveZone: Theme.barH + Theme.spaceXs * 2

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.durNormal; easing.bezierCurve: Theme.easeSpatial; easing.type: Easing.BezierSpline }
    }

    WlrLayershell.namespace: "harmonica:island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    mask: Region { item: pill }

    // content column: idle pill hugs content · music strip hugs content · panel fixed.
    Item {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        width: win.expanded ? Math.min(win.screen.width - Theme.spaceLg * 2, Theme.panelW)
             : win.basePhase === "music" ? musicStrip.contentWidth : idleBar.contentWidth
        height: parent.height
        Behavior on width {
            NumberAnimation { duration: Theme.durNormal; easing.bezierCurve: Theme.easeSpatial; easing.type: Easing.BezierSpline }
        }

        Twitch {
            id: islandBody
            anchors.fill: parent

            // the island surface: pill when idle, rounded card when open — fully opaque
            Rectangle {
                id: pill
                anchors.fill: parent
                radius: win.expanded ? Theme.radiusMd : height / 2
                color: Theme.background
                clip: true
                Behavior on radius { NumberAnimation { duration: Theme.durNormal; easing.bezierCurve: Theme.easeSpatial; easing.type: Easing.BezierSpline } }
            }

            // IDLE row slides DOWN out of view when music starts (spec §1.3);
            // music strip takes its place from above. Reverts on stop.
            IdleBar {
                id: idleBar
                anchors.fill: parent
                visible: !win.expanded && y < Theme.barH
                enabled: !win.expanded && !win.musicVisible
                y: win.expanded || !win.musicVisible ? 0 : height + Theme.spaceXs
                Behavior on y { NumberAnimation { duration: Theme.durNormal; easing.bezierCurve: Theme.easeSpatial; easing.type: Easing.BezierSpline } }
            }

            MusicStrip {
                id: musicStrip
                anchors.fill: parent
                visible: !win.expanded && win.musicVisible
                enabled: !win.expanded && win.musicVisible
                y: win.expanded || win.musicVisible ? 0 : -(height + Theme.spaceXs)
                Behavior on y { NumberAnimation { duration: Theme.durNormal; easing.bezierCurve: Theme.easeSpatial; easing.type: Easing.BezierSpline } }
            }

            PanelPages {
                id: panelPages
                anchors.fill: parent
                visible: win.expanded
                opacity: win.expanded ? 1 : 0
                enabled: win.expanded
                onPageIndexChanged: islandBody.trigger(0.5)   // lighter twitch on page slide
            }

            PulseDot {
                anchors.fill: parent
                phase: win.phase
                pageIndex: panelPages.pageIndex
            }
        }
    }

    function apiIsOpen(): bool { return win.hoverOpen }
    function apiPhase(): string { return win.phase }
    function apiPage(): int { return panelPages.pageIndex }
    function apiNextPage(): void { if (win.expanded) panelPages.pageIndex = (panelPages.pageIndex + 1) % panelPages.pageCount }
    function apiPrevPage(): void { if (win.expanded) panelPages.pageIndex = (panelPages.pageIndex + panelPages.pageCount - 1) % panelPages.pageCount }
    function apiOpen(): void { win.hoverOpen = true }
    function apiClose(): void { win.hoverOpen = false }

    // pure hover tracker — NoButton so clicks/wheel pass through to content below
    MouseArea {
        id: hoverTrack
        anchors.fill: content
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: win.expanded ? Qt.ArrowCursor : Qt.PointingHandCursor
        onContainsMouseChanged: {
            if (containsMouse) {
                closeDelay.stop();
                win.hoverOpen = true;
            } else {
                closeDelay.restart();
            }
        }
    }

    // click-to-open only while idle/music — never steals page or player clicks
    MouseArea {
        anchors.fill: content
        enabled: !win.expanded
        acceptedButtons: Qt.LeftButton
        onClicked: win.hoverOpen = true
    }

    Timer {
        id: closeDelay
        interval: 450
        onTriggered: if (!hoverTrack.containsMouse) win.hoverOpen = false
    }

    Shortcut {
        sequence: "Escape"
        enabled: win.expanded
        onActivated: win.hoverOpen = false
    }
}
