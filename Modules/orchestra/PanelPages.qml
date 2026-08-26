import QtQuick
import qs.Common
import qs.Widgets

// Three sliding pages. CENTER (system) is default. Wheel or edge chevrons navigate.
Item {
    id: pages

    readonly property int pageCount: 3
    property int pageIndex: 1   // center = default
    readonly property real pageW: Theme.panelW

    clip: true

    Item {
        id: viewport
        anchors.fill: parent
        clip: true

        Row {
            id: strip
            spacing: 0
            x: -pages.pageIndex * pages.pageW

            Behavior on x {
                enabled: pages.visible && pages.opacity > 0.8
                NumberAnimation {
                    duration: Theme.durNormal
                    easing.type: Easing.OutCubic
                }
            }

            Item {
                width: pages.pageW
                height: pages.height
                clip: true
                ControlCenterPage { anchors.fill: parent }
            }

            Item {
                width: pages.pageW
                height: pages.height
                clip: true
                SystemPage { anchors.fill: parent }
            }

            Item {
                width: pages.pageW
                height: pages.height
                clip: true
                MusicPage { anchors.fill: parent }
            }
        }
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
        anchors.bottomMargin: 6

        Repeater {
            model: pages.pageCount

            Rectangle {
                required property int index
                width: 5
                height: 5
                radius: Theme.radiusFull
                color: pages.pageIndex === index ? Theme.primary : Theme.surfaceHover
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }
        }
    }
}
