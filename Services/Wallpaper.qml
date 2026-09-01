pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// Headless wallpaper state. Directory discovery comes from pywal JSON, file
// enumeration uses find argv (no shell interpolation), and apply is serialized.
Singleton {
    id: root

    readonly property var wallpapers: _wallpapers
    property var _wallpapers: []
    readonly property int count: _wallpapers.length
    readonly property bool ready: count > 0
    readonly property bool applying: applyProc.running
    readonly property string current: _current
    property string _current: ""
    property string _scanDir: ""
    property string _pending: ""
    property bool _rescanPending: false
    property bool _cancelled: false

    signal applied(string path)
    signal applyFailed(string path)

    Component.onCompleted: Qt.callLater(_syncThemeWallpaper)
    Connections {
        target: Theme
        function onWallpaperChanged(): void {
            root._syncThemeWallpaper();
        }
    }

    function _syncThemeWallpaper(): void {
        const path = Theme.wallpaper;
        if (path !== "") {
            _current = path;
            const slash = path.lastIndexOf("/");
            _scanDir = slash > 0 ? path.substring(0, slash) : "";
        }
        if (_scanDir === "")
            _scanDir = Quickshell.env("HOME") + "/.config/nix/assets/wallpapers";
        rescan();
    }

    function rescan(): void {
        if (_scanDir === "")
            return;
        if (lister.running) {
            _rescanPending = true;
            return;
        }
        _rescanPending = false;
        lister.scanDir = _scanDir;
        lister.exec(["find", _scanDir, "-maxdepth", "1", "-type", "f"]);
    }

    Process {
        id: lister
        command: []
        property string scanDir: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const extensions = /\.(png|jpe?g|webp)$/i;
                const files = [];
                for (const line of this.text.split("\n")) {
                    const path = line.trim();
                    if (path !== "" && extensions.test(path))
                        files.push(path);
                }
                files.sort((a, b) => a.localeCompare(b));
                const unchanged = files.length === root._wallpapers.length && files.every((path, index) => path === root._wallpapers[index]);
                if (lister.scanDir === root._scanDir && !unchanged)
                    root._wallpapers = files;
                if (root._rescanPending || lister.scanDir !== root._scanDir)
                    Qt.callLater(root.rescan);
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("[wallpaper-scan]", data)
        }
    }

    function basename(path: string): string {
        const slash = path.lastIndexOf("/");
        return slash >= 0 ? path.substring(slash + 1) : path;
    }

    function _shellQuote(value: string): string {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    // Reject concurrent requests; the picker remains open until one succeeds.
    function apply(path: string): bool {
        if (path === "" || applying)
            return false;
        _cancelled = false;
        _pending = path;
        const quoted = _shellQuote(path);
        applyProc.exec(["sh", "-c", "awww img " + quoted + " && printf '\\nHARMONICA_AWWW_OK\\n' && wal -q -n -s -t -e -i " + quoted + " && printf '\\nHARMONICA_WALLPAPER_OK\\n'"]);
        return true;
    }

    function cancelApply(): void {
        if (!applying)
            return;
        _cancelled = true;
        applyProc.running = false;
    }

    Process {
        id: applyProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const request = root._pending;
                const cancelled = root._cancelled;
                const ok = this.text.indexOf("HARMONICA_WALLPAPER_OK") >= 0;
                const wallpaperChanged = this.text.indexOf("HARMONICA_AWWW_OK") >= 0;
                root._pending = "";
                root._cancelled = false;
                if (wallpaperChanged)
                    root._current = request;
                if (ok && !cancelled) {
                    root.applied(request);
                } else {
                    root.applyFailed(request);
                }
                root.rescan();
            }
        }
        stderr: SplitParser {
            onRead: data => console.warn("[wallpaper-apply]", data)
        }
    }
}
