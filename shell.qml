// Harmonica — composition root. Instantiates surfaces per screen; nothing else.
// Approved exceptions: RegionSelect + WallpaperPicker.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Modules.orchestra
import qs.Modules.screenshot
import qs.Modules.wallpaper
import qs.Services
Scope {
    id: root
    Variants {
        id: islandVariants

        model: Quickshell.screens
        Orchestra {}

        readonly property var island: instances[0] ?? null
    }
    RegionSelect {
        id: regionSelect

        onRegionAccepted: (x, y, w, h) => {
            pendingAnnotate = true;
            Screenshot.captureRegionToFile(x, y, w, h, "/tmp/harmonica-annot-" + Screenshot.stamp() + ".png");
        }
        onCancelled: pendingAnnotate = false
    }

    WallpaperModule {}

    property bool pendingAnnotate: false

    Connections {
        target: Screenshot
        function onCaptured(path: string) {
            if (root.pendingAnnotate && islandVariants.island && path !== "") {
                root.pendingAnnotate = false;
                islandVariants.island.openAnnotate(path);
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
        target: "screenshot"

        function region(): void { regionSelect.open("snip"); }
        function window(): void { regionSelect.open("window"); }
        function cancel(): void { regionSelect.close(); root.pendingAnnotate = false; }
        function fullscreen(): void {
            root.pendingAnnotate = true;
            Screenshot.captureFull();
        }
        function annotate(path: string): void {
            if (islandVariants.island) islandVariants.island.openAnnotate(path);
        }
        function save(): string {
            return islandVariants.island ? islandVariants.island.apiSaveAnnotate() : "";
        }
        function full(): string {
            Screenshot.captureFull();
            return Screenshot.lastShot;
        }
        function copyLast(): void { Screenshot.copyLast(); }
    }

}
