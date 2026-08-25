use std::{collections::BTreeMap, path::Path};

use gtk::{
    gio::{self, prelude::*},
    glib,
};

#[derive(Clone, Debug)]
pub struct ApplicationMetadata {
    pub display_name: String,
    pub icon: Option<gio::Icon>,
}

#[derive(Clone)]
pub struct LaunchableApplication {
    pub desktop_id: String,
    pub display_name: String,
    pub icon: Option<gio::Icon>,
    application: gio::AppInfo,
}

impl LaunchableApplication {
    pub fn launch(&self) -> Result<(), glib::Error> {
        let context = gio::AppLaunchContext::new();
        context.unsetenv("WAYLAND_SOCKET");
        context.unsetenv("DISPLAY");
        context.setenv("GDK_BACKEND", "wayland");
        context.setenv("GDK_DEBUG", "no-portals");
        context.setenv("QT_QPA_PLATFORM", "wayland");
        context.setenv("SDL_VIDEODRIVER", "wayland");
        if let Ok(display_name) = std::env::var("SHAPEBIT_APPLICATION_WAYLAND_DISPLAY") {
            context.setenv("WAYLAND_DISPLAY", &display_name);
        }
        self.application.launch(&[], Some(&context))
    }
}

#[derive(Clone)]
pub struct ApplicationCatalog {
    entries: BTreeMap<String, ApplicationMetadata>,
    launchable: Vec<LaunchableApplication>,
}

impl ApplicationCatalog {
    pub fn load() -> Self {
        let mut entries = BTreeMap::new();
        let mut launchable = BTreeMap::new();
        let nested_development = std::env::var_os("SHAPEBIT_APPLICATION_WAYLAND_DISPLAY").is_some();
        for application in gio::AppInfo::all() {
            let Some(desktop_id) = application.id() else {
                continue;
            };
            let metadata = ApplicationMetadata {
                display_name: application.display_name().to_string(),
                icon: application.icon(),
            };
            entries
                .entry(desktop_id.to_string())
                .or_insert_with(|| metadata.clone());
            if let Some(app_id) = desktop_id.strip_suffix(".desktop") {
                entries.entry(app_id.to_owned()).or_insert(metadata);
            }
            if application.should_show()
                && (!nested_development || is_nested_development_application(&application))
            {
                launchable
                    .entry(desktop_id.to_string())
                    .or_insert_with(|| LaunchableApplication {
                        desktop_id: desktop_id.to_string(),
                        display_name: application.display_name().to_string(),
                        icon: application.icon(),
                        application,
                    });
            }
        }
        if nested_development
            && !launchable.contains_key("org.freedesktop.weston.wayland-terminal.desktop")
            && command_is_available(Path::new("weston-terminal"))
            && let Ok(application) = gio::AppInfo::create_from_commandline(
                "weston-terminal",
                Some("Weston Terminal"),
                gio::AppInfoCreateFlags::NONE,
            )
        {
            launchable.insert(
                "org.freedesktop.weston.wayland-terminal.desktop".into(),
                LaunchableApplication {
                    desktop_id: "org.freedesktop.weston.wayland-terminal.desktop".into(),
                    display_name: "Weston Terminal".into(),
                    icon: Some(gio::ThemedIcon::new("utilities-terminal").upcast()),
                    application,
                },
            );
        }
        let mut launchable: Vec<_> = launchable.into_values().collect();
        launchable.sort_by_cached_key(|application| application.display_name.to_lowercase());
        Self {
            entries,
            launchable,
        }
    }

    pub fn resolve(&self, app_id: &str) -> Option<&ApplicationMetadata> {
        self.entries.get(app_id)
    }

    pub fn launchable_applications(&self) -> &[LaunchableApplication] {
        &self.launchable
    }

    #[cfg(test)]
    pub(crate) fn empty() -> Self {
        Self {
            entries: BTreeMap::new(),
            launchable: Vec::new(),
        }
    }
}

fn is_nested_development_application(application: &gio::AppInfo) -> bool {
    let executable = application.executable();
    let host_home = std::env::var_os("HOME").map(std::path::PathBuf::from);
    !host_home
        .as_deref()
        .is_some_and(|home| executable.starts_with(home))
        && command_is_available(&executable)
}

fn command_is_available(executable: &Path) -> bool {
    if executable.is_absolute() || executable.components().count() > 1 {
        return executable.is_file();
    }
    std::env::var_os("PATH").is_some_and(|path| {
        std::env::split_paths(&path).any(|entry| entry.join(executable).is_file())
    })
}
