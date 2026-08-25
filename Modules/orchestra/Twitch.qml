import QtQuick
import qs.Common

// Elastic twitch wrapper — EVERY island state change routes through trigger().
// Counter-phase x/y wobble, top edge pinned, settles with overshoot.
Item {
    id: tw

    default property alias content: holder.data

    function trigger(strength) {
        tw.strength = (strength === undefined || strength <= 0) ? 1 : strength;
        seq.restart();
    }

    property real strength: 1

    transform: Scale {
        id: sc
        origin.x: tw.width / 2
        origin.y: 0
    }

    Item {
        id: holder
        anchors.fill: parent
    }

    SequentialAnimation {
        id: seq

        ParallelAnimation {
            NumberAnimation { target: sc; property: "xScale"; to: 1 - 0.03 * tw.strength; duration: 55; easing.type: Easing.OutQuad }
            NumberAnimation { target: sc; property: "yScale"; to: 1 + 0.03 * tw.strength; duration: 55; easing.type: Easing.OutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: sc; property: "xScale"; to: 1 + 0.022 * tw.strength; duration: 65; easing.type: Easing.InOutQuad }
            NumberAnimation { target: sc; property: "yScale"; to: 1 - 0.022 * tw.strength; duration: 65; easing.type: Easing.InOutQuad }
        }
        ParallelAnimation {
            NumberAnimation { target: sc; property: "xScale"; to: 1; duration: 70; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
            NumberAnimation { target: sc; property: "yScale"; to: 1; duration: 70; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
        }
    }
}
