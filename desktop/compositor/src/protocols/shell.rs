use protocol::server::{
    shapebit_bar_v1::{self, ShapebitBarV1},
    shapebit_overview_v1::{self, ShapebitOverviewV1},
    shapebit_shell_manager_v1::{self, ShapebitShellManagerV1},
};
use smithay::reexports::wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource,
    backend::{ClientId, GlobalId, ObjectId},
    protocol::wl_surface::WlSurface,
};

use super::toplevel::ToplevelData;
use crate::state::{ClientState, Compositor, RegisterBarError, RegisterOverviewError};
use smithay::utils::Rectangle;

pub struct ShellState {
    _global: GlobalId,
    manager_id: Option<ObjectId>,
    ready: bool,
}

impl ShellState {
    pub fn new(display: &DisplayHandle) -> Self {
        let global = display.create_global::<Compositor, ShapebitShellManagerV1, _>(1, ());
        Self {
            _global: global,
            manager_id: None,
            ready: false,
        }
    }

    fn bind_manager(&mut self, manager: &ShapebitShellManagerV1) -> bool {
        if self.manager_id.is_some() {
            return false;
        }
        self.manager_id = Some(manager.id());
        self.ready = false;
        true
    }

    fn set_ready(&mut self) -> bool {
        if self.ready {
            return false;
        }
        self.ready = true;
        true
    }

    pub fn mark_unavailable(&mut self) -> bool {
        std::mem::replace(&mut self.ready, false)
    }

    fn unbind_manager(&mut self, manager: &ShapebitShellManagerV1) -> bool {
        if self.manager_id.as_ref() != Some(&manager.id()) {
            return false;
        }
        self.manager_id = None;
        self.mark_unavailable();
        true
    }
}

#[derive(Debug)]
pub struct BarData {
    surface: WlSurface,
}

#[derive(Debug)]
pub struct OverviewData {
    surface: WlSurface,
}

impl GlobalDispatch<ShapebitShellManagerV1, ()> for Compositor {
    fn bind(
        state: &mut Self,
        _handle: &DisplayHandle,
        _client: &Client,
        resource: New<ShapebitShellManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        let manager = data_init.init(resource, ());
        if state.shell_state.bind_manager(&manager) {
            tracing::info!("bound shell manager; shell unavailable pending ready");
        } else {
            manager.post_error(
                shapebit_shell_manager_v1::Error::AlreadyBound,
                "a shell manager is already bound",
            );
        }
    }

    fn can_view(client: Client, _global_data: &()) -> bool {
        client
            .get_data::<ClientState>()
            .is_some_and(ClientState::is_shell)
    }
}

