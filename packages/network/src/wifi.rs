//! Wi-Fi: joining a network through NetworkManager, and its secret agent,
//! which asks for a network's password again when it does not work or was
//! never kept.

use std::collections::HashMap;
use std::sync::{LazyLock, Mutex};

use futures_lite::StreamExt;
use serde_json::{Value, json};
use zbus::{DBusError, OwnedObjectPath, OwnedVariant, Variant, interface, proxy};

use crate::bus::{CALL_TIME, PROPERTY_TIME, proxy, timed};
use crate::lock;
use crate::shell::{self, tell};

pub const SERVICE: &str = "org.freedesktop.NetworkManager";
pub const AGENT_PATH: &str = "/org/freedesktop/NetworkManager/SecretAgent";
const MANAGER_PATH: &str = "/org/freedesktop/NetworkManager";

// NetworkManager's secret flags, its access point security flags, and the
// states of an active connection.
const ALLOW_INTERACTION: u32 = 0x1;
const REQUEST_NEW: u32 = 0x2;
const AP_PRIVACY: u32 = 0x1;
const KEY_MGMT_PSK: u32 = 0x100;
const KEY_MGMT_802_1X: u32 = 0x200;
const KEY_MGMT_SAE: u32 = 0x400;
const ACTIVATED: u32 = 2;
const DEACTIVATED: u32 = 4;
const WIFI: u32 = 2;

/// A connection's settings, a{sa{sv}}.
type Settings = HashMap<String, HashMap<String, OwnedVariant>>;
/// Settings to send, by setting and key.
type NewSettings = HashMap<&'static str, HashMap<&'static str, Variant<'static>>>;

#[proxy(
    interface = "org.freedesktop.NetworkManager",
    default_service = "org.freedesktop.NetworkManager"
)]
trait NetworkManager {
    fn get_devices(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
    fn add_and_activate_connection(
        &self,
        connection: &NewSettings,
        device: &OwnedObjectPath,
        specific_object: &OwnedObjectPath,
    ) -> zbus::Result<(OwnedObjectPath, OwnedObjectPath)>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Device",
    default_service = "org.freedesktop.NetworkManager"
)]
trait Device {
    #[zbus(property(emits_changed_signal = "false"))]
    fn device_type(&self) -> zbus::Result<u32>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Device.Wireless",
    default_service = "org.freedesktop.NetworkManager"
)]
trait Wireless {
    #[zbus(property(emits_changed_signal = "false"))]
    fn access_points(&self) -> zbus::Result<Vec<OwnedObjectPath>>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.AccessPoint",
    default_service = "org.freedesktop.NetworkManager"
)]
trait AccessPoint {
    #[zbus(property(emits_changed_signal = "false"))]
    fn ssid(&self) -> zbus::Result<Vec<u8>>;
    #[zbus(property(emits_changed_signal = "false"))]
    fn strength(&self) -> zbus::Result<u8>;
    #[zbus(property(emits_changed_signal = "false"))]
    fn flags(&self) -> zbus::Result<u32>;
    #[zbus(property(emits_changed_signal = "false"))]
    fn wpa_flags(&self) -> zbus::Result<u32>;
    #[zbus(property(emits_changed_signal = "false"))]
    fn rsn_flags(&self) -> zbus::Result<u32>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Connection.Active",
    default_service = "org.freedesktop.NetworkManager"
)]
trait ActiveConnection {
    #[zbus(property(emits_changed_signal = "false"))]
    fn state(&self) -> zbus::Result<u32>;
    #[zbus(signal)]
    fn state_changed(&self, state: u32, reason: u32) -> zbus::Result<()>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Settings.Connection",
    default_service = "org.freedesktop.NetworkManager"
)]
trait Connection {
    fn delete(&self) -> zbus::Result<()>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.AgentManager",
    default_service = "org.freedesktop.NetworkManager"
)]
trait AgentManager {
    fn register_with_capabilities(&self, identifier: &str, capabilities: u32) -> zbus::Result<()>;
}

/// Makes this agent NetworkManager's secret agent.
pub async fn register() {
    if let Ok(manager) = proxy::<AgentManagerProxy>(&format!("{MANAGER_PATH}/AgentManager")).await {
        let _ = timed(
            CALL_TIME,
            manager.register_with_capabilities("desktop.connection-agent", 0),
        )
        .await;
    }
}

