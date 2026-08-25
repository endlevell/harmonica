pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Network status via one shell probe (iface/type/ip/ssid) + /proc/net/dev
// deltas for throughput. Demand-gated like CpuRam.
Singleton {
    id: root

    property int consumers: 0
    function acquire(): void { consumers++; }
    function release(): void { consumers = Math.max(0, consumers - 1); }

    readonly property string state: iface === "" ? "disconnected" : netType   // "wifi" | "ethernet" | "disconnected"
    property string iface: ""
    property string netType: "wifi"
    property string ssid: ""
    property string ip: ""
    property real downKBs: 0
    property real upKBs: 0

    // ---- identity probe (slow cadence) ----
    Timer {
        interval: 6000
        running: root.consumers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: metaProc.exec(["sh", "-c", `
IF=$(ip route get 1.1.1.1 2>/dev/null | sed -n "s/.*dev \\([^ ]*\\).*/\\1/p" | head -n1)
if [ -z "$IF" ]; then echo state disconnected; exit 0; fi
echo iface "$IF"
IP=$(hostname -I 2>/dev/null | cut -d" " -f1)
echo ip "$IP"
if [ -d "/sys/class/net/$IF/wireless" ]; then
  echo type wifi
  C=$(nmcli -t -f GENERAL.CONNECTION device show "$IF" 2>/dev/null | cut -d: -f2-)
  S=$(nmcli -t -f 802-11-wireless.ssid connection show "$C" 2>/dev/null | cut -d: -f2-)
  echo ssid "$S"
else
  echo type ethernet
fi`])
    }

    Process {
        id: metaProc
        command: []
        stdout: SplitParser {
            onRead: data => {
                const line = data.trim();
                const sp = line.indexOf(" ");
                const key = sp < 0 ? line : line.substring(0, sp);
                const val = sp < 0 ? "" : line.substring(sp + 1);
                if (key === "state") root.iface = val === "connected" ? "-" : "";
                else if (key === "iface") { root.iface = val; }
                else if (key === "type") root.netType = val;
                else if (key === "ip") root.ip = val;
                else if (key === "ssid") root.ssid = val === "(null)" ? "" : val;
            }
        }
    }

    // ---- throughput (fast cadence) ----
    property real _prevRx: -1
    property real _prevTx: -1
    property real _prevT: 0

    Timer {
        interval: 2000
        running: root.consumers > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: rateProc.exec(["sh", "-c", "awk '$1!=\"lo:\"{rx+=$2; tx+=$10} END{print rx, tx}' /proc/net/dev"])
    }

    Process {
        id: rateProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = this.text.trim().split(/\s+/).map(Number);
                if (parts.length !== 2) return;
                const now = Date.now();
                if (root._prevRx >= 0 && now > root._prevT) {
                    const dt = (now - root._prevT) / 1000;
                    root.downKBs = Math.max(0, (parts[0] - root._prevRx) / 1024 / dt);
                    root.upKBs = Math.max(0, (parts[1] - root._prevTx) / 1024 / dt);
                }
                root._prevRx = parts[0];
                root._prevTx = parts[1];
                root._prevT = now;
            }
        }
    }
}
