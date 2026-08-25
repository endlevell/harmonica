#!/usr/bin/env bash
# screenshot-review.sh — mandatory visual feedback loop for Quickshell UI work.
#
# Reloads the quickshell instance for a config dir, waits for it to settle,
# captures the shell region (default: full screen; set REGION for bar/panel),
# saves a timestamped PNG, prints its path. The calling agent MUST then read
# and inspect the image against the design spec before iterating.
#
# Usage:
#   scripts/screenshot-review.sh                    # reload + full-screen shot of active output
#   REGION="2560x44+0+0" scripts/screenshot-review.sh   # capture just the bar strip
#   NO_RELOAD=1 scripts/screenshot-review.sh        # capture only (no qs restart)
#   QS_DIR=~/src/myshell OUT_DIR=/tmp/shots SETTLE=3 scripts/screenshot-review.sh
#
# Env:
#   QS_DIR    config dir containing shell.qml (default: $PWD)
#   REGION    grim geometry "WxH+X+Y"; empty = whole focused output
#   SETTLE    seconds to wait after reload (default 1.5)
#   OUT_DIR   screenshot destination (default ./shots)
#   TOOL      grim | hyprshot | auto (default auto)
set -euo pipefail

QS_DIR="${QS_DIR:-$PWD}"
REGION="${REGION:-}"
SETTLE="${SETTLE:-1.5}"
OUT_DIR="${OUT_DIR:-$PWD/shots}"
TOOL="${TOOL:-auto}"
NO_RELOAD="${NO_RELOAD:-0}"

die() { printf 'screenshot-review: %s\n' "$1" >&2; exit 1; }

case "$TOOL" in grim|hyprshot|auto) ;; *) die "TOOL must be grim|hyprshot|auto" ;; esac
[ -f "$QS_DIR/shell.qml" ] || die "no shell.qml in QS_DIR=$QS_DIR"
command -v qs >/dev/null 2>&1 || die "qs not in PATH"
if ! command -v grim >/dev/null 2>&1 && ! command -v hyprshot >/dev/null 2>&1; then
  die "need grim or hyprshot (pacman -S grim) — no Wayland screenshot tool found"
fi
[ -n "${WAYLAND_DISPLAY:-}" ] || die "WAYLAND_DISPLAY unset — run inside the Wayland session"

mkdir -p "$OUT_DIR"
STAMP="$(date +%Y%m%d-%H%M%S)"
OUT="$OUT_DIR/shot-$STAMP.png"

# 1. Reload: quickshell live-reloads on file save, but a deterministic restart
#    guarantees we review the on-disk state, not a half-applied hot reload.
#    NOTE: qs kill stops the instance bound to this config path.
QS_PID=""
if [ "$NO_RELOAD" != "1" ]; then
  qs -p "$QS_DIR" kill >/dev/null 2>&1 || qs kill >/dev/null 2>&1 || true
  sleep 0.5
  nohup qs -p "$QS_DIR" >"$OUT_DIR/qs-$STAMP.log" 2>&1 &
  QS_PID=$!
fi

# 2. Settle: let windows spawn, bindings evaluate, entrance animations finish.
sleep "$SETTLE"

# Broken config would have killed the new instance by now — fail loudly with
# its log instead of screenshotting an empty desktop.
if [ -n "$QS_PID" ] && ! kill -0 "$QS_PID" 2>/dev/null; then
  tail -n 30 "$OUT_DIR/qs-$STAMP.log" >&2 || true
  die "quickshell died after launch — fix the QML error above (log: $OUT_DIR/qs-$STAMP.log)"
fi

# 3. Capture. REGION needs grim (exact geometry); otherwise prefer grim full
#    capture, fall back to hyprshot (writes PNG bytes to stdout via --raw).
if [ -n "${REGION:-}" ]; then
  command -v grim >/dev/null || die "REGION capture requires grim"
  # REGION="WxH+X+Y" → grim geometry "X,Y WxH"
  GEOM=$(printf '%s' "$REGION" | sed -n 's/^\([0-9]*\)x\([0-9]*\)+\([0-9]*\)+\([0-9]*\)$/\3,\4 \1x\2/p')
  [ -n "$GEOM" ] || die "REGION must be WxH+X+Y"
  grim -g "$GEOM" "$OUT"
elif [ "$TOOL" = "hyprshot" ] || ! command -v grim >/dev/null 2>&1; then
  command -v hyprshot >/dev/null 2>&1 || die "need grim or hyprshot"
  hyprshot -m output --raw >"$OUT" || die "hyprshot failed"
else
  grim "$OUT"
fi

[ -s "$OUT" ] || die "capture produced an empty file"

# 4. Surface recent shell errors alongside the shot so the agent sees both.
LOG_TAIL=""
if [ -f "$OUT_DIR/qs-$STAMP.log" ]; then
  LOG_TAIL=$(grep -iE 'error|warn' "$OUT_DIR/qs-$STAMP.log" | tail -n 10 || true)
fi

printf '%s\n' "$OUT"
[ -n "$LOG_TAIL" ] && printf 'qs log warnings/errors:\n%s\n' "$LOG_TAIL" >&2 || true
printf 'AGENT ACTION REQUIRED: open %s and compare against DESIGN.md before further edits.\n' "$OUT" >&2
