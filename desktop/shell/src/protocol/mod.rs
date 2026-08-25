use std::{cell::RefCell, collections::BTreeMap, error::Error, io, rc::Rc};

use gdk4_wayland::{WaylandDisplay, WaylandMonitor, WaylandSurface, prelude::*};
use gtk::{ApplicationWindow, prelude::*};
use protocol::client::{
    shapebit_bar_v1::ShapebitBarV1,
    shapebit_overview_v1::ShapebitOverviewV1,
    shapebit_shell_manager_v1::ShapebitShellManagerV1,
    shapebit_toplevel_manager_v1::{self, ShapebitToplevelManagerV1},
    shapebit_toplevel_v1::{self, ShapebitToplevelV1},
    shapebit_workspace_manager_v1::{self, ShapebitWorkspaceManagerV1},
    shapebit_workspace_v1::{self, ShapebitWorkspaceV1},
};
use wayland_client::{
    Connection, Dispatch, EventQueue, Proxy, QueueHandle,
    globals::{GlobalListContents, registry_queue_init},
    protocol::wl_registry,
};

use crate::{
    application_catalog::ApplicationCatalog,
    presentation::{ToplevelState, WorkspaceState, build_presentations},
    ui::{
        ApplicationLauncher, BarDropTargetPlacement, OverviewControls, OverviewToggle,
        PreviewPlacement, WorkspaceControls,
    },
};

pub struct ShellSession {
    connection: Connection,
    event_queue: EventQueue<ProtocolState>,
    state: ProtocolState,
    manager: ShapebitShellManagerV1,
    workspace_manager: ShapebitWorkspaceManagerV1,
    toplevel_manager: ShapebitToplevelManagerV1,
    bar: ShapebitBarV1,
    overview: ShapebitOverviewV1,
    closed: bool,
}

