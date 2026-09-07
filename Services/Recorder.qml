pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common

// Screen recording via gpu-screen-recorder. SIGUSR2 = pause/resume toggle,
// SIGINT = graceful stop (finalizes the file). A bash wrapper owns the pid
// file (/tmp/harmonica-recorder.pid); signals fall back to pkill when the
// pid is lost. Flag construction mirrors the old shell one-to-one.
Singleton {
    id: root

    readonly property string state: _state          // idle | recording | paused
    property string _state: "idle"
    readonly property bool active: _state !== "idle"
    readonly property int elapsedSecs: _elapsed
    property int _elapsed: 0
    property string lastFile: ""
    property string lastError: ""
    readonly property string pidFile: "/tmp/harmonica-recorder.pid"
    property bool stoppingRequested: false

    // ---- audio devices (pw-dump: pipewire-native, no pactl needed) ----
    property var sinks: []                           // [{name, desc}]
    property var sources: []                         // [{name, desc}]
    property string defaultSink: ""
    property string defaultSource: ""

    function refreshAudioDevices(): void { dump.exec(["sh", "-c", "pw-dump 2>/dev/null"]); }
    function refreshAudioSources(): void { refreshAudioDevices(); } // legacy alias

    Process {
        id: dump
        command: []
        stdout: StdioCollector { onStreamFinished: root._parsePwDump(this.text) }
    }

    function _parsePwDump(text: string): void {
        const sinks = [];
        const sources = [];
        let defSink = "";
        let defSource = "";
        try {
            const arr = JSON.parse(text);
            if (!Array.isArray(arr)) throw new Error("not an array");
            for (const o of arr) {
                if (!o || typeof o !== "object") continue;
                if (o.type === "PipeWire:Interface:Metadata" && o.metadata instanceof Array) {
                    for (const m of o.metadata) {
                        if (!m || typeof m.key !== "string") continue;
                        const v = (m.value && typeof m.value === "object") ? m.value.name : m.value;
                        if (m.key === "default.audio.sink" && typeof v === "string") defSink = v;
                        if (m.key === "default.audio.source" && typeof v === "string") defSource = v;
                    }
                    continue;
                }
                if (o.type !== "PipeWire:Interface:Node") continue;
                const props = (o.info && o.info.props) || o.props || {};
                const cls = props["media.class"];
                const name = props["node.name"];
                if (typeof name !== "string" || name === "") continue;
                const desc = props["node.description"] || props["node.nick"] || name;
                if (cls === "Audio/Sink") sinks.push({ name: name, desc: String(desc) });
                else if (cls === "Audio/Source") sources.push({ name: name, desc: String(desc) });
            }
        } catch (e) {
            root.sinks = [];
            root.sources = [];
            root.defaultSink = "";
            root.defaultSource = "";
            return;
        }
        root.sinks = sinks;
        root.sources = sources;
        root.defaultSink = defSink;
        root.defaultSource = defSource;
    }

    // ---- availability ----------------------------------------------------
    readonly property bool available: _available
    property bool _available: false

    Component.onCompleted: {
        refreshAudioDevices();
        availProbe.exec(["sh", "-c", "command -v gpu-screen-recorder || true"]);
    }

    Process {
        id: availProbe
        command: []
        stdout: StdioCollector { onStreamFinished: root._available = this.text.trim() !== "" }
    }

    // ---- elapsed (frozen while paused, like the old shell) ----
    Timer {
        id: tick
        interval: 1000
        repeat: true
        running: root._state === "recording"
        onTriggered: root._elapsed++
    }

    // ---- command construction (mirrors old buildCommand) ----
    function shellQuote(value: string): string {
        return "'" + String(value).replace(/'/g, "'\\''") + "'";
    }

    function formatFilename(format: string, date): string {
        function pad(v) { return v < 10 ? "0" + v : String(v); }
        return format
            .replace(/%Y/g, String(date.getFullYear()))
            .replace(/%m/g, pad(date.getMonth() + 1))
            .replace(/%d/g, pad(date.getDate()))
            .replace(/%H/g, pad(date.getHours()))
            .replace(/%M/g, pad(date.getMinutes()))
            .replace(/%S/g, pad(date.getSeconds()));
    }

    // 16:9 render sizes; 1080p matches this machine's panel 1:1
    function resolutionSize(): string {
        const m = { "2160p": "3840x2160", "1440p": "2560x1440", "1080p": "1920x1080", "720p": "1280x720" };
        return m[SettingsData.recResolution] || "1920x1080";
    }

    function outputAudioDevice(): string {
        const sel = SettingsData.recOutputDevice;
        if (sel === "") return "default_output";
        if (sel.indexOf(".monitor") >= 0) return "device:" + sel;
        return "device:" + sel + ".monitor";
    }

    function inputAudioDevice(): string {
        const sel = SettingsData.recInputDevice;
        if (sel === "") return "default_input";
        return "device:" + sel;
    }

    function audioArg(): string {
        const parts = [];
        if (SettingsData.recCaptureAudio) parts.push(outputAudioDevice());
        if (SettingsData.recCaptureMic) parts.push(inputAudioDevice());
        return parts.join("|");
    }

    function buildCommand(output: string): var {
        const sd = SettingsData;
        const cmd = [
            "gpu-screen-recorder",
            "-w", sd.recTarget === "screen" ? "screen" : sd.recTarget,
            "-s", resolutionSize(),
            "-f", String(sd.recFps),
            "-c", sd.recExt,
            "-k", sd.recVideoCodec,
            "-ac", sd.recAudioCodec,
            "-q", String(sd.recQuality).toLowerCase(),
            "-o", output
        ];
        const audio = audioArg();
        if (audio !== "") cmd.push("-a", audio);
        if (!sd.recShowCursor) cmd.push("-cursor", "no");
        return cmd;
    }

    function buildShellCommand(output: string): string {
        const command = buildCommand(output).map(a => shellQuote(a)).join(" ");
        const pidFile = shellQuote(root.pidFile);
        const saveDir = shellQuote(SettingsData.recOutDir);
        return "mkdir -p " + saveDir
            + "; rm -f " + pidFile
            + "; " + command + " & recorder_pid=$!"
            + "; printf '%s\\n' \"$recorder_pid\" > " + pidFile
            + "; wait \"$recorder_pid\"; status=$?"
            + "; rm -f " + pidFile
            + "; exit \"$status\"";
    }

    function signalCommand(signalName: string): string {
        const pidFile = shellQuote(root.pidFile);
        return "recorder_pid=$(cat " + pidFile + " 2>/dev/null)"
            + "; if [ -n \"$recorder_pid\" ]; then kill -" + signalName + " \"$recorder_pid\"; else pkill -" + signalName + " -f '^gpu-screen-recorder( |$)'; fi";
    }

    // ---- transport ----
    Process {
        id: rec
        command: []
        stdout: SplitParser { onRead: data => console.log("[recorder]", data) }
        stderr: SplitParser { onRead: data => console.warn("[recorder]", data) }
        onStarted: {
            root._state = "recording";
            root._elapsed = 0;
            root.notifyStarted(root.lastFile);
            root.playSound("start");
        }
        onExited: code => {
            const expected = root.stoppingRequested;
            const path = root.lastFile;
            const elapsed = root._elapsed;
            root.stoppingRequested = false;
            root._state = "idle";
            if (expected || code === 0) {
                root.notifySuccess(path, elapsed);
                if (expected) root.playSound("stop");
            } else {
                root.notifyError("gpu-screen-recorder exited with code " + code);
            }
        }
    }

    Process { id: sigProc; command: [] }

    function start(): void {
        if (active) return;
        if (!available) {
            lastError = "gpu-screen-recorder not in PATH — add it to home.packages";
            console.warn("[recorder]", lastError);
            return;
        }
        lastError = "";
        const sd = SettingsData;
        const file = sd.recOutDir + "/" + formatFilename(sd.recFilenameFormat, new Date()) + "." + sd.recExt;
        lastFile = file;
        rec.exec(["bash", "-c", buildShellCommand(file)]);
    }

    function stop(): void {
        if (!active) return;
        stoppingRequested = true;
        sigProc.exec(["bash", "-c", signalCommand("INT")]);
    }

    function pause(): void {
        if (_state !== "recording") return;
        sigProc.exec(["bash", "-c", signalCommand("USR2")]);
        _state = "paused";
    }

    function resume(): void {
        if (_state !== "paused") return;
        sigProc.exec(["bash", "-c", signalCommand("USR2")]);
        _state = "recording";
    }

    function pauseToggle(): void {
        if (_state === "recording") pause();
        else if (_state === "paused") resume();
    }

    // ---- save-dir picker (zenity → kdialog → yad, like the old shell) ----
    function chooseSaveDir(): void {
        if (folderPicker.running) return;
        folderPicker.exec([
            "bash", "-c",
            "start=\"$1\"; if command -v zenity >/dev/null 2>&1; then zenity --file-selection --directory --title='Choose recording folder' --filename=\"$start/\"; elif command -v kdialog >/dev/null 2>&1; then kdialog --getexistingdirectory \"$start\" 'Choose recording folder'; elif command -v yad >/dev/null 2>&1; then yad --file-selection --directory --title='Choose recording folder' --filename=\"$start/\"; else printf 'No folder picker found: install zenity, kdialog, or yad.\\n' >&2; exit 2; fi",
            "folder-picker",
            SettingsData.recOutDir
        ]);
    }

    Process {
        id: folderPicker
        command: []
        stdout: StdioCollector { id: folderPickerOut; onStreamFinished: root._onFolderPicked(this.text) }
        stderr: SplitParser { onRead: data => console.warn("[recorder-picker]", data) }
    }

    function _onFolderPicked(text: string): void {
        const dir = text.trim();
        if (dir === "") return;
        SettingsData.recSaveDir = dir;
    }

    // ---- desktop notices (surface on our own island) ----
    function notifyStarted(path: string): void {
        Quickshell.execDetached(["notify-send", "-a", "Screen Recorder",
            "Recording started", "Saving as " + path.split("/").pop() + "."]);
    }

    function notifySuccess(path: string, seconds: int): void {
        const m = Math.floor(seconds / 60);
        const s = seconds % 60;
        const when = (m > 0 ? m + "m " : "") + s + "s";
        Quickshell.execDetached(["notify-send", "-a", "Screen Recorder",
            "Recording saved", path.split("/").pop() + " captured (" + when + ")."]);
    }

    function notifyError(message: string): void {
        lastError = message;
        Quickshell.execDetached(["notify-send", "-a", "Screen Recorder",
            "Recording failed", message]);
    }

    // ---- start/stop blips (pw-play → mpv; paplay absent on this box) ----
    function playSound(which: string): void {
        const f = Paths.shellDir + "/assets/sounds/rec-" + (which === "stop" ? "stop" : "start") + ".wav";
        Quickshell.execDetached(["sh", "-c",
            "f=" + shellQuote(f) + "; if command -v pw-play >/dev/null 2>&1; then pw-play \"$f\"; elif command -v mpv >/dev/null 2>&1; then mpv --no-terminal --really-quiet \"$f\"; fi"]);
    }
}
