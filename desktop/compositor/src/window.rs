use std::{
    ops::Deref,
    sync::{
        Arc,
        atomic::{AtomicBool, Ordering},
    },
};

use smithay::{
    backend::renderer::{
        ImportAll, Renderer,
        element::{
            AsRenderElements, Kind,
            surface::{WaylandSurfaceRenderElement, render_elements_from_surface_tree},
            utils::CropRenderElement,
        },
    },
    desktop::{PopupManager, Window as SmithayWindow, WindowSurfaceType, space::SpaceElement},
    output::Output,
    utils::{IsAlive, Logical, Physical, Point, Rectangle, Scale},
    wayland::shell::xdg::ToplevelSurface,
};

smithay::backend::renderer::element::render_elements! {
    pub WindowRenderElement<R> where R: ImportAll;
    Surface=WaylandSurfaceRenderElement<R>,
    Cropped=CropRenderElement<WaylandSurfaceRenderElement<R>>,
}

#[derive(Clone, Debug)]
pub struct Window {
    inner: SmithayWindow,
    content_only: Arc<AtomicBool>,
    logged_content_crop: Arc<AtomicBool>,
}

impl Window {
    pub fn new_wayland_window(surface: ToplevelSurface) -> Self {
        Self {
            inner: SmithayWindow::new_wayland_window(surface),
            content_only: Arc::new(AtomicBool::new(true)),
            logged_content_crop: Arc::new(AtomicBool::new(false)),
        }
    }

    pub fn set_content_only(&self, content_only: bool) {
        self.content_only.store(content_only, Ordering::Release);
    }

    pub fn id(&self) -> usize {
        self.inner.id()
    }

    pub fn surface_under(
        &self,
        point: Point<f64, Logical>,
        surface_type: WindowSurfaceType,
    ) -> Option<(
        smithay::reexports::wayland_server::protocol::wl_surface::WlSurface,
        Point<i32, Logical>,
    )> {
        let content_only = self.content_only.load(Ordering::Acquire);
        let geometry = self.inner.geometry();
        let point = if content_only {
            point + geometry.loc.to_f64()
        } else {
            point
        };
        self.inner
            .surface_under(point, surface_type)
            .map(|(surface, mut offset)| {
                if content_only {
                    offset -= geometry.loc;
                }
                (surface, offset)
            })
    }
}

impl Deref for Window {
    type Target = SmithayWindow;

    fn deref(&self) -> &Self::Target {
        &self.inner
    }
}

impl PartialEq for Window {
    fn eq(&self, other: &Self) -> bool {
        self.inner == other.inner
    }
}

impl Eq for Window {}

impl IsAlive for Window {
    fn alive(&self) -> bool {
        self.inner.alive()
    }
}

impl SpaceElement for Window {
    fn geometry(&self) -> Rectangle<i32, Logical> {
        if self.content_only.load(Ordering::Acquire) {
            Rectangle::from_size(self.inner.geometry().size)
        } else {
            SpaceElement::geometry(&self.inner)
        }
    }

    fn bbox(&self) -> Rectangle<i32, Logical> {
        if self.content_only.load(Ordering::Acquire) {
            Rectangle::from_size(self.inner.geometry().size)
        } else {
            SpaceElement::bbox(&self.inner)
        }
    }

    fn is_in_input_region(&self, point: &Point<f64, Logical>) -> bool {
        self.surface_under(*point, WindowSurfaceType::ALL).is_some()
    }

    fn z_index(&self) -> u8 {
        SpaceElement::z_index(&self.inner)
    }

    fn set_activate(&self, activated: bool) {
        SpaceElement::set_activate(&self.inner, activated);
    }

    fn output_enter(&self, output: &Output, overlap: Rectangle<i32, Logical>) {
        SpaceElement::output_enter(&self.inner, output, overlap);
    }

    fn output_leave(&self, output: &Output) {
        SpaceElement::output_leave(&self.inner, output);
    }

    fn refresh(&self) {
        SpaceElement::refresh(&self.inner);
    }
}

impl<R> AsRenderElements<R> for Window
where
    R: Renderer + ImportAll,
    R::TextureId: Clone + 'static,
{
    type RenderElement = WindowRenderElement<R>;

    fn render_elements<C: From<Self::RenderElement>>(
        &self,
        renderer: &mut R,
        location: Point<i32, Physical>,
        scale: Scale<f64>,
        alpha: f32,
    ) -> Vec<C> {
        if !self.content_only.load(Ordering::Acquire) {
            return AsRenderElements::<R>::render_elements::<WaylandSurfaceRenderElement<R>>(
                &self.inner,
                renderer,
                location,
                scale,
                alpha,
            )
            .into_iter()
            .map(WindowRenderElement::from)
            .map(C::from)
            .collect();
        }

        let Some(toplevel) = self.inner.toplevel() else {
            return Vec::new();
        };
        let geometry = self.inner.geometry();
        if !self.logged_content_crop.swap(true, Ordering::AcqRel) {
            tracing::info!(
                window_id = self.id(),
                x = geometry.loc.x,
                y = geometry.loc.y,
                width = geometry.size.w,
                height = geometry.size.h,
                "rendered client content without client-side frame"
            );
        }
        let content_size = geometry.size.to_physical_precise_round(scale);
        let content_rect = Rectangle::new(location, content_size);
        let surface_origin = location - geometry.loc.to_physical_precise_round(scale);

        let mut elements: Vec<C> = PopupManager::popups_for_surface(toplevel.wl_surface())
            .flat_map(|(popup, popup_offset)| {
                let offset = (popup_offset - popup.geometry().loc).to_physical_precise_round(scale);
                render_elements_from_surface_tree::<R, WaylandSurfaceRenderElement<R>>(
                    renderer,
                    popup.wl_surface(),
                    location + offset,
                    scale,
                    alpha,
                    Kind::Unspecified,
                )
            })
            .map(WindowRenderElement::from)
            .map(C::from)
            .collect();

        elements.extend(
            render_elements_from_surface_tree::<R, WaylandSurfaceRenderElement<R>>(
                renderer,
                toplevel.wl_surface(),
                surface_origin,
                scale,
                alpha,
                Kind::Unspecified,
            )
            .into_iter()
            .filter_map(|element| CropRenderElement::from_element(element, scale, content_rect))
            .map(WindowRenderElement::from)
            .map(C::from),
        );
        elements
    }
}