impl ShellSession {
    pub fn register(
        bar_window: &ApplicationWindow,
        overview_window: &ApplicationWindow,
        bar_controls: WorkspaceControls,
        overview_controls: OverviewControls,
        overview_toggle: OverviewToggle,
        application_catalog: Rc<RefCell<ApplicationCatalog>>,
        application_launcher: ApplicationLauncher,
    ) -> Result<Self, Box<dyn Error>> {
        gtk::prelude::WidgetExt::realize(bar_window);
        gtk::prelude::WidgetExt::realize(overview_window);

        let surface = bar_window
            .surface()
            .ok_or_else(|| io::Error::other("GTK did not create a GDK surface"))?;
        let display = surface.display();
        let monitor = display
            .monitor_at_surface(&surface)
            .ok_or_else(|| io::Error::other("GTK did not select an output for the shell bar"))?;

        let wayland_display = display
            .downcast::<WaylandDisplay>()
            .map_err(|_| io::Error::other("the ShapeBit shell requires a Wayland display"))?;
        let wayland_surface = surface
            .downcast::<WaylandSurface>()
            .map_err(|_| io::Error::other("the GTK window is not a Wayland surface"))?;
        let wayland_monitor = monitor
            .downcast::<WaylandMonitor>()
            .map_err(|_| io::Error::other("the selected monitor is not a Wayland output"))?;

        let wl_display = wayland_display
            .wl_display()
            .ok_or_else(|| io::Error::other("GDK did not expose wl_display"))?;
        let wl_surface = wayland_surface
            .wl_surface()
            .ok_or_else(|| io::Error::other("GDK did not expose wl_surface"))?;
        let overview_surface = overview_window
            .surface()
            .ok_or_else(|| io::Error::other("GTK did not create an Overview GDK surface"))?
            .downcast::<WaylandSurface>()
            .map_err(|_| io::Error::other("the GTK Overview is not a Wayland surface"))?;
        let overview_wl_surface = overview_surface
            .wl_surface()
            .ok_or_else(|| io::Error::other("GDK did not expose the Overview wl_surface"))?;
        let wl_output = wayland_monitor
            .wl_output()
            .ok_or_else(|| io::Error::other("GDK did not expose wl_output"))?;
        let backend = wl_display
            .backend()
            .upgrade()
            .ok_or_else(|| io::Error::other("the GTK Wayland connection has closed"))?;
        let connection = Connection::from_backend(backend);
        let (globals, mut event_queue) = registry_queue_init::<ProtocolState>(&connection)?;
        let queue_handle = event_queue.handle();
        let manager = globals.bind::<ShapebitShellManagerV1, _, _>(&queue_handle, 1..=1, ())?;
        let workspace_manager =
            globals.bind::<ShapebitWorkspaceManagerV1, _, _>(&queue_handle, 1..=1, ())?;
        let toplevel_manager =
            globals.bind::<ShapebitToplevelManagerV1, _, _>(&queue_handle, 1..=1, ())?;
        let bar = manager.create_bar(&wl_surface, &wl_output, &queue_handle, ());
        let overview = manager.create_overview(&overview_wl_surface, &wl_output, &queue_handle, ());
        let workspaces = Rc::new(RefCell::new(BTreeMap::new()));
        let workspace_actions = Rc::new(RefCell::new(BTreeMap::new()));
        let toplevel_actions = Rc::new(RefCell::new(BTreeMap::new()));
        let generation =
            std::env::var("SHAPEBIT_SHELL_GENERATION").unwrap_or_else(|_| "unknown".into());
        let mut state = ProtocolState {
            bar_controls: bar_controls.clone(),
            overview_controls: overview_controls.clone(),
            workspaces: Rc::clone(&workspaces),
            workspace_actions: Rc::clone(&workspace_actions),
            toplevels: BTreeMap::new(),
            toplevel_actions: Rc::clone(&toplevel_actions),
            application_catalog: Rc::clone(&application_catalog),
            generation: generation.clone(),
        };

        let workspaces_for_activate = Rc::clone(&workspace_actions);
        bar_controls.set_activate_action(move |handle| {
            if let Some(workspace) = workspaces_for_activate.borrow().get(&handle) {
                workspace.activate();
            }
        });
        let manager_for_create = workspace_manager.clone();
        bar_controls.set_create_action(move || manager_for_create.create_workspace());
        let connection_for_application = connection.clone();
        let toplevels_for_activation = Rc::clone(&toplevel_actions);
        let generation_for_application = generation.clone();
        bar_controls.set_activate_application_action(move |handle| {
            if let Some(toplevel) = toplevels_for_activation.borrow().get(&handle) {
                eprintln!(
                    "ShapeBit shell requested application badge activation generation={generation_for_application} toplevel_handle={handle}"
                );
                toplevel.activate();
                let _ = connection_for_application.flush();
            }
        });
        let connection_for_reorder = connection.clone();
        let workspaces_for_reorder = Rc::clone(&workspace_actions);
        let generation_for_reorder = generation.clone();
        bar_controls.set_reorder_action(move |handle, position| {
            if let Some(workspace) = workspaces_for_reorder.borrow().get(&handle) {
                eprintln!(
                    "ShapeBit shell requested Workspace reorder generation={generation_for_reorder} workspace_handle={handle} position={position}"
                );
                workspace.reorder(position);
                let _ = connection_for_reorder.flush();
            }
        });

        let bar_for_drop_targets = bar.clone();
        let workspaces_for_drop_targets = Rc::clone(&workspace_actions);
        let connection_for_drop_targets = connection.clone();
        let generation_for_drop_targets = generation.clone();
        bar_controls.set_drop_targets_action(move |placements: Vec<BarDropTargetPlacement>| {
            bar_for_drop_targets.clear_workspace_drop_targets();
            let mut configured = 0;
            for placement in placements {
                if let Some(workspace) = workspaces_for_drop_targets
                    .borrow()
                    .get(&placement.workspace_handle)
                {
                    bar_for_drop_targets.set_workspace_drop_target(
                        workspace,
                        placement.x,
                        placement.y,
                        placement.width,
                        placement.height,
                    );
                    configured += 1;
                }
            }
            eprintln!(
                "ShapeBit shell configured Workspace bar drop targets generation={generation_for_drop_targets} target_count={configured}"
            );
            let _ = connection_for_drop_targets.flush();
        });

        let overview_for_toggle = overview.clone();
        let overview_controls_for_toggle = overview_controls.clone();
        let application_catalog_for_toggle = Rc::clone(&application_catalog);
        let application_launcher_for_toggle = application_launcher.clone();
        let connection_for_toggle = connection.clone();
        overview_toggle.set_action(move |active| {
            if active {
                let refreshed_catalog = ApplicationCatalog::load();
                application_launcher_for_toggle.refresh(&refreshed_catalog);
                *application_catalog_for_toggle.borrow_mut() = refreshed_catalog;
                overview_controls_for_toggle.reset_selection_to_active();
                overview_for_toggle.show();
            } else {
                overview_for_toggle.hide();
            }
            let _ = connection_for_toggle.flush();
        });

        let overview_for_previews = overview.clone();
        let toplevels_for_previews = Rc::clone(&toplevel_actions);
        let connection_for_previews = connection.clone();
        overview_controls.set_preview_action(move |placements: Vec<PreviewPlacement>| {
            overview_for_previews.clear_window_previews();
            for placement in placements {
                if let Some(toplevel) = toplevels_for_previews
                    .borrow()
                    .get(&placement.activation_handle)
                {
                    overview_for_previews.set_window_preview(
                        toplevel,
                        placement.x,
                        placement.y,
                        placement.width,
                        placement.height,
                    );
                }
            }
            let _ = connection_for_previews.flush();
        });

        let workspaces_for_overview = Rc::clone(&workspace_actions);
        let overview_for_select = overview.clone();
        let toggle_for_select = overview_toggle.clone();
        let connection_for_select = connection.clone();
        overview_controls.set_activate_action(move |handle| {
            if let Some(workspace) = workspaces_for_overview.borrow().get(&handle) {
                workspace.activate();
            }
            overview_for_select.hide();
            toggle_for_select.set_active(false);
            let _ = connection_for_select.flush();
        });

        let overview_for_hide = overview.clone();
        let toggle_for_hide = overview_toggle;
        let connection_for_hide = connection.clone();
        overview_controls.set_hide_action(move || {
            overview_for_hide.hide();
            toggle_for_hide.set_active(false);
            let _ = connection_for_hide.flush();
        });

        connection.flush()?;
        event_queue.roundtrip(&mut state)?;
        eprintln!(
            "ShapeBit shell processed initial snapshot barrier generation={} workspace_count={} toplevel_count={}",
            state.generation,
            state.workspaces.borrow().len(),
            state.toplevels.len()
        );
        manager.ready();
        connection.flush()?;

        Ok(Self {
            connection,
            event_queue,
            state,
            manager,
            workspace_manager,
            toplevel_manager,
            bar,
            overview,
            closed: false,
        })
    }

