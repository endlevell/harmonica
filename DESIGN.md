# Harmonica — Design Spec

Quickshell (QML) desktop shell for Hyprland on NixOS, plus a companion Rust CLI.

This document is the canonical spec for **surfaces, states, and layout** — the *what*. It consolidates the original build spec with every correction made since (research fixes, an architecture correction, two visual reworks, a paging bugfix), so it reflects the current, corrected design rather than any single draft. Where an earlier attempt conflicts with something here, this document wins. Update it whenever a future correction changes the spec — that's the whole point of keeping it.

**Contents**
1. Product Overview
2. Architecture Rule — One Surface, One Window
3. Orchestra Phases (State Machine)
4. Signature Motion
5. Theming — Theme.qml + pywal
6. Icon System
7. Project Structure
8. Harmonica CLI (Rust)
9. Build Workflow
10. Engineering Conventions
11. Verification & Hard-Won Rules

---

## 1. Product Overview

**Harmonica** is a dynamic-island-style desktop shell. Distribution is a NixOS flake; home-manager installs the CLI and the quickshell config together. **NixOS + home-manager only — never pacman/AUR commands, anywhere in this project.**

Its whole identity is **one shape, morphing between phases** — "the Orchestra." That sentence is the design constraint everything else here serves.

This is a real product, not a prototype. Read this document fully before writing code. If a requirement is genuinely ambiguous, ask once, then proceed with a stated default — don't stall.

## 2. Architecture Rule — One Surface, One Window

There is exactly **one** `PanelWindow` in this shell: the Orchestra's.

Every feature — launcher, settings, music player, screen-record UI, screenshot tool, anything built in the future — renders **inside the island container** as a phase or page of that one window. No feature may ever create its own `PanelWindow` or overlay window.

**The only exception**: a full-screen overlay like the screenshot region-select canvas (§3.6) — and that requires explicit approval before building, never assumed.

Why this is non-negotiable:
- Harmonica's identity is one shape morphing. Anything popping up elsewhere breaks that illusion completely.
- The phase state machine loses meaning if some views live outside it.
- ActivSpot (studied for animation technique, §4.3) fakes its morph with multiple `PanelWindow`s and file-based state hacks. We deliberately don't copy that — a single-window architecture is cleaner and is the choice made here.

If you ever think *"this needs its own window"* — stop, redesign it as a phase, and only ask if it's truly impossible.

## 3. Orchestra Phases (State Machine)

The Orchestra is a single `PanelWindow` (`WlrLayershell`, top layer, exclusive zone) pinned top-center. It sits in one of six discrete phases at a time; every transition between them expands or morphs smoothly, eased on both ends — never linear, never teleporting.

| # | Phase | Trigger | Content |
|---|-------|---------|---------|
| 1 | Idle | Resting default | Wifi icon · clock · battery, three zones |
| 2 | Hover / Click | Hover or click the pill | Three-page panel: settings · system info · music |
| 3 | Music Playing | Playback starts | Idle content slides down; compact preview strip takes over |
| 4 | Launcher | Super+S | Search bar + fuzzy-filtered app list, inside the Orchestra |
| 5 | Screen Record | Record hotkey/button | Record controls + live recording indicator |
| 6 | Screenshot Annotation | Screenshot hotkey | Region select → annotation canvas → save/copy/close |

### 3.1 Phase 1 — Idle

Three fixed zones, independently anchored, never overlapping:

| Zone | Content | Rule |
|------|---------|------|
| Left | Wifi icon (+ optional network name) | Icon from `assets/icons/status/` via `Icon.qml`, tinted `Theme.colorAccentNet` |
| Center | Clock only | `Theme.fontLg` semibold; centered in the island itself — not accidentally centered because other text pushed it |
| Right | Battery icon + percentage | Percentage never touches the icon or crosses into the center zone; icon color is state-driven (§5.2) |

