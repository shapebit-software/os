use std::rc::Rc;

use gtk::{
    Align, Box as GtkBox, Button, FlowBox, Image, Label, Orientation, SearchEntry, ToggleButton,
    prelude::*,
};

use crate::application_catalog::{ApplicationCatalog, LaunchableApplication};

use super::OverviewControls;

#[derive(Clone)]
pub(crate) struct ApplicationLauncher {
    pub widget: GtkBox,
    #[cfg(feature = "smoke-test")]
    search: SearchEntry,
    #[cfg(feature = "smoke-test")]
    see_all: ToggleButton,
    #[cfg(feature = "smoke-test")]
    quick_buttons: Rc<Vec<Button>>,
    #[cfg(feature = "smoke-test")]
    launch_buttons: Rc<Vec<Button>>,
    #[cfg(feature = "smoke-test")]
    applications: Rc<Vec<LaunchableApplication>>,
}

impl ApplicationLauncher {
    pub fn new(catalog: &ApplicationCatalog, overview: &OverviewControls) -> Self {
        let applications = Rc::new(catalog.launchable_applications().to_vec());
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
        see_all.set_sensitive(!applications.is_empty());
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

        let mut quick_buttons = Vec::new();
        let mut launch_buttons = Vec::new();
        let mut search_entries = Vec::new();
        for (position, application) in applications.iter().enumerate() {
            if position < 5 {
                let button = application_button(application, overview, "overview-quick-app");
                quick.append(&button);
                quick_buttons.push(button);
            }
            let button = application_button(application, overview, "overview-app");
            all_apps.insert(&button, -1);
            search_entries.push((application.display_name.to_lowercase(), button.clone()));
            launch_buttons.push(button);
        }

        let all_apps_for_toggle = all_apps.clone();
        see_all.connect_toggled(move |toggle| {
            all_apps_for_toggle.set_visible(toggle.is_active());
        });

        let search_entries = Rc::new(search_entries);
        let all_apps_for_search = all_apps.clone();
        let quick_for_search = quick.clone();
        let see_all_for_search = see_all.clone();
        search.connect_search_changed(move |entry| {
            let query = entry.text().trim().to_lowercase();
            let mut visible_count = 0;
            for (name, button) in search_entries.iter() {
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

        eprintln!(
            "ShapeBit shell loaded Overview launcher generation={} application_count={} quick_count={} icon_count={} label_count={}",
            generation(),
            applications.len(),
            quick_buttons.len(),
            applications
                .iter()
                .filter(|application| application.icon.is_some())
                .count(),
            applications
                .iter()
                .filter(|application| !application.display_name.is_empty())
                .count()
        );

        Self {
            widget,
            #[cfg(feature = "smoke-test")]
            search,
            #[cfg(feature = "smoke-test")]
            see_all,
            #[cfg(feature = "smoke-test")]
            quick_buttons: Rc::new(quick_buttons),
            #[cfg(feature = "smoke-test")]
            launch_buttons: Rc::new(launch_buttons),
            #[cfg(feature = "smoke-test")]
            applications,
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
                .first()
                .is_some_and(|button| button.allocated_width() > 0);
        eprintln!(
            "ShapeBit shell allocated Overview application controls generation={} visible_controls={visible_controls} search_width={} see_all_width={} quick_app_count={}",
            generation(),
            self.search.allocated_width(),
            self.see_all.allocated_width(),
            self.quick_buttons.len()
        );
    }

    #[cfg(feature = "smoke-test")]
    pub(crate) fn launch_for_smoke(&self, desktop_id: &str) {
        let Some(position) = self
            .applications
            .iter()
            .position(|application| application.desktop_id == desktop_id)
        else {
            eprintln!("smoke-test application is missing from the Overview launcher");
            return;
        };
        self.launch_buttons[position].emit_clicked();
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
