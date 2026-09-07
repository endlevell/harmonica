pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Application index from XDG .desktop entries (NixOS profile paths honored).
// Scans on boot; re-scans lazily (≥30s) when asked. Text-only metadata — no icons.
Singleton {
    id: root

    // [{ name, exec, icon, genericName, keywords, fileName, _n, _g, _k, _e, _f }]
    // (_x are norm() caches: name, genericName, keywords, exec-basename, file-stem)
    property var apps: []
    readonly property int count: apps.length
    property bool scanning: false
    property real lastScan: 0

    signal rescanned()

    function rescan(force) {
        if (scanning) return;
        if (!force && Date.now() - lastScan < 30000 && count > 0) return;
        scanning = true;
        scan.exec(["sh", "-c", scanScript()]);
    }

    function scanScript(): string {
        // NOTE: written as plain lines — no ${} anywhere so this stays a dumb string
        const lines = [
            'LOCAL="${XDG_DATA_HOME:-$HOME/.local/share}"',
            'DIRS="$LOCAL /run/current-system/sw/share /etc/profiles/per-user/$USER/share $HOME/.nix-profile/share ${XDG_DATA_DIRS:-}"',
            'ICONROOTS="/run/current-system/sw/share/icons /etc/profiles/per-user/$USER/share/icons $HOME/.nix-profile/share/icons ${XDG_DATA_HOME:-$HOME/.local/share}/icons"',
            'resolve() {',
            '  i="$1"; [ -z "$i" ] && { printf ""; return; }',
            '  case "$i" in /*) printf "%s" "$i"; return ;; esac',
            '  case "$i" in *.svg|*.SVG|*.png|*.PNG) i="${i%.*}" ;; esac',
            '  for r in $ICONROOTS; do',
            '    for s in scalable 512x512 256x256 128x128 96x96 64x64 48x48 32x32 24x24; do',
            '      for e in svg png; do',
            '        f="$r/hicolor/$s/apps/$i.$e"',
            '        [ -f "$f" ] && { printf "%s" "$f"; return; }',
            '      done',
            '    done',
            '  done',
            '  printf ""',
            '}',
            'seen=""',
            'for d in $DIRS; do',
            '  [ -d "$d/applications" ] || continue',
            '  for f in "$d/applications/"*.desktop; do',
            '    [ -f "$f" ] || continue',
            '    b=$(basename "$f")',
            '    case "$seen" in *"|$b|"*) continue ;; esac',
            '    seen="$seen|$b|"',
            '    awk \'',
            '      /^\\[Desktop Entry\\]/ {e=1; next}',
            '      /^\\[/               {e=0}',
            '      e && /^Type=/      {t=substr($0,6)}',
            '      e && /^Name=/      {n=substr($0,6)}',
            '      e && /^Exec=/      {x=substr($0,6)}',
            '      e && /^Icon=/      {i=substr($0,6)}',
            '      e && /^GenericName=/ {g=substr($0,13)}',
            '      e && /^Keywords=/    {k=substr($0,10)}',
            '      e && /^NoDisplay=/ {nd=substr($0,11)}',
            '      e && /^Hidden=/    {hd=substr($0,8)}',
            '      END { if (t=="Application" && n!="" && x!="" && nd!="true" && hd!="true")',
            '              printf "%s\\037%s\\037%s\\037%s\\037%s\\n", n, x, i, g, k }',
            '    \' "$f" | while IFS="$(printf \'\\037\')" read -r n x i g k; do',
            '      printf "%s\\037%s\\037%s\\037%s\\037%s\\037%s\\n" "$n" "$x" "$(resolve "$i")" "$g" "$k" "$b"',
            '    done',
            '  done',
            'done'
        ];
        return lines.join("\n");
    }

    Process {
        id: scan
        command: []
        stdout: StdioCollector {
            onStreamFinished: {
                const list = [];
                for (const line of this.text.split("\n")) {
                    if (!line) continue;
                    const p = line.split("\x1f");       // 0x1f === awk \037
                    if (p.length < 2 || !p[0] || !p[1]) continue;
                    const name = p[0], exec = p[1], icon = p[2] || "";
                    const genericName = p.length > 3 ? p[3] : "";
                    const keywords = p.length > 4 ? p[4] : "";
                    const fileName = p.length > 5 ? p[5] : "";
                    list.push({
                        name: name, exec: exec, icon: icon,
                        genericName: genericName, keywords: keywords, fileName: fileName,
                        _n: root.norm(name),
                        _g: root.norm(genericName),
                        _k: root.norm(keywords.replace(/;/g, " ")),
                        _e: root.norm(root.execBase(exec)),
                        _f: root.norm(root.fileStem(fileName))
                    });
                }
                const byKey = {};
                for (const a of list) { if (!(a._n in byKey)) byKey[a._n] = a; }
                root.apps = Object.values(byKey)
                    .sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
                root.scanning = false;
                root.lastScan = Date.now();
                root.rescanned();
            }
        }
    }

    Component.onCompleted: rescan(true)

    signal launchResult(string name, bool ok)
    property string _probeName: ""

    function launch(app) {
        if (!app || !app.exec) return;
        const exe = app.exec.replace(/ ?%[a-zA-Z]/g, "").trim();
        if (exe === "") return;
        Quickshell.execDetached(["sh", "-c", exe]);
    }

    // Launch + spawn-validity probe. execDetached gives no failure feedback,
    // so a fast `command -v` probe on the exec's binary tells the launcher
    // whether the spawn can succeed (drives the progress bar's fail path).
    function launchProbed(app) {
        if (!app || !app.exec) { root.launchResult(app ? app.name : "", false); return; }
        const exe = app.exec.replace(/ ?%[a-zA-Z]/g, "").trim();
        if (exe === "") { root.launchResult(app.name, false); return; }
        const bin = exe.split(/\s+/)[0].replace(/^["']|["']$/g, "").replace(/'/g, "");
        _probeName = app.name;
        probe.exec(["sh", "-c", "command -v '" + bin + "' >/dev/null 2>&1 && echo ok || echo no"]);
        Quickshell.execDetached(["sh", "-c", exe]);
    }

    Process {
        id: probe
        command: []
        stdout: StdioCollector {
            onStreamFinished: root.launchResult(root._probeName, this.text.trim() === "ok")
        }
    }

    // ---- tokenized multi-field search -------------------------------------
    // Spec: lowercase word tokens; EVERY word must substring-match somewhere
    // across Name 10 > GenericName 5 = Keywords 5 > Exec-basename 3 > file-stem 1.
    // Per word only the best-field weight counts. Full-query exact match on
    // Name/GenericName scores +50%. Empty query returns the first alphabetical page.
    // aliasMap (configurable): query word -> extra substrings satisfying it,
    // for upstreams shipping no Keywords (e.g. "discord" also hits "vesktop").
    property var aliasMap: ({
        "discord": ["vesktop"],
        "code": ["vscodium", "codium", "vscode", "zcode"],
        "vscode": ["vscodium", "codium"],
        "term": ["terminal", "kitty", "foot", "alacritty"],
        "terminal": ["kitty", "foot", "alacritty"],
        "chrome": ["chromium", "helium"],
        "browser": ["helium", "qutebrowser", "firefox", "chromium", "brave"]
    })
    readonly property int maxResults: 12
    readonly property var fieldWeights: [10, 5, 5, 3, 1]   // _n _g _k _e _f

    // lowercase + diacritic-fold (accented -> base letter); guards missing String.normalize
    function norm(s: string): string {
        const v = String(s || "").toLowerCase();
        const n = v.normalize ? v.normalize("NFD") : v;
        return n.replace(/[\u0300-\u036f]/g, "");
    }

    function execBase(exec: string): string {
        const clean = String(exec || "").replace(/ ?%[a-zA-Z]/g, "").trim();
        if (clean === "") return "";
        const first = clean.split(/\s+/)[0].replace(/^["']|["']$/g, "");
        const slash = first.lastIndexOf("/");
        return slash >= 0 ? first.substring(slash + 1) : first;
    }

    function fileStem(base: string): string {
        const b = String(base || "");
        return b.toLowerCase().endsWith(".desktop") ? b.substring(0, b.length - 8) : b;
    }

    function tokens(query: string): var {
        return norm(query).split(/[^a-z0-9]+/).filter(w => w.length > 0);
    }

    // best field weight for one word (0 = no hit anywhere, incl. aliases)
    function wordHit(app, w: string): int {
        const cands = [w].concat(aliasMap[w] || []);
        const fields = [app._n, app._g, app._k, app._e, app._f];
        let best = 0;
        for (let f = 0; f < fields.length; f++) {
            const t = fields[f];
            if (!t) continue;
            for (const c of cands) {
                if (t.indexOf(c) >= 0) { best = Math.max(best, fieldWeights[f]); break; }
            }
        }
        return best;
    }

    // synchronous over the in-memory index: rescores every keystroke, no debounce
    function search(query: string): var {
        const toks = tokens(query);
        if (toks.length === 0) return apps.slice(0, maxResults);
        const full = toks.join(" ");
        const scored = [];
        for (const a of apps) {
            let sc = 0, ok = true;
            for (const w of toks) {
                const hit = wordHit(a, w);
                if (hit === 0) { ok = false; break; }
                sc += hit;
            }
            if (!ok) continue;
            if (full === a._n || (a._g !== "" && full === a._g)) sc *= 1.5;
            scored.push({ app: a, sc: sc });
        }
        scored.sort((x, y) => y.sc !== x.sc ? y.sc - x.sc
            : x.app.name.toLowerCase().localeCompare(y.app.name.toLowerCase()));
        return scored.slice(0, maxResults).map(x => x.app);
    }

    // merged [start,end) spans of query tokens inside raw text (lowercase search;
    // a diacritic-folded match may score yet not highlight — matching still holds)
    function matchSpans(text: string, query: string): var {
        const src = String(text || "").toLowerCase();
        const spans = [];
        for (const w of tokens(query)) {
            let from = 0;
            while (from < src.length) {
                const i = src.indexOf(w, from);
                if (i < 0) break;
                spans.push([i, i + w.length]);
                from = i + w.length;
            }
        }
        spans.sort((a, b) => a[0] - b[0]);
        const merged = [];
        for (const s of spans) {
            if (merged.length > 0 && s[0] <= merged[merged.length - 1][1])
                merged[merged.length - 1][1] = Math.max(merged[merged.length - 1][1], s[1]);
            else merged.push([s[0], s[1]]);
        }
        return merged;
    }

    // first non-Name field that contributed, for the row detail line (null = name-only)
    function matchSource(app, query: string): var {
        const toks = tokens(query);
        if (toks.length === 0) return null;
        const foreign = toks.filter(w => (app._n || "").indexOf(w) < 0);
        const pool = foreign.length > 0 ? foreign : toks.slice(0, 1);
        for (const w of pool) {
            const cands = [w].concat(aliasMap[w] || []);
            const has = t => cands.some(x => String(t || "").indexOf(x) >= 0);
            if (has(app._g)) return { kind: "generic", text: app.genericName };
            if (has(app._k)) return { kind: "keywords", text: String(app.keywords).replace(/;/g, " ").trim() };
            if (has(app._e)) return { kind: "exec", text: execBase(app.exec) };
            if (has(app._f)) return { kind: "file", text: fileStem(app.fileName) };
        }
        return null;
    }
}
