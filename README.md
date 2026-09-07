# Harmonica

Dynamic-island-style desktop shell for **Hyprland on NixOS** — one morphing pill that becomes an app launcher, music strip, control panel, screen recorder and screenshot capture row. Built with [Quickshell](https://quickshell.outfoxxed.me) (QML) and a companion Rust CLI.

> **All shell control goes through the `harmonica` CLI.** Direct `qs`/`quickshell` invocation is banned outside the CLI's own implementation.

## Install (NixOS + home-manager)

Add to your `home.nix`:

```nix
{
  imports = [ harmonica.homeManagerModules.default ];
  programs.harmonica.enable = true;
}
```

with the flake input:

```nix
{
  inputs.harmonica.url = "github:you/harmonica";
  # ...
}
```

then:

```bash
home-manager switch
```

This installs:

- the `harmonica` binary on PATH
- the QML shell config + `scripts/` (read-only, from the Nix store)
- `awww` + `pywal16` (wallpaper apply + live palette regeneration)
- `wf-recorder` (screen-record backend)
- a systemd user service autostart (`harmonica start --no-detach`, restarts on failure)

### Verify

```bash
which harmonica        # → ~/.nix-profile/bin/harmonica
nix run .#             # → run the CLI from the flake without installing
```

## CLI

| Command | What it does |
|---|---|
| `harmonica start` | Launch the shell (spawn-and-return). `--no-detach` for systemd. |
| `harmonica reload` | Live-reload the running instance, or start it if dead. |
| `harmonica ipc <target> <fn> [args…]` | Forward an IPC call to the shell. |
| `harmonica scripts <name> [args…]` | Run a Lua script from `scripts/`. |

IPC targets: `orchestra` (open/close/phase/page), `launcher` (open/close/toggle/results), `record` (start/pause/stop/settings/state), `screenshot` (open/close/toggle/area/screen/output/saveArea/saveScreen/color), `wallpaper` (open/close/toggle/isOpen/next/prev/focused/pick/apply/state).

## Hyprland keybinds

```ini
bind = SUPER, S, exec, harmonica ipc launcher toggle      # app launcher
bind = SUPER SHIFT, S, exec, harmonica ipc screenshot toggle
bind = SUPER SHIFT, W, exec, harmonica ipc wallpaper toggle # wallpaper picker
bind = SUPER SHIFT, R, exec, harmonica ipc record toggle  # record
exec-once = harmonica start                               # autostart
```

## Development

```bash
nix develop          # rust + quickshell + awww + pywal16 + grim + wf-recorder
cargo build --release --manifest-path cli/Cargo.toml
# run the shell from a config dir directly:
nix run .# -- start
```

The canonical spec is [DESIGN.md](DESIGN.md) — read it before writing code. QML hot-reloads on save; `harmonica reload` restarts cleanly.

## Layout

```
shell.qml              composition root — Orchestra + two approved overlays
Common/                Theme (pywal tokens) · Paths · SettingsData
Modules/orchestra/     phase views: idle, music, panel, launcher, record, screenshot
Modules/wallpaper/     approved standalone picker · carousel · IPC boundary
Services/              headless QML services: mpris, network, battery, recorder…
Widgets/               reusable QML widgets
cli/                   Rust control CLI (the only place quickshell is invoked)
scripts/               Lua scripts + screenshot-review loop
```
