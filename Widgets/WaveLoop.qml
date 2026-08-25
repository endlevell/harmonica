import QtQuick
import qs.Common

// Thin looping waveform strip — animated indicator line (danger colored).
Canvas {
    id: wave
    property bool running: false
    property color lineColor: Theme.danger
    property real amp: 1.6                 // px amplitude around the midline
    implicitWidth: 100
    implicitHeight: 6

    property real phase: 0
    Timer {
        interval: 40
        repeat: true
        running: wave.running && wave.visible
        onTriggered: {
            wave.phase += 0.35;
            if (wave.phase > Math.PI * 2) wave.phase -= Math.PI * 2;
            wave.requestPaint();
        }
    }
    Component.onCompleted: requestPaint()
    onRunningChanged: requestPaint()
    onLineColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);
        const mid = height / 2;
        ctx.beginPath();
        for (let x = 0; x <= width; x += 2) {
            const t = x / width;
            // two superposed sines scrolling at different speeds → organic loop
            const a = running ? amp * (0.55 + 0.45 * Math.sin(phase + t * 9))
                              : 0.5;
            const y = mid + Math.sin(t * 12 - phase * 2.1) * a
                        + Math.sin(t * 23 + phase * 1.3) * a * 0.4;
            x === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
        }
        ctx.strokeStyle = String(lineColor);
        ctx.lineWidth = 1.2;
        ctx.stroke();
    }
}
