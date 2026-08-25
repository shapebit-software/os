use protocol::server::{
    shapebit_workspace_manager_v1::{self, ShapebitWorkspaceManagerV1},
    shapebit_workspace_v1::{self, ShapebitWorkspaceV1},
};
use smithay::reexports::wayland_server::{
    Client, DataInit, Dispatch, DisplayHandle, GlobalDispatch, New, Resource, backend::GlobalId,
};

use crate::state::{ClientState, Compositor};

#[derive(Clone, Copy, Debug)]
pub struct WorkspaceSnapshot {
    pub id: u32,
    pub position: u32,
    pub active: bool,
}

pub struct WorkspaceProtocolState {
    _global: GlobalId,
    managers: Vec<ShapebitWorkspaceManagerV1>,
    workspaces: Vec<(u32, ShapebitWorkspaceV1)>,
}

impl WorkspaceProtocolState {
    pub fn new(display: &DisplayHandle) -> Self {
        let global = display.create_global::<Compositor, ShapebitWorkspaceManagerV1, _>(1, ());
        Self {
            _global: global,
            managers: Vec::new(),
            workspaces: Vec::new(),
        }
    }

    fn announce(
        &mut self,
        display: &DisplayHandle,
        manager: &ShapebitWorkspaceManagerV1,
        client: &Client,
        snapshot: WorkspaceSnapshot,
    ) {
        let workspace = match client.create_resource::<ShapebitWorkspaceV1, _, Compositor>(
            display,
            1,
            WorkspaceData { id: snapshot.id },
        ) {
            Ok(workspace) => workspace,
            Err(error) => {
                tracing::warn!(%error, workspace_id = snapshot.id, "failed to announce Workspace");
                return;
            }
        };
        manager.workspace(&workspace);
        workspace.position(snapshot.position);
        workspace.active(u32::from(snapshot.active));
        self.workspaces.push((snapshot.id, workspace));
    }

    pub fn announce_created(&mut self, display: &DisplayHandle, snapshot: WorkspaceSnapshot) {
        self.managers.retain(Resource::is_alive);
        let targets: Vec<_> = self
            .managers
            .iter()
            .filter_map(|manager| manager.client().map(|client| (manager.clone(), client)))
            .collect();
        for (manager, client) in targets {
            self.announce(display, &manager, &client, snapshot);
        }
    }

    pub fn broadcast_active(&mut self, active_id: u32) {
        self.workspaces.retain(|(_, resource)| resource.is_alive());
        for (id, resource) in &self.workspaces {
            resource.active(u32::from(*id == active_id));
        }
    }

    pub fn broadcast_positions(&mut self, snapshots: &[WorkspaceSnapshot]) {
        self.workspaces.retain(|(_, resource)| resource.is_alive());
        for (id, resource) in &self.workspaces {
            if let Some(snapshot) = snapshots.iter().find(|snapshot| snapshot.id == *id) {
                resource.position(snapshot.position);
            }
        }
    }

    pub fn resource_for_client(
        &mut self,
        client: &Client,
        workspace_id: u32,
    ) -> Option<ShapebitWorkspaceV1> {
        self.workspaces.retain(|(_, resource)| resource.is_alive());
        self.workspaces
            .iter()
            .find(|(id, resource)| {
                *id == workspace_id && resource.client().as_ref() == Some(client)
            })
            .map(|(_, resource)| resource.clone())
    }
}

#[derive(Debug)]
pub struct WorkspaceData {
    pub(crate) id: u32,
}

impl GlobalDispatch<ShapebitWorkspaceManagerV1, ()> for Compositor {
    fn bind(
        state: &mut Self,
        handle: &DisplayHandle,
        client: &Client,
        resource: New<ShapebitWorkspaceManagerV1>,
        _global_data: &(),
        data_init: &mut DataInit<'_, Self>,
    ) {
        let manager = data_init.init(resource, ());
        state
            .workspace_protocol_state
            .managers
            .push(manager.clone());
        let snapshots = state.workspace_snapshots();
        let active_id = snapshots
            .iter()
            .find(|workspace| workspace.active)
            .map(|workspace| workspace.id);
        tracing::info!(
            workspace_count = snapshots.len(),
            ?active_id,
            "sent Workspace snapshot"
        );
        for snapshot in snapshots {
            state
                .workspace_protocol_state
                .announce(handle, &manager, client, snapshot);
        }
    }

    fn can_view(client: Client, _global_data: &()) -> bool {
        client
            .get_data::<ClientState>()
            .is_some_and(ClientState::is_shell)
    }
}

impl Dispatch<ShapebitWorkspaceManagerV1, ()> for Compositor {
    fn request(
        state: &mut Self,
        client: &Client,
        _manager: &ShapebitWorkspaceManagerV1,
        request: shapebit_workspace_manager_v1::Request,
        _data: &(),
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
            shapebit_workspace_manager_v1::Request::CreateWorkspace => {
                state.create_workspace();
            }
            shapebit_workspace_manager_v1::Request::Destroy => {}
            _ => unreachable!("version 1 requests are exhaustively handled"),
        }
    }
}

impl Dispatch<ShapebitWorkspaceV1, WorkspaceData> for Compositor {
    fn request(
        state: &mut Self,
        client: &Client,
        _workspace: &ShapebitWorkspaceV1,
        request: shapebit_workspace_v1::Request,
        data: &WorkspaceData,
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
            shapebit_workspace_v1::Request::Activate => state.activate_workspace(data.id),
            shapebit_workspace_v1::Request::Reorder { position } => {
                state.reorder_workspace(data.id, position);
            }
            shapebit_workspace_v1::Request::Destroy => {}
            _ => unreachable!("version 1 requests are exhaustively handled"),
        }
    }
}
