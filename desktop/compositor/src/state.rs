use std::{
    ffi::OsString,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
};

use smithay::{
    desktop::{PopupManager, Space, Window, WindowSurfaceType},
    input::{Seat, SeatState},
    output::Output,
    reexports::{
        calloop::{EventLoop, Interest, LoopSignal, Mode, PostAction, generic::Generic},
        wayland_protocols::xdg::shell::server::xdg_toplevel,
        wayland_server::{
            Display, DisplayHandle, Resource,
            backend::{ClientData, ClientId, DisconnectReason},
            protocol::{wl_output::WlOutput, wl_surface::WlSurface},
        },
    },
    utils::{IsAlive, Logical, Point, Rectangle, SERIAL_COUNTER, Size},
    wayland::{
        compositor::{CompositorClientState, CompositorState, with_states},
        output::OutputManagerState,
        selection::data_device::DataDeviceState,
        shell::xdg::{ToplevelSurface, XdgShellState, XdgToplevelSurfaceData},
        shm::ShmState,
        socket::ListeningSocketSource,
    },
};

use crate::layout::{Layout, Rect};
use crate::protocols::{
    shell::ShellState,
    toplevel::{ToplevelProtocolState, ToplevelSnapshot},
    workspace::{WorkspaceProtocolState, WorkspaceSnapshot},
};
use crate::shell_supervisor::DevelopmentShellSupervisor;
use crate::workspaces::WorkspaceSet;

const BAR_HEIGHT: i32 = 58;

fn tiled_client_size(
    tile: Rect,
    geometry: Rectangle<i32, Logical>,
    bounds: Rectangle<i32, Logical>,
) -> Size<i32, Logical> {
    let horizontal_frame = (bounds.size.w - geometry.size.w).max(0);
    let vertical_frame = (bounds.size.h - geometry.size.h).max(0);
    (
        (tile.width - horizontal_frame).max(1),
        (tile.height - vertical_frame).max(1),
    )
        .into()
}

fn tiled_window_location(tile: Rect, bounds: Rectangle<i32, Logical>) -> Point<i32, Logical> {
    (tile.x - bounds.loc.x, tile.y - bounds.loc.y).into()
}

pub struct Compositor {
    pub start_time: std::time::Instant,
    pub socket_name: OsString,
    pub display_handle: DisplayHandle,
    pub space: Space<Window>,
    pub loop_signal: LoopSignal,
    pub compositor_state: CompositorState,
    pub xdg_shell_state: XdgShellState,
    pub shell_state: ShellState,
    pub workspace_protocol_state: WorkspaceProtocolState,
    pub toplevel_protocol_state: ToplevelProtocolState,
    pub shm_state: ShmState,
    _output_manager_state: OutputManagerState,
    pub seat_state: SeatState<Self>,
    pub data_device_state: DataDeviceState,
    pub popups: PopupManager,
    pub seat: Seat<Self>,
    workspaces: WorkspaceSet,
    output_size: Size<i32, Logical>,
    bar_surface: Option<WlSurface>,
    _bar_output: Option<Output>,
    bar_window: Option<Window>,
    overview_surface: Option<WlSurface>,
    _overview_output: Option<Output>,
    overview_window: Option<Window>,
    overview_visible: bool,
    overview_previews: Vec<(WlSurface, Rectangle<i32, Logical>)>,
    shell_supervisor: DevelopmentShellSupervisor,
}

