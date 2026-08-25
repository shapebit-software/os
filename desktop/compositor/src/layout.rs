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
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
enum Axis {
    Horizontal,
    Vertical,
}

#[derive(Clone, Debug, Eq, PartialEq)]
enum Node<T> {
    Leaf(T),
    Split {
        axis: Axis,
        first: Box<Node<T>>,
        second: Box<Node<T>>,
    },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Layout<T> {
    root: Option<Node<T>>,
    focused: Option<T>,
}

impl<T> Default for Layout<T> {
    fn default() -> Self {
        Self {
            root: None,
            focused: None,
        }
    }
}

impl<T: Clone + Eq> Layout<T> {
    pub fn insert(&mut self, item: T, area: Rect) {
        let Some(root) = self.root.as_mut() else {
            self.focused = Some(item.clone());
            self.root = Some(Node::Leaf(item));
            return;
        };

        let target = self
            .focused
            .clone()
            .or_else(|| root.first_item().cloned())
            .expect("a layout root always contains a leaf");
        root.insert_next_to(&target, item.clone(), area);
        self.focused = Some(item);
    }

    pub fn focus(&mut self, item: &T) -> bool {
        if self.root.as_ref().is_some_and(|root| root.contains(item)) {
            self.focused = Some(item.clone());
            true
        } else {
            false
        }
    }

    pub fn focused(&self) -> Option<&T> {
        self.focused.as_ref()
    }

    pub fn retain(&mut self, mut keep: impl FnMut(&T) -> bool) -> bool {
        let before = self.len();
        let removed_focus = self.focused.as_ref().is_some_and(|item| !keep(item));
        self.root = self.root.take().and_then(|root| root.retain(&mut keep));
        if removed_focus {
            self.focused = self.root.as_ref().and_then(Node::first_item).cloned();
        }
        before != self.len()
    }

    pub fn placements(&self, area: Rect) -> Vec<(T, Rect)> {
        let mut placements = Vec::with_capacity(self.len());
        if let Some(root) = &self.root {
            if root.len() == 3 {
                let mut items = Vec::with_capacity(3);
                root.collect_items(&mut items);
                placements.extend(equal_columns(items, area));
            } else {
                root.collect_placements(area, &mut placements);
            }
        }
        placements
    }

    pub fn len(&self) -> usize {
        self.root.as_ref().map_or(0, Node::len)
    }
}

impl<T: Clone + Eq> Node<T> {
    fn first_item(&self) -> Option<&T> {
        match self {
            Self::Leaf(item) => Some(item),
            Self::Split { first, .. } => first.first_item(),
        }
    }

    fn contains(&self, target: &T) -> bool {
        match self {
            Self::Leaf(item) => item == target,
            Self::Split { first, second, .. } => first.contains(target) || second.contains(target),
        }
    }

    fn len(&self) -> usize {
        match self {
            Self::Leaf(_) => 1,
            Self::Split { first, second, .. } => first.len() + second.len(),
        }
    }

    fn insert_next_to(&mut self, target: &T, item: T, area: Rect) -> bool {
        match self {
            Self::Leaf(current) if current == target => {
                let previous = current.clone();
                let axis = if area.width >= area.height {
                    Axis::Horizontal
                } else {
                    Axis::Vertical
                };
                *self = Self::Split {
                    axis,
                    first: Box::new(Self::Leaf(previous)),
                    second: Box::new(Self::Leaf(item)),
                };
                true
            }
            Self::Leaf(_) => false,
            Self::Split {
                axis,
                first,
                second,
            } => {
                let (first_area, second_area) = split(area, *axis);
                first.insert_next_to(target, item.clone(), first_area)
                    || second.insert_next_to(target, item, second_area)
            }
        }
    }

    fn retain(self, keep: &mut impl FnMut(&T) -> bool) -> Option<Self> {
        match self {
            Self::Leaf(item) => keep(&item).then_some(Self::Leaf(item)),
            Self::Split {
                axis,
                first,
                second,
            } => match (first.retain(keep), second.retain(keep)) {
                (Some(first), Some(second)) => Some(Self::Split {
                    axis,
                    first: Box::new(first),
                    second: Box::new(second),
                }),
                (Some(node), None) | (None, Some(node)) => Some(node),
                (None, None) => None,
            },
        }
    }

    fn collect_placements(&self, area: Rect, output: &mut Vec<(T, Rect)>) {
        match self {
            Self::Leaf(item) => output.push((item.clone(), area)),
            Self::Split {
                axis,
                first,
                second,
            } => {
                let (first_area, second_area) = split(area, *axis);
                first.collect_placements(first_area, output);
                second.collect_placements(second_area, output);
            }
        }
    }

    fn collect_items(&self, output: &mut Vec<T>) {
        match self {
            Self::Leaf(item) => output.push(item.clone()),
            Self::Split { first, second, .. } => {
                first.collect_items(output);
                second.collect_items(output);
            }
        }
    }
}

fn equal_columns<T>(items: Vec<T>, area: Rect) -> impl Iterator<Item = (T, Rect)> {
    let column_count = items.len() as i32;
    let base_width = area.width / column_count;
    items.into_iter().enumerate().map(move |(index, item)| {
        let index = index as i32;
        let x = area.x + base_width * index;
        let width = if index + 1 == column_count {
            area.width - base_width * index
        } else {
            base_width
        };
        (item, Rect::new(x, area.y, width, area.height))
    })
}

fn split(area: Rect, axis: Axis) -> (Rect, Rect) {
    match axis {
        Axis::Horizontal => {
            let first_width = area.width / 2;
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
            let first_height = area.height / 2;
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

#[cfg(test)]
mod tests {
    use super::*;

    const WIDE: Rect = Rect::new(0, 0, 1200, 800);

    #[test]
    fn first_item_fills_the_area() {
        let mut layout = Layout::default();
        layout.insert('a', WIDE);
        assert_eq!(layout.placements(WIDE), [('a', WIDE)]);
    }

    #[test]
    fn three_items_use_equal_columns() {
        let mut layout = Layout::default();
        layout.insert('a', WIDE);
        layout.insert('b', WIDE);
        layout.insert('c', WIDE);
        assert_eq!(
            layout.placements(WIDE),
            [
                ('a', Rect::new(0, 0, 400, 800)),
                ('b', Rect::new(400, 0, 400, 800)),
                ('c', Rect::new(800, 0, 400, 800)),
            ]
        );
    }

    #[test]
    fn three_columns_assign_rounding_remainder_to_the_last_item() {
        let mut layout = Layout::default();
        let area = Rect::new(0, 0, 1000, 800);
        layout.insert('a', area);
        layout.insert('b', area);
        layout.insert('c', area);
        assert_eq!(
            layout.placements(area),
            [
                ('a', Rect::new(0, 0, 333, 800)),
                ('b', Rect::new(333, 0, 333, 800)),
                ('c', Rect::new(666, 0, 334, 800)),
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
                ('a', Rect::new(0, 0, 400, 800)),
                ('c', Rect::new(400, 0, 400, 800)),
                ('b', Rect::new(800, 0, 400, 800)),
            ]
        );
    }

    #[test]
    fn removing_a_leaf_collapses_its_parent() {
        let mut layout = Layout::default();
        layout.insert('a', WIDE);
        layout.insert('b', WIDE);
        layout.insert('c', WIDE);
        assert!(layout.retain(|item| *item != 'b'));
        assert_eq!(
            layout.placements(WIDE),
            [
                ('a', Rect::new(0, 0, 600, 800)),
                ('c', Rect::new(600, 0, 600, 800)),
            ]
        );
    }
}
