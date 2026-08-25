use std::{cell::RefCell, rc::Rc, time::Duration};

use gtk::{
    Align, Application, ApplicationWindow, Box as GtkBox, Button, CenterBox, EventControllerKey,
    FlowBox, Image, Label, Orientation, ToggleButton, gdk, glib, prelude::*,
};

use crate::application_catalog::ApplicationCatalog;
use crate::presentation::WorkspacePresentation;

mod launcher;

use launcher::ApplicationLauncher;

#[derive(Clone)]
pub(crate) struct SystemBar {
    pub(crate) widget: CenterBox,
    pub(crate) workspace_controls: WorkspaceControls,
    pub(crate) overview: OverviewToggle,
    #[cfg(feature = "smoke-test")]
    pub(crate) clock: Label,
}

pub(crate) fn system_bar() -> SystemBar {
    let bar = CenterBox::new();
    bar.add_css_class("system-bar");

    let left = GtkBox::new(Orientation::Horizontal, 8);
    let overview = ToggleButton::with_label("Overview");
    overview.add_css_class("bar-button");
    overview.set_sensitive(false);
    overview.set_tooltip_text(Some("Overview is unavailable"));
    let overview = OverviewToggle::new(overview);
    let assistant = Button::with_label("Assistant");
    assistant.add_css_class("bar-button");
    assistant.set_sensitive(false);
    assistant.set_tooltip_text(Some("Assistant is not implemented yet"));
    left.append(&overview.button);
    left.append(&assistant);

    let workspaces = GtkBox::new(Orientation::Horizontal, 5);
    workspaces.add_css_class("workspace-strip");
    let add = Button::with_label("+");
    add.add_css_class("workspace-add");
    workspaces.append(&add);
    let workspace_controls = WorkspaceControls {
        strip: workspaces.clone(),
        add: add.clone(),
        segments: Rc::new(RefCell::new(Vec::new())),
        application_buttons: Rc::new(RefCell::new(Vec::new())),
        activate: Rc::new(RefCell::new(None)),
        activate_application: Rc::new(RefCell::new(None)),
        create: Rc::new(RefCell::new(None)),
    };

    let right = GtkBox::new(Orientation::Horizontal, 10);
    right.append(&indicator("●", "Privacy indicators inactive"));
    right.append(&indicator("Wi-Fi", "Network status placeholder"));
    let clock = Label::new(None);
    clock.add_css_class("clock");
    update_clock(&clock);
    let clock_for_timer = clock.clone();
    glib::timeout_add_local(Duration::from_secs(30), move || {
        update_clock(&clock_for_timer);
        glib::ControlFlow::Continue
    });
    right.append(&clock);

    let create_for_click = Rc::clone(&workspace_controls.create);
    add.connect_clicked(move |_| {
        if let Some(create) = create_for_click.borrow().as_ref() {
            create();
        }
    });

    bar.set_start_widget(Some(&left));
    bar.set_center_widget(Some(&workspaces));
    bar.set_end_widget(Some(&right));
    SystemBar {
        widget: bar,
        workspace_controls,
        overview,
        #[cfg(feature = "smoke-test")]
        clock,
    }
}

type ToggleAction = Rc<dyn Fn(bool)>;

#[derive(Clone)]
pub struct OverviewToggle {
    button: ToggleButton,
    action: Rc<RefCell<Option<ToggleAction>>>,
}

impl OverviewToggle {
    fn new(button: ToggleButton) -> Self {
        let action = Rc::new(RefCell::new(None::<ToggleAction>));
        let action_for_toggle = Rc::clone(&action);
        button.connect_toggled(move |button| {
            if let Some(action) = action_for_toggle.borrow().as_ref() {
                action(button.is_active());
            }
        });
        Self { button, action }
    }

    pub fn set_action(&self, action: impl Fn(bool) + 'static) {
        *self.action.borrow_mut() = Some(Rc::new(action));
        self.button.set_sensitive(true);
        self.button
            .set_tooltip_text(Some("Show or hide the Workspace Overview"));
    }

