import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

// Owns the user-approved standalone picker surfaces + its CLI IPC boundary.
// One picker window per screen (island Variants pattern); at most one is
// ever shown — open() resolves the Hyprland focused monitor and raises the
// matching screen's picker, closing any other.
Scope {
    id: root

    Variants {
        id: pickerVariants
        model: Quickshell.screens
        WallpaperPicker {
            required property ShellScreen modelData
            screen: modelData
        }
    }

    function shownPicker(): var {
        for (const p of pickerVariants.instances) {
            if (p.shown) return p;
        }
        return pickerVariants.instances.length > 0 ? pickerVariants.instances[0] : null;
    }

    function open(): void {
        focusProbe.exec(["sh", "-c", "hyprctl activeworkspace -j 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get(\"monitor\",\"\"))'"]);
    }

    function _openOnMonitor(name: string): void {
        let target = null;
        for (const p of pickerVariants.instances) {
            if (target === null && name !== "" && p.screen && p.screen.name === name) target = p;
            else if (p.shown) p.close();
        }
        if (target === null) target = pickerVariants.instances.length > 0 ? pickerVariants.instances[0] : null;
        if (target !== null) target.open();
    }

    Process {
        id: focusProbe
        command: []
        stdout: StdioCollector { onStreamFinished: root._openOnMonitor(this.text.trim()) }
    }

    IpcHandler {
        target: "wallpaper"

        function open(): void { root.open(); }
        function close(): void { const p = root.shownPicker(); if (p) p.close(); }
        function toggle(): void {
            const p = root.shownPicker();
            if (p && p.shown) p.close();
            else root.open();
        }
        function isOpen(): bool { const p = root.shownPicker(); return p ? p.shown : false; }
        function next(): void { const p = root.shownPicker(); if (p) p.next(); }
        function prev(): void { const p = root.shownPicker(); if (p) p.prev(); }
        function focused(): string { const p = root.shownPicker(); return p ? p.focusedPath : ""; }
        function pick(): string { const p = root.shownPicker(); return p ? p.pick() : ""; }
        function apply(path: string): string { const p = root.shownPicker(); return p ? p.apply(path) : ""; }
        function state(): string {
            return Wallpaper.ready ? Wallpaper.count + " wallpapers" : "empty";
        }
    }
}
