pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// CPU + RAM poller. Demand-gated: acquire()/release() from views; the process
// only runs while someone consumes it (ricefield pitfall #4).
Singleton {
    id: root

    // consumers
    property int consumers: 0

    readonly property real cpuPct: cpuPctInternal
    property real cpuPctInternal: 0
    readonly property var cpuHistory: cpuHistoryInternal   // last N samples, 0..1
    property var cpuHistoryInternal: []
    readonly property var memHistory: memHistoryInternal
    property var memHistoryInternal: []

    readonly property int memTotalKb: memTotal
    readonly property int memAvailKb: memAvail
    property int memTotal: 0
    property int memAvail: 0
    readonly property real memPct: memTotal > 0 ? 1 - (memAvail / memTotal) : 0
    readonly property int maxSamples: 60

    property real _prevIdle: -1
    property real _prevTotal: -1

    function acquire(): void { consumers++; }
    function release(): void { consumers = Math.max(0, consumers - 1); }

    Timer {
        interval: 2000
        running: root.consumers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: proc.exec(["sh", "-c", "head -1 /proc/stat; grep -E '^(MemTotal|MemAvailable)' /proc/meminfo"])
    }

    Process {
        id: proc
        command: []
        stdout: StdioCollector {
            onStreamFinished: root._parse(this.text)
        }
    }

    function _parse(text: string): void {
        const lines = text.trim().split("\n");
        for (const line of lines) {
            if (line.startsWith("cpu ")) {
                const f = line.split(/\s+/).slice(1).map(Number);
                const idle = f[3] + (f.length > 4 ? f[4] : 0);   // idle + iowait
                const total = f.reduce((a, b) => a + b, 0);
                if (_prevTotal > 0 && total > _prevTotal) {
                    cpuPctInternal = Math.min(1, Math.max(0, 1 - (idle - _prevIdle) / (total - _prevTotal)));
                }
                _prevIdle = idle;
                _prevTotal = total;
            } else if (line.startsWith("MemTotal:")) {
                memTotal = parseInt(line.replace(/\D+/g, "")) || 0;
            } else if (line.startsWith("MemAvailable:")) {
                memAvail = parseInt(line.replace(/\D+/g, "")) || 0;
            }
        }
        // reassign whole arrays — deep mutation doesn't notify (qml-core §7)
        cpuHistoryInternal = cpuHistoryInternal.slice(-(maxSamples - 1)).concat([cpuPctInternal]);
        memHistoryInternal = memHistoryInternal.slice(-(maxSamples - 1)).concat([memPct]);
    }
}