impl Compositor {
    pub fn new(
        event_loop: &mut EventLoop<Self>,
        display: Display<Self>,
        socket_name: Option<&str>,
    ) -> Result<Self, Box<dyn std::error::Error>> {
        let display_handle = display.handle();
        let compositor_state = CompositorState::new::<Self>(&display_handle);
        let xdg_shell_state = XdgShellState::new::<Self>(&display_handle);
        let shell_state = ShellState::new(&display_handle);
        let workspace_protocol_state = WorkspaceProtocolState::new(&display_handle);
        let toplevel_protocol_state = ToplevelProtocolState::new(&display_handle);
        let shm_state = ShmState::new::<Self>(&display_handle, vec![]);
        let output_manager_state = OutputManagerState::new_with_xdg_output::<Self>(&display_handle);
        let data_device_state = DataDeviceState::new::<Self>(&display_handle);

        let mut seat_state = SeatState::new();
        let mut seat = seat_state.new_wl_seat(&display_handle, "seat-0");
        seat.add_keyboard(Default::default(), 200, 25)?;
        seat.add_pointer();

        let listener = match socket_name {
            Some(name) => ListeningSocketSource::with_name(name)?,
            None => ListeningSocketSource::new_auto()?,
        };
        let socket_name = listener.socket_name().to_os_string();
        let loop_handle = event_loop.handle();
        loop_handle.insert_source(listener, |stream, _, state| {
            if let Err(error) = state
                .display_handle
                .insert_client(stream, Arc::new(ClientState::default()))
            {
                tracing::warn!(%error, "failed to register Wayland client");
            }
        })?;
        loop_handle.insert_source(
            Generic::new(display, Interest::READ, Mode::Level),
            |_, display, state| {
                // SAFETY: The display remains owned by this event source for the
                // full event-loop lifetime.
                unsafe { display.get_mut().dispatch_clients(state) }?;
                Ok(PostAction::Continue)
            },
        )?;

        Ok(Self {
            start_time: std::time::Instant::now(),
            socket_name,
            display_handle,
            space: Space::default(),
            loop_signal: event_loop.get_signal(),
            compositor_state,
            xdg_shell_state,
            shell_state,
            workspace_protocol_state,
            toplevel_protocol_state,
            shm_state,
            _output_manager_state: output_manager_state,
            seat_state,
            data_device_state,
            popups: PopupManager::default(),
            seat,
            workspaces: WorkspaceSet::default(),
            output_size: (1280, 800).into(),
            bar_surface: None,
            _bar_output: None,
            bar_window: None,
            overview_surface: None,
            _overview_output: None,
            overview_window: None,
            overview_visible: false,
            overview_previews: Vec::new(),
            shell_supervisor: DevelopmentShellSupervisor::default(),
        })
    }

    pub fn spawn_development_shell(
        &mut self,
        command: &[OsString],
    ) -> Result<(), Box<dyn std::error::Error>> {
        self.shell_supervisor.configure_and_start(
            command,
            &mut self.display_handle,
            &self.socket_name,
        )
    }

    pub fn add_toplevel(&mut self, surface: ToplevelSurface) {
        let window = Window::new_wayland_window(surface);
        if self
            .bar_surface
            .as_ref()
            .is_some_and(|bar| window.toplevel().is_some_and(|top| top.wl_surface() == bar))
        {
            tracing::info!("mapped shell bar");
            self.bar_window = Some(window.clone());
            self.space.map_element(window, (0, 0), false);
            self.configure_bar(true);
            self.configure_layout(false);
            return;
        }
        if self.overview_surface.as_ref().is_some_and(|overview| {
            window
                .toplevel()
                .is_some_and(|top| top.wl_surface() == overview)
        }) {
            tracing::info!("mapped shell Overview");
            self.overview_window = Some(window);
            self.configure_overview(true);
            return;
        }
        let area = self.layout_area();
        self.active_layout_mut().insert(window.clone(), area);
        tracing::info!(
            window_count = self.active_layout().len(),
            workspace_id = self.active_workspace_id(),
            "mapped xdg toplevel"
        );
        self.space.map_element(window.clone(), (0, 0), false);
        if !is_shell_client_surface(
            window
                .toplevel()
                .expect("an xdg toplevel exists")
                .wl_surface(),
        ) {
            let snapshot = self
                .toplevel_snapshot(&window, self.active_workspace_id())
                .expect("an ordinary xdg toplevel has snapshot metadata");
            ToplevelProtocolState::announce_created(self, snapshot);
        }
        self.set_focus(&window);
        self.configure_layout(true);
    }

    pub fn set_output_size(&mut self, size: Size<i32, Logical>) {
        self.output_size = size;
        self.configure_bar(false);
        self.configure_overview(false);
        self.configure_layout(false);
    }

