//! The shell's side: what it tells the agent, and the questions the agent
//! asks it.

use std::collections::HashMap;
use std::hash::Hash;
use std::io::Write;
use std::sync::{LazyLock, Mutex};

use async_channel::{Receiver, Sender};
use serde_json::{Map, Value, json};
use zbus::OwnedObjectPath;

use crate::lock;

/// What the shell answered: the answer if granted, None if dismissed; a
/// question withdrawn gets nothing, its sender dropped.
pub type Answer = Option<Value>;

/// What the shell tells the agent to do.
#[derive(Debug, PartialEq)]
pub enum Command {
    Join { ssid: String, password: String },
    Pair(OwnedObjectPath),
    Answer(u64, Answer),
}

/// The command of a line from the shell; None for a message it does not know.
pub fn read(line: &str) -> Result<Option<Command>, String> {
    let message: Value = serde_json::from_str(line).map_err(|e| e.to_string())?;
    let text = |key: &str| message.get(key).and_then(Value::as_str).map(str::to_string);
    Ok(Some(if let Some(id) = message.get("answer") {
        let id = id.as_u64().ok_or("answer: not an id")?;
        let granted = message.get("granted").and_then(Value::as_bool).unwrap_or(false);
        Command::Answer(id, granted.then(|| message.clone()))
    } else if message.get("join").is_some() {
        let ssid = text("join").ok_or("join: not a network name")?;
        Command::Join {
            ssid,
            password: text("password").unwrap_or_default(),
        }
    } else if message.get("pair").is_some() {
        let path = text("pair").ok_or("pair: not a device path")?;
        Command::Pair(OwnedObjectPath::try_from(path).map_err(|e| e.to_string())?)
    } else {
        return Ok(None);
    }))
}

/// The open questions.
#[derive(Default)]
struct Questions {
    last: u64,
    open: HashMap<u64, Sender<Answer>>,
}

impl Questions {
    /// A new question: its id, the message that asks it, and where its answer comes.
    fn ask(&mut self, question: Value) -> (u64, Value, Receiver<Answer>) {
        let (sender, receiver) = async_channel::bounded(1);
        self.last += 1;
        self.open.insert(self.last, sender);
        let mut message = Map::from_iter([("ask".to_string(), json!(self.last))]);
        if let Value::Object(fields) = question {
            message.extend(fields);
        }
        (self.last, Value::Object(message), receiver)
    }

    /// Gives an open question its answer; false if it is not open.
    fn answer(&mut self, id: u64, answer: Answer) -> bool {
        self.open
            .remove(&id)
            .is_some_and(|sender| sender.try_send(answer).is_ok())
    }

    /// Withdraws an open question: the message that tells the shell.
    fn withdraw(&mut self, id: u64) -> Option<Value> {
        self.open.remove(&id).map(|_| json!({"cancel": id}))
    }
}

static QUESTIONS: LazyLock<Mutex<Questions>> = LazyLock::new(Default::default);

pub fn tell(message: &Value) {
    let mut out = std::io::stdout().lock();
    // The shell may have gone; standard input's end says so.
    let _ = writeln!(out, "{message}").and_then(|_| out.flush());
}

/// Asks the shell; the receiver gets the answer.
pub fn ask(question: Value) -> (u64, Receiver<Answer>) {
    let (id, message, receiver) = lock(&QUESTIONS).ask(question);
    tell(&message);
    (id, receiver)
}

pub fn answer(id: u64, answer: Answer) {
    lock(&QUESTIONS).answer(id, answer);
}

pub fn withdraw(id: u64) {
    let message = lock(&QUESTIONS).withdraw(id);
    if let Some(message) = message {
        tell(&message);
    }
}

/// Forgets which question `key` asked, unless a newer one took its place.
pub fn forget<K: Eq + Hash>(asking: &mut HashMap<K, u64>, key: &K, id: u64) {
    if asking.get(key) == Some(&id) {
        asking.remove(key);
    }
}

