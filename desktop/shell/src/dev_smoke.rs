use std::{cell::RefCell, rc::Rc, time::Duration};

use gtk::{glib, prelude::*};

use crate::{
    protocol::ShellSession,
    ui::{OverviewView, SystemBar},
};

pub fn configure(session: &Rc<RefCell<ShellSession>>, bar: &SystemBar, overview: &OverviewView) {
    if std::env::var_os("SHAPEBIT_WORKSPACE_SMOKE").is_none() {
        return;
    }

    configure_bar_allocation(bar);
    if std::env::var("SHAPEBIT_SHELL_GENERATION").as_deref() != Ok("1") {
        return;
    }

    configure_workspace_actions(session, bar);
    configure_overview_actions(bar, overview);
}

fn configure_bar_allocation(bar: &SystemBar) {
    let bar = bar.clone();
    glib::timeout_add_local_once(Duration::from_millis(300), move || {
        let visible_controls = [
            bar.widget.allocated_width(),
            bar.widget.allocated_height(),
            bar.overview.button_width(),
            bar.overview.button_height(),
            bar.workspace_controls.strip_width(),
            bar.workspace_controls.strip_height(),
            bar.clock.allocated_width(),
            bar.clock.allocated_height(),
        ]
        .into_iter()
        .all(|dimension| dimension > 0);
        eprintln!(
            "ShapeBit shell allocated bar controls generation={} visible_controls={visible_controls} bar={}x{}",
            generation(),
            bar.widget.allocated_width(),
            bar.widget.allocated_height()
        );
    });
}

fn configure_workspace_actions(session: &Rc<RefCell<ShellSession>>, bar: &SystemBar) {
    let session_for_create = Rc::downgrade(session);
    glib::timeout_add_local_once(Duration::from_millis(750), move || {
        if let Some(session) = session_for_create.upgrade()
            && let Err(error) = session.borrow().create_workspace_for_smoke()
        {
            eprintln!("failed to create the smoke-test Workspace: {error}");
        }
    });

    let controls_for_reorder = bar.workspace_controls.clone();
    glib::timeout_add_local_once(Duration::from_millis(1_600), move || {
        controls_for_reorder.reorder_last_workspace_to_start();
    });

    let session_for_transfer_out = Rc::downgrade(session);
    glib::timeout_add_local_once(Duration::from_millis(1_700), move || {
        if let Some(session) = session_for_transfer_out.upgrade()
            && let Err(error) = session.borrow().move_first_toplevel_for_smoke(false)
        {
            eprintln!("failed to move a smoke-test toplevel out: {error}");
        }
    });

    let session_for_transfer_back = Rc::downgrade(session);
    glib::timeout_add_local_once(Duration::from_millis(1_900), move || {
        if let Some(session) = session_for_transfer_back.upgrade()
            && let Err(error) = session.borrow().move_first_toplevel_for_smoke(true)
        {
            eprintln!("failed to move a smoke-test toplevel back: {error}");
        }
    });

    let controls_for_activation = bar.workspace_controls.clone();
    glib::timeout_add_local_once(Duration::from_millis(950), move || {
        controls_for_activation.click_first_application();
    });

    let controls_for_return = bar.workspace_controls.clone();
    glib::timeout_add_local_once(Duration::from_millis(1_200), move || {
        controls_for_return.click_first_application();
    });
}

fn configure_overview_actions(bar: &SystemBar, overview: &OverviewView) {
    let toggle_for_show = bar.overview.clone();
    glib::timeout_add_local_once(Duration::from_millis(350), move || {
        toggle_for_show.set_active(true);
    });

    let overview_for_allocation = overview.clone();
    glib::timeout_add_local_once(Duration::from_millis(500), move || {
        let visible_controls = [
            overview_for_allocation.surface.allocated_width(),
            overview_for_allocation.surface.allocated_height(),
            overview_for_allocation.controls.workspaces_width(),
            overview_for_allocation.controls.workspaces_height(),
        ]
        .into_iter()
        .all(|dimension| dimension > 0);
        eprintln!(
            "ShapeBit shell allocated Overview generation=1 visible_controls={visible_controls} surface={}x{}",
            overview_for_allocation.surface.allocated_width(),
            overview_for_allocation.surface.allocated_height()
        );
    });

    let launcher_for_allocation = overview.launcher.clone();
    glib::timeout_add_local_once(Duration::from_millis(510), move || {
        launcher_for_allocation.log_quick_apps_allocation();
    });

    let launcher_for_search = overview.launcher.clone();
    glib::timeout_add_local_once(Duration::from_millis(530), move || {
        launcher_for_search.search_for_smoke("terminal");
    });

    let launcher_for_search_reset = overview.launcher.clone();
    glib::timeout_add_local_once(Duration::from_millis(800), move || {
        launcher_for_search_reset.search_for_smoke("");
    });

    let toggle_for_hide = bar.overview.clone();
    glib::timeout_add_local_once(Duration::from_millis(650), move || {
        toggle_for_hide.set_active(false);
    });

    let toggle_for_selection = bar.overview.clone();
    glib::timeout_add_local_once(Duration::from_millis(1_050), move || {
        toggle_for_selection.set_active(true);
    });

    let controls_for_selection = overview.controls.clone();
    glib::timeout_add_local_once(Duration::from_millis(1_100), move || {
        controls_for_selection.select_next_workspace();
    });

    let controls_for_expansion = overview.controls.clone();
    glib::timeout_add_local_once(Duration::from_millis(1_130), move || {
        controls_for_expansion.log_selected_workspace_allocation();
    });

    let controls_for_activation = overview.controls.clone();
    glib::timeout_add_local_once(Duration::from_millis(1_150), move || {
        controls_for_activation.activate_selected_workspace();
    });

    let toggle_for_second_window = bar.overview.clone();
    glib::timeout_add_local_once(Duration::from_millis(1_250), move || {
        toggle_for_second_window.set_active(true);
    });

    let launcher_for_second_window = overview.launcher.clone();
    glib::timeout_add_local_once(Duration::from_millis(1_300), move || {
        launcher_for_second_window
            .launch_for_smoke("org.freedesktop.weston.wayland-terminal.desktop");
    });

    let toggle_for_third_window = bar.overview.clone();
    glib::timeout_add_local_once(Duration::from_millis(1_400), move || {
        toggle_for_third_window.set_active(true);
    });

    let launcher_for_third_window = overview.launcher.clone();
    glib::timeout_add_local_once(Duration::from_millis(1_450), move || {
        launcher_for_third_window
            .launch_for_smoke("org.freedesktop.weston.wayland-terminal.desktop");
    });
}

fn generation() -> String {
    std::env::var("SHAPEBIT_SHELL_GENERATION").unwrap_or_else(|_| "unknown".into())
}