/// Joins a network with its password, and tells the shell what came of it.
pub async fn join(ssid: String, password: String) {
    tell(&shell::event("join", &ssid, connect(&ssid, &password).await));
}

/// A new connection to the network's strongest access point, which goes if
/// it does not come up, so a wrong password is not kept.
async fn connect(ssid: &str, password: &str) -> Result<(), String> {
    let (device, point) = strongest(access_points(ssid).await).ok_or("Network not found")?;
    let flags = proxy::<AccessPointProxy>(&point).await?;
    let security = security(
        timed(PROPERTY_TIME, flags.flags()).await.unwrap_or(0),
        timed(PROPERTY_TIME, flags.wpa_flags()).await.unwrap_or(0),
        timed(PROPERTY_TIME, flags.rsn_flags()).await.unwrap_or(0),
        password,
    )?;
    let manager = proxy::<NetworkManagerProxy>(MANAGER_PATH).await?;
    let settings = new_connection(ssid, security);
    let added = manager.add_and_activate_connection(&settings, &device, &point);
    let (connection, active) = timed(CALL_TIME, added).await?;
    let activated = activation(&active).await;
    if activated.is_err()
        && let Ok(connection) = proxy::<ConnectionProxy>(&connection).await
    {
        let _ = timed(CALL_TIME, connection.delete()).await;
    }
    activated.map_err(|reason| why_not(reason).to_string())
}

/// The Wi-Fi devices' access points of the network: strength, device, point.
async fn access_points(ssid: &str) -> Vec<(u8, OwnedObjectPath, OwnedObjectPath)> {
    let Ok(manager) = proxy::<NetworkManagerProxy>(MANAGER_PATH).await else {
        return Vec::new();
    };
    let devices = timed(PROPERTY_TIME, manager.get_devices()).await.unwrap_or_default();
    let mut found = Vec::new();
    for device in devices {
        let Ok(kind) = proxy::<DeviceProxy>(&device).await else {
            continue;
        };
        if timed(PROPERTY_TIME, kind.device_type()).await != Ok(WIFI) {
            continue;
        }
        let Ok(wireless) = proxy::<WirelessProxy>(&device).await else {
            continue;
        };
        for point in timed(PROPERTY_TIME, wireless.access_points()).await.unwrap_or_default() {
            let Ok(access_point) = proxy::<AccessPointProxy>(&point).await else {
                continue;
            };
            let name = timed(PROPERTY_TIME, access_point.ssid()).await.unwrap_or_default();
            if String::from_utf8_lossy(&name) == ssid {
                let strength = timed(PROPERTY_TIME, access_point.strength()).await.unwrap_or(0);
                found.push((strength, device.clone(), point));
            }
        }
    }
    found
}

/// The device and access point of the strongest; of equals, the last by path.
fn strongest(found: Vec<(u8, OwnedObjectPath, OwnedObjectPath)>) -> Option<(OwnedObjectPath, OwnedObjectPath)> {
    found
        .into_iter()
        .max_by(|a, b| (a.0, a.1.as_str(), a.2.as_str()).cmp(&(b.0, b.1.as_str(), b.2.as_str())))
        .map(|(_, device, point)| (device, point))
}

/// The security settings of an access point with these flags, or why it
/// cannot be joined.
fn security(
    flags: u32,
    wpa: u32,
    rsn: u32,
    password: &str,
) -> Result<HashMap<&'static str, Variant<'static>>, &'static str> {
    let password = || Variant::from(password.to_string());
    Ok(if (rsn | wpa) & KEY_MGMT_PSK != 0 {
        HashMap::from([("key-mgmt", "wpa-psk".into()), ("psk", password())])
    } else if rsn & KEY_MGMT_SAE != 0 {
        HashMap::from([("key-mgmt", "sae".into()), ("psk", password())])
    } else if (rsn | wpa) & KEY_MGMT_802_1X != 0 {
        return Err("Enterprise networks are not supported yet");
    } else if flags & AP_PRIVACY != 0 {
        HashMap::from([
            ("key-mgmt", "none".into()),
            ("wep-key0", password()),
            ("wep-key-type", Variant::from(2u32)),
        ])
    } else {
        HashMap::new()
    })
}