    pub fn set_active(&self, active: bool) {
        self.button.set_active(active);
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn button_width(&self) -> i32 {
        self.button.allocated_width()
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn button_height(&self) -> i32 {
        self.button.allocated_height()
    }
}

#[derive(Clone)]
pub(crate) struct OverviewView {
    pub(crate) window: ApplicationWindow,
    #[cfg(feature = "smoke-test")]
    pub(crate) surface: GtkBox,
    pub(crate) controls: OverviewControls,
    #[cfg(feature = "smoke-test")]
    pub(crate) launcher: ApplicationLauncher,
}

pub(crate) fn overview_surface(
    application: &Application,
    catalog: &ApplicationCatalog,
) -> OverviewView {
    let window = ApplicationWindow::builder()
        .application(application)
        .title("ShapeBit Overview")
        .default_width(1280)
        .default_height(742)
        .decorated(false)
        .build();
    window.add_css_class("overview-window");

    let surface = GtkBox::new(Orientation::Vertical, 22);
    surface.add_css_class("overview-surface");

    let title = Label::new(Some("Overview"));
    title.add_css_class("overview-title");
    title.set_halign(Align::Start);
    let description = Label::new(Some(
        "Select with Left or Right. Press Enter or double-click to activate.",
    ));
    description.add_css_class("overview-description");
    description.set_halign(Align::Start);
    let workspaces = GtkBox::new(Orientation::Horizontal, 18);
    workspaces.add_css_class("overview-workspaces");
    workspaces.set_homogeneous(false);
    workspaces.set_vexpand(true);

    let controls = OverviewControls {
        surface: surface.clone(),
        workspaces: workspaces.clone(),
        cards: Rc::new(RefCell::new(Vec::new())),
        handles: Rc::new(RefCell::new(Vec::new())),
        preview_slots: Rc::new(RefCell::new(Vec::new())),
        selected: Rc::new(RefCell::new(None)),
        active: Rc::new(RefCell::new(None)),
        activate: Rc::new(RefCell::new(None)),
        hide: Rc::new(RefCell::new(None)),
        place_previews: Rc::new(RefCell::new(None)),
    };
    let launcher = ApplicationLauncher::new(catalog, &controls);

    surface.append(&title);
    surface.append(&description);
    surface.append(&launcher.widget);
    surface.append(&workspaces);
    window.set_child(Some(&surface));
    let controls_for_escape = controls.clone();
    let keyboard = EventControllerKey::new();
    keyboard.connect_key_pressed(move |_, key, _, _| {
        if key == gdk::Key::Escape {
            controls_for_escape.request_hide();
            glib::Propagation::Stop
        } else {
            glib::Propagation::Proceed
        }
    });
    window.add_controller(keyboard);
    let controls_for_close = controls.clone();
    window.connect_close_request(move |_| {
        controls_for_close.request_hide();
        glib::Propagation::Stop
    });

    OverviewView {
        window,
        #[cfg(feature = "smoke-test")]
        surface,
        controls,
        #[cfg(feature = "smoke-test")]
        launcher,
    }
}

type WorkspaceAction = Rc<dyn Fn(u32)>;
type ApplicationAction = Rc<dyn Fn(u32)>;
type CreateAction = Rc<dyn Fn()>;
type HideAction = Rc<dyn Fn()>;
type PreviewAction = Rc<dyn Fn(Vec<PreviewPlacement>)>;

#[derive(Clone, Copy, Debug)]
pub struct PreviewPlacement {
    pub activation_handle: u32,
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
}

#[derive(Clone)]
pub struct WorkspaceControls {
    strip: GtkBox,
    add: Button,
    segments: Rc<RefCell<Vec<GtkBox>>>,
    application_buttons: Rc<RefCell<Vec<Button>>>,
    activate: Rc<RefCell<Option<WorkspaceAction>>>,
    activate_application: Rc<RefCell<Option<ApplicationAction>>>,
    create: Rc<RefCell<Option<CreateAction>>>,
}

#[derive(Clone)]
pub struct OverviewControls {
    surface: GtkBox,
    workspaces: GtkBox,
    cards: Rc<RefCell<Vec<Button>>>,
    handles: Rc<RefCell<Vec<u32>>>,
    preview_slots: Rc<RefCell<Vec<(u32, gtk::Widget)>>>,
    selected: Rc<RefCell<Option<u32>>>,
    active: Rc<RefCell<Option<u32>>>,
    activate: Rc<RefCell<Option<WorkspaceAction>>>,
    hide: Rc<RefCell<Option<HideAction>>>,
    place_previews: Rc<RefCell<Option<PreviewAction>>>,
}

impl OverviewControls {
    #[cfg(feature = "smoke-test")]
    pub(crate) fn workspaces_width(&self) -> i32 {
        self.workspaces.allocated_width()
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn workspaces_height(&self) -> i32 {
        self.workspaces.allocated_height()
    }

    pub fn set_activate_action(&self, action: impl Fn(u32) + 'static) {
        *self.activate.borrow_mut() = Some(Rc::new(action));
    }

    pub fn set_hide_action(&self, action: impl Fn() + 'static) {
        *self.hide.borrow_mut() = Some(Rc::new(action));
    }

    pub fn set_preview_action(&self, action: impl Fn(Vec<PreviewPlacement>) + 'static) {
        *self.place_previews.borrow_mut() = Some(Rc::new(action));
    }

    fn update_preview_placements(&self) {
        let placements = self
            .preview_slots
            .borrow()
            .iter()
            .filter_map(|(activation_handle, slot)| {
                let bounds = slot.compute_bounds(&self.surface)?;
                let x = bounds.x().round() as i32;
                let y = bounds.y().round() as i32;
                let width = bounds.width().round() as i32;
                let height = bounds.height().round() as i32;
                (width > 0 && height > 0).then_some(PreviewPlacement {
                    activation_handle: *activation_handle,
                    x,
                    y,
                    width,
                    height,
                })
            })
            .collect::<Vec<_>>();
        if let Some(place_previews) = self.place_previews.borrow().as_ref() {
            place_previews(placements);
        }
    }

    fn queue_preview_update(&self) {
        let controls = self.clone();
        glib::timeout_add_local_once(Duration::from_millis(16), move || {
            controls.update_preview_placements();
        });
    }

    fn request_hide(&self) {
        if let Some(hide) = self.hide.borrow().as_ref() {
            hide();
        }
    }

    pub fn reset_selection_to_active(&self) {
        if let Some(handle) = *self.active.borrow() {
            self.select_workspace(handle);
            self.focus_workspace(handle);
        }
    }

    fn select_workspace(&self, handle: u32) {
        if !self.handles.borrow().contains(&handle) {
            return;
        }
        *self.selected.borrow_mut() = Some(handle);
        for (card, card_handle) in self.cards.borrow().iter().zip(self.handles.borrow().iter()) {
            if *card_handle == handle {
                card.add_css_class("selected");
                card.set_hexpand(true);
            } else {
                card.remove_css_class("selected");
                card.set_hexpand(false);
            }
        }
        eprintln!(
            "ShapeBit shell selected Overview Workspace generation={} workspace_handle={handle}",
            std::env::var("SHAPEBIT_SHELL_GENERATION").unwrap_or_else(|_| "unknown".into())
        );
        self.queue_preview_update();
    }

    fn focus_workspace(&self, handle: u32) {
        if let Some((card, _)) = self
            .cards
            .borrow()
            .iter()
            .zip(self.handles.borrow().iter())
            .find(|(_, card_handle)| **card_handle == handle)
        {
            card.grab_focus();
        }
    }

    fn navigate_workspace(&self, handle: u32, direction: i32) {
        let handles = self.handles.borrow();
        let Some(position) = handles.iter().position(|candidate| *candidate == handle) else {
            return;
        };
        let target_position = if direction < 0 {
            position.saturating_sub(1)
        } else {
            (position + 1).min(handles.len() - 1)
        };
        let target = handles[target_position];
        drop(handles);
        self.select_workspace(target);
        self.focus_workspace(target);
        eprintln!(
            "ShapeBit shell navigated Overview Workspace generation={} direction={} workspace_handle={target}",
            std::env::var("SHAPEBIT_SHELL_GENERATION").unwrap_or_else(|_| "unknown".into()),
            if direction < 0 { "previous" } else { "next" }
        );
    }

    fn select_boundary_workspace(&self, first: bool) {
        let target = if first {
            self.handles.borrow().first().copied()
        } else {
            self.handles.borrow().last().copied()
        };
        if let Some(target) = target {
            self.select_workspace(target);
            self.focus_workspace(target);
        }
    }

    fn activate_workspace(&self, handle: u32) {
        eprintln!(
            "ShapeBit shell requested Overview Workspace activation generation={} workspace_handle={handle}",
            std::env::var("SHAPEBIT_SHELL_GENERATION").unwrap_or_else(|_| "unknown".into())
        );
        if let Some(activate) = self.activate.borrow().as_ref() {
            activate(handle);
        }
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn select_next_workspace(&self) {
        let selected = *self.selected.borrow();
        if let Some(handle) = selected {
            self.navigate_workspace(handle, 1);
        }
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn activate_selected_workspace(&self) {
        if let Some(handle) = *self.selected.borrow() {
            self.activate_workspace(handle);
        }
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn log_selected_workspace_allocation(&self) {
        let selected = *self.selected.borrow();
        let cards = self.cards.borrow();
        let handles = self.handles.borrow();
        let mut selected_width = 0;
        let mut inactive_width = 0;
        for (card, handle) in cards.iter().zip(handles.iter()) {
            if Some(*handle) == selected {
                selected_width = card.allocated_width();
            } else {
                inactive_width = inactive_width.max(card.allocated_width());
            }
        }
        let expanded = cards.len() >= 2 && selected_width > inactive_width && inactive_width > 0;
        eprintln!(
            "ShapeBit shell allocated selected Overview Workspace generation={} expanded={expanded} selected_width={selected_width} inactive_width={inactive_width}",
            std::env::var("SHAPEBIT_SHELL_GENERATION").unwrap_or_else(|_| "unknown".into())
        );
    }

    pub fn render(&self, workspaces: &[WorkspacePresentation]) {
        for card in self.cards.borrow_mut().drain(..) {
            self.workspaces.remove(&card);
        }
        self.handles.borrow_mut().clear();
        self.preview_slots.borrow_mut().clear();

        let mut workspaces = workspaces.to_vec();
        workspaces.sort_by_key(|workspace| workspace.position);
        let window_count: usize = workspaces
            .iter()
            .map(|workspace| workspace.windows.len())
            .sum();
        let resolved_window_count: usize = workspaces
            .iter()
            .flat_map(|workspace| &workspace.windows)
            .filter(|window| window.resolved)
            .count();
        let icon_window_count: usize = workspaces
            .iter()
            .flat_map(|workspace| &workspace.windows)
            .filter(|window| window.icon.is_some())
            .count();
        let active = workspaces
            .iter()
            .find(|workspace| workspace.active)
            .map(|workspace| workspace.handle);
        *self.active.borrow_mut() = active;
        let selected = self
            .selected
            .borrow()
            .filter(|selected| {
                workspaces
                    .iter()
                    .any(|workspace| workspace.handle == *selected)
            })
            .or(active)
            .or_else(|| workspaces.first().map(|workspace| workspace.handle));
        *self.selected.borrow_mut() = selected;
        for workspace in workspaces {
            self.handles.borrow_mut().push(workspace.handle);
            let card = Button::new();
            card.add_css_class("overview-workspace");
            if workspace.active {
                card.add_css_class("active");
            }
            if selected == Some(workspace.handle) {
                card.add_css_class("selected");
                card.set_hexpand(true);
            }
            let content = GtkBox::new(Orientation::Vertical, 12);
            let heading = Label::new(Some(&format!("Workspace {}", workspace.position + 1)));
            heading.add_css_class("overview-workspace-title");
            heading.set_halign(Align::Start);
            content.append(&heading);

            if workspace.windows.is_empty() {
                let empty = Label::new(Some("Empty Workspace"));
                empty.add_css_class("overview-empty");
                empty.set_halign(Align::Start);
                content.append(&empty);
            } else {
                let miniatures = FlowBox::new();
                miniatures.add_css_class("overview-window-miniatures");
                miniatures.set_column_spacing(10);
                miniatures.set_row_spacing(10);
                miniatures.set_max_children_per_line(if selected == Some(workspace.handle) {
                    3
                } else {
                    1
                });
                miniatures.set_selection_mode(gtk::SelectionMode::None);
                miniatures.set_vexpand(true);
                for window in workspace.windows {
                    let miniature = GtkBox::new(Orientation::Vertical, 10);
                    miniature.add_css_class("overview-window-miniature");
                    if window.active {
                        miniature.add_css_class("focused");
                    }
                    miniature.set_tooltip_text(Some(&format!(
                        "{} — {} (window {})",
                        window.application_label, window.title, window.activation_handle
                    )));
                    let preview = GtkBox::new(Orientation::Vertical, 0);
                    preview.add_css_class("overview-window-preview");
                    preview.set_hexpand(true);
                    preview.set_vexpand(true);
                    let application = Label::new(Some(&window.application_label));
                    application.add_css_class("overview-window-application");
                    application.set_ellipsize(gtk::pango::EllipsizeMode::End);
                    application.set_max_width_chars(18);
                    let title = Label::new(Some(&window.title));
                    title.add_css_class("overview-window-title");
                    title.set_ellipsize(gtk::pango::EllipsizeMode::End);
                    title.set_max_width_chars(22);
                    miniature.append(&preview);
                    miniature.append(&application);
                    miniature.append(&title);
                    self.preview_slots
                        .borrow_mut()
                        .push((window.activation_handle, preview.upcast::<gtk::Widget>()));
                    miniatures.insert(&miniature, -1);
                }
                content.append(&miniatures);
            }
            card.set_child(Some(&content));
            let workspace_handle = workspace.handle;
            let controls_for_select = self.clone();
            card.connect_clicked(move |_| {
                controls_for_select.select_workspace(workspace_handle);
            });
            let controls_for_double_click = self.clone();
            let double_click = gtk::GestureClick::new();
            double_click.set_button(gdk::BUTTON_PRIMARY);
            double_click.connect_released(move |_, press_count, _, _| {
                if press_count == 2 {
                    controls_for_double_click.select_workspace(workspace_handle);
                    controls_for_double_click.activate_workspace(workspace_handle);
                }
            });
            card.add_controller(double_click);
            let controls_for_enter = self.clone();
            let keyboard = EventControllerKey::new();
            keyboard.connect_key_pressed(move |_, key, _, _| {
                match key {
                    gdk::Key::Return | gdk::Key::KP_Enter => {
                        controls_for_enter.select_workspace(workspace_handle);
                        controls_for_enter.activate_workspace(workspace_handle);
                    }
                    gdk::Key::Left => {
                        controls_for_enter.navigate_workspace(workspace_handle, -1);
                    }
                    gdk::Key::Right => {
                        controls_for_enter.navigate_workspace(workspace_handle, 1);
                    }
                    gdk::Key::Home => controls_for_enter.select_boundary_workspace(true),
                    gdk::Key::End => controls_for_enter.select_boundary_workspace(false),
                    _ => return glib::Propagation::Proceed,
                }
                glib::Propagation::Stop
            });
            card.add_controller(keyboard);
            self.workspaces.append(&card);
            self.cards.borrow_mut().push(card);
        }
        if window_count > 0 {
            eprintln!(
                "ShapeBit shell rendered Overview window miniatures generation={} window_count={window_count} resolved_window_count={resolved_window_count} icon_window_count={icon_window_count}",
                std::env::var("SHAPEBIT_SHELL_GENERATION").unwrap_or_else(|_| "unknown".into())
            );
        }
        self.queue_preview_update();
    }
}

impl WorkspaceControls {
    #[cfg(feature = "smoke-test")]
    pub(crate) fn strip_width(&self) -> i32 {
        self.strip.allocated_width()
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn strip_height(&self) -> i32 {
        self.strip.allocated_height()
    }

    pub fn set_activate_action(&self, action: impl Fn(u32) + 'static) {
        *self.activate.borrow_mut() = Some(Rc::new(action));
    }

    pub fn set_create_action(&self, action: impl Fn() + 'static) {
        *self.create.borrow_mut() = Some(Rc::new(action));
    }

    pub fn set_activate_application_action(&self, action: impl Fn(u32) + 'static) {
        *self.activate_application.borrow_mut() = Some(Rc::new(action));
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn click_first_application(&self) {
        if let Some(button) = self.application_buttons.borrow().first() {
            button.emit_clicked();
        }
    }

    pub fn render(&self, workspaces: &[WorkspacePresentation]) {
        for segment in self.segments.borrow_mut().drain(..) {
            self.strip.remove(&segment);
        }
        self.application_buttons.borrow_mut().clear();
        self.strip.remove(&self.add);

        let mut workspaces = workspaces.to_vec();
        workspaces.sort_by_key(|workspace| workspace.position);
        for workspace in workspaces {
            let number = workspace.position + 1;
            let segment = GtkBox::new(Orientation::Horizontal, 3);
            segment.add_css_class("workspace-segment");
            if workspace.active {
                segment.add_css_class("active");
            }
            let workspace_button = ToggleButton::new();
            workspace_button.add_css_class("workspace-button");
            workspace_button.set_tooltip_text(Some(&format!("Activate Workspace {number}")));
            workspace_button.set_active(workspace.active);
            let number_label = Label::new(Some(&number.to_string()));
            number_label.add_css_class("workspace-number");
            workspace_button.set_child(Some(&number_label));
            let activate = Rc::clone(&self.activate);
            workspace_button.connect_clicked(move |_| {
                if let Some(activate) = activate.borrow().as_ref() {
                    activate(workspace.handle);
                }
            });
            segment.append(&workspace_button);
            for application in workspace.applications {
                let badge = Button::new();
                badge.add_css_class("workspace-app");
                badge.set_focusable(true);
                if application.active {
                    badge.add_css_class("focused");
                }
                let content = GtkBox::new(Orientation::Horizontal, 3);
                if let Some(icon) = application.icon {
                    let image = Image::from_gicon(&icon);
                    image.add_css_class("workspace-app-icon");
                    image.set_pixel_size(16);
                    content.append(&image);
                }
                let text = if application.count > 1 {
                    format!("{} ×{}", application.label, application.count)
                } else {
                    application.label
                };
                let label = Label::new(Some(&text));
                content.append(&label);
                badge.set_child(Some(&content));
                badge.set_tooltip_text(Some(&format!("Activate {}", application.tooltip)));
                let activate_application = Rc::clone(&self.activate_application);
                badge.connect_clicked(move |_| {
                    if let Some(activate) = activate_application.borrow().as_ref() {
                        activate(application.activation_handle);
                    }
                });
                segment.append(&badge);
                self.application_buttons.borrow_mut().push(badge);
            }
            self.strip.append(&segment);
            self.segments.borrow_mut().push(segment);
        }
        self.strip.append(&self.add);
    }
}

fn indicator(text: &str, tooltip: &str) -> Label {
    let label = Label::new(Some(text));
    label.add_css_class("indicator");
    label.set_tooltip_text(Some(tooltip));
    label
}

fn update_clock(label: &Label) {
    let now = glib::DateTime::now_local().expect("the local time must be available");
    label.set_label(
        now.format("%H:%M")
            .expect("the clock format must be valid")
            .as_str(),
    );
}
