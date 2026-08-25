use smithay::{
    desktop::{PopupKind, PopupManager, Space, find_popup_root_surface, get_popup_toplevel_coords},
    input::Seat,
    reexports::wayland_server::{
        Resource,
        protocol::{wl_seat, wl_surface::WlSurface},
    },
    utils::Serial,
    wayland::{
        compositor::with_states,
        shell::xdg::{
            PopupSurface, PositionerState, ToplevelSurface, XdgShellHandler, XdgShellState,
            XdgToplevelSurfaceData,
            decoration::XdgDecorationHandler,
        },
    },
};
use smithay::reexports::wayland_protocols::xdg::decoration::zv1::server::zxdg_toplevel_decoration_v1::Mode;

use crate::{
    state::{Compositor, Presentation},
    window::Window,
};

impl XdgShellHandler for Compositor {
    fn xdg_shell_state(&mut self) -> &mut XdgShellState {
        &mut self.xdg_shell_state
    }

    fn new_toplevel(&mut self, surface: ToplevelSurface) {
        self.add_toplevel(surface);
    }

    fn new_popup(&mut self, surface: PopupSurface, _positioner: PositionerState) {
        self.unconstrain_popup(&surface);
        if let Err(error) = self.popups.track_popup(PopupKind::Xdg(surface)) {
            tracing::warn!(%error, "failed to track xdg popup");
        }
    }

    fn toplevel_destroyed(&mut self, surface: ToplevelSurface) {
        self.remove_toplevel(&surface);
    }

    fn app_id_changed(&mut self, surface: ToplevelSurface) {
        self.update_toplevel_metadata(&surface);
    }

    fn title_changed(&mut self, surface: ToplevelSurface) {
        self.update_toplevel_metadata(&surface);
    }

    fn maximize_request(&mut self, surface: ToplevelSurface) {
        self.set_presentation(surface.wl_surface(), Presentation::Expanded);
    }

    fn unmaximize_request(&mut self, surface: ToplevelSurface) {
        self.set_presentation(surface.wl_surface(), Presentation::Normal);
    }

    fn fullscreen_request(
        &mut self,
        surface: ToplevelSurface,
        _output: Option<smithay::reexports::wayland_server::protocol::wl_output::WlOutput>,
    ) {
        self.set_presentation(surface.wl_surface(), Presentation::Fullscreen);
    }

    fn unfullscreen_request(&mut self, surface: ToplevelSurface) {
        self.set_presentation(surface.wl_surface(), Presentation::Normal);
    }

    fn move_request(&mut self, surface: ToplevelSurface, seat: wl_seat::WlSeat, serial: Serial) {
        let Some(seat): Option<Seat<Compositor>> = Seat::from_resource(&seat) else {
            return;
        };
        let Some(pointer) = seat.get_pointer() else {
            return;
        };
        if !pointer.has_grab(serial) {
            return;
        }
        let Some(start_data) = pointer.grab_start_data() else {
            return;
        };
        let Some((focus, _)) = start_data.focus.as_ref() else {
            return;
        };
        if !focus.id().same_client_as(&surface.wl_surface().id()) {
            return;
        }
        let Some(window) = self.window_for_surface(surface.wl_surface()) else {
            return;
        };
        self.begin_window_drag(window, start_data.location);
    }

    fn reposition_request(
        &mut self,
        surface: PopupSurface,
        positioner: PositionerState,
        token: u32,
    ) {
        surface.with_pending_state(|state| {
            state.geometry = positioner.get_geometry();
            state.positioner = positioner;
        });
        self.unconstrain_popup(&surface);
        surface.send_repositioned(token);
    }

    fn grab(&mut self, _surface: PopupSurface, _seat: wl_seat::WlSeat, _serial: Serial) {
        // Popup grabs require policy that is outside this foundation milestone.
    }
}

impl XdgDecorationHandler for Compositor {
    fn new_decoration(&mut self, toplevel: ToplevelSurface) {
        self.configure_server_decoration(toplevel);
    }

    fn request_mode(&mut self, toplevel: ToplevelSurface, _mode: Mode) {
        self.configure_server_decoration(toplevel);
    }

    fn unset_mode(&mut self, toplevel: ToplevelSurface) {
        self.configure_server_decoration(toplevel);
    }
}

impl Compositor {
    fn configure_server_decoration(&mut self, toplevel: ToplevelSurface) {
        self.mark_server_decorated(toplevel.wl_surface());
        toplevel.with_pending_state(|state| {
            state.decoration_mode = Some(Mode::ServerSide);
        });
        toplevel.send_configure();
        tracing::info!("configured compositor-owned window decoration");
    }
}

pub fn handle_commit(popups: &mut PopupManager, space: &Space<Window>, surface: &WlSurface) {
    if let Some(window) = space.elements().find(|window| {
        window
            .toplevel()
            .is_some_and(|toplevel| toplevel.wl_surface() == surface)
    }) {
        let initial_configure_sent = with_states(surface, |states| {
            states
                .data_map
                .get::<XdgToplevelSurfaceData>()
                .expect("xdg toplevel state exists")
                .lock()
                .expect("xdg toplevel state lock is not poisoned")
                .initial_configure_sent
        });
        if !initial_configure_sent {
            window
                .toplevel()
                .expect("matched window is an xdg toplevel")
                .send_configure();
        }
    }

    popups.commit(surface);
    if let Some(PopupKind::Xdg(popup)) = popups.find_popup(surface)
        && !popup.is_initial_configure_sent()
        && let Err(error) = popup.send_configure()
    {
        tracing::warn!(%error, "failed to send initial xdg popup configure");
    }
}

impl Compositor {
    fn unconstrain_popup(&self, popup: &PopupSurface) {
        let Ok(root) = find_popup_root_surface(&PopupKind::Xdg(popup.clone())) else {
            return;
        };
        let Some(window) = self.space.elements().find(|window| {
            window
                .toplevel()
                .is_some_and(|toplevel| toplevel.wl_surface() == &root)
        }) else {
            return;
        };
        let Some(output) = self.space.outputs().next() else {
            return;
        };
        let Some(mut target) = self.space.output_geometry(output) else {
            return;
        };
        let Some(window_geometry) = self.space.element_geometry(window) else {
            return;
        };
        target.loc -= get_popup_toplevel_coords(&PopupKind::Xdg(popup.clone()));
        target.loc -= window_geometry.loc;
        popup.with_pending_state(|state| {
            state.geometry = state.positioner.get_unconstrained_geometry(target);
        });
    }
}