- Zones separated by explicit gaps ≥ `Theme.spaceMd`. Nothing may touch — verify visually before calling a change done.
- Surface: **flat, solid — no border, no drop shadow, no transparency or blur.** Depth comes from contrast against the wallpaper (fixed neutral-dark surface) and from the pywal accent colors used *inside* the pill, never from chrome. A near-imperceptible vertical gradient (surface → ~4% darker) is allowed; cut it if it reads as decoration.
- Hover: the island expands (§4.3) and the surface brightens slightly (`ColorAnimation` to `Theme.surfaceHover`).

*(An earlier draft added a 1px border and a drop shadow for "richness." That was reverted — see §11.)*

### 3.2 Phase 2 — Hover / Click (3-Page Panel)

Exactly **one page renders at rest.** The bug where all three pages — including settings toggles — rendered stacked in one row must never recur.

| Page | Position | Content |
|------|----------|---------|
| `SettingsPage.qml` | Left | Every Harmonica option — checkboxes, radios, sliders, dropdowns. Persisted via `FileView` + `JsonAdapter`, with self-write suppression (ricefield pitfall). |
| `SystemInfoPage.qml` | Center — default page on open | Live RAM graph, CPU %, battery %, network SSID/speed/IP, clock/date. |
| `MusicPage.qml` | Right | Apple-Music-style player: large album art, title/artist, progress bar, prev/play-next. |

Each page is its own file under `Modules/orchestra/pages/`.

**Implementation** — either is acceptable:
- `ListView` with `orientation: Qt.Horizontal`, `snapMode: ListView.SnapOneItem`, `highlightRangeMode: ListView.StrictlyEnforceRange`; or
- `SwipeView` + `PageIndicator` (QtQuick.Controls).

**Rules:**
- Viewport width = exactly one page. `clip: true`, zero spacing leaks — at rest, no sliver of a neighboring page is visible.
- During an *active* slide, partial visibility of the outgoing/incoming page is expected — that's proof the transition is real, not a bug.
- Navigation: chevron-left/chevron-right icons on the panel edges (visible on hover) + scroll wheel → `currentIndex` ±1 with wrap-around. Page-indicator dots bind to `currentIndex`; clicking a dot jumps straight to that page.
- Transition: `Behavior on contentX`, eased, `Theme.durNormal` — a glide, never a jump cut.
- Every text element gets enough width or explicit `Text.ElideRight` + `Layout.maximumWidth`. No label may render as a clipped fragment ("P...", "Turn", "cepha") — check all three pages.

### 3.3 Phase 3 — Music Playing (Passive Morph)

- Triggered passively by playback state, not by user interaction with the island.
- Idle content **slides down** out of view; replaced by a compact preview strip: album cover (left) · title + artist (center) · mini controls (right).
- Reverts to normal idle content when music stops.
- *Assumption:* this overrides the resting Idle state only. Behavior if music starts while the hover panel, launcher, or another phase is already open isn't specified in the source spec — default to leaving that phase undisturbed until it closes back to idle; confirm if that's wrong.

### 3.4 Phase 4 — Launcher (Super+S)

- **Must be a phase view inside the Orchestra.** It was previously (wrongly) built as a separate window — fixed, and must never regress (§11).
- Super+S expands the island into a search bar + smoothly scrollable, fuzzy-filtered app list, using the same eased morph choreography as any other phase change (container grows → content enters).
- Enter launches the selected app. Esc or focus loss retracts back to the previous phase along the same animation path — no teleporting, no instant swap.
- No `/tmp` state-file coordination tricks.

### 3.5 Phase 5 — Screen Record

- Controls: record / pause / stop + a settings button.
- Settings expands a sub-panel: filename, extension, quality, audio devices (add/remove).
- While recording: red circle (left) · elapsed timestamp (center) · thin looping waveform (beneath).
- Renders as a phase inside the Orchestra like everything else — no exception needed here.

### 3.6 Phase 6 — Screenshot Annotation

- Flow: hotkey → region-select overlay → annotation canvas (pen, highlighter, shapes, text, undo/redo, Theme-colored swatches) → save/copy/close.
- Design is open. But region-select inherently needs full-screen bounds — the one flagged exception to the single-window rule (§2). **Get explicit approval before building it as a separate window.** Whether the annotation canvas also needs the exception, or can fit inside an expanded Orchestra view, is an open call — check "does this really need its own window?" first.

