use std::{cell::RefCell, rc::Rc, time::Duration};

use gtk::{Application, CssProvider, gdk, glib, prelude::*};

use crate::{
    application_catalog::ApplicationCatalog,
    protocol::ShellSession,
    ui::{overview_surface, system_bar},
};

pub fn build(application: &Application) {
    install_styles();

    let window = gtk::ApplicationWindow::builder()
        .application(application)
        .title("ShapeBit Shell Prototype")
        .default_width(1280)
        .default_height(58)
        .decorated(false)
        .build();
    window.add_css_class("shell-window");

    let application_catalog = Rc::new(RefCell::new(ApplicationCatalog::load()));
    let bar = system_bar();
    let overview = overview_surface(application, &application_catalog.borrow());
    window.set_child(Some(&bar.widget));

    match ShellSession::register(
        &window,
        &overview.window,
        bar.workspace_controls.clone(),
        overview.controls.clone(),
        bar.overview.clone(),
        Rc::clone(&application_catalog),
        overview.launcher.clone(),
    ) {
        Ok(session) => {
            let session = Rc::new(RefCell::new(session));
            #[cfg(feature = "smoke-test")]
            crate::dev_smoke::configure(&session, &bar, &overview);
            let session_for_dispatch = Rc::downgrade(&session);
            glib::timeout_add_local(Duration::from_millis(16), move || {
                let Some(session) = session_for_dispatch.upgrade() else {
                    return glib::ControlFlow::Break;
                };
                if let Err(error) = session.borrow_mut().dispatch_pending() {
                    eprintln!("failed to dispatch a ShapeBit shell event: {error}");
                    return glib::ControlFlow::Break;
                }
                glib::ControlFlow::Continue
            });
            window.connect_close_request(move |_| {
                session.borrow_mut().close();
                glib::Propagation::Proceed
            });
        }
        Err(error) => {
            eprintln!("failed to register the ShapeBit shell: {error}");
            application.quit();
            return;
        }
    }
    overview.window.present();
    window.present();
}

fn install_styles() {
    let provider = CssProvider::new();
    provider.load_from_data(include_str!("ui/style.css"));
    let display = gdk::Display::default().expect("a graphical display must be available");
    gtk::style_context_add_provider_for_display(
        &display,
        &provider,
        gtk::STYLE_PROVIDER_PRIORITY_APPLICATION,
    );
}
