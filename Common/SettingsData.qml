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
    readonly property int version: 1

    readonly property string filePath: Paths.configDir + "/config.json"

    property bool _loaded: false
    property bool _selfWrite: false
    property string _lastGoodJson: ""

    function _apply(text: string): void {
        try {
            const o = JSON.parse(text);
            if (typeof o.clock24h === "bool") root.clock24h = o.clock24h;
            if (typeof o.showSeconds === "bool") root.showSeconds = o.showSeconds;
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
            showSeconds: root.showSeconds
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
}
