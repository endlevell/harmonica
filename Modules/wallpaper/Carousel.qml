import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

// Exactly seven persistent logical slots. Only an offscreen slot is recycled,
// so crossing an index never swaps all delegate content at once.
Item {
    id: root

    signal selected(string path)

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
    readonly property real maxShear: Math.abs(Theme.wallpaperShearBase + half * Theme.wallpaperShearPerStep)
    readonly property real cardHeight: Math.min(Theme.wallpaperCardMaxH, (availableWidth - Theme.wallpaperGap * (Theme.wallpaperVisibleCount - 1)) / (Theme.wallpaperVisibleCount * (maxAspect + maxShear)))
    readonly property real pitch: cardHeight * (maxAspect + maxShear) + Theme.wallpaperGap

    property int baseWallpaper: 0
    property real offset: 0
    property real velocity: 0
    property bool interactive: true
    property bool picking: false
    property real pickProgress: 0
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
        if (count === 0)
            return;
        baseWallpaper = Math.max(0, Wallpaper.wallpapers.indexOf(Wallpaper.current));
        offset = 0;
        velocity = 0;
        picking = false;
        pickProgress = 0;
        resetSlots();
        Qt.callLater(() => root.forceActiveFocus());
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
        settle.stop();
        velocity += steps * Theme.wallpaperArrowImpulse;
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
        picking = true;
        pickProgress = 0;
        selected(path);
        return path;
    }
    function cancelPick(): void {
        pickZoom.stop();
        picking = false;
        pickProgress = 0;
        interactive = true;
        Qt.callLater(() => root.forceActiveFocus());
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
            settle.stop();
            const raw = Math.abs(event.pixelDelta.y) > 0 ? event.pixelDelta.y / Math.max(1, root.pitch) : event.angleDelta.y / 120;
            root.velocity += -raw * Theme.wallpaperWheelStep;
            momentum.restart();
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
        id: pickZoom
        target: root
        property: "pickProgress"
        duration: Theme.durWallpaperZoom
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeTwitch
    }
    onPickingChanged: if (picking)
        pickZoom.restart()

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
            readonly property real fadeAmount: Math.max(0, Math.min(1, (absDistance - 2) / 1.15))

            width: root.pitch
            height: root.height
            x: root.width / 2 - width / 2 + distance * root.pitch - distance * Theme.spaceMd * Math.min(absDistance, 2) + (root.picking && !chosen ? Math.sign(distance) * root.width * 0.38 * root.pickProgress : 0)
            z: chosen ? 200 : 100 - Math.round(absDistance * 10)

            Item {
                id: card
                width: slot.nativeWidth
                height: root.cardHeight
                anchors.centerIn: parent
                anchors.verticalCenterOffset: slot.absDistance * Theme.wallpaperArcRise
                scale: 1 - 0.18 * Math.min(slot.absDistance, 3) / 3
                opacity: (1 - 0.48 * Math.min(slot.absDistance, 3) / 3) * (root.picking ? 1 - root.pickProgress : 1)

                transform: Matrix4x4 {
                    matrix: {
                        const shear = Theme.wallpaperShearBase + Math.min(slot.absDistance, 3) * Theme.wallpaperShearPerStep;
                        return Qt.matrix4x4(1, shear, 0, -shear * card.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
                    }
                }

                Item {
                    id: imageSource
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.surface
                    }
                    Image {
                        anchors.fill: parent
                        source: slot.imagePath
                        fillMode: Image.PreserveAspectFit
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
                    blurEnabled: root.picking && !slot.chosen
                    blur: root.pickProgress * Theme.wallpaperPickBlur
                    blurMax: Theme.wallpaperBlurMax
                    antialiasing: true
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