    pub fn dispatch_pending(&mut self) -> Result<(), Box<dyn Error>> {
        self.event_queue.dispatch_pending(&mut self.state)?;
        self.connection.flush()?;
        Ok(())
    }

    #[cfg(feature = "smoke-test")]
    pub fn create_workspace_for_smoke(&self) -> Result<(), Box<dyn Error>> {
        self.workspace_manager.create_workspace();
        self.connection.flush()?;
        Ok(())
    }

    #[cfg(feature = "smoke-test")]
    pub fn move_first_toplevel_for_smoke(
        &self,
        target_active: bool,
    ) -> Result<bool, Box<dyn Error>> {
        let target_handle = self
            .state
            .workspaces
            .borrow()
            .iter()
            .find_map(|(handle, workspace)| (workspace.active == target_active).then_some(*handle));
        let Some(target_handle) = target_handle else {
            return Ok(false);
        };
        let toplevel_handle = self.state.toplevels.iter().find_map(|(handle, toplevel)| {
            (toplevel.workspace != Some(target_handle)).then_some(*handle)
        });
        let Some(toplevel_handle) = toplevel_handle else {
            return Ok(false);
        };
        let workspace = self
            .state
            .workspace_actions
            .borrow()
            .get(&target_handle)
            .cloned();
        let toplevel = self
            .state
            .toplevel_actions
            .borrow()
            .get(&toplevel_handle)
            .cloned();
        let (Some(workspace), Some(toplevel)) = (workspace, toplevel) else {
            return Ok(false);
        };
        eprintln!(
            "ShapeBit shell requested toplevel Workspace transfer generation={} toplevel_handle={toplevel_handle} target_workspace_handle={target_handle} target_active={target_active}",
            self.state.generation
        );
        toplevel.move_to_workspace(&workspace);
        self.connection.flush()?;
        Ok(true)
    }

