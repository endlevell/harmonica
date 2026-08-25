# Harmonica — Design Spec

Dynamic-island shell for Hyprland/NixOS. ONE island component living in discrete PHASES.
Every phase transition morphs with eased motion — never linear, never teleports.

## Surfaces

| Surface | Window | Layer | Namespace | Keyboard |
|---|---|---|---|---|
| Island (bar + panel) | `PanelWindow` top-anchored, exclusiveZone | Top | `harmonica:island` | OnDemand |
| Launcher | `PanelWindow` top-center, below island | Overlay | `harmonica:launcher` | Exclusive |
| Record OSD / annotation overlay | `PanelWindow` fullscreen overlay | Overlay | `harmonica:overlay` | OnDemand / Exclusive during select |

Per-monitor via `Variants { model: Quickshell.screens }`; delegates declare
`required property ShellScreen modelData`. All windows `color: "transparent"`.

## Island states (state machine: `OrchestraState`)

```
IDLE ──hover/click──► PANEL ──esc/unhover──► IDLE
 │▲                    │  pages: settings · system(default) · music
 │└──music stops───────┤
MUSIC ◄──mpris playing (from any state; passive morph)
LAUNCHER (Super+S via IPC) — independent surface
RECORDING / ANNOTATING — overlay surfaces, independent
```

Precedence: RECORD indicator > MUSIC preview > IDLE row. Panel opens above all.

### IDLE
Single row: wifi icon (left) · clock center · battery (right). Height = Theme.barH.

### PANEL (3 pages, horizontal slide)
Arrow chevrons on island edges signal navigation; click or wheel scrolls pages.
Content slides horizontally (`x` animated, expressive curve); page list:
- **LEFT — Settings**: every Harmonica option (toggles, radios, sliders, dropdowns).
  Persisted via `Common/SettingsData.qml` → FileView+JsonAdapter at
  `$XDG_CONFIG_HOME/harmonica/config.json`, debounced save + self-write suppression +
  parse-error lockout.
- **CENTER (default) — System**: live RAM graph, CPU %, battery %, SSID/speed/IP,
  clock/date. Pollers in Services, gated on visibility.
- **RIGHT — Music**: Apple-widget style. Large album art, title/artist, progress bar,
  prev/play/next. Backed by Mpris service.

### MUSIC (passive morph)
When Mpris reports playing: idle row slides down out of view, compact strip slides in —
album thumb left · title+artist center · mini controls right. Reverts on stop.

### LAUNCHER (Super+S)
Expands from island region into search bar + fuzzy-filtered app list
(`ToplevelManager` not needed; apps from XDG data via `Process` + cache). Enter launches,
Esc closes. Keyboard focus Exclusive.

### SCREEN RECORD
Island shows record cluster: rec/pause/stop + settings gear. Gear expands sub-panel
(filename, extension, quality, audio device add/remove). While recording: red pulsing dot
left · elapsed time center · thin looping waveform beneath (Theme.danger colored).

### SCREENSHOT ANNOTATION
Hotkey → fullscreen dimmed region-select (crosshair, drag rect, live size label) →
annotation canvas over frozen frame: pen, highlighter, shapes (rect/ellipse/arrow),
text, undo/redo stacks, Theme-colored swatches, stroke width. Save to file / copy /
close. Esc backs out one level.

## Signature details (identity — non-negotiable)

1. **TWITCH** — every phase/state change starts with a tiny elastic wobble of the whole
   island (~120–180 ms, scale x/y counter-phase, OutBack-family bezier), then settles.
   Implemented once in `Modules/orchestra/Twitch.qml`; every transition routes through it.
2. **PULSE DOT** — single small dot riding the island. Each phase defines an anchor pos
   (idle=left near wifi, music=center, record=left red, panel=under active page index).
   On change it glides along a quadratic-bezier arc (control point lifted perpendicular
   to travel) leaving a short fading trail (last N positions painted at decaying opacity).
   Tokens in Theme: `pulseDotSize`, `pulseArcLift`, `pulseDur`, trail length.

## Motion tokens

All durations/curves live in Theme. Entrances decel (OutCubic family), exits accel,
spatial moves get slight overshoot (expressive splines), colors/fades flat. Twitch =
custom bezier ~OutBack(1.7). Never animate: input masks, layer changes, mount/unmount
(fade around atomic swap instead).

## Theming pipeline

pywal writes `~/.cache/wal/colors.json` → `Common/Theme.qml` FileView(watchChanges) parses
→ palette object updates reactively → ColorAnimation Behaviors smooth token changes.
Theme also owns type scale, 4px spacing grid, radii, durations, curves, pulse params.
Zero hardcoded hex outside Theme — including SVGs (currentColor).

## Icon system

Own set, generated per `assets/icons/style-spec.json` (clean preset: 24 grid, 1.5 stroke,
round caps/joins, rx≈2 corners, 2px padding). Consumed ONLY through
`Widgets/Icon.qml` (category/name → path, tinted by Theme color).

## Services (zero visuals)

`Mpris`, `Network`, `Battery`, `CpuRam` (pollers gated on consumers), `HyprlandIpc`,
`Recorder`, `Screenshot`, `Applications`. Data flows Services → Modules only;
Modules call service functions. No Service imports a Module.

## IPC surface (typed, per ricefield pitfall #6)

| Target | Functions |
|---|---|
| `orchestra` | `setPhase(phase: string): void`, `phase(): string` |
| `launcher` | `toggle(): void`, `open(): void`, `close(): void` |
| `screenshot` | `region(): void`, `annotate(path: string): void` |
| `record` | `start(): void`, `pause(): void`, `stop(): void` |

Hyprland binds (user config): `Super+S → harmonica ipc launcher toggle`,
print → `harmonica ipc screenshot region`. CLI wraps `qs ipc call`.

## Layout skeleton

```
shell.qml (<100 lines) — Variants{Island}, Launcher, overlays; nothing else
Modules/orchestra/     — Orchestra.qml (container/state), IdleBar, PanelPages,
                         SettingsPage, SystemPage, MusicPage, MusicStrip,
                         RecordCluster, PulseDot, Twitch
Widgets/               — LineGraph, Toggle, RadioGroup, Slider, Dropdown,
                         IconButton, ArrowNav, Icon, ProgressRing…
Common/                — Theme, SettingsData, Paths
Services/              — as listed above
```

## Verification

`bash scripts/screenshot-review.sh` after EVERY UI change; read the PNG; compare vs this
file; iterate. Headless → say so, never claim visual success.
