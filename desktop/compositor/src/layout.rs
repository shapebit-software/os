#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub struct Rect {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
}

impl Rect {
    pub const fn new(x: i32, y: i32, width: i32, height: i32) -> Self {
        Self {
            x,
            y,
            width,
            height,
        }
    }

    fn supports(self, minimum: (i32, i32)) -> bool {
        self.width >= minimum.0 && self.height >= minimum.1
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum Axis {
    Horizontal,
    Vertical,
}

const RATIO_SCALE: i32 = 10_000;
const HALF_RATIO: u16 = 5_000;
pub const COLLAPSED_SPINE_SIZE: i32 = 28;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum InsertResult {
    First,
    Tiled,
    Stacked,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum DropEdge {
    Left,
    Right,
    Top,
    Bottom,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct ResizeHandle {
    path: Vec<bool>,
    axis: Axis,
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct Member<T> {
    item: T,
    minimum: (i32, i32),
}

#[derive(Clone, Debug, Eq, PartialEq)]
struct Region<T> {
    members: Vec<Member<T>>,
    active: usize,
    recent: Vec<T>,
    collapsed: bool,
}

impl<T: Clone + Eq> Region<T> {
    fn new(item: T, minimum: (i32, i32)) -> Self {
        Self {
            members: vec![Member {
                item: item.clone(),
                minimum,
            }],
            active: 0,
            recent: vec![item],
            collapsed: false,
        }
    }

    fn active_item(&self) -> &T {
        &self.members[self.active].item
    }

    fn contains(&self, target: &T) -> bool {
        self.members.iter().any(|member| &member.item == target)
    }

    fn focus(&mut self, target: &T) -> bool {
        let Some(index) = self
            .members
            .iter()
            .position(|member| &member.item == target)
        else {
            return false;
        };
        self.active = index;
        self.recent.retain(|item| item != target);
        self.recent.push(target.clone());
        true
    }

    fn stack(&mut self, item: T, minimum: (i32, i32)) {
        self.members.push(Member {
            item: item.clone(),
            minimum,
        });
        self.active = self.members.len() - 1;
        self.recent.push(item);
    }

    fn minimum(&self) -> (i32, i32) {
        if self.collapsed {
            return (COLLAPSED_SPINE_SIZE, COLLAPSED_SPINE_SIZE);
        }
        self.members.iter().fold((1, 1), |minimum, member| {
            (
                minimum.0.max(member.minimum.0),
                minimum.1.max(member.minimum.1),
            )
        })
    }

    fn retain(&mut self, keep: &mut impl FnMut(&T) -> bool) -> bool {
        let active = self.active_item().clone();
        self.members.retain(|member| keep(&member.item));
        self.recent
            .retain(|item| self.members.iter().any(|member| member.item == *item));
        if self.members.is_empty() {
            return false;
        }
        self.active = self
            .members
            .iter()
            .position(|member| member.item == active)
            .or_else(|| {
                self.recent.last().and_then(|recent| {
                    self.members
                        .iter()
                        .position(|member| member.item == *recent)
                })
            })
            .unwrap_or(0);
        true
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
enum Node<T> {
    Region(Region<T>),
    Split {
        axis: Axis,
        ratio: u16,
        first: Box<Node<T>>,
        second: Box<Node<T>>,
    },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Layout<T> {
    root: Option<Node<T>>,
    focused: Option<T>,
    recent: Vec<T>,
}

impl<T> Default for Layout<T> {
    fn default() -> Self {
        Self {
            root: None,
            focused: None,
            recent: Vec::new(),
        }
    }
}

impl<T: Clone + Eq> Layout<T> {
    #[cfg(test)]
    fn insert(&mut self, item: T, area: Rect) -> InsertResult {
        self.insert_with_minimum(item, area, (1, 1))
    }

    pub fn insert_with_minimum(
        &mut self,
        item: T,
        area: Rect,
        minimum: (i32, i32),
    ) -> InsertResult {
        let minimum = (minimum.0.max(1), minimum.1.max(1));
        let Some(root) = self.root.as_mut() else {
            self.focused = Some(item.clone());
            self.recent.push(item.clone());
            self.root = Some(Node::Region(Region::new(item, minimum)));
            return InsertResult::First;
        };
        let target = self
            .focused
            .clone()
            .or_else(|| root.first_item().cloned())
            .expect("a layout root always contains a region");
        let result = root.insert_next_to(&target, item.clone(), minimum, area);
        self.focused = Some(item.clone());
        self.recent.retain(|candidate| candidate != &item);
        self.recent.push(item);
        result
    }

    pub fn focus(&mut self, item: &T) -> bool {
        if self.root.as_mut().is_some_and(|root| root.focus(item)) {
            self.focused = Some(item.clone());
            self.recent.retain(|candidate| candidate != item);
            self.recent.push(item.clone());
            true
        } else {
            false
        }
    }

    pub fn collapse(&mut self, item: &T) -> bool {
        let Some(root) = self.root.as_mut() else {
            return false;
        };
        if !root.set_collapsed(item, true) {
            return false;
        }
        if self
            .focused
            .as_ref()
            .is_some_and(|focused| root.same_region(focused, item))
        {
            self.focused = self
                .recent
                .iter()
                .rev()
                .find(|candidate| !root.is_collapsed(candidate))
                .cloned();
        }
        true
    }

    pub fn restore(&mut self, item: &T) -> bool {
        self.root
            .as_mut()
            .is_some_and(|root| root.set_collapsed(item, false))
    }

    pub fn move_next_to(
        &mut self,
        item: &T,
        target: &T,
        edge: DropEdge,
        area: Rect,
        minimum: (i32, i32),
    ) -> Option<InsertResult> {
        if item == target
            || !self.root.as_ref().is_some_and(|root| root.contains(item))
            || !self.root.as_ref().is_some_and(|root| root.contains(target))
        {
            return None;
        }

        let original = self.clone();
        self.retain(|candidate| candidate != item);
        let Some(root) = self.root.as_mut() else {
            *self = original;
            return None;
        };
        let result = root.insert_at_edge(
            target,
            item.clone(),
            (minimum.0.max(1), minimum.1.max(1)),
            edge,
            area,
        );
        let Some(result) = result else {
            *self = original;
            return None;
        };
        self.focused = Some(item.clone());
        self.recent.retain(|candidate| candidate != item);
        self.recent.push(item.clone());
        Some(result)
    }

    pub fn focused(&self) -> Option<&T> {
        self.focused.as_ref()
    }

    pub fn update_minimum(&mut self, item: &T, minimum: (i32, i32)) -> bool {
        self.root
            .as_mut()
            .is_some_and(|root| root.update_minimum(item, (minimum.0.max(1), minimum.1.max(1))))
    }

    pub fn retain(&mut self, mut keep: impl FnMut(&T) -> bool) -> bool {
        let before = self.len();
        let removed_focus = self.focused.as_ref().is_some_and(|item| !keep(item));
        self.root = self.root.take().and_then(|root| root.retain(&mut keep));
        self.recent
            .retain(|item| self.root.as_ref().is_some_and(|root| root.contains(item)));
        if removed_focus {
            self.focused = self
                .recent
                .last()
                .cloned()
                .or_else(|| self.root.as_ref().and_then(Node::first_item).cloned());
        }
        before != self.len()
    }

    pub fn placements(&self, area: Rect) -> Vec<(T, Rect)> {
        let mut placements = Vec::with_capacity(self.region_count());
        if let Some(root) = &self.root {
            root.collect_placements(area, None, false, &mut placements);
        }
        placements
    }

    pub fn collapsed_placements(&self, area: Rect) -> Vec<(T, Rect)> {
        let mut placements = Vec::new();
        if let Some(root) = &self.root {
            root.collect_placements(area, None, true, &mut placements);
        }
        placements
    }

    pub fn items(&self) -> Vec<T> {
        let mut items = Vec::with_capacity(self.len());
        if let Some(root) = &self.root {
            root.collect_items(&mut items);
        }
        items
    }

    pub fn len(&self) -> usize {
        self.root.as_ref().map_or(0, Node::len)
    }

    pub fn region_count(&self) -> usize {
        self.root.as_ref().map_or(0, Node::region_count)
    }

    pub fn boundary_at(&self, x: i32, y: i32, area: Rect, threshold: i32) -> Option<ResizeHandle> {
        self.root
            .as_ref()?
            .boundary_at(x, y, area, threshold.max(0), &mut Vec::new())
    }

    pub fn resize_boundary(&mut self, handle: &ResizeHandle, x: i32, y: i32, area: Rect) -> bool {
        self.root
            .as_mut()
            .is_some_and(|root| root.resize_boundary(handle, 0, x, y, area))
    }
}

impl<T: Clone + Eq> Node<T> {
    fn first_item(&self) -> Option<&T> {
        match self {
            Self::Region(region) => Some(region.active_item()),
            Self::Split { first, .. } => first.first_item(),
        }
    }

    fn focus(&mut self, target: &T) -> bool {
        match self {
            Self::Region(region) => region.focus(target),
            Self::Split { first, second, .. } => first.focus(target) || second.focus(target),
        }
    }

    fn contains(&self, target: &T) -> bool {
        match self {
            Self::Region(region) => region.contains(target),
            Self::Split { first, second, .. } => first.contains(target) || second.contains(target),
        }
    }

    fn set_collapsed(&mut self, target: &T, collapsed: bool) -> bool {
        match self {
            Self::Region(region) if region.contains(target) && region.collapsed != collapsed => {
                region.collapsed = collapsed;
                true
            }
            Self::Region(_) => false,
            Self::Split { first, second, .. } => {
                first.set_collapsed(target, collapsed) || second.set_collapsed(target, collapsed)
            }
        }
    }

    fn is_collapsed(&self, target: &T) -> bool {
        match self {
            Self::Region(region) => region.contains(target) && region.collapsed,
            Self::Split { first, second, .. } => {
                first.is_collapsed(target) || second.is_collapsed(target)
            }
        }
    }

    fn same_region(&self, left: &T, right: &T) -> bool {
        match self {
            Self::Region(region) => region.contains(left) && region.contains(right),
            Self::Split { first, second, .. } => {
                first.same_region(left, right) || second.same_region(left, right)
            }
        }
    }

    fn all_collapsed(&self) -> bool {
        match self {
            Self::Region(region) => region.collapsed,
            Self::Split { first, second, .. } => first.all_collapsed() && second.all_collapsed(),
        }
    }

    fn update_minimum(&mut self, target: &T, minimum: (i32, i32)) -> bool {
        match self {
            Self::Region(region) => {
                let Some(member) = region
                    .members
                    .iter_mut()
                    .find(|member| &member.item == target)
                else {
                    return false;
                };
                member.minimum = minimum;
                true
            }
            Self::Split { first, second, .. } => {
                first.update_minimum(target, minimum) || second.update_minimum(target, minimum)
            }
        }
    }

    fn len(&self) -> usize {
        match self {
            Self::Region(region) => region.members.len(),
            Self::Split { first, second, .. } => first.len() + second.len(),
        }
    }

    fn region_count(&self) -> usize {
        match self {
            Self::Region(_) => 1,
            Self::Split { first, second, .. } => first.region_count() + second.region_count(),
        }
    }

    fn insert_next_to(
        &mut self,
        target: &T,
        item: T,
        minimum: (i32, i32),
        area: Rect,
    ) -> InsertResult {
        match self {
            Self::Region(region) if region.contains(target) => {
                let axis = if area.width >= area.height {
                    Axis::Horizontal
                } else {
                    Axis::Vertical
                };
                let (first_area, second_area) = split(area, axis, HALF_RATIO);
                if first_area.supports(region.minimum()) && second_area.supports(minimum) {
                    let previous = region.clone();
                    *self = Self::Split {
                        axis,
                        ratio: HALF_RATIO,
                        first: Box::new(Self::Region(previous)),
                        second: Box::new(Self::Region(Region::new(item, minimum))),
                    };
                    InsertResult::Tiled
                } else {
                    region.stack(item, minimum);
                    InsertResult::Stacked
                }
            }
            Self::Region(_) => unreachable!("the focused item belongs to a layout region"),
            Self::Split {
                axis,
                ratio,
                first,
                second,
            } => {
                let (first_area, second_area) = split(area, *axis, *ratio);
                if first.contains(target) {
                    first.insert_next_to(target, item, minimum, first_area)
                } else {
                    second.insert_next_to(target, item, minimum, second_area)
                }
            }
        }
    }

    fn insert_at_edge(
        &mut self,
        target: &T,
        item: T,
        minimum: (i32, i32),
        edge: DropEdge,
        area: Rect,
    ) -> Option<InsertResult> {
        match self {
            Self::Region(region) if region.contains(target) => {
                let axis = match edge {
                    DropEdge::Left | DropEdge::Right => Axis::Horizontal,
                    DropEdge::Top | DropEdge::Bottom => Axis::Vertical,
                };
                let (first_area, second_area) = split(area, axis, HALF_RATIO);
                if first_area.supports(minimum) && second_area.supports(region.minimum()) {
                    let previous = region.clone();
                    let moved = Self::Region(Region::new(item, minimum));
                    let target = Self::Region(previous);
                    let (first, second) = match edge {
                        DropEdge::Left | DropEdge::Top => (moved, target),
                        DropEdge::Right | DropEdge::Bottom => (target, moved),
                    };
                    *self = Self::Split {
                        axis,
                        ratio: HALF_RATIO,
                        first: Box::new(first),
                        second: Box::new(second),
                    };
                    Some(InsertResult::Tiled)
                } else {
                    region.stack(item, minimum);
                    Some(InsertResult::Stacked)
                }
            }
            Self::Region(_) => None,
            Self::Split {
                axis,
                ratio,
                first,
                second,
            } => {
                let (first_area, second_area) = split(area, *axis, *ratio);
                if first.contains(target) {
                    first.insert_at_edge(target, item, minimum, edge, first_area)
                } else {
                    second.insert_at_edge(target, item, minimum, edge, second_area)
                }
            }
        }
    }

    fn retain(self, keep: &mut impl FnMut(&T) -> bool) -> Option<Self> {
        match self {
            Self::Region(mut region) => region.retain(keep).then_some(Self::Region(region)),
            Self::Split {
                axis,
                ratio,
                first,
                second,
            } => match (first.retain(keep), second.retain(keep)) {
                (Some(first), Some(second)) => Some(Self::Split {
                    axis,
                    ratio,
                    first: Box::new(first),
                    second: Box::new(second),
                }),
                (Some(node), None) | (None, Some(node)) => Some(node),
                (None, None) => None,
            },
        }
    }

    fn collect_placements(
        &self,
        area: Rect,
        inherited_axis: Option<Axis>,
        collapsed: bool,
        output: &mut Vec<(T, Rect)>,
    ) {
        match self {
            Self::Region(region) if region.collapsed == collapsed => {
                let area = if collapsed {
                    match inherited_axis.unwrap_or(Axis::Vertical) {
                        Axis::Horizontal => Rect::new(
                            area.x,
                            area.y,
                            area.width.min(COLLAPSED_SPINE_SIZE),
                            area.height,
                        ),
                        Axis::Vertical => Rect::new(
                            area.x,
                            area.y,
                            area.width,
                            area.height.min(COLLAPSED_SPINE_SIZE),
                        ),
                    }
                } else {
                    area
                };
                output.push((region.active_item().clone(), area));
            }
            Self::Region(_) => {}
            Self::Split {
                axis,
                ratio,
                first,
                second,
            } => {
                let (first_area, second_area) = split_for_collapsed(
                    area,
                    *axis,
                    *ratio,
                    first.all_collapsed(),
                    second.all_collapsed(),
                );
                first.collect_placements(first_area, Some(*axis), collapsed, output);
                second.collect_placements(second_area, Some(*axis), collapsed, output);
            }
        }
    }

    fn collect_items(&self, output: &mut Vec<T>) {
        match self {
            Self::Region(region) => {
                output.extend(region.members.iter().map(|member| member.item.clone()))
            }
            Self::Split { first, second, .. } => {
                first.collect_items(output);
                second.collect_items(output);
            }
        }
    }

    fn minimum(&self) -> (i32, i32) {
        match self {
            Self::Region(region) => region.minimum(),
            Self::Split {
                axis,
                first,
                second,
                ..
            } => {
                let first = first.minimum();
                let second = second.minimum();
                match axis {
                    Axis::Horizontal => (first.0 + second.0, first.1.max(second.1)),
                    Axis::Vertical => (first.0.max(second.0), first.1 + second.1),
                }
            }
        }
    }

    fn boundary_at(
        &self,
        x: i32,
        y: i32,
        area: Rect,
        threshold: i32,
        path: &mut Vec<bool>,
    ) -> Option<ResizeHandle> {
        let Self::Split {
            axis,
            ratio,
            first,
            second,
        } = self
        else {
            return None;
        };
        let (first_area, second_area) = split(area, *axis, *ratio);
        let in_first = x >= first_area.x
            && x < first_area.x + first_area.width
            && y >= first_area.y
            && y < first_area.y + first_area.height;
        path.push(false);
        let nested = in_first
            .then(|| first.boundary_at(x, y, first_area, threshold, path))
            .flatten();
        path.pop();
        if nested.is_some() {
            return nested;
        }
        let in_second = x >= second_area.x
            && x < second_area.x + second_area.width
            && y >= second_area.y
            && y < second_area.y + second_area.height;
        path.push(true);
        let nested = in_second
            .then(|| second.boundary_at(x, y, second_area, threshold, path))
            .flatten();
        path.pop();
        if nested.is_some() {
            return nested;
        }
        let distance = match axis {
            Axis::Horizontal => (x - second_area.x).abs(),
            Axis::Vertical => (y - second_area.y).abs(),
        };
        let within_boundary = match axis {
            Axis::Horizontal => y >= area.y && y < area.y + area.height,
            Axis::Vertical => x >= area.x && x < area.x + area.width,
        };
        (within_boundary && distance <= threshold).then(|| ResizeHandle {
            path: path.clone(),
            axis: *axis,
        })
    }

    fn resize_boundary(
        &mut self,
        handle: &ResizeHandle,
        depth: usize,
        x: i32,
        y: i32,
        area: Rect,
    ) -> bool {
        let Self::Split {
            axis,
            ratio,
            first,
            second,
        } = self
        else {
            return false;
        };
        if depth < handle.path.len() {
            let (first_area, second_area) = split(area, *axis, *ratio);
            return if handle.path[depth] {
                second.resize_boundary(handle, depth + 1, x, y, second_area)
            } else {
                first.resize_boundary(handle, depth + 1, x, y, first_area)
            };
        }
        if *axis != handle.axis {
            return false;
        }
        let first_minimum = first.minimum();
        let second_minimum = second.minimum();
        let (extent, requested, first_minimum, second_minimum) = match axis {
            Axis::Horizontal => (area.width, x - area.x, first_minimum.0, second_minimum.0),
            Axis::Vertical => (area.height, y - area.y, first_minimum.1, second_minimum.1),
        };
        if extent < first_minimum + second_minimum || extent <= 1 {
            return false;
        }
        let first_extent = requested.clamp(first_minimum, extent - second_minimum);
        let next_ratio = ((first_extent * RATIO_SCALE) / extent).clamp(1, RATIO_SCALE - 1) as u16;
        if *ratio == next_ratio {
            return false;
        }
        *ratio = next_ratio;
        true
    }
}

fn split(area: Rect, axis: Axis, ratio: u16) -> (Rect, Rect) {
    match axis {
        Axis::Horizontal => {
            let first_width = area.width * i32::from(ratio) / RATIO_SCALE;
            (
                Rect::new(area.x, area.y, first_width, area.height),
                Rect::new(
                    area.x + first_width,
                    area.y,
                    area.width - first_width,
                    area.height,
                ),
            )
        }
        Axis::Vertical => {
            let first_height = area.height * i32::from(ratio) / RATIO_SCALE;
            (
                Rect::new(area.x, area.y, area.width, first_height),
                Rect::new(
                    area.x,
                    area.y + first_height,
                    area.width,
                    area.height - first_height,
                ),
            )
        }
    }
}

fn split_for_collapsed(
    area: Rect,
    axis: Axis,
    ratio: u16,
    first_collapsed: bool,
    second_collapsed: bool,
) -> (Rect, Rect) {
    match (first_collapsed, second_collapsed) {
        (true, false) => split_at(
            area,
            axis,
            COLLAPSED_SPINE_SIZE.min(axis_extent(area, axis)),
        ),
        (false, true) => {
            let second = COLLAPSED_SPINE_SIZE.min(axis_extent(area, axis));
            split_at(area, axis, axis_extent(area, axis) - second)
        }
        _ => split(area, axis, ratio),
    }
}

fn axis_extent(area: Rect, axis: Axis) -> i32 {
    match axis {
        Axis::Horizontal => area.width,
        Axis::Vertical => area.height,
    }
}

fn split_at(area: Rect, axis: Axis, first_extent: i32) -> (Rect, Rect) {
    let extent = axis_extent(area, axis);
    let first_extent = first_extent.clamp(0, extent);
    match axis {
        Axis::Horizontal => (
            Rect::new(area.x, area.y, first_extent, area.height),
            Rect::new(
                area.x + first_extent,
                area.y,
                area.width - first_extent,
                area.height,
            ),
        ),
        Axis::Vertical => (
            Rect::new(area.x, area.y, area.width, first_extent),
            Rect::new(
                area.x,
                area.y + first_extent,
                area.width,
                area.height - first_extent,
            ),
        ),
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const WIDE: Rect = Rect::new(0, 0, 1200, 800);

    #[test]
    fn first_item_fills_the_area() {
        let mut layout = Layout::default();
        assert_eq!(layout.insert('a', WIDE), InsertResult::First);
        assert_eq!(layout.placements(WIDE), [('a', WIDE)]);
    }

    #[test]
    fn splits_the_focused_regions_longer_axis() {
        let mut layout = Layout::default();
        layout.insert('a', WIDE);
        layout.insert('b', WIDE);
        layout.insert('c', WIDE);
        assert_eq!(
            layout.placements(WIDE),
            [
                ('a', Rect::new(0, 0, 600, 800)),
                ('b', Rect::new(600, 0, 600, 400)),
                ('c', Rect::new(600, 400, 600, 400)),
            ]
        );
    }

    #[test]
    fn inserts_beside_explicit_focus() {
        let mut layout = Layout::default();
        layout.insert('a', WIDE);
        layout.insert('b', WIDE);
        assert!(layout.focus(&'a'));
        layout.insert('c', WIDE);
        assert_eq!(
            layout.placements(WIDE),
            [
                ('a', Rect::new(0, 0, 600, 400)),
                ('c', Rect::new(0, 400, 600, 400)),
                ('b', Rect::new(600, 0, 600, 800)),
            ]
        );
    }

    #[test]
    fn stacks_when_a_split_would_violate_a_minimum_size() {
        let mut layout = Layout::default();
        layout.insert_with_minimum('a', WIDE, (700, 500));
        assert_eq!(
            layout.insert_with_minimum('b', WIDE, (700, 500)),
            InsertResult::Stacked
        );
        assert_eq!((layout.len(), layout.region_count()), (2, 1));
        assert_eq!(layout.placements(WIDE), [('b', WIDE)]);
        assert_eq!(layout.items(), ['a', 'b']);
    }

    #[test]
    fn focusing_a_stack_member_makes_it_visible() {
        let mut layout = Layout::default();
        layout.insert_with_minimum('a', WIDE, (700, 500));
        layout.insert_with_minimum('b', WIDE, (700, 500));
        assert!(layout.focus(&'a'));
        assert_eq!(layout.placements(WIDE), [('a', WIDE)]);
    }

    #[test]
    fn closing_the_active_stack_member_restores_the_remaining_member() {
        let mut layout = Layout::default();
        layout.insert_with_minimum('a', WIDE, (700, 500));
        layout.insert_with_minimum('b', WIDE, (700, 500));
        assert!(layout.retain(|item| *item != 'b'));
        assert_eq!(layout.placements(WIDE), [('a', WIDE)]);
        assert_eq!(layout.focused(), Some(&'a'));
    }

    #[test]
    fn removing_a_region_gives_its_space_to_its_sibling() {
        let mut layout = Layout::default();
        layout.insert('a', WIDE);
        layout.insert('b', WIDE);
        assert!(layout.focus(&'a'));
        layout.insert('c', WIDE);
        assert!(layout.retain(|item| *item != 'b'));
        assert_eq!(
            layout.placements(WIDE),
            [
                ('a', Rect::new(0, 0, 1200, 400)),
                ('c', Rect::new(0, 400, 1200, 400)),
            ]
        );
    }

    #[test]
    fn collapsing_a_region_creates_a_spine_and_expands_its_sibling() {
        let mut layout = Layout::default();
        layout.insert('a', WIDE);
        layout.insert('b', WIDE);

        assert!(layout.collapse(&'a'));
        assert_eq!(
            layout.collapsed_placements(WIDE),
            [('a', Rect::new(0, 0, COLLAPSED_SPINE_SIZE, 800))]
        );
        assert_eq!(
            layout.placements(WIDE),
            [(
                'b',
                Rect::new(COLLAPSED_SPINE_SIZE, 0, 1200 - COLLAPSED_SPINE_SIZE, 800)
            )]
        );

        assert!(layout.restore(&'a'));
        assert_eq!(
            layout.placements(WIDE),
            [
                ('a', Rect::new(0, 0, 600, 800)),
                ('b', Rect::new(600, 0, 600, 800)),
            ]
        );
    }

    #[test]
    fn removing_focus_restores_the_most_recent_surviving_item() {
        let mut layout = Layout::default();
        layout.insert('a', WIDE);
        layout.insert('b', WIDE);
        layout.insert('c', WIDE);
        assert!(layout.focus(&'a'));
        assert!(layout.focus(&'b'));
        assert!(layout.focus(&'c'));

        assert!(layout.retain(|item| *item != 'c'));
        assert_eq!(layout.focused(), Some(&'b'));
    }

    #[test]
    fn boundary_resize_persists_a_ratio_and_respects_minimums() {
        let mut layout = Layout::default();
        layout.insert_with_minimum('a', WIDE, (300, 200));
        layout.insert_with_minimum('b', WIDE, (300, 200));
        let boundary = layout.boundary_at(600, 300, WIDE, 6).unwrap();

        assert!(layout.resize_boundary(&boundary, 800, 300, WIDE));
        assert_eq!(
            layout.placements(WIDE),
            [
                ('a', Rect::new(0, 0, 799, 800)),
                ('b', Rect::new(799, 0, 401, 800)),
            ]
        );

        assert!(layout.resize_boundary(&boundary, 1100, 300, WIDE));
        assert_eq!(
            layout.placements(WIDE),
            [
                ('a', Rect::new(0, 0, 900, 800)),
                ('b', Rect::new(900, 0, 300, 800)),
            ]
        );
    }

    #[test]
    fn moves_an_existing_item_to_a_requested_target_edge() {
        let mut layout = Layout::default();
        layout.insert('a', WIDE);
        layout.insert('b', WIDE);
        layout.insert('c', WIDE);

        assert_eq!(
            layout.move_next_to(&'c', &'a', DropEdge::Left, WIDE, (1, 1)),
            Some(InsertResult::Tiled)
        );
        assert_eq!(
            layout.placements(WIDE),
            [
                ('c', Rect::new(0, 0, 300, 800)),
                ('a', Rect::new(300, 0, 300, 800)),
                ('b', Rect::new(600, 0, 600, 800)),
            ]
        );
        assert_eq!(layout.focused(), Some(&'c'));
    }

    #[test]
    fn rejects_an_invalid_move_without_mutating_the_layout() {
        let mut layout = Layout::default();
        layout.insert('a', WIDE);
        layout.insert('b', WIDE);
        let original = layout.clone();

        assert_eq!(
            layout.move_next_to(&'a', &'z', DropEdge::Bottom, WIDE, (1, 1)),
            None
        );
        assert_eq!(layout, original);
    }

    #[test]
    fn moved_item_stacks_when_the_requested_split_is_too_small() {
        let mut layout = Layout::default();
        layout.insert('a', WIDE);
        layout.insert('b', WIDE);

        assert_eq!(
            layout.move_next_to(&'b', &'a', DropEdge::Left, WIDE, (700, 500)),
            Some(InsertResult::Stacked)
        );
        assert_eq!(layout.placements(WIDE), [('b', WIDE)]);
        assert_eq!((layout.len(), layout.region_count()), (2, 1));
    }
}
