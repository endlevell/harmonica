import QtQuick
import QtQuick.Effects
import qs.Common
import qs.Services

// Virtualized infinite coverflow. A large circular ListView is centered at
// 5000; delegate wallpaper paths are modulo-mapped to the real model. The
// active slot is recentered long before an edge can become visible.
Item {
    id: root

    signal selected(string path)

    readonly property int count: Wallpaper.count
    readonly property int focusedWallpaperIndex: count > 0
        ? mod(list.currentIndex, count) : -1
    readonly property string focusedPath: focusedWallpaperIndex >= 0
        ? Wallpaper.wallpapers[focusedWallpaperIndex] : ""
    property bool interactive: true
    property real velocity: 0

    function mod(value: int, n: int): int {
        return ((value % n) + n) % n;
    }

    function resetToCurrent(): void {
        if (count === 0) return;
        const wanted = Math.max(0, Wallpaper.wallpapers.indexOf(Wallpaper.current));
        const base = Theme.wallpaperVirtualCenter;
        const shift = mod(wanted - mod(base, count), count);
        list.currentIndex = base + shift;
        Qt.callLater(() => list.positionViewAtIndex(list.currentIndex, ListView.Center));
        Qt.callLater(() => list.forceActiveFocus());
    }

    function recenterIfNeeded(): void {
        if (count === 0) return;
        if (list.currentIndex > Theme.wallpaperVirtualCenter / 2
                && list.currentIndex < Theme.wallpaperVirtualCenter * 1.5) return;
        const wallpaperIndex = mod(list.currentIndex, count);
        const base = Theme.wallpaperVirtualCenter;
        const shift = mod(wallpaperIndex - mod(base, count), count);
        list.currentIndex = base + shift;
        list.positionViewAtIndex(list.currentIndex, ListView.Center);
    }

    function glide(steps: int): void {
        if (!interactive || count === 0) return;
        velocity += steps * Theme.wallpaperArrowImpulse;
        momentum.restart();
    }

    function pick(): string {
        if (!interactive || focusedPath === "") return "";
        const path = focusedPath;       // signal handlers may mutate bindings
        selected(path);
        return path;
    }

    Keys.onLeftPressed: glide(-1)
    Keys.onRightPressed: glide(1)
    Keys.onReturnPressed: pick()
    Keys.onEnterPressed: pick()

    WheelHandler {
        enabled: root.interactive
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => {
            if (!root.interactive) return;
            if (Math.abs(event.pixelDelta.y) === 0 && Math.abs(event.angleDelta.y) >= 120) {
                list.currentIndex += event.angleDelta.y > 0 ? -1 : 1;
                root.recenterIfNeeded();
                return;
            }
            const raw = event.pixelDelta.y / Theme.wallpaperCardPitch;
            root.velocity += -raw * Theme.wallpaperWheelStep;
            momentum.restart();
        }
    }

    Timer {
        id: momentum
        interval: Theme.carouselTickMs
        repeat: true
        onTriggered: {
            if (!root.interactive) { stop(); root.velocity = 0; return; }
            list.contentX += root.velocity * Theme.wallpaperCardPitch * 0.18;
            root.velocity *= Theme.wallpaperMomentumDecay;
            if (Math.abs(root.velocity) < Theme.wallpaperMomentumStop) {
                stop();
                root.velocity = 0;
                list.currentIndex = list.indexAt(list.width / 2 + list.contentX, list.height / 2);
                if (list.currentIndex < 0)
                    list.currentIndex = Math.round(list.contentX / Theme.wallpaperCardPitch);
                root.recenterIfNeeded();
            }
        }
    }

    Text {
        anchors.centerIn: parent
        visible: root.count === 0
        text: "No wallpapers found"
        color: Theme.dimText
        font.pixelSize: Theme.fontSm
    }

    ListView {
        id: list
        anchors.fill: parent
        orientation: ListView.Horizontal
        model: root.count > 0 ? Theme.wallpaperVirtualCount : 0
        interactive: root.interactive
        clip: false
        cacheBuffer: Theme.wallpaperCardPitch * 3
        boundsBehavior: Flickable.StopAtBounds
        flickDeceleration: 3200
        maximumFlickVelocity: 5500
        snapMode: ListView.SnapToItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: width / 2 - Theme.wallpaperCardPitch / 2
        preferredHighlightEnd: preferredHighlightBegin
        highlightMoveDuration: Theme.durCarousel

        onMovementEnded: root.recenterIfNeeded()
        onCurrentIndexChanged: root.recenterIfNeeded()

        delegate: Item {
            id: slot
            required property int index

            width: Theme.wallpaperCardPitch
            height: list.height
            z: 100 - Math.round(absDistance * 10)

            readonly property real centerInView: x + width / 2 - list.contentX
            readonly property real distance: (centerInView - list.width / 2)
                / Theme.wallpaperCardPitch
            readonly property real absDistance: Math.abs(distance)
            readonly property string imagePath: Wallpaper.wallpapers[root.mod(index, root.count)]

            Item {
                id: card
                width: Theme.wallpaperCardW
                height: Theme.wallpaperCardH
                anchors.centerIn: parent
                // Nonlinear counter-offset: distant cards lag behind the
                // focused card while the ListView itself moves uniformly.
                anchors.horizontalCenterOffset: -slot.distance * Theme.spaceMd
                    * Math.min(slot.absDistance, 2)
                anchors.verticalCenterOffset: slot.absDistance * Theme.wallpaperArcRise
                scale: 1 - 0.18 * Math.min(slot.absDistance, 3) / 3
                opacity: 1 - 0.55 * Math.min(slot.absDistance, 3) / 3

                transform: Matrix4x4 {
                    matrix: {
                        const shear = -0.16 - Math.min(slot.absDistance, 3) * 0.045;
                        return Qt.matrix4x4(
                            1, shear, 0, -shear * card.height / 2,
                            0, 1, 0, 0,
                            0, 0, 1, 0,
                            0, 0, 0, 1);
                    }
                }

                Item {
                    id: sourceItem
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        anchors.fill: parent
                        color: Theme.surface
                    }

                    Image {
                        anchors.fill: parent
                        anchors.leftMargin: -Theme.wallpaperParallaxShift
                            - slot.distance * Theme.wallpaperParallaxShift
                        anchors.rightMargin: -Theme.wallpaperParallaxShift
                            + slot.distance * Theme.wallpaperParallaxShift
                        source: slot.imagePath
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Theme.wallpaperCardW * 2
                        sourceSize.height: Theme.wallpaperCardH * 2
                    }

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: Theme.spaceSm
                        text: Wallpaper.basename(slot.imagePath)
                        width: parent.width - Theme.spaceLg * 2
                        color: Theme.foreground
                        font.pixelSize: Theme.fontXs
                        elide: Text.ElideRight
                        horizontalAlignment: Text.AlignHCenter
                        style: Text.Outline
                        styleColor: Theme.background
                    }
                }

                Rectangle {
                    id: roundedMask
                    anchors.fill: parent
                    radius: Theme.radiusMd
                    color: Theme.foreground
                    visible: false
                    layer.enabled: true
                    antialiasing: true
                }

                MultiEffect {
                    anchors.fill: parent
                    source: sourceItem
                    maskEnabled: true
                    maskSource: roundedMask
                    antialiasing: true
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusMd
                    color: "transparent"
                    border.width: mouse.containsMouse && slot.absDistance < 0.5
                        ? Theme.spaceXs / 2 : 0
                    border.color: Theme.primary
                }

                MouseArea {
                    id: mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: root.interactive && slot.absDistance < 2.5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (slot.absDistance >= 0.5) {
                            list.currentIndex = slot.index;
                            return;
                        }
                        root.pick();
                    }
                }
            }
        }
    }

    Component.onCompleted: resetToCurrent()
    Connections {
        target: Wallpaper
        function onWallpapersChanged(): void { root.resetToCurrent(); }
    }
}
