pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Battery via sysfs — no UPower dependency. Probes /sys/class/power_supply/BAT*
// once at boot, then watches capacity/status files with a slow re-poll fallback.
Singleton {
    id: root

    readonly property bool present: baseDir !== ""
    readonly property int percentage: parseInt(capFile.text()) || 0
    readonly property string statusText: statFile.text().trim()
    readonly property bool charging: statusText.indexOf("Charging") === 0
    readonly property bool full: statusText === "Full"

    // Icon mapping over the vendored Material set.
    readonly property string iconName: !present ? "battery-low"
        : charging ? "battery-charging"
        : percentage <= 25 ? "battery-low"
        : percentage <= 75 ? "battery-mid"
        : "battery-full"

    property string baseDir: ""
    readonly property string capPath: baseDir + "/capacity"
    readonly property string statPath: baseDir + "/status"

    Component.onCompleted: probe.running = true

    Process {
        id: probe
        command: ["sh", "-c", "for d in /sys/class/power_supply/BAT*; do [ -f \"$d/capacity\" ] && echo \"$d\" && break; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.baseDir = this.text.trim();
                if (root.baseDir !== "") {
                    capFile.reload();
                    statFile.reload();
                }
            }
        }
    }

    FileView {
        id: capFile
        path: root.baseDir === "" ? "/dev/null" : root.capPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
    FileView {
        id: statFile
        path: root.baseDir === "" ? "/dev/null" : root.statPath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    // sysfs doesn't always emit change events; poll gently.
    Timer {
        interval: 30000
        running: root.present
        repeat: true
        triggeredOnStart: false
        onTriggered: { capFile.reload(); statFile.reload(); }
    }
}
