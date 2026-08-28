import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Modules.wallpaper

// User-approved standalone overlay (§2 exception). The PanelWindow is fully
// transparent; visible UI is one circle-reveal dim layer + the carousel.
PanelWindow {
    id: picker

    readonly property bool shown: _showing
    readonly property string focusedPath: carousel.focusedPath
    property bool _showing: false
    property bool _closing: false
    property bool _carouselVisible: false
    property string _pendingPick: ""
    property real revealProgress: closedScale
    readonly property real diagonal: Math.sqrt(width * width + height * height)
    readonly property real closedScale: diagonal > 0
        ? Theme.wallpaperRevealStart / diagonal : 0.02

    function open(): void {
        if (shown && !_closing) return;
        Wallpaper.rescan();
        _showing = true;
        _closing = false;
        _carouselVisible = false;
        carousel.interactive = true;
        carousel.resetToCurrent();
        revealClose.stop();
        revealOpen.from = Math.max(closedScale, revealProgress);
        revealOpen.restart();
        carouselDelay.restart();
        watchdog.restart();
        Qt.callLater(() => carousel.forceActiveFocus());
    }

    function close(): void {
        if (!shown || _closing) return;
        _closing = true;
        _carouselVisible = false;
        carousel.interactive = false;
        carousel.velocity = 0;
        carouselDelay.stop();
        revealOpen.stop();
        revealClose.from = revealProgress;
        revealClose.to = closedScale;
        revealClose.restart();
    }

    function toggle(): void { shown && !_closing ? close() : open(); }
    function next(): void { carousel.glide(1); }
    function prev(): void { carousel.glide(-1); }
    function pick(): string { return carousel.pick(); }
    function apply(path: string): string {
        if (path === "" || Wallpaper.applying) return "";
        _pendingPick = path;
        carousel.interactive = false;
        if (!Wallpaper.apply(path)) {
            _pendingPick = "";
            carousel.interactive = true;
            return "";
        }
        return path;
    }

    NumberAnimation {
        id: revealOpen
        target: picker
        property: "revealProgress"
        to: 1
        duration: Theme.durReveal
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeDecel
    }

    NumberAnimation {
        id: revealClose
        target: picker
        property: "revealProgress"
        duration: Theme.durReveal
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeAccel
        onFinished: {
            picker._showing = false;
            picker._closing = false;
            watchdog.stop();
        }
    }

    Timer {
        id: carouselDelay
        interval: Theme.durReveal - Theme.durFast
        onTriggered: if (!picker._closing) picker._carouselVisible = true
    }

    Connections {
        target: Wallpaper
        function onApplied(path: string): void {
            if (path !== picker._pendingPick) return;
            picker._pendingPick = "";
            picker.close();
        }
        function onApplyFailed(path: string): void {
            if (path !== picker._pendingPick) return;
            picker._pendingPick = "";
            if (!picker.shown || picker._closing) return;
            carousel.interactive = true;
            Qt.callLater(() => carousel.forceActiveFocus());
        }
    }

    screen: Quickshell.screens[0] ?? null
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown

    WlrLayershell.namespace: "harmonica:wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown
        ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Only the carousel band receives pointer input; the visible dim layer
    // itself is click-through outside that band.
    mask: Region { item: inputRegion }

    Shortcut { sequence: "Escape"; enabled: shown; onActivated: picker.close() }

    Rectangle {
        anchors.centerIn: parent
        width: picker.diagonal
        height: width
        radius: width / 2
        color: Theme.overlayDim
        scale: picker.revealProgress
        transformOrigin: Item.Center
    }

    Item {
        id: inputRegion
        anchors.centerIn: parent
        width: parent.width
        height: Theme.wallpaperInputH
    }

    Item {
        anchors.fill: parent
        opacity: picker._carouselVisible ? 1 : 0
        y: picker._carouselVisible ? 0 : Theme.spaceXl

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.durNormal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeDecel
            }
        }
        Behavior on y {
            NumberAnimation {
                duration: Theme.durNormal
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeDecel
            }
        }

        Carousel {
            id: carousel
            anchors.fill: parent
            onSelected: path => picker.apply(path)
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Theme.spaceLg
            text: "wheel / ←→ to browse · Enter or click to apply · Esc to close"
            color: Theme.dimText
            font.pixelSize: Theme.fontSm
        }
    }

    Timer {
        id: watchdog
        interval: Theme.wallpaperWatchdogMs
        onTriggered: picker.close()
    }
}