    pub fn close(&mut self) {
        if self.closed {
            return;
        }
        self.closed = true;
        for workspace in self.state.workspace_actions.borrow().values() {
            workspace.destroy();
        }
        for toplevel in self.state.toplevel_actions.borrow().values() {
            toplevel.destroy();
        }
        self.toplevel_manager.destroy();
        self.workspace_manager.destroy();
        self.overview.destroy();
        self.bar.destroy();
        self.manager.destroy();
        let _ = self.connection.flush();
    }
}

struct ProtocolState {
    bar_controls: WorkspaceControls,
    overview_controls: OverviewControls,
    workspaces: Rc<RefCell<BTreeMap<u32, WorkspaceState>>>,
    workspace_actions: Rc<RefCell<BTreeMap<u32, ShapebitWorkspaceV1>>>,
    toplevels: BTreeMap<u32, ToplevelState>,
    toplevel_actions: Rc<RefCell<BTreeMap<u32, ShapebitToplevelV1>>>,
    application_catalog: Rc<RefCell<ApplicationCatalog>>,
    generation: String,
}

impl ProtocolState {
    fn render_workspaces(&self) {
        let workspaces = self.workspaces.borrow();
        let application_catalog = self.application_catalog.borrow();
        let presentations = build_presentations(&workspaces, &self.toplevels, &application_catalog);
        let application_count: usize = presentations
            .iter()
            .map(|workspace| workspace.applications.len())
            .sum();
        let resolved_application_count: usize = presentations
            .iter()
            .flat_map(|workspace| &workspace.applications)
            .filter(|application| application.resolved)
            .count();
        let icon_application_count: usize = presentations
            .iter()
            .flat_map(|workspace| &workspace.applications)
            .filter(|application| application.icon.is_some())
            .count();
        self.bar_controls.render(&presentations);
        self.overview_controls.render(&presentations);
        if !self.toplevels.is_empty() {
            eprintln!(
                "ShapeBit shell rendered application inventory generation={} toplevel_count={} application_count={application_count} resolved_application_count={resolved_application_count} icon_application_count={icon_application_count}",
                self.generation,
                self.toplevels.len()
            );
            eprintln!(
                "ShapeBit shell rendered Overview model generation={} workspace_count={} application_count={application_count}",
                self.generation,
                presentations.len()
            );
        }
    }
}

impl Dispatch<wl_registry::WlRegistry, GlobalListContents> for ProtocolState {
    fn event(
        _state: &mut Self,
        _registry: &wl_registry::WlRegistry,
        _event: wl_registry::Event,
        _data: &GlobalListContents,
        _connection: &Connection,
        _queue_handle: &QueueHandle<Self>,
    ) {
    }
}

impl Dispatch<ShapebitWorkspaceManagerV1, ()> for ProtocolState {
    fn event(
        state: &mut Self,
        _manager: &ShapebitWorkspaceManagerV1,
        event: shapebit_workspace_manager_v1::Event,
        _data: &(),
        _connection: &Connection,
        _queue_handle: &QueueHandle<Self>,
    ) {
        match event {
            shapebit_workspace_manager_v1::Event::Workspace { workspace } => {
                let handle = workspace.id().protocol_id();
                state
                    .workspace_actions
                    .borrow_mut()
                    .insert(handle, workspace);
                state.workspaces.borrow_mut().insert(
                    handle,
                    WorkspaceState {
                        position: u32::MAX,
                        active: false,
                    },
                );
            }
            _ => unreachable!("version 1 events are exhaustively handled"),
        }
    }

