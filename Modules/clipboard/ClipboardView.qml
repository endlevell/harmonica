import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

// Bottom-center clipboard island: search + pins, type filter chips, pinned
// row, history list with kind tags + ages, footer hints. Standalone overlay
// (WallpaperPicker pattern): fullscreen transparent window, card bottom
// center, click outside closes. ENTER pastes via wtype when present.
PanelWindow {
    id: island

    required property var modelData
    readonly property ShellScreen screenRef: modelData as ShellScreen

    property bool shown: _showing
    property bool _showing: false
    property bool _closing: false
    property string filter: "all"       // all | text | image | code
    property string query: ""
    property real enterT: 0

    function open(): void {
        if (_showing && !_closing) return;
        _showing = true;
        _closing = false;
        Clipboard.refresh();
        searchInput.text = "";
        island.query = "";
        enterAnim.restart();
        Qt.callLater(() => searchInput.forceActiveFocus());
    }
    function close(): void {
        if (!_showing || _closing) return;
        _closing = true;
        exitAnim.restart();
    }
    function toggle(): void { island.shown && !island._closing ? island.close() : island.open(); }

    function filteredEntries(): var {
        const q = island.query.trim().toLowerCase();
        return Clipboard.entries.filter(e => {
            if (e.pinned) return false;
            if (island.filter !== "all" && e.kind !== island.filter) return false;
            if (q !== "" && e.kind !== "image" && e.text.toLowerCase().indexOf(q) < 0) return false;
            if (q !== "" && e.kind === "image") return false;
            return true;
        });
    }
    function pinnedEntries(): var {
        return Clipboard.entries.filter(e => e.pinned);
    }

    function pasteEntry(e): void {
        Clipboard.copyEntry(e);
        island.close();
        pasteTimer.restart();
    }

    function _currentEntry(): var {
        const list = filteredEntries();
        return histList.currentIndex >= 0 && histList.currentIndex < list.length ? list[histList.currentIndex] : null;
    }
    function pasteCurrent(): void { const e = _currentEntry(); if (e) pasteEntry(e); }
    function pinCurrent(): void { const e = _currentEntry(); if (e) Clipboard.togglePin(e.hash); }
    function deleteCurrent(): void { const e = _currentEntry(); if (e) Clipboard.removeEntry(e.hash); }

    Timer {
        id: pasteTimer
        interval: 200
        repeat: false
        onTriggered: {
            if (pasteProbe.text().trim() !== "") {
                Quickshell.execDetached(["sh", "-c", "wtype -M ctrl -k v -m ctrl 2>/dev/null || true"]);
            }
        }
    }
    FileView {
        id: pasteProbe
        path: "/run/current-system/sw/bin/wtype"
        watchChanges: false
        blockLoading: false
        printErrors: false
    }

    NumberAnimation {
        id: enterAnim
        target: island
        property: "enterT"
        from: 0
        to: 1
        duration: Theme.reducedMotion ? 0 : Theme.morphInMs
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Theme.easeDecel
    }
    SequentialAnimation {
        id: exitAnim
        NumberAnimation { target: island; property: "enterT"; to: 0; duration: Theme.reducedMotion ? 0 : Theme.morphOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.easeAccel }
        ScriptAction { script: { island._showing = false; island._closing = false; } }
    }

    screen: screenRef
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || enterT > 0.001

    WlrLayershell.namespace: "harmonica:clipboard"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { x: card.x; y: card.y; width: card.width; height: card.height }

    Shortcut {
        sequence: "Escape"
        enabled: island.shown
        onActivated: island.close()
    }

    // click outside closes
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: island.close()
    }

    Rectangle {
        id: card
        width: Math.min(460, island.screenRef.width - 32)
        height: 400
        radius: Theme.radiusMd
        color: Theme.background
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Theme.spaceMd + Math.round((1 - island.enterT) * 60)
        opacity: island.enterT

        Column {
            anchors.fill: parent
            anchors.margins: Theme.spaceMd
            spacing: Theme.spaceSm

            // header: search + pin-all --------------------------------
            Row {
                width: parent.width
                height: 30
                spacing: Theme.spaceSm
                Icon {
                    category: "actions"; name: "search"; size: 14
                    color: Theme.dimText
                    anchors.verticalCenter: parent.verticalCenter
                }
                TextInput {
                    id: searchInput
                    width: parent.width - 14 - 20 - Theme.spaceSm * 2
                    height: parent.height
                    color: Theme.foreground
                    font.pixelSize: Theme.fontSm
                    clip: true
                    Keys.onDownPressed: { histList.incrementCurrentIndex(); histList.positionViewAtIndex(histList.currentIndex, ListView.Contain); }
                    Keys.onUpPressed: { histList.decrementCurrentIndex(); histList.positionViewAtIndex(histList.currentIndex, ListView.Contain); }
                    Keys.onReturnPressed: island.pasteCurrent()
                    Keys.onEnterPressed: island.pasteCurrent()
                    Keys.onDeletePressed: e => { if (searchInput.text === "") island.deleteCurrent(); }
                    Keys.onPressed: e => { if ((e.text === "p" || e.text === "P") && searchInput.text === "") island.pinCurrent(); }
                    Text {
                        visible: parent.text === "" && !parent.activeFocus
                        text: "Search clipboard…"
                        color: Theme.outline
                        font.pixelSize: Theme.fontSm
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            // filter chips ---------------------------------------------
            Row {
                width: parent.width
                height: 22
                spacing: Theme.spaceXs
                Repeater {
                    model: ["all", "text", "image", "code"]
                    delegate: Rectangle {
                        required property string modelData
                        width: chipLbl.implicitWidth + Theme.spaceMd
                        height: 22
                        radius: Theme.radiusFull
                        color: island.filter === modelData ? Theme.primary : Theme.surface
                        Text {
                            id: chipLbl
                            anchors.centerIn: parent
                            text: { const m = { all: "All", text: "Text", image: "Images", code: "Code" }; return m[parent.modelData]; }
                            color: island.filter === parent.modelData ? Theme.background : Theme.dimText
                            font.pixelSize: Theme.fontXs
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: island.filter = parent.modelData
                        }
                    }
                }
            }

            // pinned row ------------------------------------------------
            Row {
                visible: island.pinnedEntries().length > 0
                width: parent.width
                height: visible ? 30 : 0
                spacing: Theme.spaceXs
                Text {
                    text: "PINNED"
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                    anchors.verticalCenter: parent.verticalCenter
                }
                Repeater {
                    model: island.pinnedEntries()
                    delegate: Rectangle {
                        required property var modelData
                        width: Math.min(pinLbl.implicitWidth + Theme.spaceMd, 150)
                        height: 24
                        radius: Theme.radiusFull
                        color: Theme.surfaceHover
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            id: pinLbl
                            anchors.centerIn: parent
                            width: parent.width - Theme.spaceSm * 2
                            text: modelData.kind === "image" ? "image" : modelData.text.split("\n")[0]
                            color: Theme.foreground
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: island.pasteEntry(parent.modelData)
                        }
                    }
                }
            }

            // history ----------------------------------------------------
            ListView {
                id: histList
                width: parent.width
                height: parent.height - 30 - 22 - (island.pinnedEntries().length > 0 ? 30 : 0) - 24 - Theme.spaceMd * 2 - Theme.spaceSm * 4
                spacing: 2
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                currentIndex: 0
                model: island.filteredEntries()
                onCountChanged: histList.currentIndex = 0

                Text {
                    visible: histList.count === 0
                    width: parent.width
                    anchors.centerIn: parent
                    text: "Clipboard is empty — copy something."
                    color: Theme.dimText
                    font.pixelSize: Theme.fontSm
                    horizontalAlignment: Text.AlignHCenter
                }

                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    height: modelData.kind === "image" ? 56 : 40
                    radius: Theme.radiusSm
                    color: index === histList.currentIndex || histHover.containsMouse ? Theme.surfaceHover : Theme.surface
                    Behavior on color { ColorAnimation { duration: Theme.durFast } }

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: Theme.spaceSm
                        anchors.rightMargin: Theme.spaceSm
                        spacing: Theme.spaceSm

                        Image {
                            visible: modelData.kind === "image"
                            width: 44
                            height: 44
                            source: modelData.kind === "image" ? "file://" + modelData.file : ""
                            fillMode: Image.PreserveAspectCrop
                            smooth: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Column {
                            width: parent.width - (modelData.kind === "image" ? 44 + Theme.spaceSm : 0) - 46 - 20 - Theme.spaceSm * 2
                            spacing: 0
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                width: parent.width
                                text: modelData.kind === "image" ? "image" : (modelData.kind === "code" ? modelData.text.split("\n")[0] : modelData.text)
                                color: Theme.foreground
                                font.pixelSize: Theme.fontSm
                                elide: Text.ElideRight
                                maximumLineCount: 2
                                wrapMode: Text.WordWrap
                            }
                            Text {
                                width: parent.width
                                text: Clipboard.ageText(modelData.time)
                                color: Theme.dimText
                                font.pixelSize: Theme.fontXs
                                font.family: "monospace"
                            }
                        }
                        Rectangle {
                            width: 46
                            height: 18
                            radius: Theme.radiusFull
                            color: Theme.background
                            anchors.verticalCenter: parent.verticalCenter
                            Text {
                                anchors.centerIn: parent
                                text: { const m = { text: "TEXT", image: "IMG", code: "CODE" }; return m[modelData.kind] || "?"; }
                                color: Theme.dimText
                                font.pixelSize: 9
                                font.weight: Font.Bold
                            }
                        }
                        Text {
                            text: "×"
                            color: histHover.containsMouse ? Theme.danger : Theme.outline
                            font.pixelSize: Theme.fontMd
                            anchors.verticalCenter: parent.verticalCenter
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -6
                                cursorShape: Qt.PointingHandCursor
                                onClicked: e => { e.accepted = true; Clipboard.removeEntry(modelData.hash); }
                            }
                        }
                    }

                    HoverHandler { id: histHover }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: histList.currentIndex = index
                        onClicked: island.pasteEntry(modelData)
                    }
                }
            }

            // footer ------------------------------------------------------
            Text {
                width: parent.width
                height: 24
                text: "↑↓ navigate · enter to paste · P pin · Del delete"
                color: Theme.dimText
                font.pixelSize: Theme.fontXs
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
        }
    }
}
