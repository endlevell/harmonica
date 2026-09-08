pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Design tokens. The ONLY place colors/spacings/radii/durations exist.
// Palette comes from pywal (~/.cache/wal/colors.json), watched live.
// Derived tones use Qt.lighter/darker so a palette swap re-derives everything.
Singleton {
    id: root

    function pick(v: string, fallback: string): string {
        return (typeof v === "string" && v.length > 0) ? v : fallback;
    }

    readonly property var _wal: {
        try {
            const t = walFile.text();
            return t && t.length > 0 ? JSON.parse(t) : null;
        } catch (e) {
            console.warn("[Theme] colors.json parse failed:", e);
            return null;
        }
    }
    readonly property string wallpaper: typeof _wal?.wallpaper === "string" ? _wal.wallpaper : ""

    FileView {
        id: walFile
        path: Paths.walPath
        watchChanges: true
        blockLoading: false
        printErrors: false
        onFileChanged: reload()
    }

    // ---- palette ----
    readonly property color background: pick(_wal?.special?.background, "#1e1e2e")
    readonly property color foreground: pick(_wal?.special?.foreground, "#cdd6f4")
    // pywal 16-color slots mapped semantically — variety without new hexes:
    readonly property color primary: pick(_wal?.colors?.color4, "#b49043")   // gold/bright accent
    readonly property color colorNet: pick(_wal?.colors?.color6, "#b5a489")   // bright cyan/sand: network
    readonly property color colorOk: pick(_wal?.colors?.color2, "#a6e3a1")   // green family: battery full / success
    readonly property color warn: pick(_wal?.colors?.color3, "#f9e2af")   // yellow family: battery mid
    readonly property color danger: pick(_wal?.colors?.color1, "#f38ba8") // red family: low / destructive
    readonly property color shadow: Qt.darker(background, 2.0) // soft-cast shadow tone, no literals
    // fixed record/pause hues survive ONLY as missing-wal fallbacks
    readonly property color _walRed: pick(_wal?.colors?.color1, "#ff3b30")
    readonly property color _walAmber: pick(_wal?.colors?.color3, "#ff9500")
    // identity colors: wal hue when vivid, fixed axis when the palette runs gray
    function identity(base: color, axisHue: real): color {
        const vivid = base.hslSaturation >= 0.4;
        const h = vivid ? base.hslHue : axisHue;
        const s = vivid ? Math.min(1, base.hslSaturation * 1.5 + 0.2) : Math.max(base.hslSaturation, 0.75);
        const l = vivid ? base.hslLightness : Math.max(base.hslLightness, 0.45);
        return Qt.hsla(h, Math.min(1, s), l, 1);
    }
    readonly property color colorRecord: identity(_walRed, 0.0) // red axis
    readonly property color colorPause: identity(_walAmber, 0.097) // amber axis (~35deg)
    // derived surfaces from background — no hardcoded hexes here either
    readonly property color surface: Qt.lighter(background, 1.25)
    readonly property color surfaceHover: Qt.lighter(background, 1.45)
    readonly property color dimText: Qt.darker(foreground, 1.35)
    readonly property color overlayDim: Qt.rgba(background.r, background.g, background.b, 0.62)

    function mix(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // ---- type scale ----
    readonly property int fontXs: 11
    readonly property int fontSm: 13
    readonly property int fontMd: 15
    readonly property int fontLg: 20
    readonly property int fontXl: 30
    // UI family from fontconfig. Applied to QGuiApplication::font once
    // here, so every Text without an explicit family inherits it. Mono spots
    // (clocks, timers, speeds) intentionally keep fontconfig monospace instead.
    readonly property string fontUi: "Google Sans"

    function applyUiFont(): void {
        Qt.application.font.family = fontUi;
    }
    Component.onCompleted: applyUiFont()

    // ---- spacing (4px grid) ----
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 16
    readonly property int spaceXl: 24

    // ---- radii ----
    readonly property real radiusXs: 5
    readonly property real radiusSm: 8
    readonly property real radiusMd: 14
    readonly property real radiusLg: 22
    readonly property real radiusFull: 9999

    // ---- island geometry (compact, dynamic-island proportions) ----
    readonly property int barH: 38
    readonly property int panelW: 460
    readonly property int launcherW: 280
    readonly property int panelH: 300
    readonly property int launcherH: 330
    readonly property int recordSettingsH: 400
    readonly property int managerH: 340   // wifi/bluetooth drill-down cards
    readonly property int shotCollapseDelayMs: 300   // island collapse → capture gap
    readonly property int wallpaperVisibleCount: 9
    readonly property int wallpaperCardMaxH: 220
    readonly property int wallpaperGap: spaceXl
    readonly property int wallpaperArcRise: 0
    readonly property int wallpaperInputH: 300
    readonly property int wallpaperRevealStart: 32
    readonly property int wallpaperWatchdogMs: 60000
    readonly property real wallpaperWheelStep: 0.34
    readonly property real wallpaperArrowImpulse: 1.0
    readonly property real wallpaperMomentumDecay: 0.84
    readonly property real wallpaperMomentumStop: 0.035
    readonly property real wallpaperDefaultAspect: 1.5
    readonly property real wallpaperEdgeOpacity: 0.04
    readonly property real wallpaperStackStepRatio: 0.57
    readonly property real wallpaperFocusScale: 1.18
    readonly property real wallpaperOuterScale: 0.76
    readonly property real wallpaperDepthOpacityStep: 0.22
    readonly property int wallpaperParallaxShift: 8
    readonly property int wallpaperParallaxOverscan: 36
    readonly property real wallpaperFocusShadowOpacity: 0.55
    readonly property int wallpaperFocusShadowBlur: 28
    readonly property int wallpaperStaggerMs: 30
    readonly property int wallpaperEntranceShift: 72
    readonly property int durWallpaperItemEnter: 280
    readonly property int durWallpaperItemExit: 180
    // ---- pick sequence: expand · scatter · shrink · check · close --------
    readonly property real wallpaperPickExpandScale: 1.8
    readonly property int durWallpaperPickExpand: 380
    readonly property int durWallpaperPickScatter: 320
    readonly property int durWallpaperPickShrink: 300
    readonly property int durWallpaperPickCheck: 300
    readonly property int wallpaperPickStaggerMs: 30
    readonly property real wallpaperPickScatterTravel: 0.38   // × carousel width
    readonly property real wallpaperPickScatterTilt: 8        // degrees
    readonly property int wallpaperPickCheckSize: 26
    readonly property int durWallpaperPickMelt: 520
    readonly property real wallpaperPickMeltGrow: 0.12   // dissolve swell × base
    readonly property real wallpaperShearBase: -0.3
    readonly property real wallpaperShearPerStep: 0
    // window itself NEVER resizes (ActivSpot lesson); only inner items animate
    readonly property int islandWinH: Math.max(panelH, launcherH, recordSettingsH) + spaceXs * 2

    // ---- morph choreography ----
    readonly property int morphDurExpand: 420      // container grow (slight back)
    readonly property int morphDurRetract: 340     // container shrink (out-cubic)
    readonly property int morphOutMs: 150          // old content exit
    readonly property int morphInMs: 240           // new content enter
    readonly property int morphTwitchLead: 70      // twitch plays before morph starts
    readonly property var easeMorphExpand: [0.22, 1.14, 0.36, 1, 1, 1]

    // ---- motion ----
    readonly property int durFast: 150
    readonly property int durNormal: 300
    readonly property int durSlow: 500
    readonly property int durBellSwing: 1000     // notification bell damped swing
    readonly property int durShutterHold: 100      // eyelid fully-closed hold
    readonly property int durConfirmPulse: 700     // screenshot check pulse on idle
    readonly property int durReveal: 420          // wallpaper-picker circle reveal
    readonly property int durCarousel: 420        // carousel glide/decay settle
    readonly property int carouselTickMs: 16

    // bezier splines for Easing.BezierSpline ([x1,y1,x2,y2,1,1] = one cubic segment)
    readonly property var easeDecel: [0.05, 0.7, 0.1, 1, 1, 1]        // entrances
    readonly property var easeAccel: [0.3, 0, 0.8, 0.15, 1, 1]        // exits
    readonly property var easeSpatial: [0.34, 1.36, 0.64, 1, 1, 1]    // overshoot moves
    readonly property var easeTwitch: [0.34, 1.86, 0.5, 1, 1, 1]      // elastic twitch
    // ---- recorder ----
    readonly property int recStaggerMs: 30          // settings row entrance step
    readonly property int recCompactDebounceMs: 80  // hover-leave settle before compact
    readonly property int recBreathMs: 2000         // compact breathing full cycle
    property bool reducedMotion: SettingsData.reduceMotion
}
