pragma Singleton
import QtQuick
import Quickshell

// Filesystem locations. Everything else asks us; nothing builds paths by hand.
Singleton {
    id: root

    // Directory containing shell.qml (works for `qs -p <dir>` and installed copies).
    readonly property string shellDir: {
        const u = Qt.resolvedUrl("../shell.qml").toString();
        const p = u.startsWith("file://") ? u.substring(7) : u;
        return decodeURIComponent(p);
    }

    readonly property string configDir: {
        const xdg = Quickshell.env("XDG_CONFIG_HOME");
        return (xdg && xdg.length > 0 ? xdg : Quickshell.env("HOME") + "/.config") + "/harmonica";
    }

    readonly property string walPath: Quickshell.env("HOME") + "/.cache/wal/colors.json"

    function iconPath(category: string, name: string): string {
        return shellDir + "/assets/icons/" + category + "/" + name + ".svg";
    }
}
