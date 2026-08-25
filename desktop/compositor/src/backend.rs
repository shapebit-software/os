use std::time::Duration;

use smithay::{
    backend::{
        renderer::{
            ImportAll, ImportMem,
            damage::OutputDamageTracker,
            element::{
                Kind,
                memory::MemoryRenderBufferRenderElement,
                solid::{SolidColorBuffer, SolidColorRenderElement},
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

use crate::{chrome::render_chrome_buffer, state::Compositor, window::WindowRenderElement};

type PreviewRenderElement<R> =
    CropRenderElement<RelocateRenderElement<RescaleRenderElement<WindowRenderElement<R>>>>;

smithay::backend::renderer::element::render_elements! {
    AdditionalRenderElement<R> where R: ImportAll + ImportMem;
    OverviewPreview=PreviewRenderElement<R>,
    WindowDropPreview=SolidColorRenderElement,
    WindowChrome=MemoryRenderBufferRenderElement<R>,
}

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
    let mut logged_window_drop_preview_render = false;
    let mut logged_window_chrome_render = false;
    let mut logged_client_managed_chrome = false;
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
                let window_drop_preview = state.window_drop_preview();
                let window_chromes = state.window_chromes();
                if !logged_client_managed_chrome
                    && window_chromes.iter().any(|chrome| !chrome.controls_enabled)
                {
                    tracing::info!(
                        "kept compositor controls disabled for client-managed window decoration"
                    );
                    logged_client_managed_chrome = true;
                }
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
                    let preview_elements: Vec<PreviewRenderElement<GlesRenderer>> = preview_windows
                        .iter()
                        .flat_map(|(window, rectangle)| {
                            constrain_space_element(
                                renderer,
                                window,
                                (rectangle.loc.x, rectangle.loc.y),
                                1.0,
                                1.0,
                                *rectangle,
                                preview_behavior,
                            )
                        })
                        .collect();
                    let preview_element_count = preview_elements.len();
                    let mut additional_elements: Vec<AdditionalRenderElement<GlesRenderer>> =
                        preview_elements.into_iter().map(Into::into).collect();
                    if let Some(rectangle) = window_drop_preview {
                        let buffer = SolidColorBuffer::new(rectangle.size, [0.31, 0.48, 1.0, 0.32]);
                        additional_elements.push(
                            SolidColorRenderElement::from_buffer(
                                &buffer,
                                (rectangle.loc.x, rectangle.loc.y),
                                1.0,
                                1.0,
                                Kind::Unspecified,
                            )
                            .into(),
                        );
                    }
                    for chrome in &window_chromes {
                        let border_color = if chrome.focused {
                            [0.34, 0.45, 0.64, 0.72]
                        } else {
                            [0.24, 0.27, 0.34, 0.52]
                        };
                        if chrome.collapsed {
                            let spine = SolidColorBuffer::new(
                                (
                                    chrome.rectangle.width.max(1),
                                    chrome.rectangle.height.max(1),
                                ),
                                [0.17, 0.21, 0.29, 0.96],
                            );
                            additional_elements.push(
                                SolidColorRenderElement::from_buffer(
                                    &spine,
                                    (chrome.rectangle.x, chrome.rectangle.y),
                                    1.0,
                                    1.0,
                                    Kind::Unspecified,
                                )
                                .into(),
                            );
                            continue;
                        }
                        for (location, size) in [
                            (
                                (chrome.rectangle.x, chrome.rectangle.y),
                                (chrome.rectangle.width, 1),
                            ),
                            (
                                (
                                    chrome.rectangle.x,
                                    chrome.rectangle.y + chrome.rectangle.height - 1,
                                ),
                                (chrome.rectangle.width, 1),
                            ),
                            (
                                (chrome.rectangle.x, chrome.rectangle.y),
                                (1, chrome.rectangle.height),
                            ),
                            (
                                (
                                    chrome.rectangle.x + chrome.rectangle.width - 1,
                                    chrome.rectangle.y,
                                ),
                                (1, chrome.rectangle.height),
                            ),
                        ] {
                            let border = SolidColorBuffer::new(size, border_color);
                            additional_elements.push(
                                SolidColorRenderElement::from_buffer(
                                    &border,
                                    location,
                                    1.0,
                                    1.0,
                                    Kind::Unspecified,
                                )
                                .into(),
                            );
                        }
                        if chrome.revealed {
                            match render_chrome_buffer(chrome) {
                                Ok(buffer) => match MemoryRenderBufferRenderElement::from_buffer(
                                    renderer,
                                    (chrome.rectangle.x as f64, chrome.rectangle.y as f64),
                                    &buffer,
                                    None,
                                    None,
                                    None,
                                    Kind::Unspecified,
                                ) {
                                    Ok(element) => additional_elements.push(element.into()),
                                    Err(error) => tracing::warn!(
                                        %error,
                                        "failed to import window chrome buffer"
                                    ),
                                },
                                Err(error) => {
                                    tracing::warn!(%error, "failed to draw window chrome")
                                }
                            }
                        }
                    }
                    smithay::desktop::space::render_output::<
                        _,
                        AdditionalRenderElement<GlesRenderer>,
                        _,
                        _,
                    >(
                        &output,
                        renderer,
                        &mut framebuffer,
                        1.0,
                        0,
                        [&state.space],
                        &additional_elements,
                        &mut damage_tracker,
                        [0.055, 0.059, 0.067, 1.0],
                    )
                    .map(|result| {
                        (
                            result,
                            preview_element_count,
                            window_drop_preview.is_some(),
                            window_chromes.len(),
                        )
                    })
                };

                let (
                    _,
                    preview_element_count,
                    rendered_window_drop_preview,
                    rendered_window_chrome_count,
                ) = match rendered {
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
                if rendered_window_drop_preview && !logged_window_drop_preview_render {
                    tracing::info!("rendered tiled window drop preview");
                    logged_window_drop_preview_render = true;
                }
                if rendered_window_chrome_count > 0 && !logged_window_chrome_render {
                    tracing::info!(
                        rendered_window_chrome_count,
                        "rendered compositor-owned window border"
                    );
                    logged_window_chrome_render = true;
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
