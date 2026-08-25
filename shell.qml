// Harmonica — composition root. Instantiates surfaces per screen; nothing else.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Modules.launcher
import qs.Modules.orchestra

Scope {
    id: root

    Variants {
        id: islandVariants

        model: Quickshell.screens
        Orchestra {}

        readonly property var island: instances[0] ?? null
    }

    Launcher {
        id: launcher
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

        function open(): void { launcher.open(); }
        function close(): void { launcher.close(); }
        function toggle(): void { launcher.toggle(); }
        function isOpen(): bool { return launcher.shown; }
        function results(): int { return launcher.resultCount; }
    }
}
