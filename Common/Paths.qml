pragma Singleton
import QtQuick
import Quickshell

// Filesystem locations. Everything else asks us; nothing builds paths by hand.
Singleton {
    id: root

    // Directory containing shell.qml — provided natively by quickshell
    // (resolves correctly for -p, installed copies AND the qs:// scheme).
    readonly property string shellDir: Quickshell.shellDir

    readonly property string configDir: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        return (xdg && xdg.length > 0 ? xdg : Quickshell.env("HOME") + "/.config") + "/harmonica";
    }

    readonly property string walPath: Quickshell.env("HOME") + "/.cache/wal/colors.json"

    function iconPath(category: string, name: string): string {
        return shellDir + "/assets/icons/" + category + "/" + name + ".svg";
    }
}
