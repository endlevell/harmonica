import QtQuick
import QtQuick.Shapes
import qs.Common

// Circular progress ring — a full-circle track with a swept progress arc.
// Used to frame album art: the arc IS the progress bar.
Item {
    id: root

    property real value: 0             // 0..1
    property color ringColor: Theme.primary
    property color trackColor: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.12)
    property real lineWidth: 3

    property real _p: Math.max(0, Math.min(1, value))
    Behavior on _p {
        enabled: root.visible
        NumberAnimation { duration: 450; easing.type: Easing.Linear }
    }

    readonly property real _cx: width / 2
    readonly property real _cy: height / 2
    readonly property real _r: Math.min(width, height) / 2 - lineWidth

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // track
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root._cx; centerY: root._cy
                radiusX: root._r; radiusY: root._r
                startAngle: -90; sweepAngle: 360
            }
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // progress
        ShapePath {
            strokeColor: root.ringColor
            strokeWidth: root.lineWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: root._cx; centerY: root._cy
                radiusX: root._r; radiusY: root._r
                startAngle: -90; sweepAngle: 360 * root._p
            }
        }
    }
}
