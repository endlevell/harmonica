import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Common

// FULLSCREEN region-select overlay — the sanctioned exception to the
// single-surface rule. Two modes:
//   snip   — crosshair drag rect (live WxH label)
//   window — hover highlights a client's bbox, click accepts it
PanelWindow {
    id: rs

    signal regionAccepted(int x, int y, int w, int h)
    signal cancelled()

    property string mode: "snip"
    readonly property bool shown: _showing
    property bool _showing: false

    // window-mode state
    property var clients: []               // [{x,y,w,h,class,title}]
    property int hoverIdx: -1
    property point cur: Qt.point(0, 0)

    // snip state
    property point dragStart: Qt.point(0, 0)
    property bool dragging: false

    function open(m: string): void {
        mode = m === "window" ? "window" : "snip";
        if (mode === "window") clientFetch.exec(["sh", "-c", "hyprctl -j clients"]);
        dragging = false;
        hoverIdx = -1;
        _showing = true;
        watchdog.restart();
    }
    function close(): void {
        watchdog.stop();
        _showing = false;
        dragging = false;
    }

    // 30s watchdog — if the user walks away, cancel cleanly
    Timer {
        id: watchdog
        interval: 30000
        repeat: false
        onTriggered: { rs.cancelled(); rs.close(); }
    }

    screen: Quickshell.screens[0] ?? null
    anchors { top: true; left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown

    WlrLayershell.namespace: "harmonica:regionselect"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Process {
        id: clientFetch
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const arr = JSON.parse(this.text);
                    rs.clients = arr.filter(c => c.mapped !== false
                        && !String(c.namespace || "").startsWith("harmonica:")
                        && c.size[0] > 20 && c.size[1] > 20)
                        .map(c => ({ x: c.at[0], y: c.at[1], w: c.size[0], h: c.size[1],
                                     cls: c.class, title: c.title }));
                } catch (e) { rs.clients = []; }
            }
        }
    }

    function pickHover(px: real, py: real): int {
        for (let i = clients.length - 1; i >= 0; i--) {
            const c = clients[i];
            if (px >= c.x && px < c.x + c.w && py >= c.y && py < c.y + c.h) return i;
        }
        return -1;
    }

    Rectangle {   // dim veil — alpha sanctioned here by design decision
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.35)
        visible: rs.shown
    }

    // window-mode highlight -------------------------------------------------
    Rectangle {
        visible: rs.mode === "window" && rs.hoverIdx >= 0
        x: rs.hoverIdx >= 0 ? rs.clients[rs.hoverIdx].x : 0
        y: rs.hoverIdx >= 0 ? rs.clients[rs.hoverIdx].y : 0
        width: rs.hoverIdx >= 0 ? rs.clients[rs.hoverIdx].w : 0
        height: rs.hoverIdx >= 0 ? rs.clients[rs.hoverIdx].h : 0
        border.width: 2
        border.color: Theme.primary
        Behavior on x { NumberAnimation { duration: 60 } }
        Behavior on y { NumberAnimation { duration: 60 } }
        Behavior on width { NumberAnimation { duration: 60 } }
        Behavior on height { NumberAnimation { duration: 60 } }

        Text {
            x: parent.x + 6; y: parent.y - 22
            text: rs.hoverIdx >= 0 ? rs.clients[rs.hoverIdx].cls : ""
            color: Theme.foreground
            font.pixelSize: Theme.fontXs
        }
    }

    // snip selection rect ----------------------------------------------------
    Rectangle {
        id: selRect
        visible: rs.dragging
        x: Math.min(rs.dragStart.x, area.mouseX)
        y: Math.min(rs.dragStart.y, area.mouseY)
        width: Math.abs(area.mouseX - rs.dragStart.x)
        height: Math.abs(area.mouseY - rs.dragStart.y)
        color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
        border.width: 2
        border.color: Theme.primary

        Text {
            property bool flip: selRect.y < 26
            x: parent.width / 2 - implicitWidth / 2
            y: flip ? parent.height + 6 : -24
            text: Math.round(parent.width) + "×" + Math.round(parent.height)
            color: Theme.foreground
            font.pixelSize: Theme.fontSm
            font.family: "monospace"
        }
    }

    // discoverability hint — Esc is unreliable under compositor-wide binds
    Text {
        visible: rs.shown
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 24
        text: rs.mode === "snip"
            ? "drag to capture · right-click or Esc to cancel"
            : "click a window to capture · right-click or Esc to cancel"
        color: Qt.rgba(Theme.foreground.r, Theme.foreground.g, Theme.foreground.b, 0.85)
        font.pixelSize: Theme.fontSm
        horizontalAlignment: Text.AlignHCenter
    }

    MouseArea {
        id: area
        anchors.fill: parent
        cursorShape: rs.shown ? Qt.CrossCursor : Qt.ArrowCursor
        enabled: rs.shown
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton

        onPressed: m => {
            if (m.button !== Qt.LeftButton) { rs.cancelled(); rs.close(); return; }   // right/middle = cancel
            if (rs.mode === "snip") { rs.dragStart = Qt.point(mouseX, mouseY); rs.dragging = true; }
            else {
                if (rs.hoverIdx >= 0) {
                    const c = rs.clients[rs.hoverIdx];
                    rs.regionAccepted(c.x, c.y, c.w, c.h);
                    rs.close();
                } else rs.cancelled();
            }
        }
        onPositionChanged: mouse => {
            rs.cur = Qt.point(mouseX, mouseY);
            if (rs.mode === "window") rs.hoverIdx = rs.pickHover(mouseX, mouseY);
        }
        onReleased: m => {
            if (rs.mode !== "snip" || !rs.dragging) return;
            rs.dragging = false;
            const w = Math.abs(area.mouseX - rs.dragStart.x);
            const h = Math.abs(area.mouseY - rs.dragStart.y);
            if (w < 4 || h < 4) return;
            const x = Math.round(Math.min(rs.dragStart.x, area.mouseX));
            const y = Math.round(Math.min(rs.dragStart.y, area.mouseY));
            rs.regionAccepted(x, y, Math.round(w), Math.round(h));
            rs.close();
        }
    }

    Shortcut {
        sequence: "Escape"
        enabled: rs.shown
        onActivated: { rs.cancelled(); rs.close(); }
    }
}
