use std::{
    ffi::{OsStr, OsString},
    io,
    os::{fd::OwnedFd, unix::net::UnixStream},
    process::{Child, Command, Stdio},
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, Instant},
};

use smithay::reexports::wayland_server::DisplayHandle;

use crate::state::ClientState;

const RESTART_DELAY: Duration = Duration::from_millis(500);

#[derive(Default)]
pub struct DevelopmentShellSupervisor {
    child: Option<Child>,
    command: Option<Vec<OsString>>,
    connection_alive: Option<Arc<AtomicBool>>,
    restart_at: Option<Instant>,
    generation: u64,
}

impl DevelopmentShellSupervisor {
    pub fn configure_and_start(
        &mut self,
        command: &[OsString],
        display: &mut DisplayHandle,
        socket_name: &OsStr,
    ) -> Result<(), Box<dyn std::error::Error>> {
        if self.command.is_some() {
            return Err(io::Error::other("the development shell is already supervised").into());
        }
        self.command = Some(command.to_vec());
        self.start(display, socket_name)
    }

    pub fn poll(&mut self) -> bool {
        if let Some(mut child) = self.child.take() {
            match child.try_wait() {
                Ok(Some(status)) => {
                    tracing::warn!(%status, "development shell exited");
                    self.restart_at = Some(Instant::now() + RESTART_DELAY);
                }
                Ok(None) => self.child = Some(child),
                Err(error) => {
                    tracing::warn!(%error, "failed to inspect development shell");
                    self.child = Some(child);
                }
            }
        }

        if self
            .connection_alive
            .as_ref()
            .is_some_and(|alive| !alive.load(Ordering::Acquire))
        {
            tracing::info!(generation = self.generation, "shell client disconnected");
            self.connection_alive = None;
            return true;
        }
        false
    }

    pub fn restart_if_due(
        &mut self,
        display: &mut DisplayHandle,
        socket_name: &OsStr,
        roles_are_clear: bool,
    ) {
        let restart_is_due = self
            .restart_at
            .is_some_and(|deadline| Instant::now() >= deadline);
        if restart_is_due
            && self.child.is_none()
            && self.connection_alive.is_none()
            && roles_are_clear
            && let Err(error) = self.start(display, socket_name)
        {
            tracing::error!(%error, "failed to restart development shell");
            self.restart_at = Some(Instant::now() + RESTART_DELAY);
        }
    }

    fn start(
        &mut self,
        display: &mut DisplayHandle,
        socket_name: &OsStr,
    ) -> Result<(), Box<dyn std::error::Error>> {
        let command = self
            .command
            .clone()
            .ok_or_else(|| io::Error::other("no development shell command is configured"))?;
        let (compositor_stream, shell_stream) = UnixStream::pair()?;
        let connection_alive = Arc::new(AtomicBool::new(true));
        display.insert_client(
            compositor_stream,
            Arc::new(ClientState::shell(Arc::clone(&connection_alive))),
        )?;

        let (program, arguments) = command
            .split_first()
            .expect("the command was validated by the option parser");
        let generation = self.generation + 1;
        let shell_fd = OwnedFd::from(shell_stream);
        let child = Command::new(program)
            .args(arguments)
            .stdin(Stdio::from(shell_fd))
            .env("WAYLAND_SOCKET", "0")
            .env("SHAPEBIT_APPLICATION_WAYLAND_DISPLAY", socket_name)
            .env("SHAPEBIT_SHELL_GENERATION", generation.to_string())
            .env_remove("WAYLAND_DISPLAY")
            .spawn()?;
        self.generation = generation;
        tracing::info!(
            pid = child.id(),
            generation = self.generation,
            program = ?program,
            "started development shell"
        );
        self.child = Some(child);
        self.connection_alive = Some(connection_alive);
        self.restart_at = None;
        Ok(())
    }
}