/// The settings of a new connection to the network.
fn new_connection(ssid: &str, security: HashMap<&'static str, Variant<'static>>) -> NewSettings {
    let mut settings: NewSettings = HashMap::from([
        (
            "connection",
            HashMap::from([
                ("type", "802-11-wireless".into()),
                ("id", Variant::from(ssid.to_string())),
            ]),
        ),
        (
            "802-11-wireless",
            HashMap::from([
                ("ssid", Variant::from(ssid.as_bytes().to_vec())),
                ("mode", "infrastructure".into()),
            ]),
        ),
    ]);
    if !security.is_empty() {
        settings.insert("802-11-wireless-security", security);
    }
    settings
}

/// Whether the active connection came up; if not, NetworkManager's reason.
async fn activation(path: &OwnedObjectPath) -> Result<(), u32> {
    let active = proxy::<ActiveConnectionProxy>(path).await.map_err(|_| 0u32)?;
    // Listening first, so that no change is missed.
    let mut changes = active.receive_state_changed().await.ok();
    let mut outcome = match timed(PROPERTY_TIME, active.state()).await {
        Ok(state) => settled(state, 0),
        Err(_) => Some(Err(0)),
    };
    loop {
        if let Some(outcome) = outcome {
            return outcome;
        }
        let change = match changes.as_mut() {
            Some(changes) => changes.next().await,
            None => None,
        };
        let Some(change) = change else { return Err(0) };
        outcome = change
            .args()
            .ok()
            .and_then(|args| settled(*args.state(), *args.reason()));
    }
}

/// Whether a connection in this state came up, or why it went down; None
/// while it is on its way.
fn settled(state: u32, reason: u32) -> Option<Result<(), u32>> {
    match state {
        ACTIVATED => Some(Ok(())),
        DEACTIVATED => Some(Err(reason)),
        _ => None,
    }
}

/// Why an activation failed, as the person reads it.
fn why_not(reason: u32) -> &'static str {
    match reason {
        9 | 10 => "Wrong password",
        5 => "Network not found",
        6 => "Timed out",
        _ => "Could not connect",
    }
}

#[derive(DBusError, Debug)]
#[zbus(prefix = "org.freedesktop.NetworkManager.SecretAgent")]
pub enum SecretAgentError {
    #[zbus(error)]
    ZBus(zbus::Error),
    NoSecrets(String),
    UserCanceled(String),
}

/// NetworkManager's open questions, by connection path and setting.
static ASKING: LazyLock<Mutex<HashMap<(String, String), u64>>> = LazyLock::new(Default::default);

pub struct SecretAgent;

#[interface(name = "org.freedesktop.NetworkManager.SecretAgent")]
impl SecretAgent {
    async fn get_secrets(
        &self,
        connection: Settings,
        connection_path: OwnedObjectPath,
        setting_name: String,
        _hints: Vec<String>,
        flags: u32,
    ) -> Result<HashMap<String, HashMap<String, Variant<'static>>>, SecretAgentError> {
        if !asks(&setting_name, flags) {
            return Err(SecretAgentError::NoSecrets("Nothing to ask".into()));
        }
        let enterprise = setting_name == "802-1x";
        let identity = text(&connection, "802-1x", "identity").unwrap_or_default();
        let question = secret_question(&network_name(&connection), enterprise, &identity, flags);
        let (id, answer) = shell::ask(question);
        let key = (connection_path.to_string(), setting_name.clone());
        lock(&ASKING).insert(key.clone(), id);
        let answer = answer.recv().await.ok().flatten();
        shell::forget(&mut lock(&ASKING), &key, id);
        let answer = answer.ok_or_else(|| SecretAgentError::UserCanceled("The person cancelled".into()))?;
        Ok(secrets(setting_name, &connection, &answer))
    }

    async fn cancel_get_secrets(&self, connection_path: OwnedObjectPath, setting_name: String) {
        let id = lock(&ASKING).get(&(connection_path.to_string(), setting_name)).copied();
        if let Some(id) = id {
            shell::withdraw(id);
        }
    }

    async fn save_secrets(&self, _connection: Settings, _connection_path: OwnedObjectPath) {}

    async fn delete_secrets(&self, _connection: Settings, _connection_path: OwnedObjectPath) {}
}

