use std::{cell::RefCell, rc::Rc};

use gtk::{
    Align, Box as GtkBox, Button, FlowBox, Image, Label, Orientation, SearchEntry, ToggleButton,
    prelude::*,
};

use crate::application_catalog::{ApplicationCatalog, LaunchableApplication};

use super::OverviewControls;

#[derive(Clone)]
pub(crate) struct ApplicationLauncher {
    pub widget: GtkBox,
    search: SearchEntry,
    see_all: ToggleButton,
    quick: GtkBox,
    all_apps: FlowBox,
    overview: OverviewControls,
    search_entries: Rc<RefCell<Vec<(String, Button)>>>,
    quick_buttons: Rc<RefCell<Vec<Button>>>,
    launch_buttons: Rc<RefCell<Vec<Button>>>,
    applications: Rc<RefCell<Vec<LaunchableApplication>>>,
}

impl ApplicationLauncher {
    pub fn new(catalog: &ApplicationCatalog, overview: &OverviewControls) -> Self {
        let widget = GtkBox::new(Orientation::Vertical, 12);
        widget.add_css_class("overview-launcher");

        let search = SearchEntry::new();
        search.add_css_class("overview-search");
        search.set_placeholder_text(Some("Search applications"));

        let heading = GtkBox::new(Orientation::Horizontal, 10);
        let label = Label::new(Some("Quick apps"));
        label.add_css_class("overview-launcher-label");
        label.set_hexpand(true);
        label.set_halign(Align::Start);
        let see_all = ToggleButton::with_label("See all");
        see_all.add_css_class("overview-see-all");
        see_all.set_sensitive(false);
        heading.append(&label);
        heading.append(&see_all);

        let quick = GtkBox::new(Orientation::Horizontal, 10);
        quick.add_css_class("overview-quick-apps");
        let all_apps = FlowBox::new();
        all_apps.add_css_class("overview-all-apps");
        all_apps.set_column_spacing(10);
        all_apps.set_row_spacing(10);
        all_apps.set_max_children_per_line(6);
        all_apps.set_selection_mode(gtk::SelectionMode::None);
        all_apps.set_visible(false);

        let all_apps_for_toggle = all_apps.clone();
        see_all.connect_toggled(move |toggle| {
            all_apps_for_toggle.set_visible(toggle.is_active());
        });

        let search_entries = Rc::new(RefCell::new(Vec::<(String, Button)>::new()));
        let search_entries_for_search = Rc::clone(&search_entries);
        let all_apps_for_search = all_apps.clone();
        let quick_for_search = quick.clone();
        let see_all_for_search = see_all.clone();
        search.connect_search_changed(move |entry| {
            let query = entry.text().trim().to_lowercase();
            let mut visible_count = 0;
            for (name, button) in search_entries_for_search.borrow().iter() {
                let visible = query.is_empty() || name.contains(&query);
                button.set_visible(visible);
                visible_count += usize::from(visible);
            }
            if query.is_empty() {
                quick_for_search.set_visible(true);
                all_apps_for_search.set_visible(see_all_for_search.is_active());
            } else {
                quick_for_search.set_visible(false);
                see_all_for_search.set_active(true);
                all_apps_for_search.set_visible(true);
            }
            eprintln!(
                "ShapeBit shell filtered Overview applications generation={} query={} visible_count={visible_count}",
                generation(),
                if query.is_empty() { "none" } else { &query }
            );
        });

        widget.append(&search);
        widget.append(&heading);
        widget.append(&quick);
        widget.append(&all_apps);

        let launcher = Self {
            widget,
            search,
            see_all,
            quick,
            all_apps,
            overview: overview.clone(),
            search_entries,
            quick_buttons: Rc::new(RefCell::new(Vec::new())),
            launch_buttons: Rc::new(RefCell::new(Vec::new())),
            applications: Rc::new(RefCell::new(Vec::new())),
        };
        launcher.refresh(catalog);
        launcher
    }

