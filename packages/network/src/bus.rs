//! The system bus: the connection, the executor the agent's work runs on,
//! and calls to system services, which must answer in time.

use std::fmt;
use std::future::Future;
use std::sync::OnceLock;
use std::time::Duration;

use async_executor::Executor;
use futures_lite::StreamExt;
use zbus::Connection;
use zbus::proxy::{Builder, CacheProperties, Defaults};

/// How long a system service has to answer: a property, and a call.
pub const PROPERTY_TIME: Duration = Duration::from_secs(2);
pub const CALL_TIME: Duration = Duration::from_secs(25);

pub static EXECUTOR: Executor<'static> = Executor::new();
static SYSTEM: OnceLock<Connection> = OnceLock::new();

pub fn connected(connection: Connection) {
    SYSTEM.set(connection).expect("connected once");
}

pub fn system() -> &'static Connection {
    SYSTEM.get().expect("connected")
}

pub fn spawn(work: impl Future<Output = ()> + Send + 'static) {
    EXECUTOR.spawn(work).detach();
}

/// A call that failed: the error's name, and what a person may read of it.
#[derive(Debug, PartialEq)]
pub struct Failed {
    pub name: String,
    pub reason: String,
}

impl From<zbus::Error> for Failed {
    fn from(error: zbus::Error) -> Self {
        match error {
            zbus::Error::MethodError(name, description, _) => Failed {
                reason: description.unwrap_or_else(|| name.to_string()),
                name: name.to_string(),
            },
            error => Failed {
                name: String::new(),
                reason: error.to_string(),
            },
        }
    }
}

impl From<Failed> for String {
    fn from(failed: Failed) -> Self {
        failed.reason
    }
}

impl fmt::Display for Failed {
    fn fmt(&self, f: &mut fmt::Formatter) -> fmt::Result {
        f.write_str(&self.reason)
    }
}

/// The call's result, or that it took longer than `time`.
pub async fn timed<T>(time: Duration, call: impl Future<Output = zbus::Result<T>>) -> Result<T, Failed> {
    let late = async {
        async_io::Timer::after(time).await;
        Err(Failed {
            name: String::new(),
            reason: "Timed out".into(),
        })
    };
    futures_lite::future::or(async { Ok(call.await?) }, late).await
}

/// A proxy of the object at `path`, which reads each property afresh.
pub async fn proxy<P>(path: &str) -> Result<P, Failed>
where
    P: From<zbus::Proxy<'static>> + Defaults,
{
    Ok(Builder::<P>::new(system())
        .path(path.to_string())
        .cache_properties(CacheProperties::No)
        .build()
        .await?)
}

/// Runs `register` whenever the service `name` starts, and now if it runs.
pub async fn watch<F: Future<Output = ()>>(name: &'static str, register: impl Fn() -> F) {
    let Ok(bus) = zbus::fdo::DBusProxy::new(system()).await else {
        return;
    };
    let changes = bus.receive_name_owner_changed_with_args(&[(0, name)]).await;
    if let Ok(name) = zbus::names::BusName::try_from(name)
        && bus.name_has_owner(name).await.unwrap_or(false)
    {
        register().await;
    }
    let Ok(mut changes) = changes else { return };
    while let Some(change) = changes.next().await {
        if change.args().is_ok_and(|args| args.new_owner().is_some()) {
            register().await;
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use futures_lite::future::{block_on, pending};

    #[test]
    fn a_call_that_takes_too_long_timed_out() {
        let late = block_on(timed(Duration::from_millis(1), pending::<zbus::Result<()>>()));
        assert_eq!(
            late,
            Err(Failed {
                name: String::new(),
                reason: "Timed out".into()
            })
        );
        assert_eq!(block_on(timed(CALL_TIME, async { Ok(7) })), Ok(7));
    }

    #[test]
    fn a_failure_reads_as_its_description() {
        let failed = Failed::from(zbus::Error::Failure("No such device".into()));
        assert_eq!((failed.name.as_str(), failed.reason.as_str()), ("", "No such device"));
        assert_eq!(String::from(failed), "No such device");
    }
}
