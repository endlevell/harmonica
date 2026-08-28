use std::path::Path;
use std::process::{Command, Stdio};

/// Forward a call to quickshell's IPC bridge. Returns exit code.
pub fn call(dir: &Path, target: &str, func: &str, args: &[String]) -> i32 {
    let mut cmd = Command::new("qs");
    cmd.arg("-p").arg(dir).arg("ipc").arg("call").arg(target).arg(func);
    for a in args {
        cmd.arg(a);
    }
    match cmd.status() {
        Ok(s) => s.code().unwrap_or(1),
        Err(e) => {
            eprintln!("harmonica: failed to run qs: {e}");
            127
        }
    }
}

/// Launch the shell. Detached = spawn quickshell and return immediately
/// (interactive use). `--no-detach` blocks so the systemd unit tracks the
/// shell directly.
pub fn start(dir: &Path, detach: bool) -> i32 {
    use std::os::unix::process::CommandExt;
    let mut cmd = Command::new("qs");
    cmd.arg("-p").arg(dir);
    if detach {
        // spawn + orphan: CLI exits at once, quickshell keeps running
        match cmd
            .process_group(0)
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
        {
            Ok(_) => 0,
            Err(e) => {
                eprintln!("harmonica: failed to start quickshell: {e}");
                1
            }
        }
    } else {
        match cmd.status() {
            Ok(s) => s.code().unwrap_or(0),
            Err(e) => {
                eprintln!("harmonica: failed to start quickshell: {e}");
                1
            }
        }
    }
}
