pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Bluetooth status and power toggle
Singleton {
    id: root

    property bool powered: false
    property string deviceName: ""

    function togglePower(): void {
        const next = !powered;
        root.powered = next;
        btSetter.exec(["sh", "-c", "bluetoothctl power " + (next ? "on" : "off")]);
        poll();
    }

    function poll(): void {
        btGetter.exec(["sh", "-c",
            "bluetoothctl show 2>/dev/null | grep -i 'Powered:' | awk '{print $2}'; " +
            "bluetoothctl info 2>/dev/null | grep -i 'Name:' | head -1 | cut -d' ' -f2-"
        ]);
    }

    Process { id: btSetter; command: [] }

    Process {
        id: btGetter
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = this.text.trim().split("\n");
                if (lines.length > 0) {
                    root.powered = lines[0].trim().toLowerCase() === "yes";
                    root.deviceName = lines.length > 1 ? lines[1].trim() : "";
                }
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }
}
