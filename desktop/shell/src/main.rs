mod app;
mod application_catalog;
#[cfg(feature = "smoke-test")]
mod dev_smoke;
mod presentation;
mod protocol;
mod ui;

use gtk::{Application, gio, glib, prelude::*};

const APPLICATION_ID: &str = "software.shapebit.Shell";

fn main() -> glib::ExitCode {
    let application = Application::builder()
        .application_id(APPLICATION_ID)
        .flags(gio::ApplicationFlags::NON_UNIQUE)
        .build();
    application.connect_activate(app::build);
    application.run()
}
