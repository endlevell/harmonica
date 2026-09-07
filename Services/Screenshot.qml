pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// Screenshot quick actions (old-shell parity: grimblast copy area, hyprpicker,
// nothing more). Every entry funnels through request(): the island collapses
// first, the capture fires ~300ms later so the island is never in the shot.
// grimblast when present, grim+slurp+wl-copy fallback otherwise. Cancelled
// selections and missing binaries are silent: any non-zero exit only resets
// state — no popups, no notifies, ever.
Singleton {
    id: root

    // Orchestra collapses every open view on this (back to IDLE).
    signal collapseRequested()

    property string lastShot: ""    // most recent save-to-file capture
    property int confirmTick: 0     // +1 per success → IdleBar check pulse

    property string _pending: ""
    property string _filePath: ""
    property bool _expectFile: false
    property bool _hasGrimblast: false
    readonly property string _picsBase: {
        const p = Quickshell.env("XDG_PICTURES_DIR");
        return (p && p.length > 0 ? p : Quickshell.env("HOME") + "/Pictures");
    }
    readonly property string saveDir: SettingsData.shotSaveDir !== "" ? SettingsData.shotSaveDir : _picsBase + "/Screenshots"

    function stamp(): string { return Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss"); }

    function _q(s: string): string {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    Component.onCompleted: probe.exec(["sh", "-c", "command -v grimblast"]);
    Process {
        id: probe
        command: []
        stdout: StdioCollector { onStreamFinished: root._hasGrimblast = this.text.trim() !== "" }
    }

    // ---- single entry: island UI and IPC share it ----
    function request(action: string): void {
        if (action !== "area" && action !== "screen" && action !== "output"
                && action !== "save-area" && action !== "save-screen" && action !== "color") return;
        root._pending = action;
        root.collapseRequested();
        delay.restart();
    }

    function area(): void { request("area"); }
    function screen(): void { request("screen"); }
    function output(): void { request("output"); }
    function saveArea(): void { request("save-area"); }
    function saveScreen(): void { request("save-screen"); }
    function pickColor(): void { request("color"); }

    Timer {
        id: delay
        interval: Theme.shotCollapseDelayMs
        repeat: false
        onTriggered: root._fire(root._pending)
    }

    function _fire(action: string): void {
        root._pending = "";
        if (action === "") return;
        root._expectFile = false;
        root._filePath = "";
        if (action === "save-area" || action === "save-screen") {
            root._filePath = root.saveDir + "/shot-" + root.stamp() + ".png";
            root._expectFile = true;
        }
        run.exec(["sh", "-c", root._build(action)]);
    }

    function _build(action: string): string {
        if (root._hasGrimblast) return root._buildBlast(action);
        return root._buildFallback(action);
    }

    // exact spec commands
    function _buildBlast(action: string): string {
        switch (action) {
        case "area": return "grimblast copy area";
        case "screen": return "grimblast copy screen";
        case "output": return "grimblast copy output";
        case "save-area": return "mkdir -p " + _q(root.saveDir) + " && grimblast save area " + _q(root._filePath);
        case "save-screen": return "mkdir -p " + _q(root.saveDir) + " && grimblast save screen " + _q(root._filePath);
        case "color": return "hyprpicker -a";
        default: return "exit 0";
        }
    }

    // grim + slurp + wl-clipboard composition of the same six actions.
    // screen/output never pick: focused output via hyprctl, all outputs via
    // bare grim. Only area actions open slurp (inherently interactive).
    function _buildFallback(action: string): string {
        const focusedOut = "$(hyprctl monitors | awk '/^Monitor /{m=$2} /^[ \\t]*focused: yes/{print m; exit}')";
        switch (action) {
        case "area": return "geo=$(slurp) || exit 0; grim -g \"$geo\" - | wl-copy --type image/png";
        case "screen": return "out=" + focusedOut + " && grim -o \"$out\" - | wl-copy --type image/png";
        case "output": return "grim - | wl-copy --type image/png";
        case "save-area": return "geo=$(slurp) || exit 0; mkdir -p " + _q(root.saveDir) + " && grim -g \"$geo\" " + _q(root._filePath);
        case "save-screen": return "out=" + focusedOut + " && mkdir -p " + _q(root.saveDir) + " && grim -o \"$out\" " + _q(root._filePath);
        case "color": return "hyprpicker -a";
        default: return "exit 0";
        }
    }


    Process {
        id: run
        command: []
        stderr: SplitParser { onRead: data => console.warn("[screenshot]", data) }
        onExited: code => {
            if (code === 0) {
                if (root._expectFile && root._filePath !== "") root.lastShot = root._filePath;
                root.confirmTick++;
            }
            // anything else (cancelled slurp, missing binary) is silent by design
            root._expectFile = false;
            root._filePath = "";
        }
    }
}
