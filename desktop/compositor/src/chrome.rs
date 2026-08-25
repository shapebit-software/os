use cairo::{Context, FontSlant, FontWeight, Format, ImageSurface};
use smithay::{
    backend::{allocator::Fourcc, renderer::element::memory::MemoryRenderBuffer},
    utils::{Logical, Point, Transform},
};

use crate::layout::Rect;

pub const WINDOW_GUTTER: i32 = 3;
pub const CHROME_HEIGHT: i32 = 34;
pub const CHROME_REVEAL_HEIGHT: i32 = 7;
pub const CHROME_BUTTON_WIDTH: i32 = 34;

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ChromeButton {
    Focus,
    Collapse,
    Close,
}

#[derive(Clone, Debug)]
pub struct WindowChrome {
    pub window_id: usize,
    pub rectangle: Rect,
    pub application: String,
    pub title: String,
    pub focused: bool,
    pub revealed: bool,
    pub collapsed: bool,
    pub controls_enabled: bool,
    pub hovered_button: Option<ChromeButton>,
}

pub fn compositor_controls_enabled(server_decorated: bool, collapsed: bool) -> bool {
    server_decorated || collapsed
}

pub fn inset_window_rectangle(rectangle: Rect) -> Rect {
    let inset = WINDOW_GUTTER
        .min(rectangle.width / 2)
        .min(rectangle.height / 2);
    Rect::new(
        rectangle.x + inset,
        rectangle.y + inset,
        (rectangle.width - inset * 2).max(1),
        (rectangle.height - inset * 2).max(1),
    )
}

pub fn chrome_button_at(rectangle: Rect, position: Point<f64, Logical>) -> Option<ChromeButton> {
    if position.x < f64::from(rectangle.x)
        || position.x >= f64::from(rectangle.x + rectangle.width)
        || position.y < f64::from(rectangle.y)
        || position.y >= f64::from(rectangle.y + CHROME_HEIGHT.min(rectangle.height))
    {
        return None;
    }
    let distance = rectangle.x + rectangle.width - position.x.floor() as i32;
    match distance {
        1..=CHROME_BUTTON_WIDTH => Some(ChromeButton::Close),
        distance if distance <= CHROME_BUTTON_WIDTH * 2 => Some(ChromeButton::Collapse),
        distance if distance <= CHROME_BUTTON_WIDTH * 3 => Some(ChromeButton::Focus),
        _ => None,
    }
}

pub fn render_chrome_buffer(chrome: &WindowChrome) -> Result<MemoryRenderBuffer, String> {
    let width = chrome.rectangle.width.max(1);
    let height = CHROME_HEIGHT.min(chrome.rectangle.height).max(1);
    let mut surface =
        ImageSurface::create(Format::ARgb32, width, height).map_err(|error| error.to_string())?;
    {
        let context = Context::new(&surface).map_err(|error| error.to_string())?;
        draw_background(&context, width, height, chrome.focused);
        draw_application_identity(&context, chrome, width, height);
        draw_buttons(&context, chrome, width, height);
    }
    surface.flush();
    let data = surface.data().map_err(|error| error.to_string())?;
    Ok(MemoryRenderBuffer::from_slice(
        &data,
        Fourcc::Argb8888,
        (width, height),
        1,
        Transform::Normal,
        None,
    ))
}

fn draw_background(context: &Context, width: i32, height: i32, focused: bool) {
    if focused {
        context.set_source_rgba(0.105, 0.133, 0.19, 0.97);
    } else {
        context.set_source_rgba(0.075, 0.086, 0.11, 0.95);
    }
    rounded_rectangle(context, 0.0, 0.0, f64::from(width), f64::from(height), 7.0);
    context
        .fill()
        .expect("drawing a chrome background succeeds");

    context.set_source_rgba(0.56, 0.67, 0.84, if focused { 0.52 } else { 0.16 });
    context.rectangle(0.0, 0.0, f64::from(width), 1.0);
    context.fill().expect("drawing a chrome accent succeeds");
}

fn draw_application_identity(context: &Context, chrome: &WindowChrome, width: i32, height: i32) {
    let icon_size = 20.0;
    let icon_x = 9.0;
    let icon_y = (f64::from(height) - icon_size) / 2.0;
    let hue = application_color(&chrome.application);
    context.set_source_rgba(hue[0], hue[1], hue[2], 1.0);
    rounded_rectangle(context, icon_x, icon_y, icon_size, icon_size, 5.0);
    context
        .fill()
        .expect("drawing an application icon succeeds");

    let glyph = chrome
        .application
        .chars()
        .find(|character| character.is_alphanumeric())
        .unwrap_or('A')
        .to_uppercase()
        .next()
        .unwrap_or('A')
        .to_string();
    context.select_font_face("Sans", FontSlant::Normal, FontWeight::Bold);
    context.set_font_size(11.0);
    context.set_source_rgba(0.98, 0.99, 1.0, 0.96);
    context.move_to(icon_x + 6.0, icon_y + 14.0);
    let _ = context.show_text(&glyph);

    let label = if chrome.title.trim().is_empty() {
        chrome.application.as_str()
    } else {
        chrome.title.as_str()
    };
    let available = (width - CHROME_BUTTON_WIDTH * 3 - 48).max(0) as usize;
    let label = truncate_label(label, available / 7);
    context.select_font_face("Sans", FontSlant::Normal, FontWeight::Normal);
    context.set_font_size(12.5);
    context.set_source_rgba(0.91, 0.93, 0.96, if chrome.focused { 0.98 } else { 0.72 });
    context.move_to(38.0, f64::from(height) / 2.0 + 4.5);
    let _ = context.show_text(&label);
}

