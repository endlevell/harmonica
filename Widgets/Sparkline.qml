import QtQuick
import qs.Common

// Mini sparkline chart for live metrics — adds movement and context
Canvas {
    id: spark
    
    property var dataPoints: []  // array of 0..1 values
    property color lineColor: Theme.primary
    property real lineWidth: 1.5
    
    implicitWidth: 60
    implicitHeight: 20
    
    onDataPointsChanged: requestPaint()
    
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        
        if (dataPoints.length < 2) return;
        
        const w = width;
        const h = height;
        const step = w / (dataPoints.length - 1);
        
        ctx.strokeStyle = lineColor;
        ctx.lineWidth = lineWidth;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        
        ctx.beginPath();
        ctx.moveTo(0, h - dataPoints[0] * h);
        
        for (let i = 1; i < dataPoints.length; i++) {
            ctx.lineTo(i * step, h - dataPoints[i] * h);
        }
        
        ctx.stroke();
    }
}
