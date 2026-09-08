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
    property bool _applyDone: false
    property bool _waitClose: false
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
        _carouselVisible = true;
        carousel.interactive = false;
        carousel.resetToCurrent();
        carousel.enter();
        revealClose.stop();
        revealOpen.from = Math.max(closedScale, revealProgress);
        revealOpen.restart();
        watchdog.restart();
    }

    function close(): void {
        if (!shown || _closing || busy)
            return;
        startClose();
    }
    function startClose(): void {
        _closing = true;
        carousel.interactive = false;
        carousel.velocity = 0;
        revealOpen.stop();
        carousel.exit();
    }
    function beginRevealClose(): void {
        if (!carousel.pickClosing)
            _carouselVisible = false;
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
        if (!shown || busy || _closing)
            return "";
        return carousel.pick();
    }
    // Beats run in the carousel; wal/awww apply fires on shrinkDone (beat 4)
    // so the re-theme lands in parallel with check + close.
    function beginPick(path: string): string {
        if (!shown || path === "" || _closing || _pickTransition || Wallpaper.applying) {
            if (shown && !_closing)
                carousel.abortPickSequence();
            return "";
        }
        _pendingPick = path;
        _pickTransition = true;
        _applyDone = false;
        _waitClose = false;
        carousel.interactive = false;
        watchdog.restart();
        carousel.beginPickSequence();
        return path;
    }

    function fireApply(): void {
        if (!_pickTransition || _closing || _pendingPick === "")
            return;
        if (!Wallpaper.apply(_pendingPick))
            abortPick();
    }

    function abortPick(): void {
        if (_closing) return;
        Wallpaper.cancelApply();
        _pendingPick = "";
        _pickTransition = false;
        _applyDone = false;
        _waitClose = false;
        if (shown)
            carousel.abortPickSequence();
    }

    // Beats 1-4 done: exit slots + shrink dim TOGETHER (~400ms),
    // unless wal is still running — then applied/failed closes for us.
    function finishPick(): void {
        if (!shown) {
            // beats outlived the surface — drop flags, never strand busy
            _pendingPick = "";
            _pickTransition = false;
            _waitClose = false;
            return;
        }
        if (_closing) return;
        _pendingPick = "";
        _pickTransition = false;
        if (_applyDone || !Wallpaper.applying) doPickClose();
        else _waitClose = true;
    }

    // light pick close: dim shrinks while the picked card melts outward
    // into the new wallpaper (melt outlives the dim, no blink-out)
    function doPickClose(): void {
        if (!shown || _closing) return;
        _closing = true;
        carousel.interactive = false;
        carousel.velocity = 0;
        carousel.pickClosing = true;
        revealOpen.stop();
        carousel.exit();
        carousel.meltOut();
        beginRevealClose();
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
            if (carousel.pickClosing) return;   // melt tail hides us instead
            picker._showing = false;
            picker._closing = false;
            watchdog.stop();
        }
    }

    Connections {
        target: Wallpaper
        function onApplied(path: string): void {
            if (path !== picker._pendingPick && !picker._waitClose)
                return;
            picker._applyDone = true;
            picker._pendingPick = "";
            if (picker._waitClose) {
                picker._waitClose = false;
                picker.finishPick();
            } else if (!picker._pickTransition) {
                picker.startClose();
            }
        }
        function onApplyFailed(path: string): void {
            if (path !== picker._pendingPick && !picker._waitClose)
                return;
            if (picker._waitClose) {
                // beats already played but nothing applied — still melt out
                picker._waitClose = false;
                picker._pickTransition = false;
                picker._pendingPick = "";
                picker.doPickClose();
            } else {
                picker.abortPick();
            }
        }
    }

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
        visible: picker._carouselVisible

        Carousel {
            id: carousel
            anchors.fill: parent
            onSelected: path => picker.beginPick(path)
            onEntered: {
                if (!picker._closing) {
                    carousel.interactive = true;
                    Qt.callLater(() => carousel.forceActiveFocus());
                }
            }
            onExited: if (picker._closing && !carousel.pickClosing)
                picker.beginRevealClose()
            onPickFinished: picker.finishPick()
            onShrinkDone: picker.fireApply()
            onMeltDone: {
                picker._carouselVisible = false;
                picker._showing = false;
                picker._closing = false;
                watchdog.stop();
            }
        }

        Text {
            font.family: Theme.fontText
            visible: !carousel.pickClosing
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
        onTriggered: {
            Wallpaper.cancelApply();
            picker.abortPick();
            picker.startClose();
        }
    }

    onShownChanged: if (!shown) {
        carousel.abortPickSequence();
        _pendingPick = "";
        _pickTransition = false;
        _applyDone = false;
        _waitClose = false;
    }
}
