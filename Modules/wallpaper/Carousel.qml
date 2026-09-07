import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

// Exactly nine persistent logical slots. Only an offscreen slot is recycled,
// so crossing an index never swaps all delegate content at once.
Item {
    id: root

    signal selected(string path)
    signal entered
    signal exited
    signal pickFinished
    signal shrinkDone
    signal meltDone

    readonly property int count: Wallpaper.count
    readonly property int half: Math.floor(Theme.wallpaperVisibleCount / 2)
    readonly property int focusedKey: Math.round(offset)
    readonly property int focusedWallpaperIndex: count > 0 ? mod(baseWallpaper + focusedKey, count) : -1
    readonly property string focusedPath: focusedWallpaperIndex >= 0 ? Wallpaper.wallpapers[focusedWallpaperIndex] : ""
    readonly property real focusedAspect: focusedWallpaperIndex >= 0 ? ratioFor(focusedWallpaperIndex) : Theme.wallpaperDefaultAspect
    readonly property real focusedCardWidth: cardHeight * focusedAspect
    readonly property real availableWidth: Math.max(1, width - Theme.spaceXl * 2)
    readonly property real maxAspect: {
        let value = Theme.wallpaperDefaultAspect;
        for (let i = 0; i < count; i++)
            value = Math.max(value, ratioFor(i));
        return value;
    }
    readonly property real maxShear: Math.abs(Theme.wallpaperShearBase)
    readonly property real cardHeight: Math.min(Theme.wallpaperCardMaxH, availableWidth / (Theme.wallpaperVisibleCount * Theme.wallpaperStackStepRatio + maxAspect * Theme.wallpaperFocusScale + maxShear))
    readonly property real pitch: cardHeight * Theme.wallpaperStackStepRatio

    property int baseWallpaper: 0
    property real offset: 0
    property real velocity: 0
    property bool interactive: true
    property bool picking: false
    property real activeZoom: 1
    property real checkIn: 0
    property bool pickClosing: false
    property real activeGone: 0
    property var aspectRatios: ({})

    function mod(value: int, n: int): int {
        return ((value % n) + n) % n;
    }
    function ratioFor(index: int): real {
        const path = index >= 0 && index < count ? Wallpaper.wallpapers[index] : "";
        const value = aspectRatios[path];
        return value > 0 ? value : Theme.wallpaperDefaultAspect;
    }
    function setRatio(path: string, ratio: real): void {
        if (path === "" || !(ratio > 0) || aspectRatios[path] === ratio)
            return;
        const copy = Object.assign({}, aspectRatios);
        copy[path] = ratio;
        aspectRatios = copy;
    }
    function resetSlots(): void {
        for (let i = 0; i < slots.count; i++) {
            const item = slots.itemAt(i);
            if (item)
                item.logicalKey = i - half;
        }
    }
    function resetToCurrent(): void {
        momentum.stop();
        settle.stop();
        abortPickTimers();
        picking = false;
        pickClosing = false;
        activeZoom = 1;
        activeGone = 0;
        checkIn = 0;
        if (count === 0)
            return;
        baseWallpaper = Math.max(0, Wallpaper.wallpapers.indexOf(Wallpaper.current));
        offset = 0;
        velocity = 0;
        resetSlots();
        for (let i = 0; i < slots.count; i++) {
            const item = slots.itemAt(i);
            if (item) item.scatterReset();
        }
        Qt.callLater(() => root.forceActiveFocus());
    }
    function enter(): void {
        exitDone.stop();
        for (let i = 0; i < slots.count; i++) {
            const item = slots.itemAt(i);
            if (item)
                item.animateIn();
        }
        enterDone.restart();
    }
    function exit(): void {
        enterDone.stop();
        for (let i = 0; i < slots.count; i++) {
            const item = slots.itemAt(i);
            if (item)
                item.animateOut();
        }
        exitDone.restart();
    }
    function recycleSlots(): void {
        const limit = half + 0.5;
        for (let i = 0; i < slots.count; i++) {
            const item = slots.itemAt(i);
            if (!item)
                continue;
            while (item.logicalKey - offset > limit)
                item.logicalKey -= Theme.wallpaperVisibleCount;
            while (item.logicalKey - offset < -limit)
                item.logicalKey += Theme.wallpaperVisibleCount;
        }
    }
    function glide(steps: int): void {
        if (!interactive || count === 0)
            return;
        applyImpulse(steps * Theme.wallpaperArrowImpulse);
    }
    function applyImpulse(impulse: real): void {
        if (!interactive || impulse === 0)
            return;
        settle.stop();
        if (velocity * impulse < 0)
            velocity = 0;
        velocity += impulse;
        momentum.restart();
    }
    function focusKey(key: int): void {
        if (!interactive)
            return;
        momentum.stop();
        settle.stop();
        velocity = 0;
        settle.from = offset;
        settle.to = key;
        settle.restart();
    }
    function pick(): string {
        if (!interactive || focusedPath === "")
            return "";
        momentum.stop();
        settle.stop();
        velocity = 0;
        const path = focusedPath;
        interactive = false;
        selected(path);
        return path;
    }
    // Five-beat pick sequence driver (timings in Theme):
    // expand + scatter start together → shrink → solo check → pickFinished.
    // Scattered cards STAY gone; the picker fires Wallpaper.apply on shrinkDone.
    function beginPickSequence(): void {
        if (picking) return;
        picking = true;
        activeZoom = 1;
        checkIn = 0;
        expandZoom.restart();
        for (let i = 0; i < slots.count; i++) {
            const item = slots.itemAt(i);
            if (item) item.scatterOut();
        }
        shrinkTimer.restart();
    }
    function abortPickSequence(): void {
        abortPickTimers();
        picking = false;
        pickClosing = false;
        activeZoom = 1;
        activeGone = 0;
        checkIn = 0;
        for (let i = 0; i < slots.count; i++) {
            const item = slots.itemAt(i);
            if (item) item.scatterReset();
        }
        interactive = true;
        Qt.callLater(() => root.forceActiveFocus());
    }
    function abortPickTimers(): void {
        shrinkTimer.stop();
        finishTimer.stop();
        expandZoom.stop();
        shrinkZoom.stop();
        checkSeq.stop();
        meltAnim.stop();
    }
    // pick-close exit: the chosen card swells and dissolves into the new
    // wallpaper behind the lifting dim (outlives revealClose — no blink-out)
    function meltOut(): void {
        meltAnim.restart();
    }
    NumberAnimation {
        id: meltAnim
        target: root
        property: "activeGone"
        to: 1
        duration: Theme.durWallpaperPickMelt
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeDecel
        onFinished: { root.pickClosing = false; root.meltDone(); }
    }

    onOffsetChanged: recycleSlots()
    Keys.onLeftPressed: glide(-1)
    Keys.onRightPressed: glide(1)
    Keys.onReturnPressed: pick()
    Keys.onEnterPressed: pick()

    WheelHandler {
        enabled: root.interactive
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            const raw = Math.abs(event.pixelDelta.y) > 0 ? event.pixelDelta.y / Math.max(1, root.pitch) : event.angleDelta.y / 120;
            root.applyImpulse(-raw * Theme.wallpaperWheelStep);
        }
    }

    Timer {
        id: momentum
        interval: Theme.carouselTickMs
        repeat: true
        onTriggered: {
            if (!root.interactive) {
                stop();
                root.velocity = 0;
                return;
            }
            root.offset += root.velocity * 0.18;
            root.velocity *= Theme.wallpaperMomentumDecay;
            if (Math.abs(root.velocity) < Theme.wallpaperMomentumStop) {
                stop();
                root.velocity = 0;
                settle.from = root.offset;
                settle.to = Math.round(root.offset);
                settle.restart();
            }
        }
    }

    NumberAnimation {
        id: settle
        target: root
        property: "offset"
        duration: Theme.durCarousel
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeDecel
    }
    NumberAnimation {
        id: expandZoom
        target: root
        property: "activeZoom"
        from: 1
        to: Theme.wallpaperPickExpandScale
        duration: Theme.durWallpaperPickExpand
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeMorphExpand
    }
    // scatter clears (stagger + glide) just as expand lands — no dead time
    Timer {
        id: shrinkTimer
        interval: (root.half - 1) * Theme.wallpaperPickStaggerMs + Theme.durWallpaperPickScatter
        onTriggered: shrinkZoom.restart()
    }
    NumberAnimation {
        id: shrinkZoom
        target: root
        property: "activeZoom"
        to: 1
        duration: Theme.durWallpaperPickShrink
        easing.type: Easing.OutCubic
        onFinished: {
            checkSeq.restart();
            finishTimer.restart();
            root.shrinkDone();
        }
    }
    SequentialAnimation {
        id: checkSeq
        NumberAnimation { target: root; property: "checkIn"; to: 1; duration: Theme.durWallpaperPickCheck / 2; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "checkIn"; to: 0; duration: Theme.durWallpaperPickCheck / 2; easing.type: Easing.InCubic }
    }
    Timer {
        id: finishTimer
        interval: Theme.durWallpaperPickCheck
        onTriggered: { root.picking = false; root.pickFinished(); }
    }

    Timer {
        id: enterDone
        interval: Theme.durWallpaperItemEnter + root.half * Theme.wallpaperStaggerMs
        onTriggered: root.entered()
    }
    Timer {
        id: exitDone
        interval: Theme.durWallpaperItemExit + root.half * Theme.wallpaperStaggerMs
        onTriggered: root.exited()
    }

    // Metadata probes: natural source ratio only, never drawn.
    Repeater {
        model: root.count
        Image {
            required property int index
            source: Wallpaper.wallpapers[index]
            sourceSize.width: 64
            cache: false
            visible: false
            asynchronous: true
            onStatusChanged: if (status === Image.Ready && sourceSize.height > 0)
                root.setRatio(Wallpaper.wallpapers[index], sourceSize.width / sourceSize.height)
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.count === 0
        text: "No wallpapers found"
        color: Theme.dimText
        font.pixelSize: Theme.fontSm
    }

    Repeater {
        id: slots
        model: Theme.wallpaperVisibleCount

        delegate: Item {
            id: slot
            required property int index
            property int logicalKey: index - root.half
            readonly property real distance: logicalKey - root.offset
            readonly property real absDistance: Math.abs(distance)
            readonly property int wallpaperIndex: root.count > 0 ? root.mod(root.baseWallpaper + logicalKey, root.count) : -1
            readonly property string imagePath: wallpaperIndex >= 0 ? Wallpaper.wallpapers[wallpaperIndex] : ""
            readonly property real aspect: wallpaperIndex >= 0 ? root.ratioFor(wallpaperIndex) : Theme.wallpaperDefaultAspect
            readonly property real nativeWidth: root.cardHeight * aspect
            readonly property bool chosen: logicalKey === root.focusedKey
            readonly property real fadeAmount: Math.max(0, Math.min(1, absDistance - 2))
            property real revealProgress: 0
            property real scatter: 0

            function animateIn(): void {
                exitDelay.stop();
                exitAnimation.stop();
                enterDelay.stop();
                enterAnimation.stop();
                revealProgress = 0;
                enterDelay.restart();
            }
            function animateOut(): void {
                if (root.pickClosing && slot.chosen) return;
                enterDelay.stop();
                enterAnimation.stop();
                exitDelay.stop();
                exitAnimation.stop();
                exitDelay.restart();
            }
            // dealt-cards scatter, one way only: outward slide + tilt + fade,
            // staggered innermost-first — swept off the table, they stay gone
            function scatterOut(): void {
                if (slot.chosen) return;
                scatterOutAnim.stop();
                scatterDelay.interval = (Math.round(slot.absDistance) - 1) * Theme.wallpaperPickStaggerMs;
                scatterDelay.restart();
            }
            function scatterReset(): void {
                scatterDelay.stop();
                scatterOutAnim.stop();
                scatter = 0;
            }
            Timer {
                id: scatterDelay
                onTriggered: scatterOutAnim.restart()
            }
            NumberAnimation {
                id: scatterOutAnim
                target: slot
                property: "scatter"
                to: 1
                duration: Theme.durWallpaperPickScatter
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeDecel
            }

            width: root.pitch
            height: root.height
            x: root.width / 2 - width / 2 + distance * root.pitch + Math.sign(distance) * Theme.wallpaperEntranceShift * (1 - revealProgress) + (!slot.chosen ? Math.sign(slot.distance) * root.width * Theme.wallpaperPickScatterTravel * slot.scatter : 0)
            z: chosen ? 1000 : 900 - Math.round(absDistance * 100)
            rotation: slot.chosen ? 0 : Math.sign(slot.distance) * Theme.wallpaperPickScatterTilt * slot.scatter
            transformOrigin: Item.Center

            Timer {
                id: enterDelay
                interval: Math.round(slot.absDistance) * Theme.wallpaperStaggerMs
                onTriggered: enterAnimation.restart()
            }
            NumberAnimation {
                id: enterAnimation
                target: slot
                property: "revealProgress"
                to: 1
                duration: Theme.durWallpaperItemEnter
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeDecel
            }
            Timer {
                id: exitDelay
                interval: (root.half - Math.round(slot.absDistance)) * Theme.wallpaperStaggerMs
                onTriggered: exitAnimation.restart()
            }
            NumberAnimation {
                id: exitAnimation
                target: slot
                property: "revealProgress"
                to: 0
                duration: Theme.durWallpaperItemExit
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Theme.easeAccel
            }

            Item {
                id: card
                width: slot.nativeWidth
                height: root.cardHeight
                anchors.centerIn: parent
                anchors.verticalCenterOffset: slot.absDistance * Theme.wallpaperArcRise + (1 - slot.revealProgress) * Theme.spaceXl
                scale: (Theme.wallpaperOuterScale + (Theme.wallpaperFocusScale - Theme.wallpaperOuterScale) * (1 - Math.min(slot.absDistance, root.half) / root.half)) * (slot.chosen ? root.activeZoom * (1 + Theme.wallpaperPickMeltGrow * root.activeGone) : 1)
                opacity: Math.max(Theme.wallpaperEdgeOpacity, 1 - slot.absDistance * Theme.wallpaperDepthOpacityStep) * slot.revealProgress * (slot.chosen ? 1 - root.activeGone : 1 - slot.scatter)

                transform: Matrix4x4 {
                    matrix: {
                        const shear = Theme.wallpaperShearBase + Math.min(slot.absDistance, 3) * Theme.wallpaperShearPerStep;
                        return Qt.matrix4x4(1, shear, 0, -shear * card.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
                    }
                }

                RectangularShadow {
                    anchors.fill: parent
                    visible: slot.chosen
                    radius: Theme.radiusMd
                    blur: Theme.wallpaperFocusShadowBlur
                    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, Theme.wallpaperFocusShadowOpacity)
                    offset: Qt.vector2d(0, Theme.spaceMd)
                    z: -1
                }

                Item {
                    id: imageSource
                    anchors.fill: parent
                    clip: true
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.surface
                    }
                    Image {
                        anchors.verticalCenter: parent.verticalCenter
                        x: -Theme.wallpaperParallaxOverscan - slot.distance * Theme.wallpaperParallaxShift
                        width: parent.width + Theme.wallpaperParallaxOverscan * 2
                        height: parent.height
                        source: slot.imagePath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Math.round(slot.nativeWidth * 2)
                        sourceSize.height: Math.round(root.cardHeight * 2)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.spaceSm
                        width: parent.width - Theme.spaceLg * 2
                        text: Wallpaper.basename(slot.imagePath)
                        color: Theme.foreground
                        font.pixelSize: Theme.fontXs
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        style: Text.Outline
                        styleColor: Theme.background
                    }
                }

                Rectangle {
                    id: cardMask
                    anchors.fill: parent
                    radius: Theme.radiusMd
                    visible: false
                    layer.enabled: true
                    antialiasing: true
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop {
                            position: 0
                            color: slot.distance < 0 ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 1 - slot.fadeAmount) : Theme.foreground
                        }
                        GradientStop {
                            position: 0.26
                            color: Theme.foreground
                        }
                        GradientStop {
                            position: 0.74
                            color: Theme.foreground
                        }
                        GradientStop {
                            position: 1
                            color: slot.distance > 0 ? Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 1 - slot.fadeAmount) : Theme.foreground
                        }
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: imageSource
                    maskEnabled: true
                    maskSource: cardMask
                    antialiasing: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMd
                    color: "transparent"
                    border.width: slot.chosen ? Theme.spaceXs / 2 : 0
                    border.color: Theme.background
                    antialiasing: true
                }

                // pick-confirm badge: flat colorOk disc + painted check, no chrome
                Item {
                    visible: slot.chosen && root.checkIn > 0.001
                    width: Theme.wallpaperPickCheckSize
                    height: Theme.wallpaperPickCheckSize
                    anchors.centerIn: parent
                    z: 50
                    opacity: root.checkIn

                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: Theme.colorOk
                    }
                    Canvas {
                        anchors.fill: parent
                        antialiasing: true
                        onVisibleChanged: if (visible) requestPaint()
                        Component.onCompleted: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.clearRect(0, 0, width, height);
                            ctx.strokeStyle = Theme.background.toString();
                            ctx.lineWidth = Math.max(2, width * 0.14);
                            ctx.lineCap = "round";
                            ctx.lineJoin = "round";
                            ctx.beginPath();
                            ctx.moveTo(width * 0.30, height * 0.55);
                            ctx.lineTo(width * 0.45, height * 0.69);
                            ctx.lineTo(width * 0.71, height * 0.32);
                            ctx.stroke();
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: root.interactive
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: slot.chosen ? root.pick() : root.focusKey(slot.logicalKey)
                }
            }
        }
    }

    Component.onCompleted: resetToCurrent()
    Connections {
        target: Wallpaper
        function onWallpapersChanged(): void {
            root.resetToCurrent();
        }
    }
}