    pub fn refresh_windows(&mut self) {
        self.space.refresh();
        self.align_layout_positions();
        if self
            .bar_window
            .as_ref()
            .is_some_and(|window| !window.alive())
        {
            self.clear_bar();
        }
        if self
            .overview_window
            .as_ref()
            .is_some_and(|window| !window.alive())
        {
            self.clear_overview();
        }
        if self.shell_supervisor.poll() {
            self.shell_state.mark_unavailable();
            self.clear_bar();
            self.clear_overview();
        }
        if self.workspaces.retain_alive() {
            self.configure_layout(false);
        }
        self.shell_supervisor.restart_if_due(
            &mut self.display_handle,
            &self.socket_name,
            self.bar_surface.is_none() && self.overview_surface.is_none(),
        );
    }

    pub fn focus_window(&mut self, window: &Window) {
        if self.overview_window.as_ref() == Some(window) {
            let surface = window
                .toplevel()
                .expect("the Overview uses a GTK xdg toplevel")
                .wl_surface()
                .clone();
            let keyboard = self
                .seat
                .get_keyboard()
                .expect("the compositor always has a keyboard");
            keyboard.set_focus(self, Some(surface), SERIAL_COUNTER.next_serial());
            self.toplevel_protocol_state.broadcast_active(None);
            return;
        }
        if self.bar_window.as_ref() == Some(window) {
            let surface = window
                .toplevel()
                .expect("the bar uses a GTK xdg toplevel")
                .wl_surface()
                .clone();
            let keyboard = self
                .seat
                .get_keyboard()
                .expect("the compositor always has a keyboard");
            keyboard.set_focus(self, Some(surface), SERIAL_COUNTER.next_serial());
            self.toplevel_protocol_state.broadcast_active(None);
            return;
        }
        if self.set_focus(window) {
            self.configure_layout(false);
        }
    }

    fn set_focus(&mut self, window: &Window) -> bool {
        if !self.active_layout_mut().focus(window) {
            return false;
        }

        let surface = window
            .toplevel()
            .expect("only xdg toplevel windows are stored")
            .wl_surface()
            .clone();
        let keyboard = self
            .seat
            .get_keyboard()
            .expect("the compositor always has a keyboard");
        keyboard.set_focus(self, Some(surface), SERIAL_COUNTER.next_serial());
        self.toplevel_protocol_state.broadcast_active(Some(
            window
                .toplevel()
                .expect("an xdg toplevel exists")
                .wl_surface(),
        ));
        true
    }

    pub fn surface_under(
        &self,
        position: Point<f64, Logical>,
    ) -> Option<(WlSurface, Point<f64, Logical>)> {
        self.space
            .element_under(position)
            .and_then(|(window, location)| {
                window
                    .surface_under(position - location.to_f64(), WindowSurfaceType::ALL)
                    .map(|(surface, offset)| (surface, (offset + location).to_f64()))
            })
    }

    fn layout_area(&self) -> Rect {
        let reserved = if self.bar_window.is_some() {
            BAR_HEIGHT
        } else {
            0
        };
        Rect::new(
            0,
            0,
            self.output_size.w.max(1),
            (self.output_size.h - reserved).max(1),
        )
    }

    fn configure_layout(&mut self, allow_initial: bool) {
        let focused = self.active_layout().focused().cloned();
        let layout_area = self.layout_area();
        let placements = self.active_layout().placements(layout_area);
        for (window, rect) in placements {
            let Some(toplevel) = window.toplevel() else {
                continue;
            };
            let geometry = window.geometry();
            let bounds = window.bbox();
            let client_size = tiled_client_size(rect, geometry, bounds);
            window.set_activated(focused.as_ref() == Some(&window));
            toplevel.with_pending_state(|state| {
                state.size = Some(client_size);
                state.bounds = Some((layout_area.width, layout_area.height).into());
                for tiled_state in [
                    xdg_toplevel::State::TiledLeft,
                    xdg_toplevel::State::TiledRight,
                    xdg_toplevel::State::TiledTop,
                    xdg_toplevel::State::TiledBottom,
                ] {
                    state.states.set(tiled_state);
                }
            });
            if allow_initial && !toplevel.is_initial_configure_sent() {
                toplevel.send_configure();
            } else {
                toplevel.send_pending_configure();
            }
        }
        self.align_layout_positions();
    }