## 4. Signature Motion

### 4.1 Twitch

Every phase/state change begins with a tiny elastic twitch of the whole island — subtle scale/wobble, 100–200ms — before anything else moves. Plays first, strictly before the morph starts.

### 4.2 Pulse Dot

One small round dot lives in the bar. Each phase defines its own anchor position (idle = left, music = center, …). On a phase change, the dot glides along a curved bezier path to the new anchor — like a commit moving between branches in a git graph — leaving a short fading trail. It glides *during* the morph, not before or after. This is a signature detail, not just a technical requirement — the aesthetic bar is high.

### 4.3 Morph Choreography

Applied to our own single-window architecture from studying ActivSpot: we borrow their *timing and sequencing*, never their multi-window technique.

1. Twitch plays first (§4.1).
2. Container begins growing: animate `implicitWidth`/`implicitHeight` via `Behavior`, not raw `width`/`height` — eased, `OutBack` (slight overshoot) for expand, `OutCubic` for retract. Never linear, never a default/unspecified easing.
3. Old content starts fading/sliding out the moment the container starts growing, finishing at roughly **40% of the transition duration** — opacity is sequenced *after* container growth begins, not simultaneous with it from frame zero.
4. New content slides/fades in as the container settles into its final size.
5. Pulse dot (§4.2) glides throughout steps 2–4.
6. All durations and curves are named tokens in `Theme.qml` — nothing hardcoded per-component.

**Known jank sources — diagnosed once already, don't reintroduce:**
- Animating `width`/`height` directly while content reflows underneath (layout thrash).
- Missing `Behavior on implicitWidth`/`implicitHeight` (window resize lags behind content).
- Linear or default easing, or durations not pulled from `Theme`.
- Old and new content both fully visible at once outside an intentional cross-fade window.
- Anchors/margins recalculating every frame instead of being set once.

**Reference study:** ActivSpot (`github.com/Devvvmn/ActivSpot`, GPL-3.0) was cloned and read once, read-only, for technique — never copied into this repo (Harmonica is MIT/original). Findings live in `Modules/orchestra/STUDY-NOTES.md`. ActivSpot's own approach — separate `PanelWindow`s sharing a top-center anchor, coordinated via `/tmp/qs_*` state files — is explicitly not used here (§2). This reference/licensing boundary applies to any future reference study, not just this one.

## 5. Theming — Theme.qml + pywal

All color comes from pywal: `~/.cache/wal/colors.json`, read at runtime via `FileView` + `watchChanges`/`onFileChanged` for live palette updates. `Theme.qml` is the only file that reads pywal directly — every other file consumes `Theme` tokens. Zero hardcoded hex or px literals anywhere, including icon SVGs (`stroke="currentColor"`).

### 5.1 Token inventory

| Category | Tokens |
|---|---|
| Colors | `surface` (fixed neutral dark, not pywal-driven), `surfaceHover`, `onBackground`/foreground, `colorAccentNet`, `colorOk`, `colorWarn`, `colorDanger`, a pulse-dot accent distinct from all of the above |
| Type scale | full scale, at minimum `fontLg` (semibold — clock) and `fontSm` (secondary color — battery %) |
| Spacing | 4px grid; `spaceMd` and up used for idle-pill zone gaps |
| Radii | full scale, per skill skeleton |
| Durations | `durNormal` (page slide), the morph expand/retract durations, and the 100–200ms twitch duration |
| Easing | `OutBack` (expand), `OutCubic` (retract), the twitch spring curve, the pulse-dot bezier path params |

### 5.2 Semantic color mapping

No new hex values — variety comes from mapping *more* of the existing pywal palette semantically, not from inventing colors.

| Element | Source |
|---|---|
| Island surface | Fixed neutral dark — constant regardless of wallpaper |
| Wifi icon / network accents | pywal blue/cyan family → `colorAccentNet` |
| Clock | foreground / `onBackground` |
| Battery — full | pywal green family → `colorOk` |
| Battery — mid | pywal yellow family → `colorWarn` |
| Battery — low | pywal red family → `colorDanger` |
| Battery — charging | Pulses between two pywal colors |
| Pulse dot | Primary accent — must read as distinct from every color above |

