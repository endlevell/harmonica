import QtQuick
import qs.Common
import qs.Widgets

// Three sliding pages. CENTER (system) is default. Wheel or edge chevrons navigate.
// Each page slides horizontally AND scales/fades by its distance from center so
// the active page pops forward while neighbors recede — a depth-carousel feel.
Item {
    id: pages

    readonly property int pageCount: 3
    property int pageIndex: 1   // center = default
    readonly property real pageW: Theme.panelW

    // animated scalar tracking pageIndex so scale/opacity interpolate smoothly
    property real animIndex: 1
    Behavior on animIndex {
        NumberAnimation {
            duration: Theme.durNormal
            easing.type: Easing.OutCubic
        }
    }
    onPageIndexChanged: animIndex = pageIndex

    clip: true

    Item {
        id: viewport
        anchors.fill: parent
        clip: true

        Row {
            id: strip
            spacing: 0
            x: -pages.animIndex * pages.pageW

            Repeater {
                id: rep
                model: pages.pageCount

                Item {
                    id: pageSlot
                    required property int index

                    width: pages.pageW
                    height: pages.height
                    clip: true

                    // distance from the (fractional) active page, 0 = centered
                    readonly property real dist: Math.abs(index - pages.animIndex)
                    readonly property real k: Math.min(1, dist)

                    // recede + fade neighbors
                    scale: 1 - k * 0.12
                    opacity: 1 - k * 0.55
                    transformOrigin: Item.Center

                    Loader {
                        anchors.fill: parent
                        // only instantiate while the panel is shown → pollers
                        // (CPU/RAM/network) idle when the island is collapsed
                        active: pages.visible
                        sourceComponent: pageSlot.index === 0 ? cControl
                            : pageSlot.index === 1 ? cSystem : cMusic
                    }
                }
            }
        }
    }

    Component { id: cControl; ControlCenterPage {} }
    Component { id: cSystem; SystemPage {} }
    Component { id: cMusic; MusicPage {} }

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

    // page dots — active page indicator; active dot stretches into a pill
    Row {
        id: dots
        spacing: 5
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 7

        Repeater {
            model: pages.pageCount

            Rectangle {
                required property int index
                readonly property bool activeDot: pages.pageIndex === index
                width: activeDot ? 16 : 6
                height: 6
                radius: Theme.radiusFull
                color: activeDot ? Theme.primary : Theme.surfaceHover
                Behavior on width { NumberAnimation { duration: Theme.durNormal; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Theme.durFast } }
            }
        }
    }
}
