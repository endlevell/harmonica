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
        // Qt color.toString() → "#rrggbb" when opaque; svg-safe
        return "data:image/svg+xml;utf8," + encodeURIComponent(
            t.replace(/currentColor/g, ic.color.toString()));
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