    wayland_client::event_created_child!(ProtocolState, ShapebitWorkspaceManagerV1, [
        shapebit_workspace_manager_v1::EVT_WORKSPACE_OPCODE => (ShapebitWorkspaceV1, ())
    ]);
}

impl Dispatch<ShapebitWorkspaceV1, ()> for ProtocolState {
    fn event(
        state: &mut Self,
        workspace: &ShapebitWorkspaceV1,
        event: shapebit_workspace_v1::Event,
        _data: &(),
        _connection: &Connection,
        _queue_handle: &QueueHandle<Self>,
    ) {
        let handle = workspace.id().protocol_id();
        let mut workspaces = state.workspaces.borrow_mut();
        let Some(workspace) = workspaces.get_mut(&handle) else {
            return;
        };
        match event {
            shapebit_workspace_v1::Event::Position { position } => {
                workspace.position = position;
            }
            shapebit_workspace_v1::Event::Active { active } => {
                workspace.active = active != 0;
            }
            _ => unreachable!("version 1 events are exhaustively handled"),
        }
        drop(workspaces);
        state.render_workspaces();
    }
}

impl Dispatch<ShapebitToplevelManagerV1, ()> for ProtocolState {
    fn event(
        state: &mut Self,
        _manager: &ShapebitToplevelManagerV1,
        event: shapebit_toplevel_manager_v1::Event,
        _data: &(),
        _connection: &Connection,
        _queue_handle: &QueueHandle<Self>,
    ) {
        match event {
            shapebit_toplevel_manager_v1::Event::Toplevel { toplevel } => {
                let handle = toplevel.id().protocol_id();
                state
                    .toplevel_actions
                    .borrow_mut()
                    .insert(handle, toplevel.clone());
                state.toplevels.insert(
                    handle,
                    ToplevelState {
                        title: String::new(),
                        app_id: String::new(),
                        workspace: None,
                        active: false,
                    },
                );
            }
            _ => unreachable!("version 1 events are exhaustively handled"),
        }
    }

    wayland_client::event_created_child!(ProtocolState, ShapebitToplevelManagerV1, [
        shapebit_toplevel_manager_v1::EVT_TOPLEVEL_OPCODE => (ShapebitToplevelV1, ())
    ]);
}

impl Dispatch<ShapebitToplevelV1, ()> for ProtocolState {
    fn event(
        state: &mut Self,
        toplevel: &ShapebitToplevelV1,
        event: shapebit_toplevel_v1::Event,
        _data: &(),
        _connection: &Connection,
        _queue_handle: &QueueHandle<Self>,
    ) {
        let handle = toplevel.id().protocol_id();
        if matches!(event, shapebit_toplevel_v1::Event::Closed) {
            state.toplevel_actions.borrow_mut().remove(&handle);
            state.toplevels.remove(&handle);
            state.render_workspaces();
            return;
        }
        let Some(toplevel) = state.toplevels.get_mut(&handle) else {
            return;
        };
        match event {
            shapebit_toplevel_v1::Event::Title { title } => toplevel.title = title,
            shapebit_toplevel_v1::Event::AppId { app_id } => toplevel.app_id = app_id,
            shapebit_toplevel_v1::Event::Workspace { workspace } => {
                toplevel.workspace = Some(workspace.id().protocol_id());
            }
            shapebit_toplevel_v1::Event::Active { active } => {
                toplevel.active = active != 0;
            }
            shapebit_toplevel_v1::Event::Closed => unreachable!("closed was handled above"),
            _ => unreachable!("version 1 events are exhaustively handled"),
        }
        state.render_workspaces();
    }
}

wayland_client::delegate_noop!(ProtocolState: ShapebitShellManagerV1);
wayland_client::delegate_noop!(ProtocolState: ShapebitBarV1);
wayland_client::delegate_noop!(ProtocolState: ShapebitOverviewV1);
