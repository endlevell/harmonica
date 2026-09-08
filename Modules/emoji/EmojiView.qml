import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Common
import qs.Widgets

// Bottom-center emoji picker island: category chips, search, glyph grid,
// click/Enter copies + toast. Static built-in table, zero backend.
PanelWindow {
    id: island

    required property var modelData
    readonly property ShellScreen screenRef: modelData as ShellScreen

    property bool shown: _showing
    property bool _showing: false
    property bool _closing: false
    property string category: "Smileys"
    property string query: ""
    property real enterT: 0
    property bool toasted: false

    readonly property var table: [
        { e: "😀", n: "grinning face", k: "grin happy smile", c: "Smileys" },
        { e: "😁", n: "beaming face", k: "grin happy smile teeth", c: "Smileys" },
        { e: "😂", n: "face with tears of joy", k: "laugh lol joy cry", c: "Smileys" },
        { e: "🥲", n: "smiling face with tear", k: "cry smile emotional", c: "Smileys" },
        { e: "😉", n: "winking face", k: "wink flirt", c: "Smileys" },
        { e: "😍", n: "smiling face with heart eyes", k: "love crush heart", c: "Smileys" },
        { e: "🤔", n: "thinking face", k: "think hmm wonder", c: "Smileys" },
        { e: "😴", n: "sleeping face", k: "sleep tired snore", c: "Smileys" },
        { e: "🥳", n: "partying face", k: "party celebrate birthday", c: "Smileys" },
        { e: "😎", n: "smiling face with sunglasses", k: "cool sunglasses", c: "Smileys" },
        { e: "🙃", n: "upside-down face", k: "silly sarcasm", c: "Smileys" },
        { e: "😭", n: "loudly crying face", k: "cry sob tears sad", c: "Smileys" },
        { e: "👍", n: "thumbs up", k: "yes approve like +1", c: "Hands" },
        { e: "👎", n: "thumbs down", k: "no dislike -1", c: "Hands" },
        { e: "👏", n: "clapping hands", k: "clap applause bravo", c: "Hands" },
        { e: "🙏", n: "folded hands", k: "pray please thanks", c: "Hands" },
        { e: "👌", n: "OK hand", k: "ok perfect", c: "Hands" },
        { e: "✌️", n: "victory hand", k: "peace victory two", c: "Hands" },
        { e: "🤝", n: "handshake", k: "deal agree shake", c: "Hands" },
        { e: "👋", n: "waving hand", k: "wave hello hi bye", c: "Hands" },
        { e: "💪", n: "flexed biceps", k: "muscle strong flex", c: "Hands" },
        { e: "🫶", n: "heart hands", k: "love heart hands", c: "Hands" },
        { e: "❤️", n: "red heart", k: "love heart red", c: "Hearts" },
        { e: "🧡", n: "orange heart", k: "love heart orange", c: "Hearts" },
        { e: "💛", n: "yellow heart", k: "love heart yellow", c: "Hearts" },
        { e: "💚", n: "green heart", k: "love heart green", c: "Hearts" },
        { e: "💙", n: "blue heart", k: "love heart blue", c: "Hearts" },
        { e: "💜", n: "purple heart", k: "love heart purple", c: "Hearts" },
        { e: "🖤", n: "black heart", k: "love heart black dark", c: "Hearts" },
        { e: "🤍", n: "white heart", k: "love heart white", c: "Hearts" },
        { e: "💔", n: "broken heart", k: "breakup heartbreak sad", c: "Hearts" },
        { e: "💕", n: "two hearts", k: "love hearts", c: "Hearts" },
        { e: "🍕", n: "pizza", k: "pizza food slice cheese", c: "Food" },
        { e: "🍔", n: "hamburger", k: "burger food fast", c: "Food" },
        { e: "🍩", n: "doughnut", k: "donut food sweet", c: "Food" },
        { e: "🍦", n: "soft ice cream", k: "ice cream dessert sweet", c: "Food" },
        { e: "☕", n: "hot beverage", k: "coffee tea drink hot", c: "Food" },
        { e: "🍺", n: "beer mug", k: "beer drink alcohol", c: "Food" },
        { e: "🍎", n: "red apple", k: "apple fruit food", c: "Food" },
        { e: "🥑", n: "avocado", k: "avocado food fruit", c: "Food" },
        { e: "🍫", n: "chocolate bar", k: "chocolate sweet candy", c: "Food" },
        { e: "🍿", n: "popcorn", k: "popcorn movie snack", c: "Food" },
        { e: "💡", n: "light bulb", k: "idea bulb light", c: "Objects" },
        { e: "📎", n: "paperclip", k: "clip attach", c: "Objects" },
        { e: "✂️", n: "scissors", k: "cut scissors", c: "Objects" },
        { e: "🔒", n: "locked", k: "lock secure closed", c: "Objects" },
        { e: "🔑", n: "key", k: "key password", c: "Objects" },
        { e: "💰", n: "money bag", k: "money cash rich", c: "Objects" },
        { e: "🎧", n: "headphone", k: "headphones music audio", c: "Objects" },
        { e: "📱", n: "mobile phone", k: "phone mobile iphone", c: "Objects" },
        { e: "💻", n: "laptop", k: "laptop computer macbook", c: "Objects" },
        { e: "🔋", n: "battery", k: "battery power charge", c: "Objects" },
        { e: "✅", n: "check mark button", k: "check yes ok done", c: "Symbols" },
        { e: "❌", n: "cross mark", k: "cross no x delete", c: "Symbols" },
        { e: "⚠️", n: "warning", k: "warning caution alert", c: "Symbols" },
        { e: "➡️", n: "right arrow", k: "arrow right next", c: "Symbols" },
        { e: "⬆️", n: "up arrow", k: "arrow up", c: "Symbols" },
        { e: "⬇️", n: "down arrow", k: "arrow down", c: "Symbols" },
        { e: "♻️", n: "recycling symbol", k: "recycle reuse", c: "Symbols" },
        { e: "©️", n: "copyright", k: "copyright c", c: "Symbols" },
        { e: "®️", n: "registered", k: "registered r trademark", c: "Symbols" },
        { e: "™️", n: "trade mark", k: "trademark tm", c: "Symbols" }
    ]
    readonly property var categories: ["Smileys", "Hands", "Hearts", "Food", "Objects", "Symbols"]

    function filtered(): var {
        const q = island.query.trim().toLowerCase();
        return island.table.filter(e => {
            if (e.c !== island.category) return false;
            if (q === "") return true;
            return e.n.indexOf(q) >= 0 || e.k.indexOf(q) >= 0 || e.e === q;
        });
    }

    function open(): void {
        if (_showing && !_closing) return;
        _showing = true;
        _closing = false;
        searchInput.text = "";
        island.query = "";
        grid.currentIndex = 0;
        enterAnim.restart();
        Qt.callLater(() => searchInput.forceActiveFocus());
    }
    function close(): void {
        if (!_showing || _closing) return;
        _closing = true;
        exitAnim.restart();
    }
    function toggle(): void { island.shown && !island._closing ? island.close() : island.open(); }

    function copyCurrent(): void {
        const list = filtered();
        if (grid.currentIndex < 0 || grid.currentIndex >= list.length) return;
        copyProc.exec(["sh", "-c", "printf '%s' " + _q(list[grid.currentIndex].e) + " | wl-copy"]);
        island.toasted = true;
        toastTimer.restart();
    }
    function _q(s: string): string {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    Process { id: copyProc; command: [] }
    Timer {
        id: toastTimer
        interval: 1200
        repeat: false
        onTriggered: island.toasted = false
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

    WlrLayershell.namespace: "harmonica:emoji"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    mask: Region { x: card.x; y: card.y; width: card.width; height: card.height }

    Shortcut {
        sequence: "Escape"
        enabled: island.shown
        onActivated: island.close()
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: island.close()
    }

    Rectangle {
        id: card
        width: Math.min(460, island.screenRef.width - 32)
        height: 380
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
                    width: parent.width - 14 - Theme.spaceSm
                    height: parent.height
                    color: Theme.foreground
                    font.pixelSize: Theme.fontSm
                    clip: true
                    verticalAlignment: TextInput.AlignVCenter
                    onTextChanged: { island.query = text; grid.currentIndex = 0; }
                    Keys.onEscapePressed: island.close()
                    Keys.onDownPressed: { grid.moveCurrentIndexDown(); }
                    Keys.onUpPressed: { grid.moveCurrentIndexUp(); }
                    Keys.onLeftPressed: { grid.moveCurrentIndexLeft(); }
                    Keys.onRightPressed: { grid.moveCurrentIndexRight(); }
                    Keys.onReturnPressed: island.copyCurrent()
                    Keys.onEnterPressed: island.copyCurrent()
                    Text {
                        visible: parent.text === "" && !parent.activeFocus
                        text: "Search emoji…"
                        color: Theme.outline
                        font.pixelSize: Theme.fontSm
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }
            }

            Row {
                width: parent.width
                height: 22
                spacing: Theme.spaceXs
                Repeater {
                    model: island.categories
                    delegate: Rectangle {
                        required property string modelData
                        width: catLbl.implicitWidth + Theme.spaceMd
                        height: 22
                        radius: Theme.radiusFull
                        color: island.category === modelData ? Theme.primary : Theme.surface
                        Text {
                            id: catLbl
                            anchors.centerIn: parent
                            text: { const m = { Smileys: "Smileys", Hands: "Hands", Hearts: "Hearts", Food: "Food", Objects: "Objects", Symbols: "Symbols" }; return m[parent.modelData]; }
                            color: island.category === parent.modelData ? Theme.background : Theme.dimText
                            font.pixelSize: Theme.fontXs
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { island.category = parent.modelData; grid.currentIndex = 0; }
                        }
                    }
                }
            }

            GridView {
                id: grid
                width: parent.width
                height: parent.height - 30 - 22 - 24 - Theme.spaceMd * 2 - Theme.spaceSm * 3
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                cellWidth: 52
                cellHeight: 52
                currentIndex: 0
                model: island.filtered()
                highlight: Rectangle {
                    radius: Theme.radiusSm
                    color: Theme.surfaceHover
                }
                highlightMoveDuration: Theme.durFast

                delegate: Item {
                    required property var modelData
                    required property int index
                    width: 52
                    height: 52
                    Text {
                        anchors.centerIn: parent
                        text: modelData.e
                        font.pixelSize: 26
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: grid.currentIndex = index
                        onClicked: { grid.currentIndex = index; island.copyCurrent(); }
                    }
                }
            }

            Item {
                width: parent.width
                height: 24
                Text {
                    visible: !island.toasted
                    anchors.centerIn: parent
                    text: "click or enter to copy"
                    color: Theme.dimText
                    font.pixelSize: Theme.fontXs
                }
                Rectangle {
                    visible: island.toasted
                    anchors.centerIn: parent
                    width: toastLbl.implicitWidth + Theme.spaceMd
                    height: 22
                    radius: Theme.radiusFull
                    color: Theme.surface
                    Text {
                        id: toastLbl
                        anchors.centerIn: parent
                        text: "COPIED · ⌘V TO PASTE"
                        color: Theme.primary
                        font.pixelSize: Theme.fontXs
                        font.weight: Font.DemiBold
                    }
                }
            }
        }
    }
}
