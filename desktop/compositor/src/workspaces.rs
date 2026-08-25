use smithay::utils::IsAlive;

use crate::{layout::Layout, window::Window};

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum WorkspaceDirection {
    Previous,
    Next,
}

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
        self.create_at(self.items.len())
    }

    pub fn create_at(&mut self, position: usize) -> (u32, u32) {
        let active_id = self.active_id();
        let id = self.next_id;
        self.next_id += 1;
        let position = position.min(self.items.len());
        self.items.insert(position, SessionWorkspace::new(id));
        self.active = self
            .items
            .iter()
            .position(|workspace| workspace.id == active_id)
            .expect("background Workspace creation preserves the active Workspace");
        (id, position as u32)
    }

    pub fn adjacent_id(&self, direction: WorkspaceDirection) -> Option<u32> {
        let position = match direction {
            WorkspaceDirection::Previous => self.active.checked_sub(1)?,
            WorkspaceDirection::Next => self.active.checked_add(1)?,
        };
        self.items.get(position).map(|workspace| workspace.id)
    }

    pub fn len(&self) -> usize {
        self.items.len()
    }

    pub fn layout_mut(&mut self, id: u32) -> Option<&mut Layout<Window>> {
        self.items
            .iter_mut()
            .find(|workspace| workspace.id == id)
            .map(|workspace| &mut workspace.layout)
    }

    pub fn reorder(&mut self, id: u32, position: u32) -> bool {
        let Some(source) = self.items.iter().position(|workspace| workspace.id == id) else {
            return false;
        };
        let target = usize::try_from(position)
            .unwrap_or(usize::MAX)
            .min(self.items.len() - 1);
        if source == target {
            return false;
        }
        let active_id = self.active_id();
        let workspace = self.items.remove(source);
        self.items.insert(target, workspace);
        self.active = self
            .items
            .iter()
            .position(|workspace| workspace.id == active_id)
            .expect("the active Workspace remains in the reordered sequence");
        true
    }

    pub fn retain_alive(&mut self) -> bool {
        let mut changed = false;
        for workspace in &mut self.items {
            changed |= workspace.layout.retain(IsAlive::alive);
        }
        changed
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

    #[test]
    fn reorders_without_changing_the_active_workspace() {
        let mut workspaces = WorkspaceSet::default();
        let (second, _) = workspaces.create();
        let (third, _) = workspaces.create();
        assert!(workspaces.activate(second));

        assert!(workspaces.reorder(third, 0));
        assert_eq!(
            workspaces
                .iter()
                .map(|workspace| workspace.id)
                .collect::<Vec<_>>(),
            [third, 1, second]
        );
        assert_eq!(workspaces.active_id(), second);
        assert!(!workspaces.reorder(99, 0));
    }

    #[test]
    fn creates_background_workspaces_on_either_side() {
        let mut workspaces = WorkspaceSet::default();
        let (right, right_position) = workspaces.create_at(workspaces.len());
        let (left, left_position) = workspaces.create_at(0);

        assert_eq!((left_position, right_position), (0, 1));
        assert_eq!(workspaces.active_id(), 1);
        assert_eq!(
            workspaces
                .iter()
                .map(|workspace| workspace.id)
                .collect::<Vec<_>>(),
            [left, 1, right]
        );
        assert_eq!(
            workspaces.adjacent_id(WorkspaceDirection::Previous),
            Some(left)
        );
        assert_eq!(
            workspaces.adjacent_id(WorkspaceDirection::Next),
            Some(right)
        );
    }
}
