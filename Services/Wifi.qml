pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wi-Fi management via nmcli. Scan list with signal/security, radio switch,
// connect (open + WPA-PSK inline), disconnect, forget. Demand-gated like
// CpuRam: the scan loop runs only while a manager view consumes it.
//
// Probe output is line-labeled (@@tag) so empty blocks can never shift
// fields out of alignment.
Singleton {
    id: root

    property bool radio: true
    property bool scanning: false
    property real lastScanMs: 0
    property string iface: ""
    property string connectedSsid: ""
    property string ip: ""
    // [{ssid, signal, security, freq, inUse}]
    property var networks: []
    // in-flight WPA handshake + inline error surface
    property string connecting: ""
    property string errorSsid: ""
    property string errorText: ""
    property string _connOut: ""
    property string _connErr: ""

    property int consumers: 0
    function acquire(): void { consumers++; if (consumers === 1) { refresh(); rescan(); } }
    function release(): void { consumers = Math.max(0, consumers - 1); }

    function _q(s: string): string {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    // periodic refresh while consumed (slow cadence; rescan is explicit)
    Timer {
        interval: 15000
        running: root.consumers > 0
        repeat: true
        onTriggered: root.refresh()
    }

    function refresh(): void {
        listProc.exec(["sh", "-c",
            "IF=$(nmcli -t -f DEVICE,TYPE device status 2>/dev/null | awk -F: '$2==\"wifi\" {print $1; exit}'); " +
            "echo \"@@iface $IF\"; " +
            "nmcli -t -f SSID,SIGNAL,SECURITY,FREQ,IN-USE dev wifi list 2>/dev/null | sed 's/^/@@net /'; " +
            "echo \"@@ip $(nmcli -t -f IP4.ADDRESS device show \"$IF\" 2>/dev/null | head -1 | cut -d: -f2- | cut -d/ -f1)\"; " +
            "echo \"@@radio $(nmcli radio wifi 2>/dev/null)\""]);
    }

    function rescan(): void {
        if (scanning) return;
        scanning = true;
        errorSsid = "";
        errorText = "";
        scanProc.exec(["sh", "-c", "nmcli dev wifi rescan >/dev/null 2>&1; sleep 2"]);
    }

    function setRadio(on: bool): void {
        radioProc.exec(["sh", "-c", "nmcli radio wifi " + (on ? "on" : "off") + " >/dev/null 2>&1; sleep 1"]);
    }

    function connect(ssid: string, password: string): void {
        if (ssid === "" || connecting !== "") return;
        connecting = ssid;
        errorSsid = "";
        errorText = "";
        _connOut = "";
        _connErr = "";
        const pw = password !== "" ? " password " + _q(password) : "";
        connProc.exec(["sh", "-c", "nmcli dev wifi connect " + _q(ssid) + pw + " 2>&1"]);
    }

    function disconnect(): void {
        if (iface === "") return;
        errorSsid = "";
        errorText = "";
        discProc.exec(["sh", "-c", "nmcli dev disconnect " + _q(iface) + " >/dev/null 2>&1; sleep 1"]);
    }

    function forget(ssid: string): void {
        if (ssid === "") return;
        errorSsid = "";
        errorText = "";
        forgetProc.exec(["sh", "-c", "nmcli connection delete id " + _q(ssid) + " >/dev/null 2>&1; sleep 1"]);
    }

    // nmcli -t escapes literal colons as \: — shield them (PUA) before splitting
    function _splitRow(line: string): var {
        return line.replace(/\\:/g, "").split(":").map(p => p.replace(//g, ":"));
    }

    Process {
        id: listProc
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const nets = [];
                for (const line of this.text.split("\n")) {
                    if (line.indexOf("@@iface ") === 0) {
                        root.iface = line.substring(8).trim();
                    } else if (line.indexOf("@@ip ") === 0) {
                        root.ip = line.substring(5).trim();
                    } else if (line.indexOf("@@radio ") === 0) {
                        const r = line.substring(8).trim();
                        if (r !== "") root.radio = r === "enabled";
                    } else if (line.indexOf("@@net ") === 0) {
                        const p = root._splitRow(line.substring(6));
                        if (p.length < 5 || p[0] === "") continue;
                        nets.push({
                            ssid: p[0],
                            signal: parseInt(p[1], 10) || 0,
                            security: p[2] === "--" ? "Open" : p[2],
                            freq: p[3].indexOf("5") === 0 ? "5GHz"
                                : p[3].indexOf("6") === 0 ? "6GHz" : "2.4GHz",
                            inUse: p[4].indexOf("*") >= 0
                        });
                    }
                }
                // strongest first, active connection pinned to top
                nets.sort((a, b) => ((b.inUse ? 1 : 0) - (a.inUse ? 1 : 0)) || (b.signal - a.signal));
                root.networks = nets;
                const active = nets.find(n => n.inUse);
                root.connectedSsid = active ? active.ssid : "";
            }
        }
    }

    Process {
        id: scanProc
        command: []
        onExited: code => { root.scanning = false; root.lastScanMs = Date.now(); root.refresh(); }
    }

    Process {
        id: radioProc
        command: []
        onExited: code => root.refresh()
    }

    Process {
        id: connProc
        command: []
        stdout: StdioCollector { onStreamFinished: root._connOut = this.text }
        stderr: SplitParser { onRead: data => { root._connErr += data; } }
        onExited: code => root._connDone(code, root._connOut)
    }

    Process {
        id: discProc
        command: []
        onExited: code => root.refresh()
    }

    Process {
        id: forgetProc
        command: []
        onExited: code => root.refresh()
    }

    function _connDone(code: int, out: string): void {
        const ssid = root.connecting;
        root.connecting = "";
        const errText = root._connErr;
        root._connOut = "";
        root._connErr = "";
        if (code === 0) {
            root.refresh();
            return;
        }
        const msg = (errText + "\n" + out).split("\n").map(l => l.replace(/^Error:\s*/i, "").trim()).filter(l => l !== "")[0] || "connection failed";
        root.errorSsid = ssid;
        root.errorText = msg.length > 80 ? msg.slice(0, 80) : msg;
        root.refresh();
    }
}
