use protocol::server::{
    shapebit_toplevel_manager_v1::{self, ShapebitToplevelManagerV1},
    shapebit_toplevel_v1::{self, ShapebitToplevelV1},
};
use smithay::reexports::wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource, backend::GlobalId,
    protocol::wl_surface::WlSurface,
};

use crate::{
    protocols::workspace::WorkspaceData,
    state::{ClientState, Compositor},
};

#[derive(Clone, Debug)]
pub struct ToplevelSnapshot {
    pub surface: WlSurface,
    pub workspace_id: u32,
    pub title: String,
    pub app_id: String,
    pub active: bool,
}

pub struct ToplevelProtocolState {
    _global: GlobalId,
    managers: Vec<ShapebitToplevelManagerV1>,
    toplevels: Vec<(WlSurface, ShapebitToplevelV1)>,
}

impl ToplevelProtocolState {
    pub fn new(display: &DisplayHandle) -> Self {
        let global = display.create_global::<Compositor, ShapebitToplevelManagerV1, _>(1, ());
        Self {
            _global: global,
            managers: Vec::new(),
            toplevels: Vec::new(),
        }
    }

    fn announce(
        state: &mut Compositor,
        manager: &ShapebitToplevelManagerV1,
        client: &Client,
        snapshot: ToplevelSnapshot,
    ) {
        let Some(workspace) = state
            .workspace_protocol_state
            .resource_for_client(client, snapshot.workspace_id)
        else {
            tracing::warn!(
                workspace_id = snapshot.workspace_id,
                "cannot announce a toplevel before its Workspace object"
            );
            return;
        };
        let resource = match client.create_resource::<ShapebitToplevelV1, _, Compositor>(
            &state.display_handle,
            1,
            ToplevelData {
                surface: snapshot.surface.clone(),
            },
        ) {
            Ok(resource) => resource,
            Err(error) => {
                tracing::warn!(%error, "failed to announce toplevel");
                return;
            }
        };
        manager.toplevel(&resource);
        resource.title(snapshot.title);
        resource.app_id(snapshot.app_id);
        resource.workspace(&workspace);
        resource.active(u32::from(snapshot.active));
        state
            .toplevel_protocol_state
            .toplevels
            .push((snapshot.surface, resource));
    }

    pub fn announce_created(state: &mut Compositor, snapshot: ToplevelSnapshot) {
        state
            .toplevel_protocol_state
            .managers
            .retain(Resource::is_alive);
        let targets: Vec<_> = state
            .toplevel_protocol_state
            .managers
            .iter()
            .filter_map(|manager| manager.client().map(|client| (manager.clone(), client)))
            .collect();
        for (manager, client) in targets {
            Self::announce(state, &manager, &client, snapshot.clone());
        }
        tracing::info!(
            workspace_id = snapshot.workspace_id,
            app_id = %snapshot.app_id,
            title = %snapshot.title,
            "announced application toplevel"
        );
    }

    pub fn update_metadata(&mut self, surface: &WlSurface, title: &str, app_id: &str) {
        self.toplevels.retain(|(_, resource)| resource.is_alive());
        for (known_surface, resource) in &self.toplevels {
            if known_surface == surface {
                resource.title(title.to_owned());
                resource.app_id(app_id.to_owned());
            }
        }
    }

    pub fn broadcast_active(&mut self, active_surface: Option<&WlSurface>) {
        self.toplevels.retain(|(_, resource)| resource.is_alive());
        for (surface, resource) in &self.toplevels {
            resource.active(u32::from(active_surface == Some(surface)));
        }
    }

    pub fn broadcast_workspace(state: &mut Compositor, surface: &WlSurface, workspace_id: u32) {
        state
            .toplevel_protocol_state
            .toplevels
            .retain(|(_, resource)| resource.is_alive());
        let targets: Vec<_> = state
            .toplevel_protocol_state
            .toplevels
            .iter()
            .filter(|(known_surface, _)| known_surface == surface)
            .filter_map(|(_, resource)| resource.client().map(|client| (resource.clone(), client)))
            .collect();
        for (resource, client) in targets {
            let Some(workspace) = state
                .workspace_protocol_state
                .resource_for_client(&client, workspace_id)
            else {
                tracing::warn!(workspace_id, "cannot update toplevel Workspace association");
                continue;
            };
            resource.workspace(&workspace);
        }
    }

    pub fn remove(&mut self, surface: &WlSurface) {
        self.toplevels.retain(|(known_surface, resource)| {
            if known_surface == surface {
                if resource.is_alive() {
                    resource.closed();
                }
                false
            } else {
                resource.is_alive()
            }
        });
    }
}

#[derive(Debug)]
pub struct ToplevelData {
    pub(crate) surface: WlSurface,
}

impl GlobalDispatch<ShapebitToplevelManagerV1, ()> for Compositor {
    fn bind(
        state: &mut Self,
        _handle: &DisplayHandle,
        client: &Client,
        resource: New<ShapebitToplevelManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        let manager = data_init.init(resource, ());
        state.toplevel_protocol_state.managers.push(manager.clone());
        let snapshots = state.toplevel_snapshots();
        tracing::info!(toplevel_count = snapshots.len(), "sent toplevel snapshot");
        for snapshot in snapshots {
            ToplevelProtocolState::announce(state, &manager, client, snapshot);
        }
    }

    fn can_view(client: Client, _global_data: &()) -> bool {
        client
            .get_data::<ClientState>()
            .is_some_and(ClientState::is_shell)
    }
}

impl Dispatch<ShapebitToplevelManagerV1, ()> for Compositor {
    fn request(
        _state: &mut Self,
        _client: &Client,
        _manager: &ShapebitToplevelManagerV1,
        request: shapebit_toplevel_manager_v1::Request,
        _data: &(),
        _handle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        match request {
            shapebit_toplevel_manager_v1::Request::Destroy => {}
            _ => unreachable!("version 1 requests are exhaustively handled"),
        }
    }
}

impl Dispatch<ShapebitToplevelV1, ToplevelData> for Compositor {
    fn request(
        state: &mut Self,
        client: &Client,
        _toplevel: &ShapebitToplevelV1,
        request: shapebit_toplevel_v1::Request,
        data: &ToplevelData,
        _handle: &DisplayHandle,
        _data_init: &mut DataInit<'_, Self>,
    ) {
        if !client
            .get_data::<ClientState>()
            .is_some_and(ClientState::is_shell)
        {
            return;
        }
        match request {
            shapebit_toplevel_v1::Request::Activate => state.activate_toplevel(&data.surface),
            shapebit_toplevel_v1::Request::MoveToWorkspace { workspace } => {
                if let Some(workspace) = workspace.data::<WorkspaceData>() {
                    state.move_toplevel_to_workspace(&data.surface, workspace.id);
                }
            }
            shapebit_toplevel_v1::Request::Destroy => {}
            _ => unreachable!("version 1 requests are exhaustively handled"),
        }
    }
}
