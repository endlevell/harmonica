import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

// The Orchestra — the SINGLE surface of Harmonica.
// One PanelWindow whose size NEVER changes (islandWinH, transparent, masked);
// an inner shape Item morphs between phase views:
//   idle · music · notification · panel(3 pages) · launcher
//
// Morph choreography (per STUDY-NOTES.md):
//   twitch (70ms lead) → container sizes animate (expand: slight-back /
//   retract: out-cubic) WHILE old view fades+slides out → new view fades+
//   slides in as the container settles. Window geometry itself is constant.
PanelWindow {
    id: win

    required property var modelData
    readonly property ShellScreen screenRef: modelData as ShellScreen

    // ---- phase machine -------------------------------------------------
    readonly property string basePhase: Recorder.active ? "recording" : Notifications.showing ? "notification" : Mpris.playing ? "music" : "idle"
    property bool hoverOpen: false          // panel requested via hover/click
    property bool launcherOpen: false       // Super+S / IPC
    property bool recordSettingsOpen: false
    property bool screenshotOpen: false       // capture quick actions (pill)

    readonly property string targetView: screenshotOpen ? "screenshot"
        : recordSettingsOpen ? "recordSettings"
        : launcherOpen ? "launcher"
        : hoverOpen ? "panel" : basePhase

    // what is mounted / animating
    property string shownView: "idle"       // settled view
    property string leavingView: ""         // view fading out during a morph
    property string pendingView: ""         // destination of an in-flight morph
    property bool sizeBig: false            // container target: card vs pill
    property string sizeView: "idle"        // which small/huge height applies

    function _isBig(v: string): bool { return v === "panel" || v === "launcher" || v === "recordSettings"; }

    function goTo(view: string): void {
        if (view === shownView && !swapSeq.running) return;
        if (view === pendingView && swapSeq.running) return;
        pendingView = view;
        leavingView = shownView;
        sizeBig = win._isBig(pendingView);
        sizeView = pendingView;
        leaveOp = 1; leaveY = 0;
        enterOp = 0; enterY = -6;
        swapSeq.restart();
    }

    SequentialAnimation {
        id: swapSeq

        // old content exits first (~40% of morph)
        ParallelAnimation {
            NumberAnimation { target: win; property: "leaveOp"; to: 0; duration: Theme.morphOutMs; easing.type: Easing.InOutCubic }
            NumberAnimation { target: win; property: "leaveY"; to: 12; duration: Theme.morphOutMs; easing.type: Easing.InCubic }
        }
        ScriptAction {
            script: {
                win.shownView = win.pendingView;
                win.leavingView = "";
                win.enterOp = 0;
                win.enterY = -10;
            }
        }
        // new content enters while container settles
        ParallelAnimation {
            NumberAnimation { target: win; property: "enterOp"; to: 1; duration: Theme.morphInMs; easing.type: Easing.OutCubic }
            NumberAnimation { target: win; property: "enterY"; to: 0; duration: Theme.morphInMs + 60; easing.bezierCurve: Theme.easeDecel; easing.type: Easing.BezierSpline }
        }
    }

    property real leaveOp: 0
    property real leaveY: 0
    property real enterOp: 1
    property real enterY: 0

    // ---- window: fixed size, transparent, input masked to the shape -----
    screen: screenRef
    anchors { top: true; left: true; right: true }
    margins { top: Theme.spaceXs }
    color: "transparent"
    implicitHeight: Theme.islandWinH                 // CONSTANT — never animated
    exclusiveZone: Theme.barH + Theme.spaceXs * 2    // windows below keep their strip

    WlrLayershell.namespace: "harmonica:island"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: launcherOpen || recordSettingsOpen
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    // explicit rect (not item:) so the click region tracks every morph;
    // item-form masks can go stale when the pill resizes between phases
    mask: Region { x: content.x; y: content.y; width: content.width; height: content.height }

    // ---- the morphing shape --------------------------------------------
    Item {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        width: sizeBig ? (sizeView === "launcher" ? Theme.launcherW
                         : Math.min(win.screen.width - Theme.spaceLg * 2, Theme.panelW))
             : sizeView === "music" ? musicStrip.contentWidth : sizeView === "notification" ? notifStrip.contentWidth : sizeView === "screenshot" ? shotStrip.contentWidth : idleBar.contentWidth
        height: sizeBig ? (sizeView === "launcher" ? launcherView.contentH
                         : sizeView === "recordSettings" ? Theme.recordSettingsH
                         : Theme.panelH)
                        : Theme.barH
        Behavior on width {
            NumberAnimation {
                duration: sizeBig ? Theme.morphDurExpand : Theme.morphDurRetract
                easing.type: sizeBig ? Easing.BezierSpline : Easing.OutCubic
                easing.bezierCurve: sizeBig ? Theme.easeMorphExpand : []
            }
        }
        Behavior on height {
            NumberAnimation {
                duration: sizeBig ? Theme.morphDurExpand : Theme.morphDurRetract
                easing.type: sizeBig ? Easing.BezierSpline : Easing.OutCubic
                easing.bezierCurve: sizeBig ? Theme.easeMorphExpand : []
            }
        }

        Twitch {
            // TEMP-DBG
            id: islandBody
            anchors.fill: parent

            Rectangle {
                id: pill
                anchors.fill: parent
                radius: sizeBig ? Theme.radiusMd : height / 2
                clip: true
                Behavior on radius {
                    NumberAnimation {
                        duration: sizeBig ? Theme.morphDurExpand : Theme.morphDurRetract
                        easing.type: Easing.OutCubic
                    }
                }
                // flat solid neutral, barely-perceptible vertical gradient
                // (surface → 4% darker); brightens slightly on collapsed hover
                gradient: Gradient {
                    GradientStop {
                        id: gsTop
                        position: 0.0
                        color: hoverTrack.containsMouse && !sizeBig
                            ? Qt.lighter(Theme.background, 1.14) : Theme.background
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }
                    GradientStop {
                        id: gsBottom
                        position: 1.0
                        color: hoverTrack.containsMouse && !sizeBig
                            ? Qt.darker(Qt.lighter(Theme.background, 1.14), 1.04)
                            : Qt.darker(Theme.background, 1.04)
                        Behavior on color { ColorAnimation { duration: Theme.durFast } }
                    }
                }
            }

            // ---- phase views (sequenced by the controller) ----------------
            IdleBar {
                id: idleBar
                anchors.fill: parent
                opacity: shownView === "idle" ? enterOp : leavingView === "idle" ? leaveOp : 0
                y: shownView === "idle" ? enterY : leavingView === "idle" ? leaveY : 0
                visible: opacity > 0.001
                enabled: shownView === "idle"
            }

            MusicStrip {
                id: musicStrip
                anchors.fill: parent
                opacity: shownView === "music" ? enterOp : leavingView === "music" ? leaveOp : 0
                y: shownView === "music" ? enterY : leavingView === "music" ? leaveY : 0
                visible: opacity > 0.001
                enabled: shownView === "music"
            }

            NotificationStrip {
                id: notifStrip
                anchors.fill: parent
                opacity: shownView === "notification" ? enterOp : leavingView === "notification" ? leaveOp : 0
                y: shownView === "notification" ? enterY : leavingView === "notification" ? leaveY : 0
                visible: opacity > 0.001
                enabled: shownView === "notification"
            }

            PanelPages {
                id: panelPages
                anchors.fill: parent
                opacity: shownView === "panel" ? enterOp : leavingView === "panel" ? leaveOp : 0
                y: shownView === "panel" ? enterY : leavingView === "panel" ? leaveY : 0
                visible: opacity > 0.001
                enabled: shownView === "panel"
                onPageIndexChanged: islandBody.trigger(0.5)
            }

            LauncherView {
                id: launcherView
                anchors.fill: parent
                opacity: shownView === "launcher" ? enterOp : leavingView === "launcher" ? leaveOp : 0
                y: shownView === "launcher" ? enterY : leavingView === "launcher" ? leaveY : 0
                visible: opacity > 0.001
                enabled: shownView === "launcher"
                onClosed: win.closeLauncher()
            }

            RecordingCluster {
                anchors.fill: parent
                opacity: shownView === "recording" ? enterOp : leavingView === "recording" ? leaveOp : 0
                y: shownView === "recording" ? enterY : leavingView === "recording" ? leaveY : 0
                visible: opacity > 0.001
                enabled: shownView === "recording"
            }

            RecordSettings {
                anchors.fill: parent
                opacity: shownView === "recordSettings" ? enterOp : leavingView === "recordSettings" ? leaveOp : 0
                y: shownView === "recordSettings" ? enterY : leavingView === "recordSettings" ? leaveY : 0
                visible: opacity > 0.001
                enabled: shownView === "recordSettings"
                onBackRequested: win.recordSettingsOpen = false
                Component.onCompleted: Recorder.refreshAudioSources()
            }

            ScreenshotStrip {
                id: shotStrip
                anchors.fill: parent
                opacity: shownView === "screenshot" ? enterOp : leavingView === "screenshot" ? leaveOp : 0
                y: shownView === "screenshot" ? enterY : leavingView === "screenshot" ? leaveY : 0
                visible: opacity > 0.001
                enabled: shownView === "screenshot"
            }
        }
    }

    // ---- reactive side effects ------------------------------------------
    onTargetViewChanged: goTo(targetView)
    onLauncherOpenChanged: {
        if (launcherOpen) Qt.callLater(() => launcherView.grabFocus());
    }
    onRecordSettingsOpenChanged: {
        if (recordSettingsOpen) Qt.callLater(() => recordSettings.grabFocus());
    }

    function openRecordSettings(): void {
        hoverOpen = false;
        recordSettingsOpen = true;
    }
    // capture actions collapse every open view first (never in the shot)
    Connections {
        target: Screenshot
        function onCollapseRequested() {
            win.hoverOpen = false;
            win.launcherOpen = false;
            win.recordSettingsOpen = false;
            win.screenshotOpen = false;
        }
    }

    function openScreenshot(): void {
        hoverOpen = false;
        recordSettingsOpen = false;
        launcherOpen = false;
        screenshotOpen = true;
    }
    function closeScreenshot(): void { screenshotOpen = false; }
    function toggleScreenshot(): void { screenshotOpen ? closeScreenshot() : openScreenshot(); }

    // ---- input ----------------------------------------------------------
    // pure hover tracker (NoButton → never blocks clicks/wheel on content)
    MouseArea {
        id: hoverTrack
        anchors.fill: content
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: hoverOpen || launcherOpen || recordSettingsOpen || screenshotOpen || Notifications.showing ? Qt.ArrowCursor : Qt.PointingHandCursor
        onContainsMouseChanged: {
            if (containsMouse) {
                closeDelay.stop();
                if (!launcherOpen && !recordSettingsOpen && !Notifications.showing) hoverOpen = true;
            } else {
                closeDelay.restart();
            }
        }
    }

    // click-to-open only while a pill phase shows; never steals page clicks
    MouseArea {
        anchors.fill: content
        enabled: !hoverOpen && !launcherOpen && !recordSettingsOpen && !screenshotOpen && !Notifications.showing
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
        enabled: hoverOpen || launcherOpen || recordSettingsOpen || screenshotOpen || Notifications.showing
        onActivated: {
            if (screenshotOpen) screenshotOpen = false;
            else if (recordSettingsOpen) recordSettingsOpen = false;
        }
    }

    // ---- api --------------------------------------------------------------
    function openLauncher(): void { hoverOpen = false; launcherOpen = true; }
    function closeLauncher(): void { launcherOpen = false; }
    function toggleLauncher(): void { launcherOpen ? closeLauncher() : openLauncher(); }
    function apiIsOpen(): bool { return hoverOpen; }
    function apiPhase(): string { return shownView; }
    function apiPage(): int { return panelPages.pageIndex; }
    function apiNextPage(): void { if (shownView === "panel") panelPages.pageIndex = (panelPages.pageIndex + 1) % panelPages.pageCount }
    function apiPrevPage(): void { if (shownView === "panel") panelPages.pageIndex = (panelPages.pageIndex + panelPages.pageCount - 1) % panelPages.pageCount }
    function apiOpen(): void { hoverOpen = true; }
    function apiClose(): void { hoverOpen = false; }
    function apiLauncherResults(): int { return launcherView.resultCount; }
}
