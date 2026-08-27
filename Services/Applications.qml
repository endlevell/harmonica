pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Application index from XDG .desktop entries (NixOS profile paths honored).
// Scans on boot; re-scans lazily (≥30s) when asked. Text-only metadata — no icons.
Singleton {
    id: root

    // [{ name, exec }]
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
            '      e && /^NoDisplay=/ {nd=substr($0,11)}',
            '      e && /^Hidden=/    {hd=substr($0,8)}',
            '      END { if (t=="Application" && n!="" && x!="" && nd!="true" && hd!="true")',
            '              printf "%s\\037%s\\037%s\\n", n, x, i }',
            '    \' "$f" | while IFS="$(printf \'\\037\')" read -r n x i; do',
            '      printf "%s\\037%s\\037%s\\n" "$n" "$x" "$(resolve "$i")"',
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
                    list.push({ name: p[0], exec: p[1], icon: p[2] || "" });
                }
                const byKey = {};
                for (const a of list) byKey[a.name.toLowerCase()] = a;
                root.apps = Object.values(byKey)
                    .sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
                root.scanning = false;
                root.lastScan = Date.now();
                            }
        }
    }

    Component.onCompleted: rescan(true)

    function launch(app) {
        if (!app || !app.exec) return;
        const exe = app.exec.replace(/ ?%[a-zA-Z]/g, "").trim();
        if (exe === "") return;
        Quickshell.execDetached(["sh", "-c", exe]);
    }

    // subsequence fuzzy match; score or -1 (consecutive + word-start bonuses)
    function fuzzy(query: string, target: string): int {
        const q = query.toLowerCase();
        const s = target.toLowerCase();
        let qi = 0, score = 0, streak = 0, lastHit = -2;
        for (let i = 0; i < s.length && qi < q.length; i++) {
            if (s[i] === q[qi]) {
                streak = (i === lastHit + 1) ? streak + 1 : 1;
                score += 2 + streak * 2 + (i === 0 || s[i-1] === " " ? 6 : 0);
                lastHit = i;
                qi++;
            }
        }
        return qi === q.length ? score : -1;
    }

    function search(query: string): var {
        if (!query || query.length === 0) return apps.slice(0, 12);
        const scored = [];
        for (const a of apps) {
            const sc = fuzzy(query, a.name);
            if (sc >= 0) scored.push({ app: a, sc: sc });
        }
        scored.sort((x, y) => y.sc - x.sc);
        return scored.slice(0, 12).map(x => x.app);
    }
}
