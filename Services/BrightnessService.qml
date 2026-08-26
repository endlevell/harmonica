pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backlight brightness control via sysfs / brightnessctl
Singleton {
    id: root

    property real percent: 0.5           // 0.0 .. 1.0
    property string backlightDevice: "intel_backlight"

    function setPercent(p: real): void {
        const clamped = Math.max(0.05, Math.min(1.0, p));
        root.percent = clamped;
        const pctInt = Math.round(clamped * 100);
        bSetter.exec(["sh", "-c",
            "if command -v brightnessctl >/dev/null 2>&1; then " +
            "  brightnessctl s " + pctInt + "% >/dev/null 2>&1; " +
            "elif [ -d /sys/class/backlight/" + backlightDevice + " ]; then " +
            "  MAX=$(cat /sys/class/backlight/" + backlightDevice + "/max_brightness 2>/dev/null); " +
            "  VAL=$(( MAX * " + pctInt + " / 100 )); " +
            "  echo $VAL | sudo tee /sys/class/backlight/" + backlightDevice + "/brightness >/dev/null 2>&1 || true; " +
            "fi"
        ]);
    }

    function poll(): void {
        bGetter.exec(["sh", "-c",
            "if [ -d /sys/class/backlight/" + backlightDevice + " ]; then " +
            "  CUR=$(cat /sys/class/backlight/" + backlightDevice + "/actual_brightness 2>/dev/null || cat /sys/class/backlight/" + backlightDevice + "/brightness 2>/dev/null); " +
            "  MAX=$(cat /sys/class/backlight/" + backlightDevice + "/max_brightness 2>/dev/null); " +
            "  if [ -n \"$CUR\" ] && [ -n \"$MAX\" ] && [ \"$MAX\" -gt 0 ]; then " +
            "    awk -v c=\"$CUR\" -v m=\"$MAX\" 'BEGIN { printf \"%.3f\", c/m }'; " +
            "  fi; " +
            "fi"
        ]);
    }

    Process { id: bSetter; command: [] }

    Process {
        id: bGetter
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const s = this.text.trim();
                const v = parseFloat(s);
                if (!isNaN(v) && v >= 0.0 && v <= 1.0) {
                    root.percent = v;
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
