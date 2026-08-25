// Harmonica — composition root. Instantiates surfaces per screen; nothing else.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Modules.orchestra
import qs.Services

Scope {
    id: root

    Variants {
        id: islandVariants

        model: Quickshell.screens
        Orchestra {}

        readonly property var island: instances[0] ?? null
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
}
