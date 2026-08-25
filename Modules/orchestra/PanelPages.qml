import QtQuick
import qs.Common
import qs.Widgets

// Three sliding pages. CENTER (system) is default. Wheel or edge chevrons navigate.
Item {
    id: pages

    readonly property int pageCount: 3
    property int pageIndex: 1   // center = default
    readonly property real pageW: width / pageCount

    clip: true

    Row {
        id: strip
        spacing: 0
        x: -pages.pageIndex * pages.pageW
        Behavior on x {
            NumberAnimation { duration: Theme.durSlow; easing.bezierCurve: Theme.easeSpatial; easing.type: Easing.BezierSpline }
        }

        SettingsPage { width: pages.pageW; height: pages.height }
        SystemPage   { width: pages.pageW; height: pages.height }
        MusicPage    { width: pages.pageW; height: pages.height }
    }

    ArrowNav {
        onNextPage: pages.pageIndex = (pages.pageIndex + 1) % pages.pageCount
        onPrevPage: pages.pageIndex = (pages.pageIndex + pages.pageCount - 1) % pages.pageCount
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.ArrowCursor
        onWheel: w => {
            if (w.angleDelta.y < 0)
                pages.pageIndex = (pages.pageIndex + 1) % pages.pageCount;
            else if (w.angleDelta.y > 0)
                pages.pageIndex = (pages.pageIndex + pages.pageCount - 1) % pages.pageCount;
        }
    }

    // page dots — active page indicator
    Row {
        id: dots
        spacing: 4
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5

        Repeater {
            model: pages.pageCount

            Rectangle {
                required property int index
                width: 5
                height: 5
                radius: Theme.radiusFull
                color: pages.pageIndex === index ? Theme.primary : Theme.outline
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }
        }
    }
}
