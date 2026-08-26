use std::fs;
use std::path::{Path, PathBuf};

/// Resolve the shell/config directory:
/// 1. $HARMONICA_CONFIG_DIR
/// 2. cwd if it contains shell.qml (dev convenience)
/// 3. $XDG_CONFIG_HOME/harmonica (or ~/.config/harmonica)
pub fn config_dir() -> PathBuf {
    if let Ok(d) = std::env::var("HARMONICA_CONFIG_DIR") {
        if !d.is_empty() {
            return PathBuf::from(d);
        }
    }
    if let Ok(cwd) = std::env::current_dir() {
        if cwd.join("shell.qml").exists() {
            return cwd;
        }
    }
    let base = std::env::var("XDG_CONFIG_HOME")
        .ok()
        .filter(|s| !s.is_empty())
        .map(PathBuf::from)
        .or_else(|| std::env::var("HOME").ok().map(|h| PathBuf::from(h).join(".config")))
        .unwrap_or_else(|| PathBuf::from("/etc/xdg"));
    base.join("harmonica")
}

/// Find a RUNNING quickshell instance and the `-p` dir it was launched with.
/// Scans /proc cmdlines; falls back to the resolved config dir.
pub fn discover_instance() -> Option<PathBuf> {
    let proc = Path::new("/proc");
    let mut entries: Vec<_> = fs::read_dir(proc).ok()?.collect();
    entries.sort_by_key(|e| e.as_ref().ok()
        .and_then(|e| e.file_name().to_str().and_then(|s| s.parse::<u32>().ok()))
        .unwrap_or(0));
    for e in entries.iter().rev() {
        let p = match e.as_ref() {
            Ok(p) => p.path(),
            Err(_) => continue,
        };
        let cmd = fs::read_to_string(p.join("cmdline")).unwrap_or_default();
        if !cmd.contains("quickshell") && !cmd.contains(".quickshell-wrapped") {
            continue;
        }
        let parts: Vec<&str> = cmd.split('\0').filter(|s| !s.is_empty()).collect();
        if let Some(i) = parts.iter().position(|a| *a == "-p") {
            if let Some(d) = parts.get(i + 1) {
                let pb = PathBuf::from(*d);
                // relative args ("qs -p .") must resolve against THAT process's cwd
                let abs = if pb.is_absolute() {
                    pb.clone()
                } else {
                    let cwd = fs::read_link(p.join("cwd")).unwrap_or_else(|_| PathBuf::from("/"));
                    cwd.join(pb)
                };
                return Some(fs::canonicalize(&abs).unwrap_or(abs));
            }
        }
    }
    None
}