/// Whether NetworkManager's request is one to ask the person: a Wi-Fi
/// network's password, when it may ask.
fn asks(setting: &str, flags: u32) -> bool {
    flags & ALLOW_INTERACTION != 0 && matches!(setting, "802-1x" | "802-11-wireless-security")
}

/// The network's name: its SSID, or else the connection's.
fn network_name(settings: &Settings) -> String {
    bytes(settings, "802-11-wireless", "ssid")
        .map(|ssid| String::from_utf8_lossy(&ssid).into_owned())
        .filter(|ssid| !ssid.is_empty())
        .or_else(|| text(settings, "connection", "id"))
        .unwrap_or_default()
}

fn secret_question(ssid: &str, enterprise: bool, identity: &str, flags: u32) -> Value {
    let fields = if enterprise {
        json!([{"id": "identity", "label": "User name", "value": identity},
               {"id": "password", "label": "Password", "secret": true}])
    } else {
        json!([{"id": "password", "label": "Password", "secret": true}])
    };
    let subtitle = if flags & REQUEST_NEW != 0 {
        "The password did not work. Type it again."
    } else {
        "The network needs its password."
    };
    json!({
        "kind": "secret",
        "icon": "network-wireless",
        "title": format!("Password for “{ssid}”"),
        "subtitle": subtitle,
        "fields": fields,
        "grant": "Join",
        "deny": "Cancel",
    })
}

/// The secrets the person typed, as the connection's setting takes them.
fn secrets(setting: String, settings: &Settings, answer: &Value) -> HashMap<String, HashMap<String, Variant<'static>>> {
    let typed = |field: &str| answer["fields"][field].as_str().unwrap_or_default().to_string();
    let wep = text(settings, "802-11-wireless-security", "key-mgmt").as_deref() == Some("none");
    let secrets: Vec<(&str, String)> = if setting == "802-1x" {
        vec![("identity", typed("identity")), ("password", typed("password"))]
    } else if wep {
        vec![("wep-key0", typed("password"))]
    } else {
        vec![("psk", typed("password"))]
    };
    let secrets = secrets
        .into_iter()
        .map(|(key, value)| (key.to_string(), Variant::from(value)))
        .collect();
    HashMap::from([(setting, secrets)])
}

fn setting<'s>(settings: &'s Settings, group: &str, key: &str) -> Option<&'s OwnedVariant> {
    settings.get(group)?.get(key)
}

fn text(settings: &Settings, group: &str, key: &str) -> Option<String> {
    String::try_from(&**setting(settings, group, key)?).ok()
}

