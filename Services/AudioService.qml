pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Volume & mute control via wpctl (PipeWire native)
Singleton {
    id: root

    property real volume: 0.5           // 0.0 .. 1.0
    property bool muted: false

    function setVolume(v: real): void {
        const clamped = Math.max(0.0, Math.min(1.0, v));
        root.volume = clamped;
        volSetter.exec(["wpctl", "set-volume", "@DEFAULT_AUDIO_SINK@", clamped.toFixed(2)]);
    }

    function toggleMute(): void {
        muteSetter.exec(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]);
        poll();
    }

    function poll(): void {
        volGetter.exec(["sh", "-c", "wpctl get-volume @DEFAULT_AUDIO_SINK@ 2>/dev/null"]);
    }

    Process { id: volSetter; command: [] }
    Process { id: muteSetter; command: [] }

    Process {
        id: volGetter
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim();
                // Format: "Volume: 0.65 [MUTED]" or "Volume: 0.65"
                const match = s.match(/Volume:\s+([0-9.]+)(.*)/i);
                if (match) {
                    root.volume = parseFloat(match[1]) || 0.0;
                    root.muted = match[2].includes("[MUTED]");
                }
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.poll()
    }
}
