// Harmonica — composition root. Instantiates surfaces per screen; nothing else.
// Approved exceptions: WallpaperPicker only.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.Modules.orchestra
import qs.Modules.wallpaper
import qs.Modules.clipboard
import qs.Services
Scope {
    id: root
    Variants {
        id: islandVariants

        model: Quickshell.screens
        Orchestra {}

        readonly property var island: instances[0] ?? null
    }

    WallpaperModule {}
    ClipboardModule {}
    // Store-install reload: the CLI cannot rewrite shell.qml in the
    // read-only Nix store, so it pokes this sentinel instead. Echo of our
    // own boot-time creation is swallowed by content comparison; empty
    // reads (cache wipe) never trigger.
    property string _reloadSeen: ""
    readonly property string reloadSentinelPath: {
        const c = Quickshell.env("XDG_CACHE_HOME");
        return ((c && c.length > 0) ? c : Quickshell.env("HOME") + "/.cache") + "/harmonica/reload-trigger";
    }
    FileView {
        id: reloadSentinel
        path: root.reloadSentinelPath
        watchChanges: true
        blockLoading: false
        printErrors: false
        onFileChanged: {
            const t = reloadSentinel.text();
            if (t !== "" && t !== root._reloadSeen) {
                root._reloadSeen = t;
                // Quickshell.reload(hard: bool) — QuickshellGlobal singleton
                // method per installed 0.3.0 quickshell-core.qmltypes; soft
                // reload mirrors the file-watcher path.
                Quickshell.reload(false);
            }
        }
        onLoadFailed: {
            root._reloadSeen = "0";
            reloadSentinel.setText("0");
        }
    }

    // XDG notification daemon: gated on busReady so a stale mako is evicted
    // BEFORE we claim org.freedesktop.Notifications (no bus race, ever).
    Loader {
        active: Notifications.busReady
        sourceComponent: Component {
            NotificationServer {
                keepOnReload: true
                bodySupported: true
                bodyMarkupSupported: true
                actionsSupported: true
                onNotification: n => Notifications._arrive(n)
                Component.onCompleted: Notifications._adoptTracked(trackedNotifications)
            }
        }
    }


    IpcHandler {
        target: "orchestra"

        function open(): void { if (islandVariants.island) islandVariants.island.apiOpen(); }
        function close(): void { if (islandVariants.island) islandVariants.island.apiClose(); }
        function isOpen(): bool { return islandVariants.island ? islandVariants.island.apiIsOpen() : false; }
        function phase(): string { return islandVariants.island ? islandVariants.island.apiPhase() : "unknown"; }
        function page(): int { return islandVariants.island ? islandVariants.island.apiPage() : -1; }
        function nextPage(): void { if (islandVariants.island) islandVariants.island.apiNextPage(); }
        function prevPage(): void { if (islandVariants.island) islandVariants.island.apiPrevPage(); }
    }

    IpcHandler {
        target: "launcher"

        function open(): void { if (islandVariants.island) islandVariants.island.openLauncher(); }
        function close(): void { if (islandVariants.island) islandVariants.island.closeLauncher(); }
        function toggle(): void { if (islandVariants.island) islandVariants.island.toggleLauncher(); }
        function isOpen(): bool { return islandVariants.island ? islandVariants.island.launcherOpen : false; }
        function results(): int { return islandVariants.island ? islandVariants.island.apiLauncherResults() : 0; }
    }

    IpcHandler {
        target: "record"

        function start(): void { if (islandVariants.island) Recorder.start(); }
        function pause(): void { if (islandVariants.island) Recorder.pauseToggle(); }
        function stop(): void { if (islandVariants.island) Recorder.stop(); }
        function settings(): void { if (islandVariants.island) islandVariants.island.openRecordSettings(); }
        function state(): string { return Recorder.state; }
    }

    IpcHandler {
        target: "wifi"

        function open(): void { if (islandVariants.island) islandVariants.island.openWifi(); }
        function close(): void { if (islandVariants.island) islandVariants.island.closeWifi(); }
        function toggle(): void { if (islandVariants.island) islandVariants.island.toggleWifi(); }
    }

    IpcHandler {
        target: "bluetooth"

        function open(): void { if (islandVariants.island) islandVariants.island.openBluetooth(); }
        function close(): void { if (islandVariants.island) islandVariants.island.closeBluetooth(); }
        function toggle(): void { if (islandVariants.island) islandVariants.island.toggleBluetooth(); }
    }

    IpcHandler {
        target: "screenshot"

        function open(): void { if (islandVariants.island) islandVariants.island.openScreenshot(); }
        function close(): void { if (islandVariants.island) islandVariants.island.closeScreenshot(); }
        function toggle(): void { if (islandVariants.island) islandVariants.island.toggleScreenshot(); }
        function area(): void { Screenshot.request("area"); }
        function screen(): void { Screenshot.request("screen"); }
        function output(): void { Screenshot.request("output"); }
        function saveArea(): void { Screenshot.request("save-area"); }
        function saveScreen(): void { Screenshot.request("save-screen"); }
        function color(): void { Screenshot.request("color"); }
    }

    IpcHandler {
        target: "notifications"

        function dismiss(): void { Notifications.dismissCurrent(); }
        function activate(): void { Notifications.activateCurrent(); }
        function clear(): void { Notifications.clearAll(); }
        function count(): int { return Notifications.count; }
        function current(): string { return Notifications.title; }
    }

}
