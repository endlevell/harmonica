import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.Common
import qs.Services
import qs.Widgets

// LAUNCHER — Super+S. Search bar + fuzzy-filtered app list, drops from the
// island region. Overlay layer, exclusive keyboard while open.
PanelWindow {
    id: win

    readonly property bool shown: persist.open
    readonly property int resultCount: list.count
    readonly property int rowH: 34
    readonly property int resultsH: list.count > 0 ? Math.min(list.count, 9) * rowH : 0
    readonly property int wanted: Theme.spaceSm * 2 + 38 + (resultsH > 0 ? resultsH + Theme.spaceXs : 0)

    
    anchors { top: true; left: true; right: true }
    margins { top: Theme.barH + Theme.spaceXs * 3 }
    color: "transparent"
    visible: shown
    implicitHeight: shown ? wanted : 0

    Behavior on implicitHeight {
        NumberAnimation { duration: Theme.durNormal; easing.bezierCurve: Theme.easeSpatial; easing.type: Easing.BezierSpline }
    }

    WlrLayershell.namespace: "harmonica:launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { item: panel }

    // deterministic key handling — item-level Keys can lose races under some
    // compositor bind setups; these fire whenever the launcher is open
    Shortcut {
        sequence: "Escape"
        enabled: win.shown
        onActivated: win.close()
    }
    Shortcut {
        sequences: ["Return", "Enter"]
        enabled: win.shown
        onActivated: win.launchCurrent()
    }

    PersistentProperties {
        id: persist
        reloadableId: "launcherOpen"
        property bool open: false
    }

    // content column centered like the island
    Item {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(win.screen.width - Theme.spaceLg * 2, Theme.panelW)
        height: parent.height

        Rectangle {
            id: panel
            anchors.fill: parent
            radius: Theme.radiusMd
            color: Theme.background   // opaque, no border
            clip: true

            Column {
                anchors.fill: parent
                anchors.margins: Theme.spaceSm

                // search row ------------------------------------------------
                Row {
                    width: parent.width
                    height: 38 - Theme.spaceSm * 2
                    spacing: Theme.spaceSm

                    Icon {
                        category: "actions"
                        name: "search"
                        size: 16
                        color: Theme.dimText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    TextInput {
                        id: input
                        width: parent.width - 16 - Theme.spaceSm
                        height: parent.height
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.foreground
                        font.pixelSize: Theme.fontMd
                        clip: true
                        cursorVisible: true
                        verticalAlignment: TextInput.AlignVCenter

                        Text {   // placeholder
                            visible: input.text === "" && !input.activeFocus
                            text: "Search apps…"
                            color: Theme.outline
                            font.pixelSize: Theme.fontMd
                            anchors.verticalCenter: parent.verticalCenter
                        }

                        onTextChanged: list.currentIndex = 0

                        Keys.onDownPressed: list.currentIndex = Math.min(list.currentIndex + 1, list.count - 1)
                        Keys.onUpPressed: list.currentIndex = Math.max(list.currentIndex - 1, 0)
                        Keys.onReturnPressed: win.launchCurrent()
                        Keys.onEnterPressed: win.launchCurrent()
                        Keys.onEscapePressed: win.close()
                    }
                }

                // results ---------------------------------------------------
                ListView {
                    id: list
                    width: parent.width
                    height: resultsH
                    spacing: 2
                    interactive: false
                    currentIndex: 0
                    model: ScriptModel {
                        objectProp: "name"
                        values: Applications.search(input.text)
                    }

                    delegate: Item {
                        required property var modelData
                        required property int index

                        width: ListView.view.width
                        height: win.rowH - 2

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.radiusSm
                            color: index === list.currentIndex ? Theme.surfaceHover
                                 : hover.hovered ? Theme.surface : "transparent"
                        }

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: Theme.spaceSm
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.name
                            color: index === list.currentIndex ? Theme.foreground : Theme.dimText
                            font.pixelSize: Theme.fontSm
                            elide: Text.ElideRight
                            width: parent.width - Theme.spaceSm * 2
                        }

                        HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onEntered: list.currentIndex = index
                            onClicked: { list.currentIndex = index; win.launchCurrent(); }
                        }
                    }
                }

                Text {
                    visible: input.text !== "" && list.count === 0 && !Applications.scanning
                    text: "No matches"
                    color: Theme.outline
                    font.pixelSize: Theme.fontSm
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    function launchCurrent(): void {
        const vals = Applications.search(input.text);
        if (list.currentIndex < 0 || list.currentIndex >= vals.length) return;
        close();
        Applications.launch(vals[list.currentIndex]);
    }

    function open(): void {
        Applications.rescan(false);
        persist.open = true;
        list.currentIndex = 0;
        input.text = "";
        Qt.callLater(() => { input.forceActiveFocus(); input.selectAll(); });
    }
    function close(): void {
        persist.open = false;
        input.text = "";
        focus = false;
    }
    function toggle(): void {
        if (persist.open) close();
        else open();
    }
}
