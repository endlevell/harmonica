import QtQuick
import Quickshell
import Quickshell.Io

// Bottom-island emoji picker: one window per screen, opened on the
// focused screen (Variants + activeworkspace probe, wallpaper pattern).
Scope {
    id: root

    Variants {
        id: viewVariants
        model: Quickshell.screens
        EmojiView {}
    }

    function shownView(): var {
        for (const v of viewVariants.instances) {
            if (v.shown) return v;
        }
        return viewVariants.instances.length > 0 ? viewVariants.instances[0] : null;
    }

    function open(): void {
        focusProbe.exec(["sh", "-c", "hyprctl activeworkspace -j 2>/dev/null | sed -n 's/.*\"monitor\"[[:space:]]*:[[:space:]]*\"\\([^\"]*\\)\".*/\\1/p'"]);
    }

    function _openOnMonitor(name: string): void {
        let target = null;
        for (const v of viewVariants.instances) {
            if (target === null && name !== "" && v.screen && v.screen.name === name) target = v;
            else if (v.shown) v.close();
        }
        if (target === null) target = viewVariants.instances.length > 0 ? viewVariants.instances[0] : null;
        if (target !== null) target.open();
    }

    Process {
        id: focusProbe
        command: []
        stdout: StdioCollector { onStreamFinished: root._openOnMonitor(this.text.trim()) }
    }

    IpcHandler {
        target: "emoji"

        function open(): void { root.open(); }
        function close(): void { const v = root.shownView(); if (v) v.close(); }
        function toggle(): void {
            const v = root.shownView();
            if (v && v.shown) v.close();
            else root.open();
        }
    }
}