fn draw_buttons(context: &Context, chrome: &WindowChrome, width: i32, height: i32) {
    for (index, button) in [
        ChromeButton::Focus,
        ChromeButton::Collapse,
        ChromeButton::Close,
    ]
    .into_iter()
    .enumerate()
    {
        let x = width - CHROME_BUTTON_WIDTH * (3 - index as i32);
        if chrome.hovered_button == Some(button) {
            match button {
                ChromeButton::Close => context.set_source_rgba(0.92, 0.27, 0.31, 0.94),
                _ => context.set_source_rgba(0.42, 0.53, 0.72, 0.58),
            }
            rounded_rectangle(
                context,
                f64::from(x + 3),
                3.0,
                f64::from(CHROME_BUTTON_WIDTH - 6),
                f64::from(height - 6),
                6.0,
            );
            context.fill().expect("drawing a chrome button succeeds");
        }

        context.set_source_rgba(0.87, 0.9, 0.95, 0.9);
        context.set_line_width(1.4);
        let center_x = f64::from(x) + f64::from(CHROME_BUTTON_WIDTH) / 2.0;
        let center_y = f64::from(height) / 2.0;
        match button {
            ChromeButton::Focus => {
                context.rectangle(center_x - 5.0, center_y - 5.0, 10.0, 10.0);
                let _ = context.stroke();
                context.rectangle(center_x - 2.0, center_y - 2.0, 4.0, 4.0);
                let _ = context.fill();
            }
            ChromeButton::Collapse => {
                context.move_to(center_x - 5.0, center_y + 3.0);
                context.line_to(center_x + 5.0, center_y + 3.0);
                let _ = context.stroke();
            }
            ChromeButton::Close => {
                context.move_to(center_x - 4.0, center_y - 4.0);
                context.line_to(center_x + 4.0, center_y + 4.0);
                context.move_to(center_x + 4.0, center_y - 4.0);
                context.line_to(center_x - 4.0, center_y + 4.0);
                let _ = context.stroke();
            }
        }
    }
}

fn rounded_rectangle(context: &Context, x: f64, y: f64, width: f64, height: f64, radius: f64) {
    let radius = radius.min(width / 2.0).min(height / 2.0);
    context.new_sub_path();
    context.arc(
        x + width - radius,
        y + radius,
        radius,
        -std::f64::consts::FRAC_PI_2,
        0.0,
    );
    context.arc(
        x + width - radius,
        y + height - radius,
        radius,
        0.0,
        std::f64::consts::FRAC_PI_2,
    );
    context.arc(
        x + radius,
        y + height - radius,
        radius,
        std::f64::consts::FRAC_PI_2,
        std::f64::consts::PI,
    );
    context.arc(
        x + radius,
        y + radius,
        radius,
        std::f64::consts::PI,
        std::f64::consts::PI * 1.5,
    );
    context.close_path();
}

fn application_color(application: &str) -> [f64; 3] {
    let hash = application.bytes().fold(0_u32, |hash, byte| {
        hash.wrapping_mul(33).wrapping_add(u32::from(byte))
    });
    [
        0.34 + f64::from(hash & 0x3f) / 420.0,
        0.42 + f64::from((hash >> 6) & 0x3f) / 420.0,
        0.58 + f64::from((hash >> 12) & 0x3f) / 500.0,
    ]
}

fn truncate_label(label: &str, maximum_chars: usize) -> String {
    if label.chars().count() <= maximum_chars {
        return label.to_owned();
    }
    if maximum_chars <= 1 {
        return "…".into();
    }
    let mut result: String = label.chars().take(maximum_chars - 1).collect();
    result.push('…');
    result
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn gutters_are_small_and_symmetric() {
        assert_eq!(
            inset_window_rectangle(Rect::new(0, 0, 600, 400)),
            Rect::new(3, 3, 594, 394)
        );
    }

    #[test]
    fn chrome_buttons_are_ordered_focus_collapse_close() {
        let rectangle = Rect::new(100, 50, 500, 300);

        assert_eq!(
            chrome_button_at(rectangle, (515.0, 60.0).into()),
            Some(ChromeButton::Focus)
        );
        assert_eq!(
            chrome_button_at(rectangle, (550.0, 60.0).into()),
            Some(ChromeButton::Collapse)
        );
        assert_eq!(
            chrome_button_at(rectangle, (585.0, 60.0).into()),
            Some(ChromeButton::Close)
        );
        assert_eq!(chrome_button_at(rectangle, (400.0, 100.0).into()), None);
    }

    #[test]
    fn long_titles_are_compact() {
        assert_eq!(truncate_label("ShapeBit Settings", 10), "ShapeBit …");
    }

    #[test]
    fn client_decorated_windows_do_not_get_duplicate_controls() {
        assert!(!compositor_controls_enabled(false, false));
        assert!(compositor_controls_enabled(true, false));
        assert!(compositor_controls_enabled(false, true));
    }
}
