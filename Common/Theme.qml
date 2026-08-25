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

    FileView {
        id: walFile
        path: Paths.walPath
        watchChanges: true
        blockLoading: false
        printErrors: false
        onFileChanged: reload()
    }

    // ---- palette ----
    readonly property color background:      pick(_wal?.special?.background, "#1e1e2e")
    readonly property color foreground:      pick(_wal?.special?.foreground, "#cdd6f4")
    // pywal 16-color slots (color0..15); pick roles that survive most rices
    readonly property color primary:         pick(_wal?.colors?.color4, "#89b4fa")
    readonly property color danger:          pick(_wal?.colors?.color1, "#f38ba8")
    readonly property color success:         pick(_wal?.colors?.color2, "#a6e3a1")
    readonly property color warn:            pick(_wal?.colors?.color3, "#f9e2af")
    readonly property color outline:         pick(_wal?.colors?.color8, "#585b70")
    // derived surfaces from background — no hardcoded hexes here either
    readonly property color surface:         Qt.lighter(background, 1.16)
    readonly property color surfaceHover:    Qt.lighter(background, 1.30)
    readonly property color dimText:         Qt.darker(foreground, 1.55)

    // ---- type scale ----
    readonly property int fontXs: 11
    readonly property int fontSm: 13
    readonly property int fontMd: 15
    readonly property int fontLg: 20
    readonly property int fontXl: 30

    // ---- spacing (4px grid) ----
    readonly property int spaceXs: 4
    readonly property int spaceSm: 8
    readonly property int spaceMd: 12
    readonly property int spaceLg: 16
    readonly property int spaceXl: 24

    // ---- radii ----
    readonly property real radiusSm: 8
    readonly property real radiusMd: 14
    readonly property real radiusLg: 22
    readonly property real radiusFull: 9999

    // ---- island geometry (compact, dynamic-island proportions) ----
    readonly property int barH: 38
    readonly property int idleW: 280
    readonly property int panelW: 460
    readonly property int panelH: 220

    // ---- motion ----
    readonly property int durFast: 150
    readonly property int durNormal: 300
    readonly property int durSlow: 500

    // bezier splines for Easing.BezierSpline ([x1,y1,x2,y2,1,1] = one cubic segment)
    readonly property var easeDecel: [0.05, 0.7, 0.1, 1, 1, 1]        // entrances
    readonly property var easeAccel: [0.3, 0, 0.8, 0.15, 1, 1]        // exits
    readonly property var easeSpatial: [0.34, 1.36, 0.64, 1, 1, 1]    // overshoot moves
    readonly property var easeTwitch: [0.34, 1.86, 0.5, 1, 1, 1]      // elastic twitch (P2)

    // ---- pulse dot params (consumed in Phase 2) ----
    readonly property int pulseDotSize: 5
    readonly property int pulseArcLift: 16
    readonly property int pulseDur: 650
    readonly property int pulseTrail: 5
}
