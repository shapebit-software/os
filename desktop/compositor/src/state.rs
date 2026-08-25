use std::{
    collections::HashMap,
    ffi::OsString,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
    time::{Duration, Instant},
};

use smithay::{
    desktop::{PopupManager, Space, WindowSurfaceType},
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
        shell::xdg::{SurfaceCachedState, ToplevelSurface, XdgShellState, XdgToplevelSurfaceData},
        shm::ShmState,
        socket::ListeningSocketSource,
    },
};

use crate::protocols::{
    shell::ShellState,
    toplevel::{ToplevelProtocolState, ToplevelSnapshot},
    workspace::{WorkspaceProtocolState, WorkspaceSnapshot},
};
use crate::shell_supervisor::DevelopmentShellSupervisor;
use crate::workspaces::{WorkspaceDirection, WorkspaceSet};
use crate::{
    chrome::{
        CHROME_HEIGHT, CHROME_REVEAL_HEIGHT, ChromeButton, WINDOW_GUTTER, WindowChrome,
        chrome_button_at, compositor_controls_enabled, inset_window_rectangle,
    },
    layout::{DropEdge, Layout, Rect, ResizeHandle},
    window::Window,
};

const BAR_HEIGHT: i32 = 58;
const MINIMUM_TILE_WIDTH: i32 = 320;
const MINIMUM_TILE_HEIGHT: i32 = 240;
const WORKSPACE_EDGE_ZONE: i32 = 24;
const WORKSPACE_EDGE_HOLD_DELAY: Duration = Duration::from_millis(650);

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum Presentation {
    #[default]
    Normal,
    Expanded,
    Fullscreen,
}

#[derive(Clone, Debug)]
struct WindowDropTarget {
    window: Window,
    edge: DropEdge,
    preview: Rect,
}

