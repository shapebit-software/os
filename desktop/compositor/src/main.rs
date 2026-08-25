mod backend;
mod handlers;
mod input;
mod layout;
mod protocols;
mod shell_supervisor;
mod state;
mod workspaces;

use std::{env, ffi::OsString, process::Command};

use calloop::signals::{Signal, Signals};
use smithay::reexports::{calloop::EventLoop, wayland_server::Display};
use state::Compositor;
use tracing::info;
use tracing_subscriber::EnvFilter;

#[derive(Debug, Default, Eq, PartialEq)]
struct Options {
    socket: Option<String>,
    shell_command: Vec<OsString>,
    command: Vec<OsString>,
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    init_logging();
    let options = parse_options(env::args_os().skip(1))?;

    let mut event_loop: EventLoop<Compositor> = EventLoop::try_new()?;
    let loop_signal = event_loop.get_signal();
    event_loop.handle().insert_source(
        Signals::new(&[Signal::SIGINT, Signal::SIGTERM])?,
        move |event, _, _| {
            info!(signal = ?event.signal(), "stopping ShapeBit compositor");
            loop_signal.stop();
        },
    )?;
    let display = Display::new()?;
    let mut state = Compositor::new(&mut event_loop, display, options.socket.as_deref())?;

    backend::init(&mut event_loop, &mut state)?;
    info!(socket = ?state.socket_name, "ShapeBit compositor is ready");

    if !options.shell_command.is_empty() {
        state.spawn_development_shell(&options.shell_command)?;
    }

    if let Some((program, arguments)) = options.command.split_first() {
        Command::new(program)
            .args(arguments)
            .env("WAYLAND_DISPLAY", &state.socket_name)
            .spawn()?;
    }

    event_loop.run(None, &mut state, |_| {})?;
    Ok(())
}

fn init_logging() {
    let filter = EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info"));
    tracing_subscriber::fmt().with_env_filter(filter).init();
}

fn parse_options(arguments: impl IntoIterator<Item = OsString>) -> Result<Options, String> {
    let mut options = Options::default();
    let mut arguments = arguments.into_iter();

    while let Some(argument) = arguments.next() {
        if argument == "--" {
            options.command.extend(arguments);
            break;
        }
        if argument == "--shell" {
            options.shell_command.extend(arguments);
            if options.shell_command.is_empty() {
                return Err("--shell requires a program".into());
            }
            break;
        }
        if argument == "--socket" {
            let value = arguments.next().ok_or("--socket requires a name")?;
            let value = value
                .into_string()
                .map_err(|_| "socket name must be UTF-8")?;
            if value.is_empty() || value.contains('/') {
                return Err("socket name must be non-empty and must not contain '/'".into());
            }
            options.socket = Some(value);
            continue;
        }
        if argument == "--help" || argument == "-h" {
            println!(
                "Usage: compositor [--socket NAME] [--shell PROGRAM [ARG ...] | -- PROGRAM [ARG ...]]"
            );
            std::process::exit(0);
        }
        return Err(format!("unknown argument: {}", argument.to_string_lossy()));
    }

    Ok(options)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parses_socket_and_child_command() {
        let options = parse_options([
            "--socket".into(),
            "wayland-shapebit-test".into(),
            "--".into(),
            "demo".into(),
            "--flag".into(),
        ])
        .unwrap();

        assert_eq!(options.socket.as_deref(), Some("wayland-shapebit-test"));
        assert_eq!(
            options.command,
            [OsString::from("demo"), OsString::from("--flag")]
        );
    }

    #[test]
    fn rejects_unsafe_socket_names() {
        assert!(parse_options(["--socket".into(), "../socket".into()]).is_err());
    }

    #[test]
    fn parses_development_shell_command() {
        let options = parse_options(["--shell".into(), "shell".into(), "--demo".into()]).unwrap();

        assert_eq!(
            options.shell_command,
            [OsString::from("shell"), OsString::from("--demo")]
        );
        assert!(options.command.is_empty());
    }
}
