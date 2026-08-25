import QtQuick
import qs.Common

// The PulseDot — one dot riding the island. Each phase defines an anchor;
// on change the dot glides along a quadratic bezier (lifted arc, git-graph
// style) leaving a short fading trail. Trail links are OPAQUE blends of
// primary→background (no alpha anywhere, per design rule).
Canvas {
    id: dot

    property string phase: "idle"
    property int pageIndex: 1
    readonly property real dotSize: Theme.pulseDotSize
    readonly property int trailLinks: 8

    // live target recomputes while geometry animates; path bends to follow it
    readonly property point targetPt: computeAnchor(phase, pageIndex, width, height)
    property point fromPt: targetPt
    property point curPt: targetPt
    property real t: 1                      // glide progress 0..1

    function computeAnchor(ph: string, pi: int, W: real, H: real): point {
        if (ph === "panel")
            return Qt.point(W * ((pi + 0.5) / 3), H - 7);
        if (ph === "music")                  // reserved for Phase 3 strip
            return Qt.point(W / 2, Theme.barH / 2);
        return Qt.point(Theme.spaceMd + 8, Theme.barH / 2);   // idle: beside wifi
    }

    function bez(tt: real): point {
        const p2 = targetPt;
        const mx = (fromPt.x + p2.x) / 2;
        const my = Math.min(fromPt.y, p2.y) - Theme.pulseArcLift;
        const u = 1 - tt;
        return Qt.point(
            u * u * fromPt.x + 2 * u * tt * mx + tt * tt * p2.x,
            u * u * fromPt.y + 2 * u * tt * my + tt * tt * p2.y);
    }

    function blend(a: color, b: color, k: real): string {
        const r = a.r + (b.r - a.r) * k;
        const g = a.g + (b.g - a.g) * k;
        const bl = a.b + (b.b - a.b) * k;
        const c = Qt.rgba(r, g, bl, 1);
        return String(c);
    }

    onTargetPtChanged: retarget()
    Component.onCompleted: requestPaint()

    function retarget(): void {
        fromPt = curPt;
        t = 0;
        driver.restart();
    }

    Timer {
        id: driver
        interval: 16
        repeat: true
        running: false
        onTriggered: {
            dot.t = Math.min(1, dot.t + interval / Theme.pulseDur);
            dot.curPt = dot.bez(dot.t);
            dot.requestPaint();
            if (dot.t >= 1) driver.stop();
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        // fading trail — opaque links, shrinking radius
        for (let k = trailLinks; k >= 1; k--) {
            const tt = t - k * 0.07;
            if (tt < 0) continue;
            const p = bez(tt);
            ctx.beginPath();
            ctx.arc(p.x, p.y, dotSize / 2 * (1 - k / (trailLinks + 4)), 0, Math.PI * 2);
            ctx.fillStyle = blend(Theme.primary, Theme.background, k / (trailLinks + 2));
            ctx.fill();
        }

        // head
        ctx.beginPath();
        ctx.arc(curPt.x, curPt.y, dotSize / 2, 0, Math.PI * 2);
        ctx.fillStyle = String(Theme.primary);
        ctx.fill();
    }
}
