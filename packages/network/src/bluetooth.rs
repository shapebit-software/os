//! Bluetooth: pairing, which this agent does so that BlueZ asks it, and
//! BlueZ's pairing agent.

use std::collections::{HashMap, HashSet};
use std::sync::{LazyLock, Mutex};
use std::time::Duration;

use serde_json::{Value, json};
use zbus::{DBusError, OwnedObjectPath, interface, proxy};

use crate::bus::{CALL_TIME, Failed, PROPERTY_TIME, proxy, spawn, timed};
use crate::lock;
use crate::shell::{self, tell};

pub const SERVICE: &str = "org.bluez";
pub const AGENT_PATH: &str = "/desktop/agent";

/// How long pairing may take: it waits for the person at the device.
const PAIR_TIME: Duration = Duration::from_secs(120);

#[proxy(interface = "org.bluez.Device1", default_service = "org.bluez")]
trait Device {
    fn pair(&self) -> zbus::Result<()>;
    fn cancel_pairing(&self) -> zbus::Result<()>;
    fn connect(&self) -> zbus::Result<()>;
    #[zbus(property(emits_changed_signal = "false"))]
    fn alias(&self) -> zbus::Result<String>;
    #[zbus(property(emits_changed_signal = "false"))]
    fn paired(&self) -> zbus::Result<bool>;
    #[zbus(property(emits_changed_signal = "false"))]
    fn set_trusted(&self, trusted: bool) -> zbus::Result<()>;
}

#[proxy(interface = "org.bluez.AgentManager1", default_service = "org.bluez")]
trait AgentManager {
    fn register_agent(&self, agent: &OwnedObjectPath, capability: &str) -> zbus::Result<()>;
    fn request_default_agent(&self, agent: &OwnedObjectPath) -> zbus::Result<()>;
}

/// Makes this agent BlueZ's pairing agent.
pub async fn register() {
    let Ok(manager) = proxy::<AgentManagerProxy>("/org/bluez").await else {
        return;
    };
    let agent = OwnedObjectPath::try_from(AGENT_PATH).expect("a path");
    if timed(CALL_TIME, manager.register_agent(&agent, "KeyboardDisplay"))
        .await
        .is_ok()
    {
        let _ = timed(CALL_TIME, manager.request_default_agent(&agent)).await;
    }
}

/// Pairs, trusts and connects a device, and tells the shell what came of it.
pub async fn pair(path: OwnedObjectPath) {
    let result = pairing(&path).await;
    let shown = lock(&ASKING).showing.remove(path.as_str());
    if let Some(id) = shown {
        shell::withdraw(id);
    }
    tell(&shell::event("pair", path.as_str(), result));
}

async fn pairing(path: &str) -> Result<(), String> {
    let device = proxy::<DeviceProxy>(path).await?;
    paired(timed(PAIR_TIME, device.pair()).await)?;
    let _ = timed(CALL_TIME, device.set_trusted(true)).await;
    let _ = timed(CALL_TIME, device.connect()).await;
    Ok(())
}

/// Whether pairing went through: a device paired already is; a refusal
/// reads as the person understands it.
fn paired(result: Result<(), Failed>) -> Result<(), String> {
    match result {
        Err(failed) if failed.name.contains("AlreadyExists") => Ok(()),
        Err(failed) if failed.name.contains("AuthenticationFailed") => Err("Pairing failed".into()),
        Err(failed) => Err(failed.reason),
        Ok(()) => Ok(()),
    }
}

async fn device_name(path: &str) -> String {
    match proxy::<DeviceProxy>(path).await {
        Ok(device) => timed(PROPERTY_TIME, device.alias()).await.ok(),
        Err(_) => None,
    }
    .unwrap_or_else(|| "the device".to_string())
}

/// BlueZ's open questions, and the codes shown, by device.
#[derive(Default)]
struct Asking {
    questions: HashSet<u64>,
    showing: HashMap<String, u64>,
}

impl Asking {
    /// All that is open, which is then no more.
    fn all(&mut self) -> Vec<u64> {
        let showing: Vec<u64> = self.showing.drain().map(|(_, id)| id).collect();
        self.questions.drain().chain(showing).collect()
    }
}

static ASKING: LazyLock<Mutex<Asking>> = LazyLock::new(Default::default);

#[derive(DBusError, Debug)]
#[zbus(prefix = "org.bluez.Error")]
pub enum BluezError {
    #[zbus(error)]
    ZBus(zbus::Error),
    Rejected(String),
}

/// A question about pairing, which the person may cancel.
fn pairing_question(mut question: Value) -> Value {
    question["kind"] = "pairing".into();
    question["icon"] = "bluetooth".into();
    question["deny"] = "Cancel".into();
    question
}

/// A code to type on the device.
fn code_question(name: &str, code: &str) -> Value {
    pairing_question(json!({"title": format!("Pair with {name}"),
                            "subtitle": "Type this code on the device, then Enter.", "code": code}))
}

/// A passkey as the device shows it: six digits.
fn code(passkey: u32) -> String {
    format!("{passkey:06}")
}

/// The digits typed, at most six.
fn passkey(typed: &str) -> u32 {
    typed
        .chars()
        .filter(char::is_ascii_digit)
        .take(6)
        .collect::<String>()
        .parse()
        .unwrap_or(0)
}

/// Asks; the answer if granted, otherwise BlueZ is told the person refused.
async fn confirm(question: Value) -> Result<Value, BluezError> {
    let (id, answer) = shell::ask(pairing_question(question));
    lock(&ASKING).questions.insert(id);
    let answer = answer.recv().await.ok().flatten();
    lock(&ASKING).questions.remove(&id);
    answer.ok_or_else(|| BluezError::Rejected("The person refused".into()))
}

