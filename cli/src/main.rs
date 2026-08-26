mod ipc;
mod paths;
mod scripts;

use clap::{Parser, Subcommand};
use std::process::exit;

#[derive(Parser)]
#[command(name = "harmonica", version, about = "Control the Harmonica quickshell island")]
struct Cli {
    #[command(subcommand)]
    cmd: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Launch the shell (detached). Use --no-detach under systemd.
    Start {
        #[arg(long)]
        no_detach: bool,
    },
    /// Live-reload the running instance, or start it if not running
    Reload,
    /// Forward an IPC call: harmonica ipc <target> <function> [args...]
    Ipc {
        target: String,
        function: String,
        args: Vec<String>,
    },
    /// Run a Lua script from scripts/: harmonica scripts <name> [args...]
    Scripts {
        name: String,
        args: Vec<String>,
    },
}

fn main() {
    let cli = Cli::parse();
    let dir = paths::config_dir();

    let code = match cli.cmd {
        Cmd::Start { no_detach } => ipc::start(&dir, !no_detach),
        Cmd::Reload => {
            if let Some(live) = paths::discover_instance() {
                scripts::do_reload(&live);
                0
            } else {
                println!("harmonica: no running instance, starting");
                ipc::start(&dir, true)
            }
        }
        Cmd::Ipc { target, function, args } => {
            // prefer the dir of an already-running instance (store vs config paths)
            let d = paths::discover_instance().unwrap_or(dir);
            ipc::call(&d, &target, &function, &args)
        }
        Cmd::Scripts { name, args } => match scripts::run(&dir, &dir.join("scripts"), &name, &args) {
            Ok(c) => c,
            Err(e) => {
                eprintln!("harmonica: {e}");
                1
            }
        },
    };
    exit(code);
}