    fn align_layout_positions(&mut self) {
        let placements = self.active_layout().placements(self.layout_area());
        let mut changed = false;
        for (window, rect) in placements {
            let bounds = window.bbox();
            let target = tiled_window_location(rect, bounds);
            if self.space.element_location(&window) != Some(target) {
                self.space.map_element(window, target, false);
                changed = true;
            }
        }
        if !changed {
            return;
        }
        self.raise_shell_surfaces();
    }

    fn configure_bar(&mut self, allow_initial: bool) {
        let Some(window) = self.bar_window.clone() else {
            return;
        };
        let Some(toplevel) = window.toplevel() else {
            return;
        };
        let geometry = window.geometry();
        let y = (self.output_size.h - BAR_HEIGHT).max(0);
        self.space
            .map_element(window.clone(), (-geometry.loc.x, y - geometry.loc.y), false);
        window.set_activated(false);
        toplevel.with_pending_state(|state| {
            state.size = Some((self.output_size.w.max(1), BAR_HEIGHT).into());
        });
        if allow_initial && !toplevel.is_initial_configure_sent() {
            toplevel.send_configure();
        } else {
            toplevel.send_pending_configure();
        }
        self.raise_shell_surfaces();
    }

    fn configure_overview(&mut self, allow_initial: bool) {
        let Some(window) = self.overview_window.clone() else {
            return;
        };
        let Some(toplevel) = window.toplevel() else {
            return;
        };
        let area = Rect::new(0, 0, self.output_size.w.max(1), self.output_size.h.max(1));
        let geometry = window.geometry();
        if self.overview_visible {
            self.space.map_element(
                window.clone(),
                (area.x - geometry.loc.x, area.y - geometry.loc.y),
                false,
            );
        } else {
            self.space.unmap_elem(&window);
        }
        window.set_activated(self.overview_visible);
        toplevel.with_pending_state(|state| {
            state.size = Some((area.width.max(1), area.height.max(1)).into());
        });
        if allow_initial && !toplevel.is_initial_configure_sent() {
            toplevel.send_configure();
        } else {
            toplevel.send_pending_configure();
        }
        self.raise_shell_surfaces();
        if self.overview_visible {
            tracing::info!(
                width = area.width,
                height = area.height,
                "configured full-output Overview above the bar"
            );
        }
    }

    fn raise_shell_surfaces(&mut self) {
        if let Some(bar) = self.bar_window.clone() {
            self.space.raise_element(&bar, false);
        }
        if self.overview_visible
            && let Some(overview) = self.overview_window.clone()
        {
            self.space.raise_element(&overview, false);
        }
    }

    pub fn register_bar(
        &mut self,
        surface: WlSurface,
        output_resource: WlOutput,
    ) -> Result<(), RegisterBarError> {
        if self.bar_surface.is_some() {
            return Err(RegisterBarError::AlreadyHasBar);
        }
        let output = Output::from_resource(&output_resource)
            .filter(|requested| self.space.outputs().any(|known| known == requested))
            .ok_or(RegisterBarError::InvalidOutput)?;
        let existing_window = self
            .space
            .elements()
            .find(|window| {
                window
                    .toplevel()
                    .is_some_and(|toplevel| toplevel.wl_surface() == &surface)
            })
            .cloned();

        self.bar_surface = Some(surface.clone());
        self._bar_output = Some(output);
        if let Some(window) = existing_window {
            for workspace in self.workspaces.iter_mut() {
                workspace.layout.retain(|candidate| candidate != &window);
            }
            self.toplevel_protocol_state.remove(&surface);
            self.bar_window = Some(window);
            tracing::info!(
                height = BAR_HEIGHT,
                "reclassified xdg toplevel as shell bar"
            );
            self.configure_bar(false);
            self.configure_layout(false);
        }
        Ok(())
    }

    pub fn required_shell_roles_registered(&self) -> bool {
        self.bar_surface.is_some() && self.overview_surface.is_some()
    }

    pub fn clear_shell_roles(&mut self) {
        self.clear_bar();
        self.clear_overview();
    }

