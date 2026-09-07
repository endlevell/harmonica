import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets

// LAUNCHER phase view — lives INSIDE the island (single-surface rule).
// Tokenized multi-field search (Applications): every query word substring-matches
// Name/GenericName/Keywords/Exec-basename/file-stem, weighted + ranked; matched
// substrings highlight, non-Name hits show their source field, empty results
// offer the configurable fallback. Arrow keys / wheel / click navigate.
// Esc / row click hand control back to Orchestra.
Item {
    id: lv

    signal closed()

    readonly property int resultCount: list.count
    readonly property int rowH: 52   // two-line wrapped name + detail line
    readonly property int rowSpacing: 2
    readonly property int visibleRows: 2
    readonly property var results: Applications.search(input.text)   // sync over index: rescores every keystroke, no debounce
    readonly property int rowsShown: Math.min(resultCount, visibleRows)
    // honest list height: N rows + N-1 gaps
    readonly property int listH: rowsShown > 0 ? rowsShown * rowH + (rowsShown - 1) * rowSpacing : 0
    // card height hugs content: pads + search row + list (or "no matches") + launch bar
    readonly property int contentH: Theme.spaceSm * 2 + 34
        + (resultCount > 0 ? listH : input.text !== "" ? 26 : 0)
        + (launching ? 8 : 0)
    // ---- configurable no-match fallback (%1 = URL-encoded query) ----
    property string fallbackTemplate: "xdg-open 'https://duckduckgo.com/?q=%1'"

    function runFallback(): void {
        const q = input.text.trim();
        if (q === "") return;
        Quickshell.execDetached(["sh", "-c", fallbackTemplate.split("%1").join(encodeURIComponent(q))]);
    }

    // ---- match highlighting (bold + primary tint over escaped text) ----
    function esc(s: string): string {
        return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    function fmtHi(source: string): string {
        const raw = String(source || "");
        const spans = Applications.matchSpans(raw, input.text);
        if (spans.length === 0) return esc(raw);
        const hi = Theme.primary.toString();
        let out = "", at = 0;
        for (const s of spans) {
            out += esc(raw.substring(at, s[0])) + '<b><font color="' + hi + '">'
                + esc(raw.substring(s[0], s[1])) + "</font></b>";
            at = s[1];
        }
        return out + esc(raw.substring(at));
    }

    function detailText(app): string {
        const m = Applications.matchSource(app, input.text);
        return m ? String(m.text) : "";
    }


    // ---- launching state ----
    property bool launching: false
    property real progress: 0.0

    function grabFocus(): void {
        input.text = "";
        list.currentIndex = 0;
        launching = false;
        progress = 0.0;
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
                    enabled: !lv.launching

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

        // launch progress bar ---------------------------------------------
        Item {
            width: parent.width
            height: 4
            visible: lv.launching

            Rectangle {
                width: parent.width
                height: parent.height
                radius: 2
                color: Theme.surface
            }

            Rectangle {
                id: progressBar
                width: parent.width * lv.progress
                height: parent.height
                radius: 2
                color: lv.barColor

                Behavior on color { ColorAnimation { duration: 200 } }
            }
        }

        Item { height: 4; width: 1; visible: lv.launching }

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

                    Column {
                        width: parent.width - 20 - Theme.spaceSm
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0

                        Text {
                            width: parent.width
                            text: lv.fmtHi(modelData.name)
                            textFormat: Text.RichText
                            color: index === list.currentIndex ? Theme.foreground : Theme.dimText
                            font.pixelSize: Theme.fontSm
                            wrapMode: Text.WordWrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: lv.detailText(modelData) !== ""
                            width: parent.width
                            text: lv.fmtHi(lv.detailText(modelData))
                            textFormat: Text.RichText
                            color: Theme.dimText
                            font.pixelSize: Theme.fontXs
                            elide: Text.ElideRight
                        }
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

        // fallback: no desktop entry matched — configurable system/web search
        MouseArea {
            visible: input.text !== "" && list.count === 0 && !Applications.scanning
            width: parent.width
            height: 26
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: lv.runFallback()

            Text {
                width: parent.width - Theme.spaceMd * 2
                anchors.centerIn: parent
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: 'Search for "' + input.text + '" in the system'
                color: hovered.hovered ? Theme.foreground : Theme.primary
                font.pixelSize: Theme.fontXs
                font.italic: true
            }
            HoverHandler { id: hovered }
        }
    }

    // ---- color cycling during launch ----
    readonly property var colorStops: [Theme.colorOk, Theme.primary, Theme.warn]
    readonly property color barColor: failFlash > 0
        ? Theme.mix(barColor, Theme.danger, failFlash)
        : progress <= 0.33 ? Theme.mix(colorStops[0], colorStops[1], progress * 3)
        : progress <= 0.66 ? Theme.mix(colorStops[1], colorStops[2], (progress - 0.33) * 3)
        : Theme.mix(colorStops[2], colorStops[0], (progress - 0.66) * 3)

    // ---- launch animation ----
    NumberAnimation on progress {
        id: launchAnim
        running: false
        from: 0.0
        to: 1.0
        duration: Theme.durSlow + 250
        easing.type: Easing.OutCubic
        onFinished: lv.closed()
    }

    // fail path (spec #6): bar stops where it is, brief danger flash, retract
    property real failFlash: 0
    SequentialAnimation {
        id: failAnim
        NumberAnimation { target: lv; property: "failFlash"; to: 1.0; duration: Theme.durFast }
        NumberAnimation { target: lv; property: "failFlash"; to: 0.0; duration: Theme.durFast * 2 }
        PauseAnimation { duration: Theme.durFast }
    }
    Timer {
        id: failRetract
        interval: Theme.durFast * 4
        onTriggered: lv.closed()
    }
    Connections {
        target: Applications
        function onLaunchResult(name: string, ok: bool) {
            if (!lv.launching || ok) return;
            launchAnim.stop();
            failAnim.start();
            failRetract.start();
        }
    }

    function launchCurrent(): void {
        const vals = Applications.search(input.text);
        if (vals.length === 0) { lv.runFallback(); return; }
        if (list.currentIndex < 0 || list.currentIndex >= vals.length) return;
        if (launching) return;  // already launching

        launching = true;
        progress = 0.0;
        failFlash = 0.0;
        Applications.launchProbed(vals[list.currentIndex]);
        launchAnim.restart();
    }
}
