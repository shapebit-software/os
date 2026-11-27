// The connection agent, which the shell runs (shell/src/services/Connectivity.qml) and talks
// to over its standard input and output, one JSON line at a time. It joins
// Wi-Fi networks with the password the person types in the network panel and
// pairs Bluetooth devices, which Quickshell cannot; and it is NetworkManager's
// secret agent and BlueZ's pairing agent, so that what they ask the person, a
// network's password again or a device's pairing code, the shell asks
// (QuestionDialog.qml).
//
// From the shell: {"join": ssid, "password": text}, {"pair": device path},
// and answers, {"answer": id, "granted": bool, "fields": {id: text}}.
// To the shell: questions, {"ask": id, "kind": ..., "title": ..., ...}, and
// their withdrawal, {"cancel": id}; and what came of joining and pairing,
// {"event": "join" or "pair", "target": ssid or path, "ok": bool, "reason": text}.
//
// D-Bus method calls to the agents run on zbus's threads; the shell's
// messages, joining and pairing on the executor of main().

mod bluetooth;
mod bus;
mod shell;
mod wifi;

use std::io::BufRead;
use std::sync::{Mutex, MutexGuard};

use shell::Command;

/// What a lock guards; a thread that panicked holding it leaves it as it was.
fn lock<T>(mutex: &Mutex<T>) -> MutexGuard<'_, T> {
    mutex.lock().unwrap_or_else(|poisoned| poisoned.into_inner())
}

async fn run() -> zbus::Result<()> {
    let connection = zbus::connection::Builder::system()
        .serve_at(wifi::AGENT_PATH, wifi::SecretAgent)
        .serve_at(bluetooth::AGENT_PATH, bluetooth::Agent)
        .build()
        .await?;
    bus::connected(connection);
    bus::spawn(bus::watch(bluetooth::SERVICE, bluetooth::register));
    bus::spawn(bus::watch(wifi::SERVICE, wifi::register));

    // The shell's lines, read on a thread of their own; their end is the
    // shell gone.
    let (sender, lines) = async_channel::unbounded();
    std::thread::spawn(move || {
        for line in std::io::stdin().lock().lines() {
            let Ok(line) = line else { break };
            if sender.send_blocking(line).is_err() {
                break;
            }
        }
    });
    while let Ok(line) = lines.recv().await {
        match shell::read(&line) {
            Ok(Some(Command::Join { ssid, password })) => bus::spawn(wifi::join(ssid, password)),
            Ok(Some(Command::Pair(device))) => bus::spawn(bluetooth::pair(device)),
            Ok(Some(Command::Answer(id, answer))) => shell::answer(id, answer),
            Ok(None) => {}
            Err(error) => eprintln!("connection-agent: {error}"),
        }
    }
    Ok(())
}

fn main() {
    if let Err(error) = zbus::block_on(bus::EXECUTOR.run(run())) {
        eprintln!("connection-agent: {error}");
        std::process::exit(1);
    }
}
