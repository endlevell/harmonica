import QtQuick
import Quickshell.Io
import qs.Common

// Tinted SVG icon. Loads the vendored Material file, swaps its
// fill="currentColor" for a concrete Theme color, serves it as a data URL.
Item {
    id: ic

    property string category: "status"
    property string name: ""
    property color color: Theme.foreground
    property int size: 24

    implicitWidth: size
    implicitHeight: size

    readonly property string dataUrl: {
        const t = src.text();
        if (!t || t.length === 0) return "";
        return "data:image/svg+xml;utf8," + encodeURIComponent(
            t.replace(/currentColor/g, ic.svgColor()));
    }

    // #rrggbb when opaque; rgba() when translucent — Qt.toString emits
    // #AARRGGBB for alpha < 1, which SVG fill parsers reject, silently
    // dropping the icon. Non-hex toString output falls back to rgb().
    function svgColor(): string {
        const c = ic.color;
        const r = Math.round(c.r * 255), g = Math.round(c.g * 255), b = Math.round(c.b * 255);
        if (c.a >= 1) {
            const s = c.toString();
            if (/^#[0-9a-fA-F]{6}$/.test(s)) return s;
            return "rgb(" + r + "," + g + "," + b + ")";
        }
        return "rgba(" + r + "," + g + "," + b + "," + Number(c.a.toFixed(3)) + ")";
    }

    FileView {
        id: src
        // never feed the watcher an empty path (warns + no-ops)
        path: ic.name !== "" ? Paths.iconPath(ic.category, ic.name)
                             : Paths.shellDir + "/shell.qml"
        watchChanges: false
        blockLoading: false
        printErrors: false
    }

    Image {
        anchors.centerIn: parent
        width: ic.size
        height: ic.size
        sourceSize.width: ic.size * 2   // render at 2x, downscale = crisp on hidpi
        sourceSize.height: ic.size * 2
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        source: ic.dataUrl
        visible: ic.dataUrl !== ""
    }
}
