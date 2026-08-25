import QtQuick
import qs.Common

// Minimal filled sparkline. values: number[] 0..1 (or auto-scaled).
Canvas {
    id: graph

    property var values: []
    property color lineColor: Theme.primary
    property real normalizeMax: -1        // -1 = scale to data peak, else fixed ceiling
    property bool filled: true

    implicitWidth: 120
    implicitHeight: 36

    onValuesChanged: requestPaint()
    onLineColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        const vals = graph.values;
        if (!vals || vals.length < 2) return;
        let max = normalizeMax;
        if (max <= 0) {
            max = 0.001;
            for (const v of vals) if (v > max) max = v;
            max *= 1.15;
        }
        const stepX = width / (vals.length - 1);
        ctx.beginPath();
        for (let i = 0; i < vals.length; i++) {
            const x = i * stepX;
            const y = height - Math.min(1, vals[i] / max) * (height - 2) - 1;
            i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
        }
        if (filled) {
            ctx.save();
            ctx.lineTo(width, height);
            ctx.lineTo(0, height);
            ctx.closePath();
            ctx.fillStyle = Qt.rgba(lineColor.r, lineColor.g, lineColor.b, 0.22);
            ctx.fill();
            ctx.restore();
            // re-trace stroke path (closePath mutated it)
            ctx.beginPath();
            for (let i = 0; i < vals.length; i++) {
                const x = i * stepX;
                const y = height - Math.min(1, vals[i] / max) * (height - 2) - 1;
                i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
            }
        }
        ctx.strokeStyle = String(lineColor);
        ctx.lineWidth = 1.5;
        ctx.lineJoin = "round";
        ctx.stroke();
    }
}
