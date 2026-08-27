import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// LAUNCHER phase view — lives INSIDE the island (single-surface rule).
// Search bar + fuzzy app list. Arrow keys / wheel / click navigate.
// Esc / row click hand control back to Orchestra.
Item {
    id: lv

    signal closed()

    readonly property int resultCount: list.count
    readonly property int rowH: 34
    readonly property int rowSpacing: 2
    readonly property int visibleRows: 2
    readonly property var results: Applications.search(input.text)
    readonly property int rowsShown: Math.min(resultCount, visibleRows)
    // honest list height: N rows + N-1 gaps
    readonly property int listH: rowsShown > 0 ? rowsShown * rowH + (rowsShown - 1) * rowSpacing : 0
    // card height hugs content: pads + search row + list (or "no matches")
    readonly property int contentH: Theme.spaceSm * 2 + 34
        + (resultCount > 0 ? listH : input.text !== "" ? 26 : 0)

    function grabFocus(): void {
        input.text = "";
        list.currentIndex = 0;
        Qt.callLater(() => input.forceActiveFocus());
    }

    function move(delta: int): void {
        if (list.count === 0) return;
        const next = Math.min(Math.max(list.currentIndex + delta, 0), list.count - 1);
        list.currentIndex = next;
        list.positionViewAtIndex(next, ListView.Contain);
    }

    Column {
        anchors.fill: parent
        anchors.margins: Theme.spaceSm

        // search row ------------------------------------------------------
        Item {
            width: parent.width
            height: 34
            Row {
                spacing: Theme.spaceSm
                anchors.fill: parent

                Icon {
                    category: "actions"
                    name: "search"
                    size: 15
                    color: Theme.dimText
                    anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                    id: input
                    width: parent.width - 15 - Theme.spaceSm
                    height: parent.height
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.foreground
                    font.pixelSize: Theme.fontSm
                    clip: true
                    cursorVisible: activeFocus
                    verticalAlignment: TextInput.AlignVCenter

                    Text {
                        visible: input.text === "" && !input.activeFocus
                        text: "Search apps…"
                        color: Theme.outline
                        font.pixelSize: Theme.fontSm
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    onTextChanged: { list.currentIndex = 0; list.positionViewAtIndex(0, ListView.Beginning) }

                    Keys.onDownPressed: lv.move(1)
                    Keys.onUpPressed: lv.move(-1)
                    Keys.onReturnPressed: lv.launchCurrent()
                    Keys.onEnterPressed: lv.launchCurrent()
                    Keys.onEscapePressed: lv.closed()
                }
            }
        }

        // results ---------------------------------------------------------
        ListView {
            id: list
            width: parent.width
            height: lv.listH
            spacing: lv.rowSpacing
            clip: true
            interactive: true                      // mouse-wheel scroll
            boundsBehavior: Flickable.StopAtBounds
            currentIndex: 0
            model: lv.results

            delegate: Item {
                required property var modelData
                required property int index

                width: ListView.view.width
                height: lv.rowH

                // row backdrop: hover + selection highlight
                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusXs
                    color: index === list.currentIndex ? Theme.surfaceHover
                         : hover.hovered ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }

                // selection accent bar (left)
                Rectangle {
                    visible: index === list.currentIndex
                    width: 3
                    height: lv.rowH - Theme.spaceSm * 2
                    radius: 2
                    color: Theme.primary
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceXs
                    anchors.verticalCenter: parent.verticalCenter
                }

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceSm + 5
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.spaceSm
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Theme.spaceSm

                    // app icon, or first-letter chip when none resolves
                    Item {
                        width: 20
                        height: 20
                        anchors.verticalCenter: parent.verticalCenter

                        Image {
                            id: appIcon
                            anchors.fill: parent
                            source: modelData.icon !== "" ? modelData.icon : ""
                            sourceSize.width: 40
                            sourceSize.height: 40
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                            visible: source !== "" && status !== Image.Error
                        }

                        Rectangle {
                            id: iconFallback
                            anchors.fill: parent
                            radius: Theme.radiusXs
                            color: Theme.surface
                            visible: modelData.icon === "" || appIcon.status === Image.Error
                            Text {
                                anchors.centerIn: parent
                                text: modelData.name.length > 0 ? modelData.name.charAt(0).toUpperCase() : "?"
                                color: Theme.primary
                                font.pixelSize: Theme.fontSm - 1
                                font.weight: Font.DemiBold
                            }
                        }
                    }

                    Text {
                        width: parent.width - 20 - Theme.spaceSm
                        text: modelData.name
                        color: index === list.currentIndex ? Theme.foreground : Theme.dimText
                        font.pixelSize: Theme.fontSm
                        elide: Text.ElideRight
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: list.currentIndex = index
                    onClicked: { list.currentIndex = index; lv.launchCurrent(); }
                }
            }
        }

        Text {
            visible: input.text !== "" && list.count === 0 && !Applications.scanning
            text: "No matches"
            color: Theme.outline
            font.pixelSize: Theme.fontXs
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    function launchCurrent(): void {
        const vals = Applications.search(input.text);
        if (list.currentIndex < 0 || list.currentIndex >= vals.length) return;
        Applications.launch(vals[list.currentIndex]);
        lv.closed();
    }
}
