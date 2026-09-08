import QtQuick
import QtQuick.Shapes
import qs.Common

// Clean flat circular gauge
Item {
    id: root

    property real value: 0.5           // 0..1
    property color gaugeColor: Theme.primary
    property color trackColor: Theme.surface
    property string label: ""
    property string valueText: ""
    property int lineWidth: 6
    property real startAngle: -140     // degrees, 0 = right
    property real sweepAngle: 280      // total arc degrees

    implicitWidth: 90
    implicitHeight: 90

    property real _progress: Math.max(0, Math.min(1, value))
    readonly property real _centerX: width / 2
    readonly property real _centerY: height / 2
    readonly property real _radius: Math.min(width, height) / 2 - lineWidth

    Behavior on _progress {
        enabled: root.visible
        NumberAnimation {
            duration: Theme.durSlow
            easing.type: Easing.OutCubic
        }
    }

    // Track arc (background)
    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root._centerX
                centerY: root._centerY
                radiusX: root._radius
                radiusY: root._radius
                startAngle: root.startAngle
                sweepAngle: root.sweepAngle
            }
        }
    }

    // Clean flat progress arc
    Shape {
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: root.gaugeColor
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap

            PathAngleArc {
                centerX: root._centerX
                centerY: root._centerY
                radiusX: root._radius
                radiusY: root._radius
                startAngle: root.startAngle
                sweepAngle: root.sweepAngle * root._progress
            }
        }
    }

    // Center content
    Column {
        anchors.centerIn: parent
        spacing: 2

        Text {
            visible: root.valueText !== ""
            text: root.valueText
            color: Theme.foreground
            font.family: Theme.fontDisplay
            font.pixelSize: Theme.fontLg
            font.weight: Font.Bold
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            visible: root.label !== ""
            text: root.label
            color: Theme.dimText
            font.family: Theme.fontText
            font.pixelSize: Theme.fontXs
            font.weight: Font.Medium
            font.letterSpacing: Theme.fontTrackingWide
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }
}