impl Dispatch<ShapebitShellManagerV1, ()> for Compositor {
    fn request(
        state: &mut Self,
        client: &Client,
        manager: &ShapebitShellManagerV1,
        request: shapebit_shell_manager_v1::Request,
        _data: &(),
        _handle: &DisplayHandle,
        data_init: &mut DataInit<'_, Self>,
    ) {
        if !client
            .get_data::<ClientState>()
            .is_some_and(ClientState::is_shell)
        {
            manager.post_error(
                shapebit_shell_manager_v1::Error::InvalidSurface,
                "only the authenticated shell may use this interface",
            );
            return;
        }

        match request {
            shapebit_shell_manager_v1::Request::CreateBar {
                id,
                surface,
                output,
            } => match state.register_bar(surface.clone(), output) {
                Ok(()) => {
                    data_init.init(id, BarData { surface });
                    tracing::info!("registered shell bar policy");
                }
                Err(RegisterBarError::AlreadyHasBar) => manager.post_error(
                    shapebit_shell_manager_v1::Error::AlreadyHasBar,
                    "the output already has a shell bar",
                ),
                Err(RegisterBarError::InvalidOutput) => manager.post_error(
                    shapebit_shell_manager_v1::Error::InvalidOutput,
                    "the requested output is not managed by this compositor",
                ),
            },
            shapebit_shell_manager_v1::Request::CreateOverview {
                id,
                surface,
                output,
            } => match state.register_overview(surface.clone(), output) {
                Ok(()) => {
                    data_init.init(id, OverviewData { surface });
                    tracing::info!("registered shell Overview policy");
                }
                Err(RegisterOverviewError::AlreadyHasOverview) => manager.post_error(
                    shapebit_shell_manager_v1::Error::AlreadyHasOverview,
                    "the output already has a shell Overview",
                ),
                Err(RegisterOverviewError::InvalidOutput) => manager.post_error(
                    shapebit_shell_manager_v1::Error::InvalidOutput,
                    "the requested output is not managed by this compositor",
                ),
            },
            shapebit_shell_manager_v1::Request::Ready => {
                if !state.required_shell_roles_registered() {
                    manager.post_error(
                        shapebit_shell_manager_v1::Error::MissingRequiredSurface,
                        "the bar and Overview must exist before the shell becomes ready",
                    );
                } else if !state.shell_state.set_ready() {
                    manager.post_error(
                        shapebit_shell_manager_v1::Error::AlreadyReady,
                        "the shell has already declared readiness",
                    );
                } else {
                    tracing::info!("shell became ready after initial snapshot barrier");
                }
            }
            shapebit_shell_manager_v1::Request::Destroy => {}
            _ => unreachable!("version 1 requests are exhaustively handled"),
        }
    }

    fn destroyed(
        state: &mut Self,
        _client_id: ClientId,
        resource: &ShapebitShellManagerV1,
        _data: &(),
    ) {
        if state.shell_state.unbind_manager(resource) {
            state.clear_shell_roles();
            tracing::info!("unbound shell manager; shell unavailable");
        }
    }
}

impl Dispatch<ShapebitOverviewV1, OverviewData> for Compositor {
    fn request(
        state: &mut Self,
        _client: &Client,
        _overview: &ShapebitOverviewV1,
        request: shapebit_overview_v1::Request,
        data: &OverviewData,
        _handle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            shapebit_overview_v1::Request::Show => state.show_overview(&data.surface),
            shapebit_overview_v1::Request::Hide => state.hide_overview(&data.surface),
            shapebit_overview_v1::Request::ClearWindowPreviews => {
                state.clear_overview_previews(&data.surface);
            }
            shapebit_overview_v1::Request::SetWindowPreview {
                toplevel,
                x,
                y,
                width,
                height,
            } => {
                if let Some(toplevel_data) = toplevel.data::<ToplevelData>() {
                    state.set_overview_preview(
                        &data.surface,
                        toplevel_data.surface.clone(),
                        Rectangle::new((x, y).into(), (width, height).into()),
                    );
                }
            }
            shapebit_overview_v1::Request::Destroy => state.unregister_overview(&data.surface),
            _ => unreachable!("version 1 requests are exhaustively handled"),
        }
    }

    fn destroyed(
        state: &mut Self,
        _client: smithay::reexports::wayland_server::backend::ClientId,
        _resource: &ShapebitOverviewV1,
        data: &OverviewData,
    ) {
        state.unregister_overview(&data.surface);
    }
}

impl Dispatch<ShapebitBarV1, BarData> for Compositor {
    fn request(
        state: &mut Self,
        _client: &Client,
        _bar: &ShapebitBarV1,
        request: shapebit_bar_v1::Request,
        data: &BarData,
        _handle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            shapebit_bar_v1::Request::Destroy => state.unregister_bar(&data.surface),
            _ => unreachable!("version 1 requests are exhaustively handled"),
        }
    }

    fn destroyed(
        state: &mut Self,
        _client: smithay::reexports::wayland_server::backend::ClientId,
        _resource: &ShapebitBarV1,
        data: &BarData,
    ) {
        state.unregister_bar(&data.surface);
    }
}
