pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// User settings persisted to $XDG_CONFIG_HOME/harmonica/config.json.
// Manual JSON (schema version + migrations), debounced writes, self-write
// suppression, parse-error lockout (never clobber the file after a bad reload).
Singleton {
    id: root

    // ---- schema ----
    property bool clock24h: true
    property bool showSeconds: false
    property bool reduceMotion: false
    property string recFilenameFormat: "recording_%Y-%m-%d_%H-%M-%S"
    property string recExt: "mkv"                // mkv | mp4 | mov | flv | webm
    property string recQuality: "medium"         // low | medium | high | lossless
    property string recResolution: "1080p"       // 2160p | 1440p | 1080p | 720p
    property int recFps: 60                      // 24 | 30 | 60 | 120
    property string recVideoCodec: "h264"        // h264 | hevc | av1 | vp9
    property string recAudioCodec: "aac"         // aac | opus | flac
    property string recTarget: "screen"          // screen | window
    property bool recCaptureAudio: true
    property bool recCaptureMic: false
    property bool recShowCursor: true
    property string recOutputDevice: ""          // pw node name, "" = default
    property string recInputDevice: ""           // pw node name, "" = default
    property string recSaveDir: ""               // "" = recOutDir default
    property string shotSaveDir: ""             // "" = ~/Pictures/Screenshots
    readonly property int version: 4

    readonly property string recOutDir: {
        if (recSaveDir !== "") return recSaveDir;
        const v = Quickshell.env("XDG_VIDEOS_DIR");
        return (v && v.length > 0) ? v : Quickshell.env("HOME") + "/Videos/harmonica";
    }

    readonly property string filePath: Paths.configDir + "/config.json"

    property bool _loaded: false
    property bool _selfWrite: false
    property string _lastGoodJson: ""

    function _apply(text: string): void {
        try {
            const o = JSON.parse(text);
            const ver = (typeof o.version === "number") ? o.version : 0;
            if (typeof o.clock24h === "boolean") root.clock24h = o.clock24h;
            if (typeof o.showSeconds === "boolean") root.showSeconds = o.showSeconds;
            if (typeof o.reduceMotion === "boolean") root.reduceMotion = o.reduceMotion;
            if (typeof o.recFilenameFormat === "string" && o.recFilenameFormat !== "") {
                root.recFilenameFormat = o.recFilenameFormat;
            } else if (ver < 3 && typeof o.recFilename === "string" && o.recFilename !== "") {
                // v2 migration: bare prefix becomes a dated format
                root.recFilenameFormat = o.recFilename.replace(/[^\w-]/g, "") + "-%Y-%m-%d_%H-%M-%S";
            }
            if (o.recExt === "mp4" || o.recExt === "mkv" || o.recExt === "mov" || o.recExt === "flv" || o.recExt === "webm") root.recExt = o.recExt;
            else if (ver < 3) root.recExt = "mkv";
            if (o.recQuality === "low" || o.recQuality === "medium" || o.recQuality === "high" || o.recQuality === "lossless") root.recQuality = o.recQuality;
            if (o.recResolution === "2160p" || o.recResolution === "1440p" || o.recResolution === "1080p" || o.recResolution === "720p") root.recResolution = o.recResolution;
            if (o.recFps === 24 || o.recFps === 30 || o.recFps === 60 || o.recFps === 120) root.recFps = o.recFps;
            if (o.recVideoCodec === "h264" || o.recVideoCodec === "hevc" || o.recVideoCodec === "av1" || o.recVideoCodec === "vp9") root.recVideoCodec = o.recVideoCodec;
            if (o.recAudioCodec === "aac" || o.recAudioCodec === "opus" || o.recAudioCodec === "flac") root.recAudioCodec = o.recAudioCodec;
            if (o.recTarget === "screen" || o.recTarget === "window") root.recTarget = o.recTarget;
            if (typeof o.recCaptureAudio === "boolean") root.recCaptureAudio = o.recCaptureAudio;
            if (typeof o.recCaptureMic === "boolean") root.recCaptureMic = o.recCaptureMic;
            if (typeof o.recShowCursor === "boolean") root.recShowCursor = o.recShowCursor;
            if (typeof o.recOutputDevice === "string") root.recOutputDevice = o.recOutputDevice;
            if (typeof o.recInputDevice === "string") root.recInputDevice = o.recInputDevice;
            if (typeof o.recSaveDir === "string") root.recSaveDir = o.recSaveDir;
            if (typeof o.shotSaveDir === "string") root.shotSaveDir = o.shotSaveDir;
            else if (ver < 3 && typeof o.recAudioSource === "string" && o.recAudioSource !== "") root.recOutputDevice = o.recAudioSource;
            root._lastGoodJson = text;
            root._loaded = true;
        } catch (e) {
            console.warn("[Settings] parse failed, keeping in-memory state:", e);
            // parse-error lockout: do NOT write back until next good external load
        }
    }

    function save(): void {
        const payload = JSON.stringify({
            version: root.version,
            clock24h: root.clock24h,
            showSeconds: root.showSeconds,
            reduceMotion: root.reduceMotion,
            recFilenameFormat: root.recFilenameFormat,
            recExt: root.recExt,
            recQuality: root.recQuality,
            recResolution: root.recResolution,
            recFps: root.recFps,
            recVideoCodec: root.recVideoCodec,
            recAudioCodec: root.recAudioCodec,
            recTarget: root.recTarget,
            recCaptureAudio: root.recCaptureAudio,
            recCaptureMic: root.recCaptureMic,
            recShowCursor: root.recShowCursor,
            recOutputDevice: root.recOutputDevice,
            recInputDevice: root.recInputDevice,
            recSaveDir: root.recSaveDir,
            shotSaveDir: root.shotSaveDir
        }, null, 2);
        root._selfWrite = true;
        file.setText(payload);
        root._lastGoodJson = payload;
    }

    function scheduleSave(): void {
        if (!root._loaded) return;   // don't echo initial load back to disk
        saveTimer.restart();
    }

    function _ensureDir(): void {
        mkdirProc.command = ["mkdir", "-p", Paths.configDir];
        mkdirProc.running = true;
    }

    Process { id: mkdirProc; command: [] }

    Timer {
        id: saveTimer
        interval: 250
        onTriggered: root.save()
    }

    FileView {
        id: file
        path: root.filePath
        watchChanges: true
        atomicWrites: true
        blockLoading: true     // settings needed before first frame
        printErrors: false
        onLoaded: root._apply(text())
        onLoadFailed: err => {
            if (!root._loaded) {           // first boot, no file yet → write defaults
                root._loaded = true;
                root._ensureDir();
                Qt.callLater(root.save);
            }
            // otherwise: keep last good state, don't clobber
        }
        onFileChanged: {
            if (root._selfWrite) { root._selfWrite = false; return; }
            reload();
        }
        onSaved: root._selfWrite = false   // our own write echoed back — swallow next change event
    }

    onClock24hChanged: scheduleSave()
    onShowSecondsChanged: scheduleSave()
    onReduceMotionChanged: scheduleSave()
    onRecFilenameFormatChanged: scheduleSave()
    onRecExtChanged: scheduleSave()
    onRecQualityChanged: scheduleSave()
    onRecResolutionChanged: scheduleSave()
    onRecFpsChanged: scheduleSave()
    onRecVideoCodecChanged: scheduleSave()
    onRecAudioCodecChanged: scheduleSave()
    onRecTargetChanged: scheduleSave()
    onRecCaptureAudioChanged: scheduleSave()
    onRecCaptureMicChanged: scheduleSave()
    onRecShowCursorChanged: scheduleSave()
    onRecOutputDeviceChanged: scheduleSave()
    onRecInputDeviceChanged: scheduleSave()
    onRecSaveDirChanged: scheduleSave()
    onShotSaveDirChanged: scheduleSave()
}
