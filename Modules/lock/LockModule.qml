import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import qs.Services

// Session lock (WlSessionLock): one surface per output, driven by the
// Lock controller. IPC only LOCKS (open/toggle) — nothing unlocks except
// a successful password check inside, so no IPC path can bypass it.
Scope {
    id: root

    WlSessionLock {
        id: sessionLock
        locked: Lock.engaged
        surface: Component {
            WlSessionLockSurface {
                LockView {}
            }
        }
    }

    IpcHandler {
        target: "lock"

        function open(): void { Lock.open(); }
        function toggle(): void { if (!Lock.engaged) Lock.open(); }
        function isLocked(): bool { return Lock.engaged; }
        function state(): string { return Lock.engaged ? Lock.state : "unlocked"; }
    }
}
