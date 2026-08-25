use std::time::Duration;

use smithay::{
    backend::{
        renderer::{
            damage::OutputDamageTracker,
            element::{
                surface::WaylandSurfaceRenderElement,
                utils::{
                    ConstrainAlign, ConstrainScaleBehavior, CropRenderElement,
                    RelocateRenderElement, RescaleRenderElement,
                },
            },
            gles::GlesRenderer,
        },
        winit::{self, WinitEvent},
    },
    desktop::space::{ConstrainBehavior, ConstrainReference, constrain_space_element},
    output::{Mode, Output, PhysicalProperties, Subpixel},
    reexports::calloop::EventLoop,
    utils::{Rectangle, Transform},
};
use tracing::{error, warn};

use crate::state::Compositor;

type PreviewRenderElement = CropRenderElement<
    RelocateRenderElement<RescaleRenderElement<WaylandSurfaceRenderElement<GlesRenderer>>>,
>;

pub fn init(
    event_loop: &mut EventLoop<Compositor>,
    state: &mut Compositor,
) -> Result<(), Box<dyn std::error::Error>> {
    let (mut backend, source) = winit::init()?;
    let initial_mode = Mode {
        size: backend.window_size(),
        refresh: 60_000,
    };
    let output = Output::new(
        "nested-0".into(),
        PhysicalProperties {
            size: (0, 0).into(),
            subpixel: Subpixel::Unknown,
            make: "ShapeBit".into(),
            model: "Nested".into(),
            serial_number: "development".into(),
        },
    );
    output.create_global::<Compositor>(&state.display_handle);
    output.change_current_state(
        Some(initial_mode),
        Some(Transform::Flipped180),
        None,
        Some((0, 0).into()),
    );
    output.set_preferred(initial_mode);
    state.space.map_output(&output, (0, 0));
    state.set_output_size(initial_mode.size.to_logical(1));

    let mut damage_tracker = OutputDamageTracker::from_output(&output);
    let mut logged_live_preview_render = false;
    event_loop
        .handle()
        .insert_source(source, move |event, _, state| match event {
            WinitEvent::Resized { size, .. } => {
                output.change_current_state(
                    Some(Mode {
                        size,
                        refresh: 60_000,
                    }),
                    None,
                    None,
                    None,
                );
                state.set_output_size(size.to_logical(1));
            }
            WinitEvent::Input(event) => state.process_input_event(event),
            WinitEvent::Redraw => {
                let size = backend.window_size();
                let damage = Rectangle::from_size(size);
                let preview_windows = state.overview_preview_windows();
                let rendered = {
                    let (renderer, mut framebuffer) = match backend.bind() {
                        Ok(target) => target,
                        Err(error) => {
                            error!(%error, "failed to bind the nested compositor framebuffer");
                            state.loop_signal.stop();
                            return;
                        }
                    };
                    let preview_behavior = ConstrainBehavior {
                        reference: ConstrainReference::BoundingBox,
                        behavior: ConstrainScaleBehavior::Fit,
                        align: ConstrainAlign::CENTER,
                    };
                    let preview_elements: Vec<PreviewRenderElement> = preview_windows
                        .iter()
                        .flat_map(|(window, rectangle)| {
                            constrain_space_element(
                                renderer,
                                window,
                                rectangle.loc,
                                1.0,
                                1.0,
                                *rectangle,
                                preview_behavior,
                            )
                        })
                        .collect();
                    let preview_element_count = preview_elements.len();
                    smithay::desktop::space::render_output::<_, PreviewRenderElement, _, _>(
                        &output,
                        renderer,
                        &mut framebuffer,
                        1.0,
                        0,
                        [&state.space],
                        &preview_elements,
                        &mut damage_tracker,
                        [0.055, 0.059, 0.067, 1.0],
                    )
                    .map(|result| (result, preview_element_count))
                };

                let (_, preview_element_count) = match rendered {
                    Ok(result) => result,
                    Err(error) => {
                        error!(%error, "nested compositor rendering failed");
                        state.loop_signal.stop();
                        return;
                    }
                };
                if preview_element_count > 0 && !logged_live_preview_render {
                    tracing::info!(
                        preview_element_count,
                        "rendered live Overview window previews"
                    );
                    logged_live_preview_render = true;
                }
                if let Err(error) = backend.submit(Some(&[damage])) {
                    error!(%error, "nested compositor buffer submission failed");
                    state.loop_signal.stop();
                    return;
                }

                for window in state.space.elements() {
                    window.send_frame(
                        &output,
                        state.start_time.elapsed(),
                        Some(Duration::ZERO),
                        |_, _| Some(output.clone()),
                    );
                }
                state.refresh_windows();
                state.popups.cleanup();
                if let Err(error) = state.display_handle.flush_clients() {
                    warn!(%error, "failed to flush one or more Wayland clients");
                }
                backend.window().request_redraw();
            }
            WinitEvent::CloseRequested => state.loop_signal.stop(),
            _ => {}
        })?;

    Ok(())
}