## 6. Icon System

Own icon set, generated with the icon-set-generator methodology (`github.com/jezweb/claude-skills` → `icon-set-generator`). No Lucide, no Material Icons.

`assets/icons/style-spec.json` — written once, defines the shared style for every icon:

```json
{
  "name": "harmonica-icons",
  "preset": "clean",
  "grid": 24,
  "strokeWidth": 1.5,
  "strokeLinecap": "round",
  "strokeLinejoin": "round",
  "cornerRadius": 2,
  "padding": 2,
  "opticalBalance": true
}
```

Every SVG follows it exactly — `viewBox="0 0 24 24"`, `fill="none"`, `stroke="currentColor"`. Consistency over individual-icon beauty.

Category folders under `assets/icons/`:
- `status/` — wifi, battery-low, battery-mid, battery-full, battery-charging, bluetooth, airplane
- `system/` — cpu, ram, disk, temperature, gear
- `media/` — play, pause, stop, next, prev, shuffle, repeat, music-note
- `actions/` — search, close, minimize, arrow-left, arrow-right, refresh, chevron-left, chevron-right *(chevrons added — the hover-panel pager, §3.2, names them specifically; reconcile with arrow-left/right rather than shipping visual duplicates)*
- `record/` — record-circle, pause-circle, stop-circle, screenshot, scissors

All icons are consumed through exactly **one** component, `Widgets/Icon.qml` — loads by category/name, tints through `Theme`. No SVG is ever referenced directly from elsewhere.

## 7. Project Structure

```
harmonica/
├── shell.qml                 # composition root ONLY (<100 lines)
├── DESIGN.md                 # this file
├── config.json               # persisted settings (SettingsPage writes here)
├── Common/                   # singletons: Theme.qml (pywal), SettingsData.qml, Paths.qml
├── Services/                 # stateful logic, zero visuals — mpris, network, battery,
│                              #   cpu/ram pollers, hyprland ipc, recorder, screenshot
├── Modules/orchestra/        # island container, one file per phase view, PulseDot.qml, Twitch.qml
│   ├── pages/                # SettingsPage.qml, SystemInfoPage.qml, MusicPage.qml
│   └── STUDY-NOTES.md        # ActivSpot research notes — read-only reference, see §4.3
├── Widgets/                  # dumb reusable controls — LineGraph, Toggle, Radio, Slider,
│                              #   Dropdown, IconButton, ArrowNav, Icon.qml
├── assets/icons/              # generated icon set + style-spec.json — see §6
├── scripts/                  # Lua scripts for the CLI
│   ├── full-reload.lua       # example: restart quickshell + reapply pywal
│   └── screenshot-review.sh  # run after every UI change — see §11
├── docs/script-api.md        # Lua script API reference
└── cli/                       # Rust crate
```

Modular, OOP-style QML — one component per file, one feature per folder, no god-files. `DankMaterialShell` idioms apply throughout; the `ricefield` skill has already distilled them, so no separate research is needed there (unlike the ActivSpot animation study, §4.3).

## 8. Harmonica CLI (Rust)

Binary `harmonica`, distributed via the NixOS flake alongside the quickshell config (§1) — home-manager installs both together.

| Command | Behavior |
|---|---|
| `harmonica start` | Spawn quickshell against the installed config dir and return immediately (`--no-detach` blocks for systemd) |
| `harmonica reload` | IPC reload if a shell instance is alive, else start one |
| `harmonica ipc <args>` | Thin wrapper over quickshell IPC |
| `harmonica scripts <name> [args...]` | Run `scripts/<name>.lua` |

- The CLI is the ONLY component in the repo allowed to invoke quickshell directly. Hyprland keybinds and scripts call `harmonica ipc …`, never `qs …`.
- Scripts are plain `.lua` files executed by an embedded Lua VM (`mlua`, Lua 5.4) at invocation time — no recompile, save and run immediately.
- Built-in script API (documented in `docs/script-api.md`): `shell.reload()`, `shell.ipc(cmd, args)`, `sys.run(cmd)`.
- Ships one example script, `scripts/full-reload.lua` (restarts quickshell + reapplies pywal).
- `clap` for argument parsing. No heavy async runtime. Target: <10ms startup.