    pub(crate) fn refresh(&self, catalog: &ApplicationCatalog) {
        while let Some(child) = self.quick.first_child() {
            self.quick.remove(&child);
        }
        while let Some(child) = self.all_apps.first_child() {
            self.all_apps.remove(&child);
        }

        let applications = catalog.launchable_applications().to_vec();
        let mut quick_buttons = Vec::new();
        let mut launch_buttons = Vec::new();
        let mut search_entries = Vec::new();
        for (position, application) in applications.iter().enumerate() {
            if position < 5 {
                let button = application_button(application, &self.overview, "overview-quick-app");
                self.quick.append(&button);
                quick_buttons.push(button);
            }
            let button = application_button(application, &self.overview, "overview-app");
            self.all_apps.insert(&button, -1);
            search_entries.push((application.display_name.to_lowercase(), button.clone()));
            launch_buttons.push(button);
        }
        self.see_all.set_sensitive(!applications.is_empty());
        *self.search_entries.borrow_mut() = search_entries;
        *self.quick_buttons.borrow_mut() = quick_buttons;
        *self.launch_buttons.borrow_mut() = launch_buttons;
        *self.applications.borrow_mut() = applications;
        self.apply_current_filter();

        let applications = self.applications.borrow();
        eprintln!(
            "ShapeBit shell loaded Overview launcher generation={} application_count={} quick_count={} icon_count={} label_count={}",
            generation(),
            applications.len(),
            self.quick_buttons.borrow().len(),
            applications
                .iter()
                .filter(|application| application.icon.is_some())
                .count(),
            applications
                .iter()
                .filter(|application| !application.display_name.is_empty())
                .count()
        );
    }

    fn apply_current_filter(&self) {
        let query = self.search.text().trim().to_lowercase();
        for (name, button) in self.search_entries.borrow().iter() {
            button.set_visible(query.is_empty() || name.contains(&query));
        }
        if query.is_empty() {
            self.quick.set_visible(true);
            self.all_apps.set_visible(self.see_all.is_active());
        } else {
            self.quick.set_visible(false);
            self.see_all.set_active(true);
            self.all_apps.set_visible(true);
        }
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn search_for_smoke(&self, query: &str) {
        self.search.set_text(query);
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn log_quick_apps_allocation(&self) {
        let visible_controls = self.search.allocated_width() > 0
            && self.see_all.allocated_width() > 0
            && self
                .quick_buttons
                .borrow()
                .first()
                .is_some_and(|button| button.allocated_width() > 0);
        eprintln!(
            "ShapeBit shell allocated Overview application controls generation={} visible_controls={visible_controls} search_width={} see_all_width={} quick_app_count={}",
            generation(),
            self.search.allocated_width(),
            self.see_all.allocated_width(),
            self.quick_buttons.borrow().len()
        );
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn launch_for_smoke(&self, desktop_id: &str) {
        let Some(position) = self
            .applications
            .borrow()
            .iter()
            .position(|application| application.desktop_id == desktop_id)
        else {
            eprintln!("smoke-test application is missing from the Overview launcher");
            return;
        };
        self.launch_buttons.borrow()[position].emit_clicked();
    }
}

fn application_button(
    application: &LaunchableApplication,
    overview: &OverviewControls,
    css_class: &str,
) -> Button {
    let button = Button::new();
    button.add_css_class(css_class);
    button.set_tooltip_text(Some(&format!("Launch {}", application.display_name)));
    let content = GtkBox::new(Orientation::Vertical, 6);
    content.set_halign(Align::Center);
    let image = application
        .icon
        .as_ref()
        .map(Image::from_gicon)
        .unwrap_or_else(|| Image::from_icon_name("application-x-executable-symbolic"));
    image.add_css_class("overview-app-icon");
    image.set_pixel_size(32);
    let label = Label::new(Some(&application.display_name));
    label.add_css_class("overview-app-label");
    label.set_ellipsize(gtk::pango::EllipsizeMode::End);
    label.set_max_width_chars(14);
    content.append(&image);
    content.append(&label);
    button.set_child(Some(&content));

    let application = application.clone();
    let overview = overview.clone();
    button.connect_clicked(move |_| match application.launch() {
        Ok(()) => {
            eprintln!(
                "ShapeBit shell launched Overview application generation={} desktop_id={}",
                generation(),
                application.desktop_id
            );
            overview.request_hide();
        }
        Err(error) => eprintln!(
            "failed to launch Overview application desktop_id={}: {error}",
            application.desktop_id
        ),
    });
    button
}

fn generation() -> String {
    std::env::var("SHAPEBIT_SHELL_GENERATION").unwrap_or_else(|_| "unknown".into())
}