#[derive(Clone, Debug)]
enum WindowDragTarget {
    Tile(WindowDropTarget),
    WorkspaceBar {
        workspace_id: u32,
        preview: Rect,
    },
    WorkspaceEdge {
        direction: WorkspaceDirection,
        preview: Rect,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum WindowDragTargetKey {
    Tile(usize, DropEdge),
    WorkspaceBar(u32),
    WorkspaceEdge(WorkspaceDirection),
}

impl WindowDragTarget {
    fn key(&self) -> WindowDragTargetKey {
        match self {
            Self::Tile(target) => WindowDragTargetKey::Tile(target.window.id(), target.edge),
            Self::WorkspaceBar { workspace_id, .. } => {
                WindowDragTargetKey::WorkspaceBar(*workspace_id)
            }
            Self::WorkspaceEdge { direction, .. } => WindowDragTargetKey::WorkspaceEdge(*direction),
        }
    }

    fn preview(&self) -> Rect {
        match self {
            Self::Tile(target) => target.preview,
            Self::WorkspaceBar { preview, .. } => *preview,
            Self::WorkspaceEdge { preview, .. } => *preview,
        }
    }
}

#[derive(Clone, Debug)]
struct WindowDrag {
    window: Window,
    start: Point<f64, Logical>,
    origin: Point<i32, Logical>,
    target: Option<WindowDragTarget>,
    edge_hold_started: Option<(WorkspaceDirection, Instant)>,
    latched_edge: Option<WorkspaceDirection>,
    transferred_during_hold: bool,
}

fn presented_rectangle(
    presentation: Presentation,
    tile: Rect,
    layout_area: Rect,
    output_size: Size<i32, Logical>,
) -> Rect {
    match presentation {
        Presentation::Normal => tile,
        Presentation::Expanded => layout_area,
        Presentation::Fullscreen => Rect::new(0, 0, output_size.w.max(1), output_size.h.max(1)),
    }
}

fn tiled_client_size(tile: Rect) -> Size<i32, Logical> {
    (tile.width.max(1), tile.height.max(1)).into()
}

fn tiled_window_location(tile: Rect) -> Point<i32, Logical> {
    (tile.x, tile.y).into()
}

fn minimum_tile_size(window: &Window) -> (i32, i32) {
    let requested = window.toplevel().map_or((0, 0).into(), |toplevel| {
        with_states(toplevel.wl_surface(), |states| {
            states
                .cached_state
                .get::<SurfaceCachedState>()
                .current()
                .min_size
        })
    });
    (
        requested.w.max(MINIMUM_TILE_WIDTH) + WINDOW_GUTTER * 2,
        requested.h.max(MINIMUM_TILE_HEIGHT) + WINDOW_GUTTER * 2,
    )
}

fn point_in_rect(position: Point<f64, Logical>, rectangle: Rect) -> bool {
    position.x >= f64::from(rectangle.x)
        && position.x < f64::from(rectangle.x + rectangle.width)
        && position.y >= f64::from(rectangle.y)
        && position.y < f64::from(rectangle.y + rectangle.height)
}

fn closest_drop_edge(position: Point<f64, Logical>, rectangle: Rect) -> DropEdge {
    let distances = [
        (position.x - f64::from(rectangle.x), DropEdge::Left),
        (
            f64::from(rectangle.x + rectangle.width) - position.x,
            DropEdge::Right,
        ),
        (position.y - f64::from(rectangle.y), DropEdge::Top),
        (
            f64::from(rectangle.y + rectangle.height) - position.y,
            DropEdge::Bottom,
        ),
    ];
    distances
        .into_iter()
        .min_by(|(left, _), (right, _)| left.total_cmp(right))
        .expect("a rectangle always has four edges")
        .1
}

fn workspace_edge_direction(
    position: Point<f64, Logical>,
    output_size: Size<i32, Logical>,
) -> Option<WorkspaceDirection> {
    if position.y < 0.0
        || position.y >= f64::from(output_size.h)
        || position.x < 0.0
        || position.x >= f64::from(output_size.w)
    {
        return None;
    }
    let left_distance = position.x;
    let right_distance = f64::from(output_size.w) - position.x;
    if left_distance <= f64::from(WORKSPACE_EDGE_ZONE) && left_distance <= right_distance {
        Some(WorkspaceDirection::Previous)
    } else if right_distance <= f64::from(WORKSPACE_EDGE_ZONE) {
        Some(WorkspaceDirection::Next)
    } else {
        None
    }
}

fn workspace_edge_hold_elapsed(started: Instant, now: Instant) -> bool {
    now.saturating_duration_since(started) >= WORKSPACE_EDGE_HOLD_DELAY
}

fn update_workspace_edge_hold_state(
    started: &mut Option<(WorkspaceDirection, Instant)>,
    latched: &mut Option<WorkspaceDirection>,
    target: Option<WorkspaceDirection>,
    now: Instant,
) -> bool {
    match target {
        Some(direction) if *latched == Some(direction) => {
            *started = None;
            true
        }
        Some(direction) => {
            if started.is_none_or(|(known, _)| known != direction) {
                *started = Some((direction, now));
            }
            false
        }
        None => {
            *started = None;
            *latched = None;
            false
        }
    }
}

fn workspace_bar_drop_target_at(
    targets: &[(u32, Rect)],
    active_id: u32,
    position: Point<f64, Logical>,
    output_size: Size<i32, Logical>,
) -> Option<(u32, Rect)> {
    let bar_y = (output_size.h - BAR_HEIGHT).max(0);
    targets
        .iter()
        .filter(|(workspace_id, _)| *workspace_id != active_id)
        .find_map(|(workspace_id, rectangle)| {
            let output_rectangle = Rect::new(
                rectangle.x,
                bar_y + rectangle.y,
                rectangle.width,
                rectangle.height,
            );
            point_in_rect(position, output_rectangle).then_some((*workspace_id, output_rectangle))
        })
}

pub struct Compositor {
    pub start_time: std::time::Instant,
    pub socket_name: OsString,
    pub display_handle: DisplayHandle,
    pub space: Space<Window>,
    pub loop_signal: LoopSignal,
    pub compositor_state: CompositorState,
    pub xdg_shell_state: XdgShellState,
    _xdg_decoration_state: smithay::wayland::shell::xdg::decoration::XdgDecorationState,
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
    bar_workspace_drop_targets: Vec<(u32, Rect)>,
    overview_surface: Option<WlSurface>,
    _overview_output: Option<Output>,
    overview_window: Option<Window>,
    overview_visible: bool,
    overview_previews: Vec<(WlSurface, Rectangle<i32, Logical>)>,
    presentations: HashMap<usize, Presentation>,
    layout_resize: Option<ResizeHandle>,
    window_drag: Option<WindowDrag>,
    server_decorated_surfaces: Vec<WlSurface>,
    hovered_window_chrome: Option<usize>,
    pointer_location: Point<f64, Logical>,
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
        let xdg_decoration_state =
            smithay::wayland::shell::xdg::decoration::XdgDecorationState::new::<Self>(
                &display_handle,
            );
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
            _xdg_decoration_state: xdg_decoration_state,
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
            bar_workspace_drop_targets: Vec::new(),
            overview_surface: None,
            _overview_output: None,
            overview_window: None,
            overview_visible: false,
            overview_previews: Vec::new(),
            presentations: HashMap::new(),
            layout_resize: None,
            window_drag: None,
            server_decorated_surfaces: Vec::new(),
            hovered_window_chrome: None,
            pointer_location: (0.0, 0.0).into(),
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
            window.set_content_only(false);
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
            window.set_content_only(false);
            self.overview_window = Some(window);
            self.configure_overview(true);
            return;
        }
        let area = self.layout_area();
        let insertion = self.active_layout_mut().insert_with_minimum(
            window.clone(),
            area,
            minimum_tile_size(&window),
        );
        tracing::info!(
            window_count = self.active_layout().len(),
            region_count = self.active_layout().region_count(),
            workspace_id = self.active_workspace_id(),
            placement = ?insertion,
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
        self.update_window_edge_hold(Instant::now());
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
        let focused_closed = self
            .active_layout()
            .focused()
            .is_some_and(|window| !window.alive());
        if self.workspaces.retain_alive() {
            self.configure_layout(false);
            if focused_closed && let Some(window) = self.active_layout().focused().cloned() {
                self.set_focus(&window);
                self.configure_layout(false);
            }
        }
        self.shell_supervisor.restart_if_due(
            &mut self.display_handle,
            &self.socket_name,
            self.bar_surface.is_none() && self.overview_surface.is_none(),
        );
    }

    pub fn commit_window(&mut self, window: &Window) {
        window.on_commit();
        let minimum = minimum_tile_size(window);
        for workspace in self.workspaces.iter_mut() {
            workspace.layout.update_minimum(window, minimum);
        }
        let is_tiled = self
            .active_layout()
            .items()
            .into_iter()
            .any(|candidate| candidate == *window);
        if is_tiled && self.configure_layout(false) {
            tracing::info!(
                window_id = window.id(),
                "reconfigured tiled layout after committed window geometry"
            );
        } else {
            self.align_layout_positions();
        }
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
        self.sync_layout_visibility();

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
        self.space.raise_element(window, false);
        self.configure_bar(false);
        self.raise_shell_surfaces();
        true
    }

    pub fn set_presentation(&mut self, surface: &WlSurface, presentation: Presentation) {
        if self.window_drag.as_ref().is_some_and(|drag| {
            drag.window
                .toplevel()
                .is_some_and(|toplevel| toplevel.wl_surface() == surface)
        }) {
            self.cancel_window_drag();
        }
        let Some(window) = self.window_for_surface(surface) else {
            return;
        };
        if presentation == Presentation::Normal {
            self.presentations.remove(&window.id());
        } else {
            self.presentations.insert(window.id(), presentation);
        }
        self.configure_bar(false);
        self.configure_layout(false);
        if self.active_layout().focused() == Some(&window) {
            self.space.raise_element(&window, false);
        }
        self.raise_shell_surfaces();
        tracing::info!(
            window_id = window.id(),
            ?presentation,
            "changed window presentation"
        );
    }

    pub fn begin_layout_resize(&mut self, position: Point<f64, Logical>) -> bool {
        let focused_is_normal = self
            .active_layout()
            .focused()
            .is_none_or(|window| self.presentation(window) == Presentation::Normal);
        if self.overview_visible || !focused_is_normal {
            return false;
        }
        self.layout_resize = self.active_layout().boundary_at(
            position.x.round() as i32,
            position.y.round() as i32,
            self.layout_area(),
            6,
        );
        self.layout_resize.is_some()
    }

    pub fn update_layout_resize(&mut self, position: Point<f64, Logical>) -> bool {
        let Some(handle) = self.layout_resize.clone() else {
            return false;
        };
        let area = self.layout_area();
        if self.active_layout_mut().resize_boundary(
            &handle,
            position.x.round() as i32,
            position.y.round() as i32,
            area,
        ) {
            self.configure_layout(false);
        }
        true
    }

    pub fn end_layout_resize(&mut self) -> bool {
        self.layout_resize.take().is_some()
    }

    pub fn begin_window_drag(&mut self, window: Window, start: Point<f64, Logical>) -> bool {
        let is_active_tiled = self
            .active_layout()
            .items()
            .into_iter()
            .any(|candidate| candidate == window);
        if self.overview_visible
            || self.layout_resize.is_some()
            || self.window_drag.is_some()
            || !is_active_tiled
            || self.presentation(&window) != Presentation::Normal
        {
            return false;
        }
        let Some(origin) = self.space.element_location(&window) else {
            return false;
        };
        self.window_drag = Some(WindowDrag {
            window: window.clone(),
            start,
            origin,
            target: None,
            edge_hold_started: None,
            latched_edge: None,
            transferred_during_hold: false,
        });
        self.space.raise_element(&window, true);
        self.raise_shell_surfaces();
        tracing::info!(
            window_id = window.id(),
            "started interactive tiled window drag"
        );
        true
    }

    pub fn update_window_drag(&mut self, position: Point<f64, Logical>) -> bool {
        let Some(drag) = self.window_drag.as_ref() else {
            return false;
        };
        let window = drag.window.clone();
        let next_location = (drag.origin.to_f64() + (position - drag.start)).to_i32_round();
        self.space.map_element(window.clone(), next_location, true);

        let mut target = self.window_drag_target(&window, position);
        let changed = if let Some(drag) = self.window_drag.as_mut() {
            let edge = target.as_ref().and_then(|target| match target {
                WindowDragTarget::WorkspaceEdge { direction, .. } => Some(*direction),
                _ => None,
            });
            if update_workspace_edge_hold_state(
                &mut drag.edge_hold_started,
                &mut drag.latched_edge,
                edge,
                Instant::now(),
            ) {
                target = None;
            }
            let changed = drag.target.as_ref().map(WindowDragTarget::key)
                != target.as_ref().map(WindowDragTarget::key);
            drag.target = target;
            changed
        } else {
            false
        };
        if changed {
            if let Some(target) = self
                .window_drag
                .as_ref()
                .and_then(|drag| drag.target.as_ref())
            {
                match target {
                    WindowDragTarget::Tile(target) => tracing::info!(
                        window_id = window.id(),
                        target_window_id = target.window.id(),
                        edge = ?target.edge,
                        "updated tiled window drop preview"
                    ),
                    WindowDragTarget::WorkspaceBar { workspace_id, .. } => tracing::info!(
                        window_id = window.id(),
                        workspace_id,
                        "targeted Workspace bar segment transfer"
                    ),
                    WindowDragTarget::WorkspaceEdge { direction, .. } => tracing::info!(
                        window_id = window.id(),
                        ?direction,
                        "targeted quick Workspace edge transfer"
                    ),
                }
            } else {
                tracing::info!(window_id = window.id(), "cleared tiled window drop preview");
            }
        }
        true
    }

    pub fn update_window_chrome_hover(&mut self, position: Point<f64, Logical>) {
        self.pointer_location = position;
        let previous = self.hovered_window_chrome;
        self.hovered_window_chrome = self
            .window_chromes()
            .into_iter()
            .filter(|chrome| chrome.controls_enabled)
            .find(|chrome| {
                if chrome.collapsed {
                    point_in_rect(position, chrome.rectangle)
                } else {
                    let reveal = Rect::new(
                        chrome.rectangle.x,
                        chrome.rectangle.y,
                        chrome.rectangle.width,
                        CHROME_REVEAL_HEIGHT.min(chrome.rectangle.height),
                    );
                    point_in_rect(position, reveal)
                        || (previous == Some(chrome.window_id)
                            && point_in_rect(
                                position,
                                Rect::new(
                                    chrome.rectangle.x,
                                    chrome.rectangle.y,
                                    chrome.rectangle.width,
                                    CHROME_HEIGHT.min(chrome.rectangle.height),
                                ),
                            ))
                }
            })
            .map(|chrome| chrome.window_id);
    }

    pub fn press_window_chrome(&mut self, position: Point<f64, Logical>) -> bool {
        let Some(chrome) = self.window_chromes().into_iter().find(|chrome| {
            chrome.controls_enabled
                && chrome.window_id == self.hovered_window_chrome.unwrap_or(usize::MAX)
        }) else {
            return false;
        };
        let Some(window) = self
            .active_layout()
            .items()
            .into_iter()
            .find(|window| window.id() == chrome.window_id)
        else {
            return false;
        };

        if chrome.collapsed {
            if self.active_layout_mut().restore(&window) {
                self.configure_layout(false);
                self.set_focus(&window);
                tracing::info!(
                    window_id = window.id(),
                    "restored collapsed window from spine"
                );
            }
            return true;
        }

        match chrome_button_at(chrome.rectangle, position) {
            Some(ChromeButton::Close) => {
                if let Some(toplevel) = window.toplevel() {
                    toplevel.send_close();
                    tracing::info!(
                        window_id = window.id(),
                        "requested window close from chrome"
                    );
                }
            }
            Some(ChromeButton::Collapse) => {
                if self.active_layout_mut().collapse(&window) {
                    self.configure_layout(false);
                    self.focus_active_layout_fallback();
                    tracing::info!(window_id = window.id(), "collapsed tiled window to spine");
                }
            }
            Some(ChromeButton::Focus) => {
                let presentation = if self.presentation(&window) == Presentation::Expanded {
                    Presentation::Normal
                } else {
                    Presentation::Expanded
                };
                let surface = window
                    .toplevel()
                    .expect("an ordinary window has an xdg toplevel")
                    .wl_surface()
                    .clone();
                self.set_presentation(&surface, presentation);
                self.set_focus(&window);
            }
            None => {
                self.set_focus(&window);
                self.begin_window_drag(window, position);
            }
        }
        true
    }

    pub fn pointer_over_window_chrome(&self, position: Point<f64, Logical>) -> bool {
        self.window_chromes().into_iter().any(|chrome| {
            chrome.controls_enabled
                && chrome.window_id == self.hovered_window_chrome.unwrap_or(usize::MAX)
                && (chrome.collapsed
                    || point_in_rect(
                        position,
                        Rect::new(
                            chrome.rectangle.x,
                            chrome.rectangle.y,
                            chrome.rectangle.width,
                            CHROME_HEIGHT.min(chrome.rectangle.height),
                        ),
                    ))
        })
    }

    pub fn window_chromes(&self) -> Vec<WindowChrome> {
        let focused = self.active_layout().focused().map(Window::id);
        let dragged = self.window_drag.as_ref().map(|drag| drag.window.id());
        let mut chromes: Vec<_> = self
            .presented_placements()
            .into_iter()
            .filter(|(window, _)| self.presentation(window) != Presentation::Fullscreen)
            .map(|(window, mut rectangle)| {
                if dragged == Some(window.id())
                    && let Some(location) = self.space.element_location(&window)
                {
                    rectangle.x = location.x;
                    rectangle.y = location.y;
                }
                self.window_chrome(window, rectangle, false, focused, dragged)
            })
            .collect();
        chromes.extend(
            self.active_layout()
                .collapsed_placements(self.layout_area())
                .into_iter()
                .map(|(window, rectangle)| {
                    self.window_chrome(
                        window,
                        inset_window_rectangle(rectangle),
                        true,
                        focused,
                        dragged,
                    )
                }),
        );
        chromes
    }

    fn window_chrome(
        &self,
        window: Window,
        rectangle: Rect,
        collapsed: bool,
        focused: Option<usize>,
        dragged: Option<usize>,
    ) -> WindowChrome {
        let (title, application_id) = window.toplevel().map(toplevel_metadata).unwrap_or_default();
        let application = application_id
            .rsplit('.')
            .next()
            .filter(|name| !name.is_empty())
            .unwrap_or_else(|| {
                if title.is_empty() {
                    "Application"
                } else {
                    &title
                }
            })
            .replace(['-', '_'], " ");
        let window_id = window.id();
        let server_decorated = window.toplevel().is_some_and(|toplevel| {
            self.server_decorated_surfaces
                .iter()
                .any(|surface| surface == toplevel.wl_surface())
        });
        let controls_enabled = compositor_controls_enabled(server_decorated, collapsed);
        let revealed = controls_enabled
            && (collapsed
                || self.hovered_window_chrome == Some(window_id)
                || dragged == Some(window_id));
        WindowChrome {
            window_id,
            rectangle,
            application,
            title,
            focused: focused == Some(window_id),
            revealed,
            collapsed,
            controls_enabled,
            hovered_button: revealed
                .then(|| chrome_button_at(rectangle, self.pointer_location))
                .flatten(),
        }
    }

    fn update_window_edge_hold(&mut self, now: Instant) -> bool {
        let Some((window, direction, started)) = self.window_drag.as_ref().and_then(|drag| {
            drag.edge_hold_started
                .map(|(direction, started)| (drag.window.clone(), direction, started))
        }) else {
            return false;
        };
        if !workspace_edge_hold_elapsed(started, now) {
            return false;
        }

        let drag_location = self.space.element_location(&window);
        let target_id = self
            .workspaces
            .adjacent_id(direction)
            .unwrap_or_else(|| self.create_background_workspace(direction));
        if let Some(drag) = self.window_drag.as_mut() {
            drag.edge_hold_started = None;
            drag.latched_edge = Some(direction);
            drag.target = None;
        }
        let Some(placement) = self.transfer_window_to_workspace(&window, target_id) else {
            return false;
        };
        if let Some(drag) = self.window_drag.as_mut() {
            drag.transferred_during_hold = true;
        }
        self.activate_workspace_during_drag(target_id, &window);
        if let Some(location) = drag_location {
            self.space.map_element(window.clone(), location, true);
            self.raise_shell_surfaces();
        }
        tracing::info!(
            window_id = window.id(),
            workspace_id = target_id,
            ?direction,
            ?placement,
            "opened Workspace after held window edge drag"
        );
        true
    }

    pub fn end_window_drag(&mut self) -> bool {
        let Some(drag) = self.window_drag.take() else {
            return false;
        };
        let result = match drag.target {
            Some(WindowDragTarget::Tile(target)) => {
                let area = self.layout_area();
                let minimum = minimum_tile_size(&drag.window);
                self.active_layout_mut().move_next_to(
                    &drag.window,
                    &target.window,
                    target.edge,
                    area,
                    minimum,
                )
            }
            Some(WindowDragTarget::WorkspaceBar { workspace_id, .. }) => {
                let placement = self.transfer_window_to_workspace(&drag.window, workspace_id);
                if let Some(placement) = placement {
                    tracing::info!(
                        window_id = drag.window.id(),
                        workspace_id,
                        ?placement,
                        "committed Workspace bar drop"
                    );
                } else {
                    self.configure_layout(false);
                }
                return true;
            }
            Some(WindowDragTarget::WorkspaceEdge { direction, .. }) => {
                self.transfer_window_at_edge(&drag.window, direction);
                return true;
            }
            None => None,
        };
        self.configure_layout(false);
        if let Some(placement) = result {
            self.set_focus(&drag.window);
            tracing::info!(
                window_id = drag.window.id(),
                ?placement,
                "committed tiled window drop"
            );
        } else if drag.transferred_during_hold {
            self.set_focus(&drag.window);
            tracing::info!(
                window_id = drag.window.id(),
                "completed held Workspace transfer at automatic insertion"
            );
        } else {
            tracing::info!(
                window_id = drag.window.id(),
                "restored tiled window after cancelled drop"
            );
        }
        true
    }

    pub fn cancel_window_drag(&mut self) -> bool {
        let Some(drag) = self.window_drag.take() else {
            return false;
        };
        self.configure_layout(false);
        tracing::info!(
            window_id = drag.window.id(),
            "cancelled interactive tiled window drag"
        );
        true
    }

    pub fn window_drop_preview(&self) -> Option<Rectangle<i32, Logical>> {
        self.window_drag.as_ref()?.target.as_ref().map(|target| {
            let preview = target.preview();
            Rectangle::new(
                (preview.x, preview.y).into(),
                (preview.width, preview.height).into(),
            )
        })
    }

    fn window_drag_target(
        &self,
        dragged: &Window,
        position: Point<f64, Logical>,
    ) -> Option<WindowDragTarget> {
        if let Some((workspace_id, preview)) = workspace_bar_drop_target_at(
            &self.bar_workspace_drop_targets,
            self.active_workspace_id(),
            position,
            self.output_size,
        ) {
            return Some(WindowDragTarget::WorkspaceBar {
                workspace_id,
                preview,
            });
        }
        if let Some(direction) = workspace_edge_direction(position, self.output_size) {
            let area = self.layout_area();
            let width = WORKSPACE_EDGE_ZONE.min(area.width);
            let x = match direction {
                WorkspaceDirection::Previous => area.x,
                WorkspaceDirection::Next => area.x + area.width - width,
            };
            return Some(WindowDragTarget::WorkspaceEdge {
                direction,
                preview: Rect::new(x, area.y, width, area.height),
            });
        }
        self.window_drop_target(dragged, position)
            .map(WindowDragTarget::Tile)
    }

    fn window_drop_target(
        &self,
        dragged: &Window,
        position: Point<f64, Logical>,
    ) -> Option<WindowDropTarget> {
        let area = self.layout_area();
        let (window, rectangle) = self
            .active_layout()
            .placements(self.layout_area())
            .into_iter()
            .filter(|(window, _)| window != dragged)
            .find(|(_, rectangle)| point_in_rect(position, *rectangle))?;
        let edge = closest_drop_edge(position, rectangle);
        let mut preview_layout = self.active_layout().clone();
        preview_layout.move_next_to(dragged, &window, edge, area, minimum_tile_size(dragged))?;
        let preview = preview_layout
            .placements(area)
            .into_iter()
            .find_map(|(window, rectangle)| (window == *dragged).then_some(rectangle))?;
        Some(WindowDropTarget {
            window,
            edge,
            preview,
        })
    }

    fn transfer_window_at_edge(&mut self, window: &Window, direction: WorkspaceDirection) -> bool {
        let (target_id, created) = match self.workspaces.adjacent_id(direction) {
            Some(id) => (id, false),
            None => (self.create_background_workspace(direction), true),
        };
        let Some(placement) = self.transfer_window_to_workspace(window, target_id) else {
            self.configure_layout(false);
            return false;
        };
        tracing::info!(
            window_id = window.id(),
            workspace_id = target_id,
            ?direction,
            created,
            ?placement,
            "committed quick Workspace edge transfer"
        );
        true
    }

    fn create_background_workspace(&mut self, direction: WorkspaceDirection) -> u32 {
        let position = match direction {
            WorkspaceDirection::Previous => 0,
            WorkspaceDirection::Next => self.workspaces.len(),
        };
        let (id, position) = self.workspaces.create_at(position);
        self.workspace_protocol_state.announce_created(
            &self.display_handle,
            WorkspaceSnapshot {
                id,
                position,
                active: false,
            },
        );
        let snapshots = self.workspace_snapshots();
        self.workspace_protocol_state
            .broadcast_positions(&snapshots);
        tracing::info!(
            workspace_id = id,
            position,
            ?direction,
            "created background Workspace"
        );
        id
    }

    fn transfer_window_to_workspace(
        &mut self,
        window: &Window,
        target_id: u32,
    ) -> Option<crate::layout::InsertResult> {
        let source_id = self.workspaces.iter().find_map(|workspace| {
            workspace
                .layout
                .items()
                .contains(window)
                .then_some(workspace.id)
        })?;
        if source_id == target_id || !self.workspaces.contains(target_id) {
            return None;
        }
        let source_was_active = self.workspaces.is_active(source_id);
        let target_is_active = self.workspaces.is_active(target_id);
        let window_is_being_dragged = self
            .window_drag
            .as_ref()
            .is_some_and(|drag| drag.window == *window);
        let removed = self
            .workspaces
            .layout_mut(source_id)?
            .retain(|candidate| candidate != window);
        if !removed {
            return None;
        }
        let area = self.layout_area();
        let placement = self.workspaces.layout_mut(target_id)?.insert_with_minimum(
            window.clone(),
            area,
            minimum_tile_size(window),
        );

        let surface = window.toplevel()?.wl_surface().clone();
        ToplevelProtocolState::broadcast_workspace(self, &surface, target_id);
        if source_was_active {
            if !window_is_being_dragged {
                self.space.unmap_elem(window);
            }
            self.configure_layout(false);
            self.focus_active_layout_fallback();
        } else if target_is_active {
            self.configure_layout(false);
            self.set_focus(window);
        }
        self.configure_bar(false);
        Some(placement)
    }

    fn focus_active_layout_fallback(&mut self) {
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
            self.configure_bar(false);
        }
    }

