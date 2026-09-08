pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth

// Bluetooth status + device management via Quickshell BlueZ bindings
// (no bluetoothctl needed). Same consumer gating as the other pollers:
// discovery runs only while a manager view holds us.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool present: adapter !== null
    readonly property bool powered: adapter ? adapter.enabled : false
    readonly property bool discovering: adapter ? adapter.discovering : false
    readonly property var devices: adapter ? adapter.devices : null
    readonly property int deviceCount: devices ? devices.count : 0
    // friendly name: first connected device, else adapter name
    readonly property string deviceName: {
        if (!adapter) return "";
        const ds = adapter.devices;
        if (ds) {
            for (let i = 0; i < ds.count; i++) {
                const d = ds.get(i);
                if (d && d.connected) return d.name || d.deviceName || d.address;
            }
        }
        return adapter.name || "";
    }

    property int consumers: 0
    function acquire(): void {
        consumers++;
        if (consumers === 1 && adapter) adapter.discovering = true;
    }
    function release(): void {
        consumers = Math.max(0, consumers - 1);
        if (consumers === 0 && adapter) adapter.discovering = false;
    }

    function togglePower(): void {
        if (adapter) adapter.enabled = !adapter.enabled;
    }
    function setDiscovering(on: bool): void {
        if (adapter) adapter.discovering = on;
    }

    function _find(address: string): var {
        if (!adapter || !adapter.devices || address === "") return null;
        const ds = adapter.devices;
        for (let i = 0; i < ds.count; i++) {
            const d = ds.get(i);
            if (d && d.address === address) return d;
        }
        return null;
    }

    function pair(address: string): void { const d = _find(address); if (d) d.pair(); }
    function connect(address: string): void { const d = _find(address); if (d) d.connect(); }
    function disconnect(address: string): void { const d = _find(address); if (d) d.disconnect(); }
    function forget(address: string): void { const d = _find(address); if (d) d.forget(); }
    function cancelPair(address: string): void { const d = _find(address); if (d) d.cancelPair(); }

    // BlueZ device icon taxonomy → vendored symbol file
    function glyphFor(icon: string): string {
        const s = String(icon || "");
        if (s.indexOf("audio-") === 0) return "headphones";
        if (s.indexOf("input-mouse") === 0) return "mouse";
        if (s.indexOf("input-keyboard") === 0 || s.indexOf("input-key") === 0) return "keyboard";
        if (s.indexOf("phone") === 0) return "phone";
        return "bluetooth";
    }
    function glyphCat(icon: string): string {
        return glyphFor(icon) === "bluetooth" ? "status" : "system";
    }
}
