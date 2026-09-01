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
    readonly property bool busy: _pickTransition || _pendingPick !== "" || Wallpaper.applying
    property bool _showing: false
    property bool _closing: false
    property bool _carouselVisible: false
    property string _pendingPick: ""
    property bool _pickTransition: false
    property bool _applySucceeded: false
    property bool _irisFinished: false
    property bool _bloomStarted: false
    property real revealProgress: closedScale
    readonly property real diagonal: Math.sqrt(width * width + height * height)
    readonly property real closedScale: diagonal > 0 ? Theme.wallpaperRevealStart / diagonal : 0.02

    function open(): void {
        if (busy)
            return;
        if (shown && !_closing)
            return;
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
        if (!shown || _closing || busy)
            return;
        startClose();
    }
    function startClose(): void {
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

    function toggle(): void {
        if (busy)
            return;
        shown && !_closing ? close() : open();
    }
    function next(): void {
        carousel.glide(1);
    }
    function prev(): void {
        carousel.glide(-1);
    }
    function pick(): string {
        if (busy || _closing)
            return "";
        return carousel.pick();
    }
    function beginPick(path: string): string {
        if (path === "" || _closing || _pickTransition || Wallpaper.applying) {
            if (shown && !_closing)
                carousel.cancelPick();
            return "";
        }
        _pendingPick = path;
        _pickTransition = true;
        _applySucceeded = false;
        _irisFinished = false;
        _bloomStarted = false;
        carousel.interactive = false;
        watchdog.restart();
        transition.start(path, carousel.focusedAspect, carousel.focusedCardWidth, carousel.cardHeight);
        return path;
    }

    function abortPick(): void {
        _pendingPick = "";
        _pickTransition = false;
        _applySucceeded = false;
        _irisFinished = false;
        _bloomStarted = false;
        transition.abort();
        if (shown && !_closing)
            carousel.cancelPick();
    }
    function apply(path: string): string {
        if (path === "" || busy || _closing)
            return "";
        _pendingPick = path;
        carousel.interactive = false;
        if (!Wallpaper.apply(path)) {
            _pendingPick = "";
            carousel.interactive = true;
            return "";
        }
        watchdog.restart();
        return path;
    }
    function maybeStartBloom(): void {
        if (!_pickTransition || _bloomStarted || !_applySucceeded || !_irisFinished)
            return;
        if (Theme.wallpaper !== _pendingPick)
            return;
        _bloomStarted = true;
        transition.startBloom();
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
        onTriggered: if (!picker._closing)
            picker._carouselVisible = true
    }

    Connections {
        target: Wallpaper
        function onApplied(path: string): void {
            if (path !== picker._pendingPick)
                return;
            if (!picker._pickTransition) {
                picker._pendingPick = "";
                picker.startClose();
                return;
            }
            picker._applySucceeded = true;
            picker.maybeStartBloom();
        }
        function onApplyFailed(path: string): void {
            if (path !== picker._pendingPick)
                return;
            if (picker._pickTransition) {
                picker.abortPick();
                return;
            }
            picker._pendingPick = "";
            if (!picker.shown || picker._closing)
                return;
            carousel.interactive = true;
            Qt.callLater(() => carousel.forceActiveFocus());
        }
    }

    Connections {
        target: Theme
        function onWallpaperChanged(): void {
            picker.maybeStartBloom();
        }
    }

    screen: Quickshell.screens[0] ?? null
    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown

    WlrLayershell.namespace: "harmonica:wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // Only the carousel band receives pointer input; the visible dim layer
    // itself is click-through outside that band.
    mask: Region {
        item: inputRegion
    }

    Shortcut {
        sequence: "Escape"
        enabled: shown
        onActivated: picker.close()
    }

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
            onSelected: path => picker.beginPick(path)
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

    PickTransition {
        id: transition
        anchors.fill: parent
        onZoomFinished: startIris()
        onImagesReady: {
            if (!Wallpaper.apply(picker._pendingPick))
                picker.abortPick();
        }
        onIrisFinished: {
            picker._irisFinished = true;
            picker.maybeStartBloom();
        }
        onBloomFinished: {
            picker._pendingPick = "";
            picker._pickTransition = false;
            transition.finish();
            picker.close();
        }
        onLoadFailed: picker.abortPick()
    }

    Timer {
        id: watchdog
        interval: Theme.wallpaperWatchdogMs
        onTriggered: {
            Wallpaper.cancelApply();
            picker.abortPick();
            picker.startClose();
        }
    }

    onShownChanged: if (!shown) {
        transition.abort();
        carousel.cancelPick();
        _pendingPick = "";
        _pickTransition = false;
    }
}
