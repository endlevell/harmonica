import QtQuick
import qs.Common

// Elastic pre-morph twitch: a quick scale pop on the whole island body
// that plays BEFORE the container morph begins (see goTo/leadTimer).
// trigger(strength) restarts it; reducedMotion disables it entirely.
Item {
    id: tw

    default property alias content: holder.data

    property real amplitude: 1

    function trigger(strength: real): void {
        if (Theme.reducedMotion) return;
        tw.amplitude = strength;
        twitchSeq.restart();
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    SequentialAnimation {
        id: twitchSeq
        NumberAnimation { target: holder; property: "scale"; from: 1; to: 1 + 0.035 * tw.amplitude; duration: 80; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeTwitch }
        NumberAnimation { target: holder; property: "scale"; to: 1; duration: 110; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeTwitch }
    }
}
