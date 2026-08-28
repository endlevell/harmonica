import QtQuick
import Quickshell
import Quickshell.Io
import qs.Services

// Owns the user-approved standalone picker surface + its CLI IPC boundary.
Scope {
    WallpaperPicker { id: picker }

    IpcHandler {
        target: "wallpaper"

        function open(): void { picker.open(); }
        function close(): void { picker.close(); }
        function toggle(): void { picker.toggle(); }
        function isOpen(): bool { return picker.shown; }
        function next(): void { picker.next(); }
        function prev(): void { picker.prev(); }
        function focused(): string { return picker.focusedPath; }
        function pick(): string { return picker.pick(); }
        function apply(path: string): string { return picker.apply(path); }
        function state(): string {
            return Wallpaper.ready ? Wallpaper.count + " wallpapers" : "empty";
        }
    }
}
