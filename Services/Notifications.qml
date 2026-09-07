pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// XDG notification daemon facade. Owns org.freedesktop.Notifications via
// NotificationServer (API verified against the installed 0.3.0 qmltypes),
// keeps an arrival-ordered queue, urgency-aware expiry, action activation
// with correct close reasons: timeout → expire() (Expired), user → dismiss()
// (Dismissed), sender CloseNotification → closed(CloseRequested).
Singleton {
    id: root

    // ---- tuning ----
    property int defaultTimeoutMs: 5000   // sender timeout <= 0
    property int maxQueue: 20             // overflow drops oldest via expire()

    // ---- queue (arrival order; current = latest) ----
    property var queue: []
    readonly property var current: queue.length > 0 ? queue[queue.length - 1] : null
    readonly property int count: queue.length
    readonly property bool showing: current !== null

    // null-safe display bindings (views touch THESE only)
    readonly property string title: current ? (current.summary !== "" ? current.summary : current.appName) : ""
    readonly property string body: current ? plainBody(current.body) : ""
    readonly property bool critical: current ? current.urgency === NotificationUrgency.Critical : false
    readonly property bool hasDefaultAction: current ? hasDefault(current) : false

    signal arrived()   // every NEW arrival (bell swing + content swap)

    // Boot order: evict a stale mako first so the server below always wins
    // the name race; the Loader only instantiates once the bus is settled.
    property bool busReady: false
    Process {
        id: makoEvict
        command: []
        stdout: StdioCollector {}
        Component.onCompleted: makoEvict.exec(["pkill", "-f", "/bin/mako"])
        onExited: root.busReady = true
    }
    Timer {
        interval: 1500
        running: !root.busReady
        onTriggered: root.busReady = true
    }

    // re-adopt server-kept notifications after a live reload (best effort)
    function _adoptTracked(m): void {
        try {
            for (let i = 0; i < m.count; i++) _arrive(m.get(i), true);
        } catch (e) {}
    }

    function _arrive(n, silent): void {
        if (!n) return;
        try { n.tracked = true; } catch (e) {}
        for (let i = 0; i < queue.length; i++) {
            if (queue[i].id === n.id && queue[i] !== n) {
                const q = queue.slice();
                try { q[i].tracked = false; } catch (e2) {}
                q[i] = n;
                queue = q;
                _hookClose(n);
                if (!silent) arrived();
                return;
            }
        }
        const q = queue.slice();
        q.push(n);
        while (q.length > maxQueue) {
            const dropped = q.shift();
            try { dropped.expire(); _expectClose(dropped); } catch (e3) {}
        }
        queue = q;
        _hookClose(n);
        if (!silent) arrived();
    }

    property var _hooked: []
    function _hookClose(n): void {
        if (_hooked.indexOf(n) >= 0) return;
        _hooked = _hooked.concat([n]);
        n.closed.connect(reason => root._onClosed(n, reason));
        try { n.destroyed.connect(() => root._forceDrop(n)); } catch (e2) {}
    }

    function _onClosed(n, reason): void {
        _hooked = _hooked.filter(x => x !== n);
        if (queue.indexOf(n) < 0) return;
        queue = queue.filter(x => x !== n);
    }

    // ---- expiry (sender ms per XDG; <= 0 → server default) ----
    Timer {
        id: expiry
        repeat: false
        onTriggered: { const n = root.current; if (n) { try { n.expire(); } catch (e) {} root._expectClose(n); } }
    }
    // backstop: if the daemon's closed signal is ever lost, reap locally
    Timer {
        id: reap
        interval: 800
        repeat: false
        property var target: null
        onTriggered: { if (target && queue.indexOf(target) >= 0) _forceDrop(target); target = null; }
    }
    function _expectClose(n): void { reap.target = n; reap.restart(); }
    function timeoutMs(n): int {
        const v = n.expireTimeout;
        if (!(v > 0)) return defaultTimeoutMs;
        return Math.max(500, Math.round(v));
    }
    function _armTimer(): void {
        expiry.stop();
        const n = current;
        if (!n) return;
        if (n.urgency === NotificationUrgency.Critical) return;   // sticky
        expiry.interval = timeoutMs(n);
        expiry.restart();
    }
    onCurrentChanged: _armTimer()

    // ---- user actions ----
    function dismissCurrent(): void {
        const n = current;
        if (!n) return;
        expiry.stop();
        try { n.dismiss(); } catch (e) { _forceDrop(n); return; }
        _expectClose(n);
    }
    function activateCurrent(): void {
        const n = current;
        if (!n) return;
        expiry.stop();
        const dflt = (n.actions || []).find(a => a.identifier === "default");
        try { if (dflt) dflt.invoke(); } catch (e) {}
        if (n.resident) _armTimer();   // resident survives its own action
        else { try { n.dismiss(); _expectClose(n); } catch (e2) { _forceDrop(n); } }
    }
    function clearAll(): void {
        const all = queue.slice();
        queue = [];
        for (const n of all) { try { n.dismiss(); } catch (e) {} }
    }
    function _forceDrop(n): void {
        queue = queue.filter(x => x !== n);
    }

    // ---- helpers ----
    function hasDefault(n): bool {
        return ((n.actions || []).some(a => a.identifier === "default"));
    }
    function plainBody(s: string): string {
        return String(s || "").replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, '"').replace(/&apos;/g, "'").replace(/&amp;/g, "&").trim();
    }
}