    pub fn unregister_bar(&mut self, surface: &WlSurface) {
        if self.bar_surface.as_ref() != Some(surface) {
            return;
        }
        self.clear_bar();
    }

    fn clear_bar(&mut self) {
        let had_bar = self.bar_surface.is_some() || self.bar_window.is_some();
        if let Some(window) = self.bar_window.take() {
            self.space.unmap_elem(&window);
        }
        self.bar_surface = None;
        self._bar_output = None;
        if self.shell_state.mark_unavailable() {
            tracing::info!(reason = "bar removed", "shell became unavailable");
        }
        self.configure_layout(false);
        if had_bar {
            tracing::info!("cleared shell bar policy");
        }
    }

    pub fn register_overview(
        &mut self,
        surface: WlSurface,
        output_resource: WlOutput,
    ) -> Result<(), RegisterOverviewError> {
        if self.overview_surface.is_some() {
            return Err(RegisterOverviewError::AlreadyHasOverview);
        }
        let output = Output::from_resource(&output_resource)
            .filter(|requested| self.space.outputs().any(|known| known == requested))
            .ok_or(RegisterOverviewError::InvalidOutput)?;
        let existing_window = self
            .space
            .elements()
            .find(|window| {
                window
                    .toplevel()
                    .is_some_and(|toplevel| toplevel.wl_surface() == &surface)
            })
            .cloned();

        self.overview_surface = Some(surface.clone());
        self._overview_output = Some(output);
        if let Some(window) = existing_window {
            for workspace in self.workspaces.iter_mut() {
                workspace.layout.retain(|candidate| candidate != &window);
            }
            self.toplevel_protocol_state.remove(&surface);
            self.overview_window = Some(window);
            tracing::info!("reclassified xdg toplevel as shell Overview");
            self.configure_overview(false);
            self.configure_layout(false);
        }
        Ok(())
    }

    pub fn show_overview(&mut self, surface: &WlSurface) {
        if self.overview_surface.as_ref() != Some(surface) || self.overview_visible {
            return;
        }
        self.overview_visible = true;
        self.configure_overview(false);
        if let Some(window) = self.overview_window.clone() {
            self.focus_window(&window);
        }
        tracing::info!("showed shell Overview");
    }

    pub fn hide_overview(&mut self, surface: &WlSurface) {
        if self.overview_surface.as_ref() != Some(surface) || !self.overview_visible {
            return;
        }
        self.overview_visible = false;
        self.configure_overview(false);
        if let Some(window) = self.active_layout().focused().cloned() {
            self.set_focus(&window);
        } else {
            let keyboard = self
                .seat
                .get_keyboard()
                .expect("the compositor always has a keyboard");
            keyboard.set_focus(
                self,
                Option::<WlSurface>::None,
                SERIAL_COUNTER.next_serial(),
            );
        }
        tracing::info!("hid shell Overview");
    }

    pub fn clear_overview_previews(&mut self, surface: &WlSurface) {
        if self.overview_surface.as_ref() == Some(surface) {
            self.overview_previews.clear();
        }
    }

    pub fn set_overview_preview(
        &mut self,
        overview_surface: &WlSurface,
        toplevel_surface: WlSurface,
        rectangle: Rectangle<i32, Logical>,
    ) {
        if self.overview_surface.as_ref() != Some(overview_surface)
            || rectangle.size.w <= 0
            || rectangle.size.h <= 0
            || !self
                .toplevel_snapshots()
                .iter()
                .any(|snapshot| snapshot.surface == toplevel_surface)
        {
            return;
        }
        let output = Rectangle::from_size(self.output_size);
        let Some(rectangle) = rectangle.intersection(output) else {
            return;
        };
        self.overview_previews
            .retain(|(surface, _)| surface != &toplevel_surface);
        self.overview_previews.push((toplevel_surface, rectangle));
        tracing::info!(
            x = rectangle.loc.x,
            y = rectangle.loc.y,
            width = rectangle.size.w,
            height = rectangle.size.h,
            "configured live Overview preview"
        );
    }