/// Shows a code to type on the device until pairing ends; the person's
/// Cancel cancels it.
async fn show(device: OwnedObjectPath, code: String) {
    let name = device_name(&device).await;
    if lock(&ASKING).showing.contains_key(device.as_str()) {
        return;
    }
    let (id, answer) = shell::ask(code_question(&name, &code));
    lock(&ASKING).showing.insert(device.to_string(), id);
    spawn(async move {
        // Answered, not withdrawn.
        if answer.recv().await.is_ok() {
            lock(&ASKING).showing.remove(device.as_str());
            if let Ok(device) = proxy::<DeviceProxy>(&device).await {
                let _ = timed(CALL_TIME, device.cancel_pairing()).await;
            }
        }
    });
}

/// BlueZ gave up on what it asked.
fn withdraw_all() {
    let ids = lock(&ASKING).all();
    for id in ids {
        shell::withdraw(id);
    }
}

pub struct Agent;

#[interface(name = "org.bluez.Agent1")]
impl Agent {
    async fn release(&self) {
        withdraw_all();
    }

    async fn request_pin_code(&self, device: OwnedObjectPath) -> Result<String, BluezError> {
        let name = device_name(&device).await;
        let answer = confirm(json!({"title": format!("PIN for {name}"),
                                    "subtitle": "Type the PIN the device shows or came with.",
                                    "fields": [{"id": "pin", "label": "PIN"}], "grant": "Pair"}))
        .await?;
        Ok(answer["fields"]["pin"].as_str().unwrap_or_default().to_string())
    }

    async fn display_pin_code(&self, device: OwnedObjectPath, pincode: String) {
        show(device, pincode).await;
    }

    async fn request_passkey(&self, device: OwnedObjectPath) -> Result<u32, BluezError> {
        let name = device_name(&device).await;
        let answer = confirm(json!({"title": format!("Passkey for {name}"),
                                    "subtitle": "Type the six digits the device shows.",
                                    "fields": [{"id": "passkey", "label": "Passkey"}], "grant": "Pair"}))
        .await?;
        Ok(passkey(answer["fields"]["passkey"].as_str().unwrap_or_default()))
    }

    async fn display_passkey(&self, device: OwnedObjectPath, passkey: u32, _entered: u16) {
        show(device, code(passkey)).await;
    }

    async fn request_confirmation(&self, device: OwnedObjectPath, passkey: u32) -> Result<(), BluezError> {
        let name = device_name(&device).await;
        confirm(
            json!({"title": format!("Pair with {name}?"), "subtitle": "Check that it shows the same code.",
                       "code": code(passkey), "grant": "Pair"}),
        )
        .await
        .map(drop)
    }

    async fn request_authorization(&self, device: OwnedObjectPath) -> Result<(), BluezError> {
        let name = device_name(&device).await;
        confirm(json!({"title": format!("Pair with {name}?"), "grant": "Pair"}))
            .await
            .map(drop)
    }

    /// Paired devices may use their services; BlueZ asks only for those not
    /// trusted.
    async fn authorize_service(&self, device: OwnedObjectPath, _uuid: String) -> Result<(), BluezError> {
        let paired = match proxy::<DeviceProxy>(&device).await {
            Ok(device) => timed(PROPERTY_TIME, device.paired()).await,
            Err(failed) => Err(failed),
        };
        match paired {
            Ok(true) => Ok(()),
            _ => Err(BluezError::Rejected("Not paired".into())),
        }
    }

    async fn cancel(&self) {
        withdraw_all();
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn failed(name: &str, reason: &str) -> Failed {
        Failed {
            name: name.into(),
            reason: reason.into(),
        }
    }

    #[test]
    fn a_device_paired_already_is_paired_and_a_refusal_failed() {
        assert_eq!(paired(Ok(())), Ok(()));
        assert_eq!(
            paired(Err(failed("org.bluez.Error.AlreadyExists", "Already Exists"))),
            Ok(())
        );
        let refused = failed("org.bluez.Error.AuthenticationFailed", "Authentication Failed");
        assert_eq!(paired(Err(refused)), Err("Pairing failed".into()));
        assert_eq!(paired(Err(failed("", "Timed out"))), Err("Timed out".into()));
    }

    #[test]
    fn pairing_questions_may_be_cancelled() {
        let question = pairing_question(json!({"title": "Pair with Headphones?", "grant": "Pair"}));
        assert_eq!(
            question,
            json!({"title": "Pair with Headphones?", "grant": "Pair", "kind": "pairing", "icon": "bluetooth",
                   "deny": "Cancel"})
        );
    }

    #[test]
    fn a_code_to_type_shows_six_digits() {
        let question = code_question("Keyboard", &code(4321));
        assert_eq!(
            (question["title"].as_str(), question["code"].as_str()),
            (Some("Pair with Keyboard"), Some("004321"))
        );
        assert_eq!(question["kind"], "pairing");
        assert!(question.get("grant").is_none());
    }

    #[test]
    fn a_passkey_is_the_first_six_digits_typed() {
        assert_eq!(passkey("12 34 56 78"), 123456);
        assert_eq!(passkey("007"), 7);
        assert_eq!(passkey("none"), 0);
    }

    #[test]
    fn bluez_giving_up_withdraws_its_questions_and_codes_shown() {
        let mut asking = Asking::default();
        asking.questions.insert(1);
        asking.showing.insert("/org/bluez/hci0/dev_AA".into(), 2);
        let mut all = asking.all();
        all.sort();
        assert_eq!(all, [1, 2]);
        assert!(asking.all().is_empty());
    }
}
