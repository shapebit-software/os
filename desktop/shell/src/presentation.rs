use std::collections::BTreeMap;

use gtk::gio;

use crate::application_catalog::ApplicationCatalog;

#[derive(Clone, Debug, Default)]
pub struct WorkspaceState {
    pub position: u32,
    pub active: bool,
}

#[derive(Clone, Debug, Default)]
pub struct ToplevelState {
    pub title: String,
    pub app_id: String,
    pub workspace: Option<u32>,
    pub active: bool,
}

#[derive(Clone, Debug)]
pub struct WorkspacePresentation {
    pub handle: u32,
    pub position: u32,
    pub active: bool,
    pub applications: Vec<ApplicationPresentation>,
    pub windows: Vec<WindowPresentation>,
}

#[derive(Clone, Debug)]
pub struct WindowPresentation {
    pub activation_handle: u32,
    pub title: String,
    pub application_label: String,
    pub icon: Option<gio::Icon>,
    pub active: bool,
    pub resolved: bool,
}

#[derive(Clone, Debug)]
pub struct ApplicationPresentation {
    pub activation_handle: u32,
    pub label: String,
    pub tooltip: String,
    pub icon: Option<gio::Icon>,
    pub count: u32,
    pub active: bool,
    pub resolved: bool,
}

struct ApplicationGroup {
    count: u32,
    active: bool,
    has_app_id: bool,
    activation_handle: u32,
}

pub fn build_presentations(
    workspaces: &BTreeMap<u32, WorkspaceState>,
    toplevels: &BTreeMap<u32, ToplevelState>,
    catalog: &ApplicationCatalog,
) -> Vec<WorkspacePresentation> {
    let mut presentations = Vec::with_capacity(workspaces.len());
    for (handle, workspace) in workspaces {
        let mut applications = BTreeMap::<String, ApplicationGroup>::new();
        let mut windows = Vec::new();
        for (toplevel_handle, toplevel) in toplevels
            .iter()
            .filter(|(_, toplevel)| toplevel.workspace == Some(*handle))
        {
            let has_app_id = !toplevel.app_id.is_empty();
            let identity = if has_app_id {
                toplevel.app_id.as_str()
            } else {
                toplevel.title.as_str()
            };
            let identity = if identity.is_empty() {
                "Window"
            } else {
                identity
            };
            let metadata = has_app_id.then(|| catalog.resolve(identity)).flatten();
            let application_label = metadata
                .map(|metadata| metadata.display_name.as_str())
                .unwrap_or_else(|| fallback_application_name(identity));
            windows.push(WindowPresentation {
                activation_handle: *toplevel_handle,
                title: if toplevel.title.is_empty() {
                    application_label.to_owned()
                } else {
                    toplevel.title.clone()
                },
                application_label: application_label.to_owned(),
                icon: metadata.and_then(|metadata| metadata.icon.clone()),
                active: toplevel.active,
                resolved: metadata.is_some(),
            });
            let application = applications
                .entry(identity.to_owned())
                .or_insert(ApplicationGroup {
                    count: 0,
                    active: false,
                    has_app_id: false,
                    activation_handle: *toplevel_handle,
                });
            application.count += 1;
            application.active |= toplevel.active;
            application.has_app_id |= has_app_id;
            if toplevel.active {
                application.activation_handle = *toplevel_handle;
            }
        }
        let applications = applications
            .into_iter()
            .map(|(identity, application)| {
                let metadata = application
                    .has_app_id
                    .then(|| catalog.resolve(&identity))
                    .flatten();
                let display_name = metadata
                    .map(|metadata| metadata.display_name.as_str())
                    .unwrap_or_else(|| fallback_application_name(&identity));
                ApplicationPresentation {
                    activation_handle: application.activation_handle,
                    label: compact_application_label(display_name),
                    tooltip: if metadata.is_some() {
                        format!("{display_name} ({identity})")
                    } else {
                        identity
                    },
                    icon: metadata.and_then(|metadata| metadata.icon.clone()),
                    count: application.count,
                    active: application.active,
                    resolved: metadata.is_some(),
                }
            })
            .collect();
        presentations.push(WorkspacePresentation {
            handle: *handle,
            position: workspace.position,
            active: workspace.active,
            applications,
            windows,
        });
    }
    presentations
}

fn fallback_application_name(identity: &str) -> &str {
    identity.rsplit('.').next().unwrap_or(identity)
}

fn compact_application_label(display_name: &str) -> String {
    let mut characters = display_name.chars();
    let compact: String = characters.by_ref().take(10).collect();
    if characters.next().is_some() {
        format!("{compact}…")
    } else {
        compact
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn fallback_uses_the_last_application_id_component() {
        assert_eq!(fallback_application_name("org.example.Editor"), "Editor");
        assert_eq!(fallback_application_name("Terminal"), "Terminal");
    }

    #[test]
    fn compact_labels_preserve_short_names_and_truncate_long_names() {
        assert_eq!(compact_application_label("Terminal"), "Terminal");
        assert_eq!(compact_application_label("Long Application"), "Long Appli…");
    }

    #[test]
    fn groups_toplevels_by_application_within_each_workspace() {
        let workspaces = BTreeMap::from([(
            7,
            WorkspaceState {
                position: 0,
                active: true,
            },
        )]);
        let toplevels = BTreeMap::from([
            (
                11,
                ToplevelState {
                    title: "First".into(),
                    app_id: "org.example.Editor".into(),
                    workspace: Some(7),
                    active: true,
                },
            ),
            (
                12,
                ToplevelState {
                    title: "Second".into(),
                    app_id: "org.example.Editor".into(),
                    workspace: Some(7),
                    active: false,
                },
            ),
        ]);

        let presentations =
            build_presentations(&workspaces, &toplevels, &ApplicationCatalog::empty());

        assert_eq!(presentations.len(), 1);
        assert_eq!(presentations[0].applications.len(), 1);
        assert_eq!(presentations[0].applications[0].count, 2);
        assert_eq!(presentations[0].applications[0].activation_handle, 11);
        assert_eq!(presentations[0].windows.len(), 2);
    }
}
