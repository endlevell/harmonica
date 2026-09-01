import QtQuick
import QtQuick.Effects
import qs.Common

// Three-beat wallpaper pick feedback:
// 1) native-ratio spring zoom, 2) circular textured iris + ripple,
// 3) one horizontal Theme-palette bloom.
Item {
    id: root

    signal zoomFinished
    signal irisFinished
    signal bloomFinished
    signal imagesReady
    signal loadFailed

    property string imagePath: ""
    property real sourceAspect: Theme.wallpaperDefaultAspect
    property real startWidth: 1
    property real startHeight: 1
    property bool active: false
    property real zoomProgress: 0
    property real irisProgress: 0
    property real bloomProgress: 0
    property bool _waitingForImages: false

    readonly property real coverHeight: Math.max(height, width / Math.max(0.01, sourceAspect))
    readonly property real coverWidth: coverHeight * sourceAspect

    function start(path: string, aspect: real, cardW: real, cardH: real): void {
        imagePath = path;
        sourceAspect = aspect > 0 ? aspect : Theme.wallpaperDefaultAspect;
        startWidth = Math.max(1, cardW);
        startHeight = Math.max(1, cardH);
        zoomProgress = 0;
        irisProgress = 0;
        bloomProgress = 0;
        active = true;
        _waitingForImages = true;
        maybeStartZoom();
    }
    function maybeStartZoom(): void {
        if (!_waitingForImages || zoomSource.status !== Image.Ready || irisSource.status !== Image.Ready)
            return;
        _waitingForImages = false;
        imagesReady();
        if (active)
            zoom.restart();
    }
    function failLoad(): void {
        if (!_waitingForImages)
            return;
        _waitingForImages = false;
        loadFailed();
    }

    function startIris(): void {
        iris.restart();
    }
    function startBloom(): void {
        bloom.restart();
    }
    function finish(): void {
        zoom.stop();
        iris.stop();
        bloom.stop();
        _waitingForImages = false;
        active = false;
    }
    function abort(): void {
        zoom.stop();
        iris.stop();
        bloom.stop();
        _waitingForImages = false;
        active = false;
        zoomProgress = irisProgress = bloomProgress = 0;
    }

    visible: active
    z: 1000

    // Beat 1 — source card expands with native aspect and de-shears.
    Item {
        id: zoomCard
        anchors.centerIn: parent
        width: root.startWidth + (root.coverWidth - root.startWidth) * root.zoomProgress
        height: root.startHeight + (root.coverHeight - root.startHeight) * root.zoomProgress
        visible: root.zoomProgress < 1

        transform: Matrix4x4 {
            matrix: {
                const shear = Theme.wallpaperShearBase * (1 - root.zoomProgress);
                return Qt.matrix4x4(1, shear, 0, -shear * zoomCard.height / 2, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
            }
        }

        Image {
            id: zoomSource
            anchors.fill: parent
            source: root.imagePath
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            visible: false
            layer.enabled: true
            onStatusChanged: {
                if (status === Image.Ready)
                    root.maybeStartZoom();
                else if (status === Image.Error)
                    root.failLoad();
            }
        }

        Rectangle {
            id: zoomMask
            anchors.fill: parent
            radius: Theme.radiusMd * (1 - root.zoomProgress)
            color: Theme.foreground
            visible: false
            layer.enabled: true
            antialiasing: true
        }

        MultiEffect {
            anchors.fill: parent
            source: zoomSource
            maskEnabled: true
            maskSource: zoomMask
            antialiasing: true
        }
    }

    NumberAnimation {
        id: zoom
        target: root
        property: "zoomProgress"
        from: 0
        to: 1
        duration: Theme.durWallpaperZoom
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeTwitch
        onFinished: root.zoomFinished()
    }

    // Beat 2 — selected texture appears only inside an expanding circle.
    Image {
        id: irisSource
        anchors.fill: parent
        source: root.imagePath
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        layer.enabled: true
        onStatusChanged: {
            if (status === Image.Ready)
                root.maybeStartZoom();
            else if (status === Image.Error)
                root.failLoad();
        }
    }

    ShaderEffect {
        anchors.fill: parent
        property variant source: irisSource
        property real progress: root.irisProgress
        property real aspect: width / Math.max(1, height)
        property real rippleStrength: Math.sin(Math.PI * root.irisProgress) * Theme.wallpaperRippleStrength
        fragmentShader: Qt.resolvedUrl("../../assets/shaders/wallpaper-iris.frag.qsb")
        visible: root.irisProgress > 0
    }

    NumberAnimation {
        id: iris
        target: root
        property: "irisProgress"
        from: 0
        to: 1
        duration: Theme.durWallpaperIris
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeDecel
        onFinished: root.irisFinished()
    }

    // Beat 3 — one soft horizontal sweep using the NEW Theme palette.
    Rectangle {
        id: paletteWave
        width: root.width * 0.52
        height: root.height
        x: -width + (root.width + width) * root.bloomProgress
        visible: root.bloomProgress > 0 && root.bloomProgress < 1
        opacity: Math.sin(Math.PI * root.bloomProgress)
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop {
                position: 0
                color: Qt.rgba(Theme.colorNet.r, Theme.colorNet.g, Theme.colorNet.b, 0)
            }
            GradientStop {
                position: 0.16
                color: Qt.rgba(Theme.colorNet.r, Theme.colorNet.g, Theme.colorNet.b, Theme.wallpaperBloomAlpha)
            }
            GradientStop {
                position: 0.36
                color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, Theme.wallpaperBloomAlpha)
            }
            GradientStop {
                position: 0.56
                color: Qt.rgba(Theme.colorOk.r, Theme.colorOk.g, Theme.colorOk.b, Theme.wallpaperBloomAlpha)
            }
            GradientStop {
                position: 0.76
                color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, Theme.wallpaperBloomAlpha)
            }
            GradientStop {
                position: 0.9
                color: Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, Theme.wallpaperBloomAlpha)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(Theme.warn.r, Theme.warn.g, Theme.warn.b, 0)
            }
        }
    }

    NumberAnimation {
        id: bloom
        target: root
        property: "bloomProgress"
        from: 0
        to: 1
        duration: Theme.durWallpaperBloom
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeDecel
        onFinished: root.bloomFinished()
    }
}
