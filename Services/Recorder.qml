pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// Screen recording via wf-recorder. Pause = SIGSTOP (frames freeze), resume =
// SIGCONT. Audio: single capture device (pipewire node name) — upgrade path
// for multi-source mixing is a pw loopback sink.
Singleton {
    id: root

    readonly property string state: _state          // idle | recording | paused
    property string _state: "idle"
    readonly property bool active: _state !== "idle"
    readonly property int elapsedSecs: _elapsed
    property int _elapsed: 0
    property string lastFile: ""

    // settings mirrored from SettingsData for command building
    readonly property string outDir: {
        const v = Quickshell.env("XDG_VIDEOS_DIR");
        return (v && v.length > 0) ? v : Quickshell.env("HOME") + "/Videos";
    }

    // ---- audio sources (pipewire capture-capable nodes) ----
    property var audioSources: []                    // [{name, desc}]
    function refreshAudioSources(): void { srcScan.exec(["sh", "-c",
        "pw-cli ls Node 2>/dev/null | awk '\n" +
        "  /node.name =/    {gsub(/.*= \\\"|\\\"$/,\"\"); nm=$0}\n" +
        "  /node.description =/ {gsub(/.*= \\\"|\\\"$/,\"\"); ds=$0}\n" +
        "  /media.class = \"Audio\\/Source\"/ && nm!=\"\" && ds!=\"\" {\n" +
        "      printf \"%s\\037%s\\n\", nm, ds; nm=\"\"; ds=\"\" }'"]) }

    Process {
        id: srcScan
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const arr = [];
                for (const line of this.text.split("\n")) {
                    if (!line) continue;
                    const p = line.split("\x1f");
                    if (p.length >= 2 && p[0] !== "" && p[1] !== "")
                        arr.push({ name: p[0], desc: p[1] });
                }
                root.audioSources = arr;
            }
        }
    }
    // ---- availability ----------------------------------------------------
    readonly property bool available: _available
    property bool _available: false

    Component.onCompleted: {
        refreshAudioSources();
        availProbe.exec(["sh", "-c", "command -v wf-recorder || true"]);
    }

    Process {
        id: availProbe
        command: []
        stdout: StdioCollector { onStreamFinished: root._available = this.text.trim() !== "" }
    }

    // ---- recording process ----
    Process {
        id: rec
        command: []
        stdout: SplitParser { onRead: data => console.log("[recorder]", data) }
        stderr: SplitParser { onRead: data => console.warn("[recorder]", data) }
        onStarted: { root._state = "recording"; root._elapsed = 0; tick.restart(); }
        onExited: {
            tick.stop();
            root._state = "idle";
            root.refreshAudioSources();
        }
    }

    Timer {
        id: tick
        interval: 1000
        repeat: true
        running: false
        onTriggered: root._elapsed++
    }

    function _crf(quality: string): string {
        return quality === "low" ? "28" : quality === "high" ? "18" : "23";
    }

    function start(): void {
        if (active) return;
        if (!available) { console.warn("[recorder] wf-recorder not in PATH — add it to home.packages"); return; }
        const sd = SettingsData;
        const stamp = Qt.formatDateTime(new Date(), "yyyyMMdd-HHmmss");
        const file = sd.recOutDir + "/" + sd.recFilename + "-" + stamp + "." + sd.recExt;
        const args = ["wf-recorder", "-f", file, "-r", "30",
                      "-p", "crf=" + _crf(sd.recQuality)];
        if (sd.recAudioSource !== "")
            args.push("-a" + sd.recAudioSource);
        mkProc.command = ["mkdir", "-p", sd.recOutDir];
        mkProc.running = true;                 // FileView-less dir ensure
        lastFile = file;
        rec.command = args;
        rec.running = true;
    }
    function stop(): void {
        if (!active) return;
        if (_state === "paused") cont();
        rec.running = false;                   // SIGTERM → clean finalize
    }
    function pauseToggle(): void {
        if (_state === "recording") { rec.signal(19); _state = "paused"; }       // SIGSTOP
        else if (_state === "paused") { rec.signal(18); _state = "recording"; }  // SIGCONT
    }

    Process { id: mkProc; command: [] }
}
