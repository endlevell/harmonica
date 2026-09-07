# Harmonica script API

Lua scripts live in `scripts/` and run at invocation time via an embedded
Lua 5.4 VM (`harmonica scripts <name> [args...]`). No recompile needed —
save and run.

## Globals

| Global | Type | Description |
|---|---|---|
| `args` | `string[]` | Positional args after the script name |

## `shell`

### `shell.reload()`
Live-reloads the running quickshell instance (forces a config reload by
touching its entry file). No-op-safe: if no instance is running nothing
happens.

### `shell.ipc(target, function, ...)`
Forward a typed IPC call to the shell, same as
`harmonica ipc <target> <function> [...]`. Exits with quickshell's exit code
on failure.

```lua
shell.ipc("launcher", "toggle")
shell.ipc("record", "start")
shell.ipc("orchestra", "page")
```

Targets registered by the shell:
- `orchestra` — open/close/isOpen/phase/page/nextPage/prevPage
- `launcher`  — open/close/toggle/isOpen/results
- `record`    — start/pause/stop/settings/state
- `screenshot`— open/close/toggle/area/screen/output/saveArea/saveScreen/color

## `sys`

### `sys.run(cmd) -> exit_code`
Run `cmd` through `/bin/sh -c`, inheriting stdio. Returns the process exit
code.

```lua
local ok = sys.run("notify-send 'harmonica' 'hi'")
```

### `sys.spawn(cmd)`
Run `cmd` detached (own process group, no stdio). Fire-and-forget — use for
tools that may kill their own process group (e.g. `wal -R`).

```lua
sys.spawn("wal -R")
```

## Example

See `scripts/full-reload.lua`:

```lua
sys.run("wal -R")
sys.run("sleep 0.3")
shell.reload()
```
