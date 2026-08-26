import QtQuick
import Quickshell.Io
import qs.Common
import qs.Services
import qs.Widgets

// ANNOTATE phase view — frozen shot + drawing canvas, lives INSIDE the island.
// Strokes stored in NATIVE image coords; display scales to fit; export
// replays at native resolution via grabToImage on the unscaled wrapper.
Item {
    id: av

    property string imagePath: ""
    signal closed()
    signal saved(string path)

    // ---- tool state ------------------------------------------------------
    property string tool: "pen"             // pen|highlighter|rect|ellipse|arrow|text
    property color ink: Theme.foreground
    property real strokeWidth: 3            // native px
    property var strokes: []                // committed (native coords)
    property var redoStack: []              // popped strokes
    property var draft: null
    property bool imgReady: false

    readonly property var tools: ["pen", "hl", "rect", "ellipse", "arrow", "text"]
    readonly property var swatches: [Theme.foreground, Theme.danger, Theme.primary, Theme.colorOk, Theme.warn]

    // native image dims (from Image.status/sourceSize once loaded)
    property int natW: 1
    property int natH: 1

    // displayed geometry of the image inside the card
    readonly property real dispScale: Math.min(imgArea.width / natW, imgArea.height / natH, 1)
    readonly property int dispW: Math.round(natW * dispScale)
    readonly property int dispH: Math.round(natH * dispScale)

    function grabFocus(): void { }

    function _esc(s: string): string {
        return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    // Export = original screenshot + strokes flattened to one PNG at NATIVE
    // resolution. Strokes are serialized to SVG and composited with magick.
    function buildSvg(): string {
        let body = "";
        for (const s of strokes) {
            const wAttr = 'fill="none" stroke="' + s.color + '" stroke-width="' + s.width +
                          '" stroke-linecap="round" stroke-linejoin="round"';
            if (s.tool === "pen" || s.tool === "hl") {
                const pts = s.points.map(p => p.x.toFixed(1) + "," + p.y.toFixed(1)).join(" ");
                body += '<polyline points="' + pts + '" ' + wAttr +
                        (s.tool === "hl" ? ' opacity="0.35" stroke-width="' + (s.width * 3.5) + '"' : "") + '/>';
            } else if (s.tool === "rect") {
                body += '<rect x="' + Math.min(s.p0.x, s.p1.x) + '" y="' + Math.min(s.p0.y, s.p1.y) +
                        '" width="' + Math.abs(s.p1.x - s.p0.x) + '" height="' + Math.abs(s.p1.y - s.p0.y) +
                        '" ' + wAttr + '/>';
            } else if (s.tool === "ellipse") {
                body += '<ellipse cx="' + ((s.p0.x + s.p1.x) / 2).toFixed(1) + '" cy="' + ((s.p0.y + s.p1.y) / 2).toFixed(1) +
                        '" rx="' + (Math.abs(s.p1.x - s.p0.x) / 2).toFixed(1) + '" ry="' + (Math.abs(s.p1.y - s.p0.y) / 2).toFixed(1) +
                        '" ' + wAttr + '/>';
            } else if (s.tool === "arrow") {
                const dx = s.p1.x - s.p0.x, dy = s.p1.y - s.p0.y;
                const len = Math.max(1, Math.hypot(dx, dy));
                const ux = dx / len, uy = dy / len;
                const hs = Math.max(6, s.width * 3);
                body += '<line x1="' + s.p0.x + '" y1="' + s.p0.y + '" x2="' + s.p1.x + '" y2="' + s.p1.y + '" ' + wAttr + '/>' +
                        '<polygon points="' + s.p1.x + ',' + s.p1.y + ' ' +
                        (s.p1.x - hs * ux + hs * 0.5 * uy).toFixed(1) + ',' + (s.p1.y - hs * uy - hs * 0.5 * ux).toFixed(1) + ' ' +
                        (s.p1.x - hs * ux - hs * 0.5 * uy).toFixed(1) + ',' + (s.p1.y - hs * uy + hs * 0.5 * ux).toFixed(1) +
                        '" fill="' + s.color + '"/>';
            } else if (s.tool === "text") {
                const fs = Math.round(8 + s.width * 4);
                const lines = String(s.text || "").split("\n");
                for (let i = 0; i < lines.length; i++)
                    body += '<text x="' + s.p0.x.toFixed(1) + '" y="' + (s.p0.y + fs + i * (fs + 2)).toFixed(1) +
                            '" font-family="sans-serif" font-size="' + fs + '" fill="' + s.color + '">' +
                            _esc(lines[i]) + "</text>";
            }
        }
        // NOTE: no viewBox — with zero drawn shapes an empty viewBoxed SVG
        // makes ImageMagick flatten into a degenerate opaque layer.
        return '<svg xmlns="http://www.w3.org/2000/svg" width="' + natW + '" height="' + natH + '">' +
               body + "</svg>";
    }

    FileView {
        id: svgWriter
        printErrors: false
    }

    Process {
        id: exportProc
        command: []
        stderr: SplitParser { onRead: data => console.warn("[annotate-export]", data) }
    }

    function doExport(afterCopy: bool): void {
        if (!imgReady || imagePath === "") return;
        const out = Screenshot.shotsDir + "/annot-" + Screenshot.stamp() + ".png";
        let cmd = "";
        if (strokes.length === 0) {
            cmd = "cp '" + imagePath + "' '" + out + "'";   // nothing drawn: keep original bytes
        } else {
            const svgFile = "/tmp/harmonica-annot-" + Screenshot.stamp() + ".svg";
            svgWriter.path = svgFile;
            svgWriter.setText(buildSvg());
            cmd = "magick '" + imagePath + "' '" + svgFile + "' -background none -flatten '" + out + "'";
        }
        if (afterCopy) cmd += " && wl-copy < '" + out + "'";
        Screenshot.lastShot = out;
        exportProc.exec(["sh", "-c", cmd]);
        closed();
    }
    function doSave(): void { doExport(false); }
    function doCopy(): void { doExport(true); }

    function pushStroke(s): void {
        const arr = strokes.slice();
        arr.push(s);
        strokes = arr;
        redoStack = [];
    }
    function undo(): void {
        if (strokes.length === 0) return;
        const arr = strokes.slice();
        const s = arr.pop();
        strokes = arr;
        redoStack = redoStack.concat([s]);
    }
    function redo(): void {
        if (redoStack.length === 0) return;
        const arr = redoStack.slice();
        const s = arr.pop();
        redoStack = arr;
        strokes = strokes.concat([s]);
    }

    // display→native
    function toNat(dx: real, dy: real): point {
        return Qt.point((dx - stage.x) / dispScale, (dy - stage.y) / dispScale);
    }

    // ---- layout ----------------------------------------------------------
    Column {
        anchors.fill: parent
        anchors.margins: Theme.spaceSm
        spacing: Theme.spaceSm

        // toolbar ----------------------------------------------------------
        Row {
            width: parent.width
            spacing: Theme.spaceXs

            Repeater {
                model: av.tools

                delegate: Rectangle {
                    required property string modelData
                    property bool on: av.tool === modelData
                    width: tLbl.implicitWidth + 12
                    height: 20
                    radius: Theme.radiusFull
                    color: on ? Theme.primary : Theme.surface
                    Text {
                        id: tLbl
                        anchors.centerIn: parent
                        text: {
                            const m = { pen: "pen", hl: "hl", rect: "rect",
                                        ellipse: "oval", arrow: "arrow", text: "text" };
                            return m[parent.modelData];
                        }
                        color: parent.on ? Theme.background : Theme.dimText
                        font.pixelSize: Theme.fontXs
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: av.tool = parent.modelData
                    }
                }
            }

            Item { width: 4; height: 1 }

            Repeater {
                model: av.swatches

                delegate: Rectangle {
                    required property color modelData
                    property bool on: av.ink === modelData
                    width: 16; height: 16; radius: Theme.radiusFull
                    color: modelData
                    border.width: on ? 2 : 0
                    border.color: Theme.foreground
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: av.ink = parent.modelData
                    }
                }
            }

            Item { width: 4; height: 1 }

            Repeater {
                model: [{ l: "S", w: 2 }, { l: "M", w: 4 }, { l: "L", w: 7 }]

                delegate: Rectangle {
                    required property var modelData
                    property bool on: av.strokeWidth === modelData.w
                    width: wLbl.implicitWidth + 10
                    height: 20
                    radius: Theme.radiusFull
                    color: on ? Theme.primary : Theme.surface
                    Text {
                        id: wLbl
                        anchors.centerIn: parent
                        text: parent.modelData.l
                        color: parent.on ? Theme.background : Theme.dimText
                        font.pixelSize: Theme.fontXs
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: av.strokeWidth = parent.modelData.w
                    }
                }
            }

            Item { width: Theme.spaceMd; height: 1 }

            Buttonish { label: "Undo"; enabled_: av.strokes.length > 0; onClicked: av.undo() }
            Buttonish { label: "Redo"; enabled_: av.redoStack.length > 0; onClicked: av.redo() }
            Item { width: Theme.spaceMd; height: 1 }
            Buttonish {
                label: "Save"
                accent: true
                enabled_: av.imgReady
                onClicked: stage.grabToImage(res => {
                    const p = String(res.url).replace("file://", "");
                    const f = Screenshot.saveAs(p);
                    av.saved(f);
                    av.closed();
                })
            }
            Buttonish {
                label: "Copy"
                enabled_: av.imgReady
                onClicked: stage.grabToImage(res => {
                    Screenshot.copyToClipboard(String(res.url).replace("file://", ""));
                    av.closed();
                })
            }
            Buttonish { label: "✕"; onClicked: av.closed() }
        }

        // canvas area --------------------------------------------------------
        Rectangle {
            id: imgArea
            width: parent.width
            height: parent.height - 26 - Theme.spaceSm * 2
            color: Theme.surface
            radius: Theme.radiusSm
            clip: true

            Item {
                id: stage
                x: (imgArea.width - width) / 2
                y: (imgArea.height - height) / 2
                width: Math.max(dispW, 1)
                height: Math.max(dispH, 1)

                Image {
                    id: img
                    x: 0; y: 0
                    width: av.dispW
                    height: av.dispH
                    source: av.imagePath !== "" ? "file://" + av.imagePath : ""
                    fillMode: Image.Stretch
                    asynchronous: false
                    onStatusChanged: {
                        if (status === Image.Ready && sourceSize.width > 0) {
                            av.natW = sourceSize.width;
                            av.natH = sourceSize.height;
                            av.imgReady = true;
                            paintCanvas.requestPaint();
                        }
                    }
                }

                Canvas {
                    id: paintCanvas
                    anchors.fill: parent
                    antialiasing: true

                    Connections {
                        target: av
                        function onImgReadyChanged() { paintCanvas.requestPaint(); }
                        function onStrokesChanged() { paintCanvas.requestPaint(); }
                        function onDraftChanged() { paintCanvas.requestPaint(); }
                    }

                    function drawStroke(ctx, s) {
                        ctx.strokeStyle = String(s.color);
                        ctx.fillStyle = String(s.color);
                        ctx.lineWidth = s.width;
                        ctx.lineCap = "round";
                        ctx.lineJoin = "round";
                        if (s.tool === "pen" || s.tool === "hl") {
                            if (s.tool === "hl") { ctx.globalAlpha = 0.35; ctx.lineWidth = s.width * 3.5; ctx.lineCap = "butt"; }
                            ctx.beginPath();
                            for (let i = 0; i < s.points.length; i++)
                                i === 0 ? ctx.moveTo(s.points[i].x, s.points[i].y)
                                        : ctx.lineTo(s.points[i].x, s.points[i].y);
                            ctx.stroke();
                            ctx.globalAlpha = 1;
                        } else if (s.tool === "rect") {
                            ctx.strokeRect(Math.min(s.p0.x, s.p1.x), Math.min(s.p0.y, s.p1.y),
                                           Math.abs(s.p1.x - s.p0.x), Math.abs(s.p1.y - s.p0.y));
                        } else if (s.tool === "ellipse") {
                            ctx.beginPath();
                            ctx.ellipse((s.p0.x + s.p1.x) / 2, (s.p0.y + s.p1.y) / 2,
                                        Math.abs(s.p1.x - s.p0.x) / 2, Math.abs(s.p1.y - s.p0.y) / 2,
                                        0, 0, Math.PI * 2);
                            ctx.stroke();
                        } else if (s.tool === "arrow") {
                            const dx = s.p1.x - s.p0.x, dy = s.p1.y - s.p0.y;
                            const len = Math.max(1, Math.hypot(dx, dy));
                            const ux = dx / len, uy = dy / len;
                            ctx.beginPath();
                            ctx.moveTo(s.p0.x, s.p0.y);
                            ctx.lineTo(s.p1.x, s.p1.y);
                            ctx.stroke();
                            const hs = Math.max(6, s.width * 3);
                            ctx.beginPath();
                            ctx.moveTo(s.p1.x, s.p1.y);
                            ctx.lineTo(s.p1.x - hs * ux + hs * 0.5 * uy, s.p1.y - hs * uy - hs * 0.5 * ux);
                            ctx.lineTo(s.p1.x - hs * ux - hs * 0.5 * uy, s.p1.y - hs * uy + hs * 0.5 * ux);
                            ctx.closePath();
                            ctx.fill();
                        } else if (s.tool === "text") {
                            ctx.font = Math.round(8 + s.width * 4) + "px sans-serif";
                            ctx.textBaseline = "top";
                            let ty = s.p0.y;
                            const lh = 9 + s.width * 4;
                            for (const ln of String(s.text).split("\n")) {
                                ctx.fillText(ln, s.p0.x, ty);
                                ty += lh;
                            }
                        }
                    }

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        if (!av.imgReady) return;
                        for (const s of av.strokes) drawStroke(ctx, s);
                        if (av.draft) drawStroke(ctx, av.draft);
                    }
                }

                // text input overlay -------------------------------------------
                TextInput {
                    id: textEntry
                    visible: false
                    color: av.ink
                    font.pixelSize: 12
                    Keys.onReturnPressed: commitText()
                    Keys.onEscapePressed: cancelText()

                    function commitText() {
                        if (text.trim() !== "" && av.draft)
                            av.pushStroke({ tool: "text", color: String(av.ink), width: av.strokeWidth / av.dispScale,
                                            p0: Qt.point(av.draft.p0.x, av.draft.p0.y), text: text });
                        hide_();
                    }
                    function cancelText() { hide_(); }
                    function hide_() { visible = false; text = ""; av.draft = null; }
                }
            }

            // pointer handling in display space -------------------------------
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: av.tool === "text" ? Qt.IBeamCursor : Qt.CrossCursor
                enabled: av.imgReady

                onPressed: m => {
                    const n = av.toNat(m.x, m.y);
                    if (av.tool === "text") {
                        av.draft = { tool: "text", p0: n };
                        textEntry.x = m.x + 2; textEntry.y = m.y;
                        textEntry.visible = true; textEntry.text = "";
                        textEntry.forceActiveFocus();
                        return;
                    }
                    if (av.tool === "pen" || av.tool === "hl")
                        av.draft = { tool: av.tool, color: String(av.ink), width: av.strokeWidth / av.dispScale, points: [n] };
                    else
                        av.draft = { tool: av.tool, color: String(av.ink), width: av.strokeWidth / av.dispScale, p0: n, p1: n };
                }
                onPositionChanged: mouse => {
                    if (!av.draft || av.tool === "text") return;
                    const n = av.toNat(mouse.x, mouse.y);
                    if (av.tool === "pen" || av.tool === "hl")
                        av.draft = { tool: av.draft.tool, color: av.draft.color, width: av.draft.width,
                                     points: av.draft.points.concat([n]) };
                    else
                        av.draft = { tool: av.draft.tool, color: av.draft.color, width: av.draft.width,
                                     p0: av.draft.p0, p1: n };
                }
                onReleased: {
                    if (!av.draft || av.tool === "text") return;
                    av.pushStroke(av.draft);
                    av.draft = null;
                }
            }
        }

        // bottom actions row ---------------------------------------------------
        Row {
            spacing: Theme.spaceXs
            anchors.horizontalCenter: parent.horizontalCenter

            Buttonish { label: "Undo"; enabled_: av.strokes.length > 0; onClicked: av.undo() }
            Buttonish { label: "Redo"; enabled_: av.redoStack.length > 0; onClicked: av.redo() }
            Item { width: Theme.spaceMd; height: 1 }
            Buttonish { label: "Save"; accent: true; enabled_: av.imgReady; onClicked: av.doSave() }
            Buttonish { label: "Copy"; enabled_: av.imgReady; onClicked: av.doCopy() }
            Buttonish { label: "✕"; onClicked: av.closed() }
        }
    }
}