    pub fn overview_preview_windows(&self) -> Vec<(Window, Rectangle<i32, Logical>)> {
        if !self.overview_visible {
            return Vec::new();
        }
        self.overview_previews
            .iter()
            .filter_map(|(surface, rectangle)| {
                self.workspaces
                    .iter()
                    .flat_map(|workspace| {
                        workspace.layout.placements(self.layout_area()).into_iter()
                    })
                    .find(|(window, _)| {
                        window
                            .toplevel()
                            .is_some_and(|toplevel| toplevel.wl_surface() == surface)
                    })
                    .map(|(window, _)| (window, *rectangle))
            })
            .collect()
    }

    pub fn unregister_overview(&mut self, surface: &WlSurface) {
        if self.overview_surface.as_ref() == Some(surface) {
            self.clear_overview();
        }
    }

    fn clear_overview(&mut self) {
        let had_overview = self.overview_surface.is_some() || self.overview_window.is_some();
        if let Some(window) = self.overview_window.take() {
            self.space.unmap_elem(&window);
        }
        self.overview_surface = None;
        self._overview_output = None;
        self.overview_visible = false;
        self.overview_previews.clear();
        if self.shell_state.mark_unavailable() {
            tracing::info!(reason = "Overview removed", "shell became unavailable");
        }
        if had_overview {
            tracing::info!("cleared shell Overview policy");
        }
    }

    fn active_layout(&self) -> &Layout<Window> {
        self.workspaces.active_layout()
    }

    fn active_layout_mut(&mut self) -> &mut Layout<Window> {
        self.workspaces.active_layout_mut()
    }

    fn active_workspace_id(&self) -> u32 {
        self.workspaces.active_id()
    }

    pub fn workspace_snapshots(&self) -> Vec<WorkspaceSnapshot> {
        let active_id = self.active_workspace_id();
        self.workspaces
            .iter()
            .enumerate()
            .map(|(position, workspace)| WorkspaceSnapshot {
                id: workspace.id,
                position: position as u32,
                active: workspace.id == active_id,
            })
            .collect()
    }

    pub fn create_workspace(&mut self) {
        let (id, position) = self.workspaces.create();
        self.workspace_protocol_state.announce_created(
            &self.display_handle,
            WorkspaceSnapshot {
                id,
                position,
                active: false,
            },
        );
        tracing::info!(workspace_id = id, position, "created Workspace");
        self.activate_workspace(id);
    }

    pub fn activate_workspace(&mut self, id: u32) {
        if !self.workspaces.contains(id) || self.workspaces.is_active(id) {
            return;
        }

        let old_windows: Vec<_> = self
            .active_layout()
            .placements(self.layout_area())
            .into_iter()
            .map(|(window, _)| window)
            .collect();
        for window in old_windows {
            self.space.unmap_elem(&window);
        }

        if !self.workspaces.activate(id) {
            return;
        }
        self.configure_layout(false);
        if let Some(window) = self.active_layout().focused().cloned() {
            self.set_focus(&window);
        } else {
            let keyboard = self
                .seat
                .get_keyboard()
                .expect("the compositor always has a keyboard");
            keyboard.set_focus(
                self,
                Option::<WlSurface>::None,
                SERIAL_COUNTER.next_serial(),
            );
            self.toplevel_protocol_state.broadcast_active(None);
        }
        self.workspace_protocol_state.broadcast_active(id);
        tracing::info!(
            workspace_id = id,
            visible_window_count = self.active_layout().len(),
            "activated Workspace"
        );
    }

    pub fn toplevel_snapshots(&self) -> Vec<ToplevelSnapshot> {
        let active_surface = self
            .active_layout()
            .focused()
            .and_then(Window::toplevel)
            .map(|toplevel| toplevel.wl_surface());
        let mut snapshots = Vec::new();
        for workspace in self.workspaces.iter() {
            for (window, _) in workspace.layout.placements(self.layout_area()) {
                if window
                    .toplevel()
                    .is_some_and(|toplevel| is_shell_client_surface(toplevel.wl_surface()))
                {
                    continue;
                }
                if let Some(mut snapshot) = self.toplevel_snapshot(&window, workspace.id) {
                    snapshot.active = active_surface == Some(&snapshot.surface);
                    snapshots.push(snapshot);
                }
            }
        }
        snapshots
    }