fn bytes(settings: &Settings, group: &str, key: &str) -> Option<Vec<u8>> {
    Vec::try_from(setting(settings, group, key)?.try_clone().ok()?).ok()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn path(path: &str) -> OwnedObjectPath {
        OwnedObjectPath::try_from(path).unwrap()
    }

    fn settings(values: &[(&str, &str, Variant<'static>)]) -> Settings {
        let mut settings = Settings::new();
        for (group, key, value) in values {
            let value = OwnedVariant::try_from(value.clone()).unwrap();
            settings
                .entry(group.to_string())
                .or_default()
                .insert(key.to_string(), value);
        }
        settings
    }

    #[test]
    fn the_strongest_access_point_is_joined() {
        let found = vec![
            (40, path("/devices/wifi"), path("/points/1")),
            (80, path("/devices/wifi"), path("/points/2")),
            (80, path("/devices/wifi"), path("/points/0")),
        ];
        assert_eq!(strongest(found), Some((path("/devices/wifi"), path("/points/2"))));
        assert_eq!(strongest(Vec::new()), None);
    }

    #[test]
    fn wpa_and_wpa3_networks_take_the_password_as_their_key() {
        let psk = security(0, 0, KEY_MGMT_PSK, "secret").unwrap();
        assert_eq!(psk["key-mgmt"], Variant::from("wpa-psk"));
        assert_eq!(psk["psk"], Variant::from("secret"));
        assert_eq!(
            security(0, KEY_MGMT_PSK, 0, "x").unwrap()["key-mgmt"],
            Variant::from("wpa-psk")
        );
        assert_eq!(
            security(0, 0, KEY_MGMT_SAE, "x").unwrap()["key-mgmt"],
            Variant::from("sae")
        );
    }

    #[test]
    fn wep_networks_take_it_as_their_first_key() {
        let wep = security(AP_PRIVACY, 0, 0, "secret").unwrap();
        assert_eq!(wep["key-mgmt"], Variant::from("none"));
        assert_eq!(wep["wep-key0"], Variant::from("secret"));
        assert_eq!(wep["wep-key-type"], Variant::from(2u32));
    }

    #[test]
    fn open_networks_need_nothing_and_enterprise_ones_are_refused() {
        assert!(security(0, 0, 0, "").unwrap().is_empty());
        assert!(security(0, KEY_MGMT_802_1X, 0, "").is_err());
    }

    #[test]
    fn a_new_connection_has_security_settings_only_if_the_network_needs_them() {
        let open = new_connection("Cafe", HashMap::new());
        assert_eq!(open["802-11-wireless"]["ssid"], Variant::from(b"Cafe".to_vec()));
        assert_eq!(open["connection"]["id"], Variant::from("Cafe"));
        assert!(!open.contains_key("802-11-wireless-security"));
        let secured = new_connection("Home", security(0, 0, KEY_MGMT_PSK, "secret").unwrap());
        assert_eq!(secured["802-11-wireless-security"]["psk"], Variant::from("secret"));
    }

    #[test]
    fn a_connection_settles_when_it_is_up_or_down() {
        assert_eq!(settled(ACTIVATED, 0), Some(Ok(())));
        assert_eq!(settled(DEACTIVATED, 9), Some(Err(9)));
        assert_eq!(settled(1, 0), None);
    }

    #[test]
    fn failures_read_as_the_person_understands_them() {
        assert_eq!(why_not(9), "Wrong password");
        assert_eq!(why_not(10), "Wrong password");
        assert_eq!(why_not(5), "Network not found");
        assert_eq!(why_not(6), "Timed out");
        assert_eq!(why_not(0), "Could not connect");
    }

    #[test]
    fn only_wifi_passwords_are_asked_and_only_when_networkmanager_may_ask() {
        assert!(asks("802-11-wireless-security", ALLOW_INTERACTION));
        assert!(asks("802-1x", ALLOW_INTERACTION | REQUEST_NEW));
        assert!(!asks("802-11-wireless-security", 0));
        assert!(!asks("vpn", ALLOW_INTERACTION));
    }

    #[test]
    fn a_network_is_named_by_its_ssid_or_else_its_connection() {
        let ssid = settings(&[
            ("802-11-wireless", "ssid", Variant::from(b"Home".to_vec())),
            ("connection", "id", Variant::from("Home 2")),
        ]);
        assert_eq!(network_name(&ssid), "Home");
        assert_eq!(
            network_name(&settings(&[("connection", "id", Variant::from("Work"))])),
            "Work"
        );
    }

    #[test]
    fn enterprise_networks_ask_for_the_user_name_too() {
        let question = secret_question("Work", true, "me", REQUEST_NEW);
        assert_eq!(
            question["fields"][0],
            json!({"id": "identity", "label": "User name", "value": "me"})
        );
        assert_eq!(question["subtitle"], "The password did not work. Type it again.");
    }

    #[test]
    fn the_password_typed_goes_where_the_setting_takes_it() {
        let answer = json!({"fields": {"identity": "me", "password": "secret"}});
        let psk = secrets("802-11-wireless-security".into(), &Settings::new(), &answer);
        assert_eq!(
            psk["802-11-wireless-security"],
            HashMap::from([("psk".into(), Variant::from("secret"))])
        );
        let wep_network = settings(&[("802-11-wireless-security", "key-mgmt", Variant::from("none"))]);
        let wep = secrets("802-11-wireless-security".into(), &wep_network, &answer);
        assert_eq!(
            wep["802-11-wireless-security"],
            HashMap::from([("wep-key0".into(), Variant::from("secret"))])
        );
        let enterprise = secrets("802-1x".into(), &Settings::new(), &answer);
        assert_eq!(enterprise["802-1x"]["identity"], Variant::from("me"));
        assert_eq!(enterprise["802-1x"]["password"], Variant::from("secret"));
    }
}
