import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

// The Orchestra — the SINGLE surface of Harmonica.
// One PanelWindow whose size NEVER changes (islandWinH, transparent, masked);
// an inner shape Item morphs between phase views:
//   idle · music · panel(3 pages) · launcher
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
    readonly property string basePhase: Recorder.active ? "recording" : Mpris.playing ? "music" : "idle"
    property bool hoverOpen: false          // panel requested via hover/click
    property bool launcherOpen: false       // Super+S / IPC
    property bool recordSettingsOpen: false
    property bool annotateOpen: false
    property string annotatePath: ""        // frozen shot feeding the annotator

    readonly property string targetView: annotateOpen ? "annotate"
        : recordSettingsOpen ? "recordSettings"
        : launcherOpen ? "launcher"
        : hoverOpen ? "panel" : basePhase

    // what is mounted / animating
    property string shownView: "idle"       // settled view
    property string leavingView: ""         // view fading out during a morph
    property string pendingView: ""         // destination of an in-flight morph
    property bool sizeBig: false            // container target: card vs pill
    property string sizeView: "idle"        // which small/huge height applies

    function _isBig(v: string): bool { return v === "panel" || v === "launcher"; }

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
    WlrLayershell.keyboardFocus: launcherOpen || recordSettingsOpen || annotateOpen
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.OnDemand

    mask: Region { item: pill }

    // ---- the morphing shape --------------------------------------------
    Item {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        width: sizeBig ? Math.min(win.screen.width - Theme.spaceLg * 2, Theme.panelW)
             : sizeView === "music" ? musicStrip.contentWidth : idleBar.contentWidth
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

            AnnotateView {
                id: annotateView
                anchors.fill: parent
                imagePath: win.annotatePath
                opacity: shownView === "annotate" ? enterOp : leavingView === "annotate" ? leaveOp : 0
                y: shownView === "annotate" ? enterY : leavingView === "annotate" ? leaveY : 0
                visible: opacity > 0.001
                enabled: shownView === "annotate"
                onClosed: win.annotateOpen = false
            }
        }
    }

    // ---- reactive side effects ------------------------------------------
    onTargetViewChanged: goTo(targetView)
    onLauncherOpenChanged: {
        if (launcherOpen) Qt.callLater(() => launcherView.grabFocus());
    }
    onRecordSettingsOpenChanged: {
        if (recordSettingsOpen) Qt.callLater(() => launcherView.grabFocus()); // noop focus reset
    }

    function openRecordSettings(): void {
        hoverOpen = false;
        recordSettingsOpen = true;
    }

    function openAnnotate(path: string): void {
        hoverOpen = false;
        recordSettingsOpen = false;
        launcherOpen = false;
        annotatePath = path;
        annotateOpen = true;
    }
    function apiSaveAnnotate(): string { annotateView.doSave(); return Screenshot.lastShot; }

    // ---- input ----------------------------------------------------------
    // pure hover tracker (NoButton → never blocks clicks/wheel on content)
    MouseArea {
        id: hoverTrack
        anchors.fill: content
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        cursorShape: hoverOpen || launcherOpen || recordSettingsOpen || annotateOpen ? Qt.ArrowCursor : Qt.PointingHandCursor
        onContainsMouseChanged: {
            if (containsMouse) {
                closeDelay.stop();
                if (!launcherOpen && !recordSettingsOpen) hoverOpen = true;
            } else {
                closeDelay.restart();
            }
        }
    }

    // click-to-open only while a pill phase shows; never steals page clicks
    MouseArea {
        anchors.fill: content
        enabled: !hoverOpen && !launcherOpen && !recordSettingsOpen && !annotateOpen
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
        enabled: hoverOpen || launcherOpen || recordSettingsOpen || annotateOpen
        onActivated: {
            if (annotateOpen) annotateOpen = false;
            else if (recordSettingsOpen) recordSettingsOpen = false;
            else if (launcherOpen) closeLauncher();
            else hoverOpen = false;
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
