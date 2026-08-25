# ActivSpot study — how production dynamic-islands stay fluid

Reference: github.com/Devvvmn/ActivSpot (GPL-3.0) — READ-ONLY study, no code copied.

## 1. The core trick: the window NEVER resizes

- `PanelWindow.implicitHeight` is a FIXED constant (s(720)); `exclusionMode: Ignore`.
- ALL size animation happens on an inner `islandShape` Item (plain QML Item),
  centered with `x = (Screen.width - width)/2`.
- Consequence: zero layer-surface reconfigures during morphs. No compositor
  round-trips, no window-manager relayout — only cheap QML item geometry.
- Input mask is `null` while expanded (whole window takes input =
  built-in click-outside-to-close), pill-bounds `Region` when collapsed.

## 2. Container motion values (their actual numbers)

| Property | Duration | Easing |
|---|---|---|
| shape width | 540ms | OutExpo |
| shape height | 540ms | OutExpo |
| radius | 540ms | OutExpo |
| hover scale (collapsed) | 280ms | OutExpo (scale 1.025) |
| badge scale-in | 420ms | OutBack |
| collapsed-content crossfade | 220ms | InOutCubic |
| page enter slide (Translate y −8→0) | 500ms | OutExpo |
| page crossfade | 300ms | InOutCubic |

Pattern: **containers get pure-decel easing (OutExpo)**; overshoot (OutBack) is
reserved for tiny decorative elements. Fades use InOut/OutCubic.

## 3. Sequencing / choreography

- Collapsed↔expanded contents are separate layers; each fades by
  `opacity: expanded ? 0 : 1` with `visible: opacity > 0.001` gating —
  old content fades OUT while container grows, new content fades IN as it settles,
  staggered by a 60ms PauseAnimation on the incoming side.
- Expanded pages enter with BOTH fade (300) and upward slide (500, OutExpo) —
  slide finishes after fade, giving settle feel.
- Notification expansion sequences width FIRST, height +220ms later
  (PauseAnimation inside the height Behavior).

## 4. Their launcher (what we deliberately do NOT copy)

Separate PanelWindow process-pair coordinated via `/tmp/qs_launcher_state`
inotify watch; island hides itself (`opacity 0`) while launcher shows.
Same visual recipe though: shape Item 540 OutExpo w/h, y animated, radius 300
OutCubic, content 220 OutCubic, results-list height 200 OutCubic, exit kept
alive 600ms (hideTimer) so the retract animation finishes before `visible:false`.

---

# OUR jank diagnosis (pre-fix)

1. **win.implicitHeight animated** → per-frame layer-surface reconfigure +
   whole-window relayout every frame. ActivSpot never resizes its window. (worst offender)
2. **content.width Behavior + horizontalCenter anchor** → every anchored
   descendant recomputes per-frame during width morph.
3. **Simultaneous content swap**: IdleBar/MusicStrip/PanelPages flip
   visible/opacity at the same instant the container starts resizing — both
   contents partially visible mid-flight, no in/out sequencing.
4. **Overshoot curve (easeSpatial) on the CONTAINER** — bounce against the
   static desktop reads as glitch, not polish. Reference: OutExpo containers.
5. **Twitch fires simultaneously with the size morph** — two competing motions;
   spec wants twitch BEFORE the morph begins.