    fn toplevel_snapshot(&self, window: &Window, workspace_id: u32) -> Option<ToplevelSnapshot> {
        let toplevel = window.toplevel()?;
        let (title, app_id) = toplevel_metadata(toplevel);
        Some(ToplevelSnapshot {
            surface: toplevel.wl_surface().clone(),
            workspace_id,
            title,
            app_id,
            active: false,
        })
    }

    pub fn update_toplevel_metadata(&mut self, surface: &ToplevelSurface) {
        if is_shell_client_surface(surface.wl_surface()) {
            return;
        }
        let (title, app_id) = toplevel_metadata(surface);
        self.toplevel_protocol_state
            .update_metadata(surface.wl_surface(), &title, &app_id);
        tracing::info!(%title, %app_id, "updated application toplevel metadata");
    }

    pub fn remove_toplevel(&mut self, surface: &ToplevelSurface) {
        self.toplevel_protocol_state.remove(surface.wl_surface());
    }

    pub fn activate_toplevel(&mut self, surface: &WlSurface) {
        let target = self.workspaces.iter().find_map(|workspace| {
            workspace
                .layout
                .placements(self.layout_area())
                .into_iter()
                .find(|(window, _)| {
                    window
                        .toplevel()
                        .is_some_and(|toplevel| toplevel.wl_surface() == surface)
                })
                .map(|(window, _)| (workspace.id, window))
        });
        let Some((workspace_id, window)) = target else {
            return;
        };
        self.activate_workspace(workspace_id);
        if self.set_focus(&window) {
            self.configure_layout(false);
        }
    }
}

fn toplevel_metadata(surface: &ToplevelSurface) -> (String, String) {
    with_states(surface.wl_surface(), |states| {
        let attributes = states
            .data_map
            .get::<XdgToplevelSurfaceData>()
            .expect("xdg toplevel state exists")
            .lock()
            .expect("xdg toplevel state lock is not poisoned");
        (
            attributes.title.clone().unwrap_or_default(),
            attributes.app_id.clone().unwrap_or_default(),
        )
    })
}

fn is_shell_client_surface(surface: &WlSurface) -> bool {
    surface
        .client()
        .and_then(|client| client.get_data::<ClientState>().map(ClientState::is_shell))
        .unwrap_or(false)
}

pub enum RegisterBarError {
    AlreadyHasBar,
    InvalidOutput,
}

pub enum RegisterOverviewError {
    AlreadyHasOverview,
    InvalidOutput,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
enum ClientKind {
    #[default]
    Application,
    Shell,
}

#[derive(Default)]
pub struct ClientState {
    pub compositor_state: CompositorClientState,
    kind: ClientKind,
    connection_alive: Option<Arc<AtomicBool>>,
}

impl ClientState {
    pub(crate) fn shell(connection_alive: Arc<AtomicBool>) -> Self {
        Self {
            compositor_state: CompositorClientState::default(),
            kind: ClientKind::Shell,
            connection_alive: Some(connection_alive),
        }
    }

    pub fn is_shell(&self) -> bool {
        self.kind == ClientKind::Shell
    }
}

impl ClientData for ClientState {
    fn initialized(&self, _client_id: ClientId) {}

    fn disconnected(&self, _client_id: ClientId, reason: DisconnectReason) {
        if let Some(connection_alive) = &self.connection_alive {
            connection_alive.store(false, Ordering::Release);
        }
        tracing::debug!(?reason, kind = ?self.kind, "Wayland client disconnected");
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn tiled_client_size_reserves_visible_frame_extents() {
        let tile = Rect::new(0, 0, 600, 742);
        let geometry = Rectangle::new((0, 0).into(), (600, 800).into());
        let bounds = Rectangle::new((-4, -30).into(), (608, 834).into());

        assert_eq!(tiled_client_size(tile, geometry, bounds), (592, 708).into());
    }

    #[test]
    fn tiled_location_places_visible_bounds_at_tile_origin() {
        let tile = Rect::new(600, 0, 600, 742);
        let bounds = Rectangle::new((-4, -30).into(), (608, 834).into());

        assert_eq!(tiled_window_location(tile, bounds), (604, 30).into());
    }
}