    pub fn surface_under(
        &self,
        position: Point<f64, Logical>,
    ) -> Option<(WlSurface, Point<f64, Logical>)> {
        if self.pointer_over_window_chrome(position) {
            return None;
        }
        self.space
            .element_under(position)
            .and_then(|(window, location)| {
                window
                    .surface_under(position - location.to_f64(), WindowSurfaceType::ALL)
                    .map(|(surface, offset)| (surface, (offset + location).to_f64()))
            })
    }

    pub fn window_for_surface(&self, surface: &WlSurface) -> Option<Window> {
        self.space
            .elements()
            .find(|window| {
                window
                    .toplevel()
                    .is_some_and(|toplevel| toplevel.wl_surface() == surface)
            })
            .cloned()
            .or_else(|| {
                self.workspaces
                    .iter()
                    .flat_map(|workspace| workspace.layout.items())
                    .find(|window| {
                        window
                            .toplevel()
                            .is_some_and(|toplevel| toplevel.wl_surface() == surface)
                    })
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

    fn presented_placements(&self) -> Vec<(Window, Rect)> {
        let layout_area = self.layout_area();
        self.active_layout()
            .placements(layout_area)
            .into_iter()
            .map(|(window, tile)| {
                let rectangle = presented_rectangle(
                    self.presentation(&window),
                    tile,
                    layout_area,
                    self.output_size,
                );
                let rectangle = if self.presentation(&window) == Presentation::Normal {
                    inset_window_rectangle(rectangle)
                } else {
                    rectangle
                };
                (window, rectangle)
            })
            .collect()
    }

    fn presentation(&self, window: &Window) -> Presentation {
        self.presentations
            .get(&window.id())
            .copied()
            .unwrap_or_default()
    }

    fn foreground_fullscreen(&self) -> bool {
        self.active_layout()
            .focused()
            .is_some_and(|window| self.presentation(window) == Presentation::Fullscreen)
    }

    fn configure_layout(&mut self, allow_initial: bool) -> bool {
        self.sync_layout_visibility();
        let focused = self.active_layout().focused().cloned();
        let layout_area = self.layout_area();
        let placements = self.presented_placements();
        let mut configure_sent = false;
        for (window, rect) in placements {
            let Some(toplevel) = window.toplevel() else {
                continue;
            };
            let client_size = tiled_client_size(rect);
            window.set_activated(focused.as_ref() == Some(&window));
            let presentation = self.presentation(&window);
            let bounds_size = if presentation == Presentation::Fullscreen {
                self.output_size
            } else {
                (layout_area.width, layout_area.height).into()
            };
            toplevel.with_pending_state(|state| {
                state.size = Some(client_size);
                state.bounds = Some(bounds_size);
                for tiled_state in [
                    xdg_toplevel::State::TiledLeft,
                    xdg_toplevel::State::TiledRight,
                    xdg_toplevel::State::TiledTop,
                    xdg_toplevel::State::TiledBottom,
                ] {
                    state.states.unset(tiled_state);
                }
                state.states.unset(xdg_toplevel::State::Maximized);
                state.states.unset(xdg_toplevel::State::Fullscreen);
                match presentation {
                    Presentation::Normal => {
                        for tiled_state in [
                            xdg_toplevel::State::TiledLeft,
                            xdg_toplevel::State::TiledRight,
                            xdg_toplevel::State::TiledTop,
                            xdg_toplevel::State::TiledBottom,
                        ] {
                            state.states.set(tiled_state);
                        }
                    }
                    Presentation::Expanded => {
                        state.states.set(xdg_toplevel::State::Maximized);
                    }
                    Presentation::Fullscreen => {
                        state.states.set(xdg_toplevel::State::Fullscreen);
                    }
                }
            });
            if allow_initial && !toplevel.is_initial_configure_sent() {
                toplevel.send_configure();
                configure_sent = true;
            } else {
                configure_sent |= toplevel.send_pending_configure().is_some();
            }
        }
        self.align_layout_positions();
        configure_sent
    }

    fn sync_layout_visibility(&mut self) {
        let visible: Vec<_> = self
            .active_layout()
            .placements(self.layout_area())
            .into_iter()
            .map(|(window, _)| window)
            .collect();
        for window in self.active_layout().items() {
            if visible.contains(&window) {
                if self.space.element_location(&window).is_none() {
                    self.space.map_element(window, (0, 0), false);
                }
            } else {
                self.space.unmap_elem(&window);
            }
        }
    }

    fn align_layout_positions(&mut self) {
        let placements = self.presented_placements();
        let mut changed = false;
        for (window, rect) in placements {
            if self
                .window_drag
                .as_ref()
                .is_some_and(|drag| drag.window == window)
            {
                continue;
            }
            let target = tiled_window_location(rect);
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
        if self.foreground_fullscreen() && !self.overview_visible {
            self.space.unmap_elem(&window);
        } else {
            self.space
                .map_element(window.clone(), (-geometry.loc.x, y - geometry.loc.y), false);
        }
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
            window.set_content_only(false);
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

    pub fn clear_bar_workspace_drop_targets(&mut self, surface: &WlSurface) {
        if self.bar_surface.as_ref() == Some(surface) {
            self.bar_workspace_drop_targets.clear();
        }
    }

    pub fn set_bar_workspace_drop_target(
        &mut self,
        surface: &WlSurface,
        workspace_id: u32,
        rectangle: Rect,
    ) {
        let right = i64::from(rectangle.x) + i64::from(rectangle.width);
        let bottom = i64::from(rectangle.y) + i64::from(rectangle.height);
        if self.bar_surface.as_ref() != Some(surface)
            || !self.workspaces.contains(workspace_id)
            || rectangle.x < 0
            || rectangle.y < 0
            || rectangle.width <= 0
            || rectangle.height <= 0
            || right > i64::from(self.output_size.w)
            || bottom > i64::from(BAR_HEIGHT)
        {
            return;
        }
        self.bar_workspace_drop_targets
            .retain(|(id, _)| *id != workspace_id);
        self.bar_workspace_drop_targets
            .push((workspace_id, rectangle));
        tracing::info!(
            workspace_id,
            x = rectangle.x,
            y = rectangle.y,
            width = rectangle.width,
            height = rectangle.height,
            "configured Workspace bar drop target"
        );
    }

    fn clear_bar(&mut self) {
        let had_bar = self.bar_surface.is_some() || self.bar_window.is_some();
        if let Some(window) = self.bar_window.take() {
            self.space.unmap_elem(&window);
        }
        self.bar_surface = None;
        self._bar_output = None;
        self.bar_workspace_drop_targets.clear();
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
            window.set_content_only(false);
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
        self.cancel_window_drag();
        self.overview_visible = true;
        self.configure_bar(false);
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
                    .flat_map(|workspace| workspace.layout.items())
                    .find(|window| {
                        window
                            .toplevel()
                            .is_some_and(|toplevel| toplevel.wl_surface() == surface)
                    })
                    .map(|window| (window, *rectangle))
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

    pub fn reorder_workspace(&mut self, id: u32, position: u32) {
        if !self.workspaces.reorder(id, position) {
            return;
        }
        let snapshots = self.workspace_snapshots();
        self.workspace_protocol_state
            .broadcast_positions(&snapshots);
        let position = snapshots
            .iter()
            .find(|workspace| workspace.id == id)
            .map_or(position, |workspace| workspace.position);
        tracing::info!(workspace_id = id, position, "reordered Workspace");
    }

    pub fn activate_workspace(&mut self, id: u32) {
        if !self.workspaces.contains(id) || self.workspaces.is_active(id) {
            return;
        }

        self.cancel_window_drag();

        let old_windows: Vec<_> = self.active_layout().items();
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
            visible_window_count = self.active_layout().region_count(),
            "activated Workspace"
        );
    }

    fn activate_workspace_during_drag(&mut self, id: u32, window: &Window) {
        if !self.workspaces.contains(id) || self.workspaces.is_active(id) {
            return;
        }

        let old_windows = self.active_layout().items();
        for old_window in old_windows {
            self.space.unmap_elem(&old_window);
        }

        if !self.workspaces.activate(id) {
            return;
        }
        self.configure_layout(false);
        self.set_focus(window);
        self.workspace_protocol_state.broadcast_active(id);
        tracing::info!(
            workspace_id = id,
            visible_window_count = self.active_layout().region_count(),
            "activated Workspace during held window drag"
        );
    }

    pub fn toplevel_snapshots(&self) -> Vec<ToplevelSnapshot> {
        let active_surface = self
            .active_layout()
            .focused()
            .and_then(|window| window.toplevel())
            .map(|toplevel| toplevel.wl_surface());
        let mut snapshots = Vec::new();
        for workspace in self.workspaces.iter() {
            for window in workspace.layout.items() {
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
        if self.window_drag.as_ref().is_some_and(|drag| {
            drag.window
                .toplevel()
                .is_some_and(|toplevel| toplevel.wl_surface() == surface.wl_surface())
        }) {
            self.window_drag = None;
        }
        if let Some(window) = self.window_for_surface(surface.wl_surface()) {
            self.presentations.remove(&window.id());
        }
        self.server_decorated_surfaces
            .retain(|candidate| candidate != surface.wl_surface());
        self.toplevel_protocol_state.remove(surface.wl_surface());
    }

    pub fn mark_server_decorated(&mut self, surface: &WlSurface) {
        if !self
            .server_decorated_surfaces
            .iter()
            .any(|candidate| candidate == surface)
        {
            self.server_decorated_surfaces.push(surface.clone());
        }
    }

    pub fn activate_toplevel(&mut self, surface: &WlSurface) {
        let target = self.workspaces.iter().find_map(|workspace| {
            workspace
                .layout
                .items()
                .into_iter()
                .find(|window| {
                    window
                        .toplevel()
                        .is_some_and(|toplevel| toplevel.wl_surface() == surface)
                })
                .map(|window| (workspace.id, window))
        });
        let Some((workspace_id, window)) = target else {
            return;
        };
        self.activate_workspace(workspace_id);
        if self.set_focus(&window) {
            self.configure_layout(false);
        }
    }

    pub fn move_toplevel_to_workspace(&mut self, surface: &WlSurface, workspace_id: u32) {
        let Some(window) = self.window_for_surface(surface) else {
            return;
        };
        let Some(placement) = self.transfer_window_to_workspace(&window, workspace_id) else {
            return;
        };
        tracing::info!(
            window_id = window.id(),
            workspace_id,
            ?placement,
            "moved toplevel to Workspace"
        );
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
    fn tiled_client_size_matches_content_tile() {
        let tile = Rect::new(0, 0, 600, 742);

        assert_eq!(tiled_client_size(tile), (600, 742).into());
    }

    #[test]
    fn tiled_location_places_content_at_tile_origin() {
        let tile = Rect::new(600, 0, 600, 742);

        assert_eq!(tiled_window_location(tile), (600, 0).into());
    }

    #[test]
    fn presentation_changes_rendered_geometry_without_changing_the_tile() {
        let tile = Rect::new(600, 0, 600, 742);
        let layout_area = Rect::new(0, 0, 1200, 742);
        let output_size = (1200, 800).into();

        assert_eq!(
            presented_rectangle(Presentation::Normal, tile, layout_area, output_size),
            tile
        );
        assert_eq!(
            presented_rectangle(Presentation::Expanded, tile, layout_area, output_size),
            layout_area
        );
        assert_eq!(
            presented_rectangle(Presentation::Fullscreen, tile, layout_area, output_size),
            Rect::new(0, 0, 1200, 800)
        );
    }

    #[test]
    fn drop_preview_uses_the_closest_target_edge() {
        let target = Rect::new(100, 50, 600, 400);

        assert_eq!(
            closest_drop_edge((115.0, 250.0).into(), target),
            DropEdge::Left
        );
        assert_eq!(
            closest_drop_edge((685.0, 250.0).into(), target),
            DropEdge::Right
        );
        assert_eq!(
            closest_drop_edge((400.0, 60.0).into(), target),
            DropEdge::Top
        );
        assert_eq!(
            closest_drop_edge((400.0, 440.0).into(), target),
            DropEdge::Bottom
        );
    }

    #[test]
    fn outer_horizontal_zones_target_workspace_transfer() {
        let output = (1280, 800).into();

        assert_eq!(
            workspace_edge_direction((12.0, 400.0).into(), output),
            Some(WorkspaceDirection::Previous)
        );
        assert_eq!(
            workspace_edge_direction((1268.0, 400.0).into(), output),
            Some(WorkspaceDirection::Next)
        );
        assert_eq!(
            workspace_edge_direction((640.0, 400.0).into(), output),
            None
        );
        assert_eq!(workspace_edge_direction((-1.0, 400.0).into(), output), None);
    }

    #[test]
    fn workspace_edge_hold_opens_only_after_the_full_delay() {
        let started = Instant::now();

        assert!(!workspace_edge_hold_elapsed(
            started,
            started + WORKSPACE_EDGE_HOLD_DELAY - Duration::from_millis(1)
        ));
        assert!(workspace_edge_hold_elapsed(
            started,
            started + WORKSPACE_EDGE_HOLD_DELAY
        ));
    }

    #[test]
    fn workspace_edge_hold_latches_until_the_pointer_leaves_the_edge() {
        let now = Instant::now();
        let mut started = None;
        let mut latched = Some(WorkspaceDirection::Next);

        assert!(update_workspace_edge_hold_state(
            &mut started,
            &mut latched,
            Some(WorkspaceDirection::Next),
            now,
        ));
        assert_eq!(started, None);

        assert!(!update_workspace_edge_hold_state(
            &mut started,
            &mut latched,
            None,
            now,
        ));
        assert_eq!(latched, None);

        assert!(!update_workspace_edge_hold_state(
            &mut started,
            &mut latched,
            Some(WorkspaceDirection::Next),
            now,
        ));
        assert_eq!(started, Some((WorkspaceDirection::Next, now)));
    }

    #[test]
    fn bar_geometry_targets_only_an_inactive_workspace_segment() {
        let targets = [
            (1, Rect::new(500, 8, 100, 42)),
            (2, Rect::new(605, 8, 120, 42)),
        ];
        let output = (1280, 800).into();

        assert_eq!(
            workspace_bar_drop_target_at(&targets, 1, (650.0, 770.0).into(), output),
            Some((2, Rect::new(605, 750, 120, 42)))
        );
        assert_eq!(
            workspace_bar_drop_target_at(&targets, 1, (550.0, 770.0).into(), output),
            None
        );
        assert_eq!(
            workspace_bar_drop_target_at(&targets, 1, (650.0, 700.0).into(), output),
            None
        );
    }
}
