pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// Screenshot plumbing: grim capture (region/full), wl-copy, shot bookkeeping.
// The region-select + annotation OVERLAYS live elsewhere (approved exception).
Singleton {
    id: root

    readonly property string shotsDir: {
        const p = Quickshell.env("XDG_PICTURES_DIR");
        return (p && p.length > 0 ? p : Quickshell.env("HOME") + "/Pictures") + "/harmonica";
    }

    property string lastShot: ""           // absolute path of most recent capture

    signal captured(string path)

    function stamp(): string { return Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss"); }

    function _ensureDirThen(cmd: list): void {
        ensure.exec(["sh", "-c", "mkdir -p '" + shotsDir + "' && " + cmd]);
    }

    // capture a WxH+X+Y region straight to shotsDir
    function captureRegion(x: int, y: int, w: int, h: int): void {
        captureRegionToFile(x, y, w, h, shotsDir + "/shot-" + stamp() + ".png");
    }

    // capture to an explicit path (temp annotate sources, tests…)
    function captureRegionToFile(x: int, y: int, w: int, h: int, path: string): void {
        _ensureDirThen("grim -g '" + x + "," + y + " " + w + "x" + h + "' '" + path + "'");
        lastShot = path;
    }

    // full-output capture (used to freeze the frame for annotation)
    function captureFull(): void {
        const f = shotsDir + "/shot-" + stamp() + ".png";
        _ensureDirThen("grim '" + f + "'");
        lastShot = f;
    }

    function saveAs(tempPath: string): string {
        const f = shotsDir + "/annot-" + stamp() + ".png";
        saver.exec(["sh", "-c", "cp '" + tempPath + "' '" + f + "'"]);
        lastShot = f;
        return f;
    }

    function copyToClipboard(path: string): void {
        copyProc.exec(["sh", "-c", "wl-copy < '" + path + "'"]);
    }
    function copyLast(): void { if (lastShot !== "") copyToClipboard(lastShot); }

    Process {
        id: ensure
        command: []
        stdout: StdioCollector { onStreamFinished: root.captured(root.lastShot) }
    }

    Process { id: copyProc; command: [] }
    Process { id: saver; command: [] }
}
