use mlua::{Lua, MultiValue};
use std::path::{Path, PathBuf};
use std::process::Command;

use crate::ipc;

/// Run scripts/<name>.lua in an embedded Lua 5.4 VM with the Harmonica API:
///   shell.reload()               — live-reload the running instance
///   shell.ipc(target, func, ...) — forward an IPC call
///   sys.run(cmd)                 — run a shell command, returns exit code
/// Script args arrive as the global `args` table.
pub fn run(shell_dir: &Path, script_dir: &Path, name: &str, args: &[String]) -> Result<i32, Box<dyn std::error::Error>> {
    let file = resolve_script(script_dir, name)?;
    let lua = Lua::new();
    let globals = lua.globals();

    let reload_dir: PathBuf = discover_reload_dir(shell_dir);
    let shell = lua.create_table()?;
    shell.set(
        "reload",
        lua.create_function(move |_, _: ()| {
            do_reload(&reload_dir);
            Ok(())
        })?,
    )?;
    let ipc_dir = shell_dir.to_path_buf();
    shell.set(
        "ipc",
        lua.create_function(move |_, (target, func, rest): (String, String, MultiValue)| {
            let args: Vec<String> = coerce(rest);
            let code = ipc::call(&ipc_dir, &target, &func, &args);
            if code != 0 {
                std::process::exit(code);
            }
            Ok(())
        })?,
    )?;

    let sys = lua.create_table()?;
    sys.set(
        "run",
        lua.create_function(|_, cmd: String| {
            let st = Command::new("sh").arg("-c").arg(cmd).status()
                .map_err(mlua::Error::external)?;
            Ok(st.code().unwrap_or(-1))
        })?,
    )?;
    // fire-and-forget: survives even if the child kills its own process group
    sys.set(
        "spawn",
        lua.create_function(|_, cmd: String| {
            use std::os::unix::process::CommandExt;
            Command::new("sh").arg("-c").arg(cmd)
                .process_group(0)
                .stdin(std::process::Stdio::null())
                .stdout(std::process::Stdio::null())
                .stderr(std::process::Stdio::null())
                .spawn()
                .map_err(mlua::Error::external)?;
            Ok(())
        })?,
    )?;

    globals.set("shell", shell)?;
    globals.set("sys", sys)?;
    let args_table = lua.create_table()?;
    for (i, a) in args.iter().enumerate() {
        args_table.set(i + 1, a.as_str())?;
    }
    globals.set("args", args_table)?;

    let source = std::fs::read_to_string(&file)?;
    lua.load(source).set_name(name.to_string()).exec()?;
    Ok(0)
}

fn resolve_script(script_dir: &Path, name: &str) -> Result<PathBuf, Box<dyn std::error::Error>> {
    let direct = PathBuf::from(name);
    if direct.is_file() && name.ends_with(".lua") {
        return Ok(direct);
    }
    let with_ext = script_dir.join(format!("{name}.lua"));
    if with_ext.is_file() {
        return Ok(with_ext);
    }
    Err(format!("script not found: {} (looked in {})", name, script_dir.display()).into())
}

fn discover_reload_dir(fallback: &Path) -> PathBuf {
    crate::paths::discover_instance().unwrap_or_else(|| fallback.to_path_buf())
}

pub fn do_reload(dir: &Path) {
    // quickshell live-reloads on config file changes; rewriting shell.qml
    // (same content) fires its watcher. An open() alone does not.
    let marker = dir.join("shell.qml");
    match std::fs::read_to_string(&marker)
        .map_err(mlua::Error::external)
        .and_then(|content| std::fs::write(&marker, content).map_err(mlua::Error::external))
    {
        Ok(_) => println!("harmonica: reloaded {}", dir.display()),
        Err(e) => eprintln!("harmonica: reload failed ({}): {e}", marker.display()),
    }
}

fn coerce(v: MultiValue) -> Vec<String> {
    v.into_iter()
        .map(|x| match x {
            mlua::Value::String(s) => s.to_str().unwrap_or_default().to_string(),
            mlua::Value::Integer(i) => i.to_string(),
            mlua::Value::Number(n) => n.to_string(),
            mlua::Value::Boolean(b) => b.to_string(),
            other => format!("{other:?}"),
        })
        .collect()
}