## 9. Build Workflow

Two separate numbering systems — don't conflate them:
- **Orchestra Phases** (§3, 1–6) are UI *states* the shell can be in at runtime.
- **Build Phases** (below, 0–7) are *development milestones* — the order this project gets built in.

| Build Phase | Scope |
|---|---|
| 0 | File tree + this DESIGN.md + `style-spec.json` + generate **all** icons — assets exist before anything needs them |
| 1 | Scaffold + `Theme`/pywal wiring + Orchestra container + Idle + Hover 3-page panel with arrow navigation |
| 2 | Pulse-dot glide + twitch polish |
| 3 | Music passive morph + Apple-style player page |
| 4 | Launcher (Super+S) |
| 5 | Screen record (+ settings sub-panel + recording UI) |
| 6 | Screenshot annotation tool |
| 7 | Rust CLI (+ mlua scripts + example script) |

**Process rule:** after each build phase, run the screenshot-review loop (§11), report what was built and what needs visual verification, then **stop and wait** for explicit go-ahead. Never write ahead of the current phase.

## 10. Engineering Conventions

Binding, from the `ricefield` skill (`~/.config/opencode/skills/ricefield/SKILL.md` and everything in its `references/` directory) — read it before writing any code:

- QML is declarative-reactive, not a web paradigm: prefer bindings over imperative assignment, `required` properties over creation-context capture.
- Token discipline: every color, space, radius, and duration comes from `Theme` (§5). A hardcoded hex or px literal anywhere else is a bug, not a style choice.
- Pitfall checklist: typed `IpcHandler` params, `SplitParser` for `Process` stdout, `WlrLayershell` namespace/anchors set correctly, self-write suppression around settings writes, restart guards.
- Scope discipline: when fixing one thing (idle layout, paging, etc.), don't touch unrelated systems (phase morphing, PulseDot logic, other phases) in the same pass.

**Authority split:** where this document and the `ricefield` skill disagree, the skill wins on **how** (idioms, API usage); this document wins on **what** (features, layout, behavior).

## 11. Verification & Hard-Won Rules

### Definition of done

The screenshot-review loop is a hard rule: after *every* UI change, run `scripts/screenshot-review.sh`, **read** the resulting image, compare it against this spec, and iterate. Never claim visual success without looking. For motion/animation work specifically, a short screen recording (e.g. `wf-recorder`) alongside screenshots helps judge smoothness that stills can't show.

For any phase or page work, screenshot **every distinct state separately**, not just the happy path:
- Each page/state on its own (e.g. idle, page-left, page-center, page-right).
- At least one mid-transition frame (proves the animation is real, not an instant swap).
- The state after an interaction (e.g. after clicking a page-indicator dot).

Attach all of them to the report. A report without full visual proof isn't done.

### Don't re-break these

Each of these was built wrong once already and corrected — don't regress:

1. **The launcher is not a separate window.** It's a phase inside the Orchestra, same as everything else. If a new feature seems to "need its own window," that's a signal to redesign it as a phase — ask first, and only for the flagged screenshot-region-select exception (§3.6).
2. **No borders, drop shadows, or blur/transparency on the island — ever.** Tried once for "richness," reverted. Richness comes from layout precision and pywal color, not chrome.
3. **The hover panel shows exactly one page at a time.** All-pages-in-one-row, with dots that don't do anything, is the specific bug that happened twice — real paging means a real `ListView`/`SwipeView` with a one-page viewport, not a static row of content.
4. **No truncated labels.** Every text element needs enough width or explicit `Text.ElideRight` + `Layout.maximumWidth` — clipped fragments must never ship again.
5. **A recolor is not a revamp.** Changing font size or nudging a color without fixing layout/structure doesn't count as addressing a structural spec — if the ask is about overlap, missing icons, or broken paging, the fix has to touch structure.
