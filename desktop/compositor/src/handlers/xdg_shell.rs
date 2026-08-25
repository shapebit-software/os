use smithay::{
    desktop::{
        PopupKind, PopupManager, Space, Window, find_popup_root_surface, get_popup_toplevel_coords,
    },
    reexports::wayland_server::protocol::{wl_seat, wl_surface::WlSurface},
    utils::Serial,
    wayland::{
        compositor::with_states,
        shell::xdg::{
            PopupSurface, PositionerState, ToplevelSurface, XdgShellHandler, XdgShellState,
            XdgToplevelSurfaceData,
        },
    },
};

use crate::state::Compositor;

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
