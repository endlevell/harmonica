pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// Clipboard history without a daemon: polls wl-paste on a slow tick
// (always on — a history that only records while open is useless; one
// tiny spawn per 2.5s). Text/code entries inline, images spooled to the
// cache dir. Pins live in memory only.
Singleton {
    id: root

    // {kind: text|code|image, text, file, time, pinned, hash}
    property var entries: []
    property int maxEntries: 50

    property string _lastHash: ""
    readonly property string imgDir: {
        const c = Quickshell.env("XDG_CACHE_HOME");
        return ((c && c.length > 0) ? c : Quickshell.env("HOME") + "/.cache") + "/harmonica/clips";
    }

    function _hash(s: string): string {
        let h = 5381;
        for (let i = 0; i < s.length; i++) h = ((h << 5) + h + s.charCodeAt(i)) | 0;
        return "t" + (h >>> 0).toString(36);
    }

    function stamp(): string { return Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss"); }
    Component.onCompleted: mkdirProc.exec(["mkdir", "-p", imgDir]);
    Process { id: mkdirProc; command: [] }

    Timer {
        interval: 2500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function refresh(): void {
        typeProbe.exec(["sh", "-c", "wl-paste --list-types 2>/dev/null | head -5"]);
    }

    Process {
        id: typeProbe
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const types = this.text;
                if (types.indexOf("image/png") >= 0) root._grabImage();
                else if (types.indexOf("text/plain") >= 0 || types.indexOf("text/") >= 0) root._grabText();
            }
        }
    }

    function _grabText(): void {
        textGrab.exec(["sh", "-c", "wl-paste --no-newline 2>/dev/null | head -c 65536"]);
    }

    Process {
        id: textGrab
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text;
                if (t === "") return;
                const h = root._hash(t);
                if (h === root._lastHash) return;
                root._lastHash = h;
                const e = { kind: t.replace(/\s+$/, "").indexOf("\n") >= 0 ? "code" : "text", text: t, file: "", time: Date.now(), pinned: false, hash: h };
                root._push(e);
            }
        }
    }

    function _grabImage(): void {
        imgGrab.exec(["sh", "-c",
            "mkdir -p " + _q(imgDir) + "; " +
            "f=" + _q(imgDir + "/clip-" + stamp() + ".png") + "; " +
            "wl-paste --type image/png 2>/dev/null | head -c 8388608 > \"$f\"; " +
            "h=$(md5sum \"$f\" 2>/dev/null | cut -d' ' -f1); " +
            "if [ \"$h\" = \"" + _lastHash + "\" ]; then rm -f \"$f\"; printf 'SAME'; " +
            "else printf '%s %s' \"$h\" \"$f\"; fi"]);
    }

    Process {
        id: imgGrab
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const t = this.text.trim();
                if (t === "" || t === "SAME") return;
                const sp = t.indexOf(" ");
                if (sp < 0) return;
                const h = t.substring(0, sp);
                const f = t.substring(sp + 1);
                if (h === "") return;
                root._lastHash = h;
                root._push({ kind: "image", text: "", file: f, time: Date.now(), pinned: false, hash: h });
            }
        }
    }

    function _q(s: string): string {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function _push(e): void {
        const list = root.entries.slice();
        list.unshift(e);
        while (list.length > root.maxEntries) {
            const dropped = list.pop();
            if (!dropped.pinned && dropped.file !== "") _rmFile(dropped.file);
        }
        root.entries = list;
    }

    function _rmFile(f: string): void {
        rmProc.exec(["rm", "-f", f]);
    }
    Process { id: rmProc; command: [] }

    function copyEntry(e): void {
        if (!e) return;
        if (e.kind === "image" && e.file !== "") {
            root._lastHash = e.hash;
            copyProc.exec(["sh", "-c", "wl-copy --type image/png < " + _q(e.file)]);
        } else {
            root._lastHash = e.hash;
            outWriter.path = imgDir + "/clip-out.txt";
            pendingCopy = imgDir + "/clip-out.txt";
            outWriter.setText(e.text);
        }
    }

    property string pendingCopy: ""
    FileView {
        id: outWriter
        watchChanges: false
        blockLoading: false
        printErrors: false
        onSaved: {
            if (pendingCopy !== "") {
                copyProc.exec(["sh", "-c", "wl-copy < " + _q(pendingCopy)]);
                pendingCopy = "";
            }
        }
    }
    function togglePin(hash: string): void {
        const list = root.entries.slice();
        for (const e of list) if (e.hash === hash) e.pinned = !e.pinned;
        root.entries = list;
    }

    function removeEntry(hash: string): void {
        const list = [];
        for (const e of root.entries) {
            if (e.hash === hash) {
                if (!e.pinned && e.file !== "") _rmFile(e.file);
            } else {
                list.push(e);
            }
        }
        root.entries = list;
    }

    function ageText(t: real): string {
        const s = Math.max(0, Math.floor((Date.now() - t) / 1000));
        if (s < 60) return s + "s";
        const m = Math.floor(s / 60);
        if (m < 60) return m + "m";
        return Math.floor(m / 60) + "h";
    }
}
