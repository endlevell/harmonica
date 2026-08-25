import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

// LAUNCHER phase view — lives INSIDE the island (single-surface rule).
// Search bar + fuzzy app list. Esc / row click hand control back to Orchestra.
Item {
    id: lv

    signal closed()

    readonly property int resultCount: list.count
    readonly property int rowH: 30
    readonly property var results: Applications.search(input.text)

    function grabFocus(): void {
        input.text = "";
        list.currentIndex = 0;
        Qt.callLater(() => input.forceActiveFocus());
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

                    onTextChanged: list.currentIndex = 0

                    Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
                    Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)
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
            height: count > 0 ? Math.min(count, 9) * (lv.rowH + 2) : 0
            spacing: 2
            interactive: false
            currentIndex: 0
            model: lv.results

            delegate: Item {
                required property var modelData
                required property int index

                width: ListView.view.width
                height: lv.rowH

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radiusXs
                    color: index === list.currentIndex ? Theme.surfaceHover
                         : hover.hovered ? Theme.surface : "transparent"
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }
                }

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.spaceSm
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - Theme.spaceSm * 2
                    text: modelData.name
                    color: index === list.currentIndex ? Theme.foreground : Theme.dimText
                    font.pixelSize: Theme.fontXs + 1
                    elide: Text.ElideRight
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
