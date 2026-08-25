use smithay::{desktop::Window, utils::IsAlive};

use crate::layout::Layout;

pub struct WorkspaceSet {
    items: Vec<SessionWorkspace>,
    active: usize,
    next_id: u32,
}

impl Default for WorkspaceSet {
    fn default() -> Self {
        Self {
            items: vec![SessionWorkspace::new(1)],
            active: 0,
            next_id: 2,
        }
    }
}

impl WorkspaceSet {
    pub fn active_layout(&self) -> &Layout<Window> {
        &self.items[self.active].layout
    }

    pub fn active_layout_mut(&mut self) -> &mut Layout<Window> {
        &mut self.items[self.active].layout
    }

    pub fn active_id(&self) -> u32 {
        self.items[self.active].id
    }

    pub fn is_active(&self, id: u32) -> bool {
        self.active_id() == id
    }

    pub fn contains(&self, id: u32) -> bool {
        self.items.iter().any(|workspace| workspace.id == id)
    }

    pub fn activate(&mut self, id: u32) -> bool {
        let Some(target) = self.items.iter().position(|workspace| workspace.id == id) else {
            return false;
        };
        self.active = target;
        true
    }

    pub fn create(&mut self) -> (u32, u32) {
        let id = self.next_id;
        self.next_id += 1;
        let position = self.items.len() as u32;
        self.items.push(SessionWorkspace::new(id));
        (id, position)
    }

    pub fn retain_alive(&mut self) -> bool {
        self.items[self.active].layout.retain(IsAlive::alive)
    }

    pub fn iter(&self) -> impl Iterator<Item = &SessionWorkspace> {
        self.items.iter()
    }

    pub fn iter_mut(&mut self) -> impl Iterator<Item = &mut SessionWorkspace> {
        self.items.iter_mut()
    }
}

pub struct SessionWorkspace {
    pub id: u32,
    pub layout: Layout<Window>,
}

impl SessionWorkspace {
    fn new(id: u32) -> Self {
        Self {
            id,
            layout: Layout::default(),
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn starts_with_one_active_workspace() {
        let workspaces = WorkspaceSet::default();

        assert_eq!(workspaces.active_id(), 1);
        assert!(workspaces.contains(1));
    }

    #[test]
    fn creates_and_activates_workspace_with_stable_identity() {
        let mut workspaces = WorkspaceSet::default();

        let (id, position) = workspaces.create();

        assert_eq!((id, position), (2, 1));
        assert!(workspaces.activate(id));
        assert_eq!(workspaces.active_id(), 2);
    }

    #[test]
    fn rejects_unknown_workspace_identity() {
        let mut workspaces = WorkspaceSet::default();

        assert!(!workspaces.activate(99));
        assert_eq!(workspaces.active_id(), 1);
    }
}