/// What came of joining or pairing, for the shell.
pub fn event(kind: &str, target: &str, result: Result<(), String>) -> Value {
    let reason = result.err().unwrap_or_default();
    json!({"event": kind, "target": target, "ok": reason.is_empty(), "reason": reason})
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn joining_takes_the_network_and_its_password_if_any() {
        assert_eq!(
            read(r#"{"join": "Home", "password": "secret"}"#),
            Ok(Some(Command::Join {
                ssid: "Home".into(),
                password: "secret".into()
            }))
        );
        assert_eq!(
            read(r#"{"join": "Cafe"}"#),
            Ok(Some(Command::Join {
                ssid: "Cafe".into(),
                password: "".into()
            }))
        );
        assert!(read(r#"{"join": 1}"#).is_err());
    }

    #[test]
    fn pairing_takes_a_device_path() {
        assert_eq!(
            read(r#"{"pair": "/org/bluez/hci0/dev_AA"}"#),
            Ok(Some(Command::Pair(
                OwnedObjectPath::try_from("/org/bluez/hci0/dev_AA").unwrap()
            )))
        );
        assert!(read(r#"{"pair": "not a path"}"#).is_err());
    }

    #[test]
    fn an_answer_is_the_message_if_granted_and_nothing_if_dismissed() {
        let granted = r#"{"answer": 3, "granted": true, "fields": {"password": "x"}}"#;
        let Ok(Some(Command::Answer(3, Some(answer)))) = read(granted) else {
            panic!("not an answer")
        };
        assert_eq!(answer["fields"]["password"], "x");
        assert_eq!(read(r#"{"answer": 3}"#), Ok(Some(Command::Answer(3, None))));
        assert!(read(r#"{"answer": "three"}"#).is_err());
    }

    #[test]
    fn what_cannot_be_read_is_an_error_and_what_is_unknown_is_nothing() {
        assert!(read("not json").is_err());
        assert_eq!(read(r#"{"hello": true}"#), Ok(None));
    }

    #[test]
    fn each_question_has_its_own_id_in_the_message_that_asks_it() {
        let mut questions = Questions::default();
        let (first, message, _) = questions.ask(json!({"title": "Password"}));
        let (second, _, _) = questions.ask(json!({}));
        assert_ne!(first, second);
        assert_eq!(message, json!({"ask": first, "title": "Password"}));
    }

    #[test]
    fn an_answer_reaches_its_question_once() {
        let mut questions = Questions::default();
        let (id, _, answer) = questions.ask(json!({}));
        assert!(questions.answer(id, Some(json!("yes"))));
        assert!(!questions.answer(id, None));
        assert_eq!(answer.try_recv(), Ok(Some(json!("yes"))));
    }

    #[test]
    fn a_withdrawn_question_is_cancelled_and_gets_no_answer() {
        let mut questions = Questions::default();
        let (id, _, answer) = questions.ask(json!({}));
        assert_eq!(questions.withdraw(id), Some(json!({"cancel": id})));
        assert_eq!(questions.withdraw(id), None);
        assert!(!questions.answer(id, None));
        assert!(answer.try_recv().is_err() && answer.is_closed());
    }

    #[test]
    fn a_question_is_forgotten_only_if_no_newer_one_took_its_place() {
        let mut asking = HashMap::from([("key", 2)]);
        forget(&mut asking, &"key", 1);
        assert_eq!(asking.get("key"), Some(&2));
        forget(&mut asking, &"key", 2);
        assert!(asking.is_empty());
    }

    #[test]
    fn an_event_has_a_reason_only_if_it_failed() {
        assert_eq!(
            event("join", "Home", Ok(())),
            json!({"event": "join", "target": "Home", "ok": true, "reason": ""})
        );
        assert_eq!(
            event("pair", "/dev", Err("Timed out".into())),
            json!({"event": "pair", "target": "/dev", "ok": false, "reason": "Timed out"})
        );
    }
}
