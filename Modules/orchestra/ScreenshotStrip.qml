import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// SCREENSHOT pill — flat quick-action row (old-shell parity: captures plus
// a color picker, nothing more). Hovering a button raises its label in a
// small tooltip inside the island; clicking collapses the island first and
// the capture fires after Theme.shotCollapseDelayMs.
Item {
    id: strip

    readonly property int btnCell: 13 + 4 * 2
    readonly property int contentWidth: Theme.spaceMd * 2 + btnCell * 6 + Theme.spaceXs * 5

    readonly property string hoveredLabel: bArea.hovered ? "Area to clipboard"
        : bScreen.hovered ? "Screen to clipboard"
        : bOutput.hovered ? "Output to clipboard"
        : bSaveArea.hovered ? "Save area to file"
        : bSaveScreen.hovered ? "Save screen to file"
        : bColor.hovered ? "Pick screen color" : ""

    Row {
        anchors.centerIn: parent
        spacing: Theme.spaceXs

        IconButton {
            id: bArea
            category: "record"; iconName: "crop-free"; iconSize: 13; pad: 4
            onClicked: Screenshot.request("area")
        }
        IconButton {
            id: bScreen
            category: "record"; iconName: "screenshot"; iconSize: 13; pad: 4
            onClicked: Screenshot.request("screen")
        }
        IconButton {
            id: bOutput
            category: "record"; iconName: "output"; iconSize: 13; pad: 4
            onClicked: Screenshot.request("output")
        }
        IconButton {
            id: bSaveArea
            category: "record"; iconName: "save"; iconSize: 13; pad: 4
            onClicked: Screenshot.request("save-area")
        }
        IconButton {
            id: bSaveScreen
            category: "record"; iconName: "photo"; iconSize: 13; pad: 4
            onClicked: Screenshot.request("save-screen")
        }
        IconButton {
            id: bColor
            category: "record"; iconName: "colorize"; iconSize: 13; pad: 4
            onClicked: Screenshot.request("color")
        }
    }

    // tooltip — visual only (no MouseArea), so it never steals hover
    Rectangle {
        anchors.centerIn: parent
        width: tipLbl.implicitWidth + Theme.spaceMd
        height: 22
        radius: Theme.radiusFull
        color: Theme.surface
        visible: strip.hoveredLabel !== ""
        Text {
            id: tipLbl
            anchors.centerIn: parent
            text: strip.hoveredLabel
            color: Theme.foreground
            font.pixelSize: Theme.fontXs
        }
    }
}
