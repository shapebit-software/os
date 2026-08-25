#!/usr/bin/env bash
set -euo pipefail

repository_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
runtime_dir=$(mktemp -d /tmp/shapebit-nested-smoke.XXXXXX)
weston_pid=
compositor_pid=
terminal_pid=

wait_for_log_count() {
    local pattern=$1
    local expected=$2

    for _ in {1..100}; do
        local observed
        observed=$(grep -Ec "${pattern}" "${runtime_dir}/compositor.log" || true)
        if [[ ${observed} -ge ${expected} ]]; then
            return 0
        fi
        kill -0 "${compositor_pid}"
        sleep 0.05
    done
    return 1
}

cleanup() {
    if [[ -n ${terminal_pid} ]]; then
        kill "${terminal_pid}" 2>/dev/null || true
        wait "${terminal_pid}" 2>/dev/null || true
    fi
    if [[ -n ${compositor_pid} ]]; then
        kill "${compositor_pid}" 2>/dev/null || true
        wait "${compositor_pid}" 2>/dev/null || true
    fi
    if [[ -n ${weston_pid} ]]; then
        kill "${weston_pid}" 2>/dev/null || true
        wait "${weston_pid}" 2>/dev/null || true
    fi
    rm -r -- "${runtime_dir}"
}
trap cleanup EXIT

chmod 0700 "${runtime_dir}"
export XDG_RUNTIME_DIR=${runtime_dir}
export XDG_DATA_HOME=${runtime_dir}/data
mkdir -p "${XDG_DATA_HOME}/applications"
install -m 0644 \
    "${repository_root}/tests/fixtures/org.freedesktop.weston.wayland-terminal.desktop" \
    "${XDG_DATA_HOME}/applications/"

weston \
    --backend=headless \
    --socket=wayland-shapebit-parent \
    --idle-time=0 \
    --log="${runtime_dir}/weston.log" &
weston_pid=$!

for _ in {1..100}; do
    [[ -S ${runtime_dir}/wayland-shapebit-parent ]] && break
    kill -0 "${weston_pid}"
    sleep 0.05
done
[[ -S ${runtime_dir}/wayland-shapebit-parent ]]

cd "${repository_root}"
cargo build --locked --workspace
cargo build --locked -p shell --features smoke-test

WAYLAND_DISPLAY=wayland-shapebit-parent \
LIBGL_ALWAYS_SOFTWARE=1 \
GSK_RENDERER=gl \
SHAPEBIT_WORKSPACE_SMOKE=1 \
RUST_LOG=info \
timeout --signal=INT --kill-after=2s 16s \
    target/debug/compositor \
    --socket wayland-shapebit-child \
    --shell target/debug/shell \
    >"${runtime_dir}/compositor.log" 2>&1 &
compositor_pid=$!

for _ in {1..100}; do
    [[ -S ${runtime_dir}/wayland-shapebit-child ]] && break
    kill -0 "${compositor_pid}"
    sleep 0.05
done
[[ -S ${runtime_dir}/wayland-shapebit-child ]]

WAYLAND_DISPLAY=wayland-shapebit-child \
LIBGL_ALWAYS_SOFTWARE=1 \
    weston-terminal \
    >"${runtime_dir}/terminal.log" 2>&1 &
terminal_pid=$!

if ! wait_for_log_count 'registered shell bar policy' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The trusted GTK shell did not register its initial bar policy." >&2
    exit 1
fi
if ! wait_for_log_count 'registered shell Overview policy' 1 \
    || ! wait_for_log_count 'mapped shell Overview' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The trusted GTK Overview did not register and map its initial role." >&2
    exit 1
fi
if ! wait_for_log_count 'ShapeBit shell processed initial snapshot barrier generation=1 workspace_count=1 toplevel_count=[0-9]+' 1 \
    || ! wait_for_log_count 'shell became ready after initial snapshot barrier' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The trusted GTK shell did not complete its initial readiness handshake." >&2
    exit 1
fi
if ! wait_for_log_count 'ShapeBit shell allocated bar controls generation=1 visible_controls=true bar=[1-9][0-9]*x[1-9][0-9]*' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The GTK shell controls were not allocated inside the initial bar surface." >&2
    exit 1
fi
if ! wait_for_log_count 'mapped xdg toplevel' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The terminal did not map before the shell restart test." >&2
    exit 1
fi
if ! wait_for_log_count 'updated application toplevel metadata.*app_id=..*' 1 \
    || ! wait_for_log_count 'ShapeBit shell rendered application inventory generation=1 toplevel_count=1 application_count=1 resolved_application_count=1 icon_application_count=1' 1 \
    || ! wait_for_log_count 'ShapeBit shell rendered Overview model generation=1 workspace_count=1 application_count=1' 1 \
    || ! wait_for_log_count 'ShapeBit shell rendered Overview window miniatures generation=1 window_count=1 resolved_window_count=1 icon_window_count=1' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The shell did not render a terminal miniature from compositor toplevel metadata." >&2
    exit 1
fi
if ! wait_for_log_count 'showed shell Overview' 2 \
    || ! wait_for_log_count 'hid shell Overview' 2 \
    || ! wait_for_log_count 'ShapeBit shell allocated Overview generation=1 visible_controls=true surface=[1-9][0-9]*x[1-9][0-9]*' 1 \
    || ! wait_for_log_count 'ShapeBit shell loaded Overview launcher generation=1 application_count=1 quick_count=1 icon_count=1 label_count=1' 1 \
    || ! wait_for_log_count 'ShapeBit shell allocated Overview application controls generation=1 visible_controls=true search_width=[1-9][0-9]* see_all_width=[1-9][0-9]* quick_app_count=1' 1 \
    || ! wait_for_log_count 'ShapeBit shell filtered Overview applications generation=1 query=terminal visible_count=1' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "Overview did not allocate its search, quick apps, See all control, and Workspace content." >&2
    exit 1
fi
if ! wait_for_log_count 'configured full-output Overview above the bar.*width=[1-9][0-9]*.*height=[1-9][0-9]*' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "Overview did not cover the complete output above the bar." >&2
    exit 1
fi
if ! wait_for_log_count 'configured live Overview preview.*width=[1-9][0-9]*.*height=[1-9][0-9]*' 1 \
    || ! wait_for_log_count 'rendered live Overview window previews.*preview_element_count=[1-9][0-9]*' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "Overview did not submit compositor-rendered live window previews." >&2
    exit 1
fi
if ! wait_for_log_count 'created Workspace.*workspace_id=2' 1 \
    || ! wait_for_log_count 'ShapeBit shell requested application badge activation generation=1 toplevel_handle=[1-9][0-9]*' 2 \
    || ! wait_for_log_count 'activated Workspace.*workspace_id=2.*visible_window_count=0' 2 \
    || ! wait_for_log_count 'activated Workspace.*workspace_id=1.*visible_window_count=1' 2; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The shell did not exercise Workspace creation, Overview activation, and application-badge return." >&2
    exit 1
fi
if ! wait_for_log_count 'ShapeBit shell selected Overview Workspace generation=1 workspace_handle=[1-9][0-9]*' 1 \
    || ! wait_for_log_count 'ShapeBit shell navigated Overview Workspace generation=1 direction=next workspace_handle=[1-9][0-9]*' 1 \
    || ! wait_for_log_count 'ShapeBit shell allocated selected Overview Workspace generation=1 expanded=true selected_width=[1-9][0-9]* inactive_width=[1-9][0-9]*' 1 \
    || ! wait_for_log_count 'ShapeBit shell requested Overview Workspace activation generation=1 workspace_handle=[1-9][0-9]*' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "Overview did not navigate, expand, and explicitly activate a selected Workspace." >&2
    exit 1
fi
selection_line=$(grep -nEm1 'ShapeBit shell selected Overview Workspace generation=1 workspace_handle=[1-9][0-9]*' "${runtime_dir}/compositor.log" | cut -d: -f1)
activation_request_line=$(grep -nEm1 'ShapeBit shell requested Overview Workspace activation generation=1 workspace_handle=[1-9][0-9]*' "${runtime_dir}/compositor.log" | cut -d: -f1)
second_workspace_activation_line=$(grep -nE 'activated Workspace.*workspace_id=2.*visible_window_count=0' "${runtime_dir}/compositor.log" | sed -n '2p' | cut -d: -f1)
if [[ ${selection_line} -ge ${activation_request_line} \
    || ${activation_request_line} -ge ${second_workspace_activation_line} ]]; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "Overview activated a Workspace before the explicit activation step." >&2
    exit 1
fi
if ! wait_for_log_count 'ShapeBit shell launched Overview application generation=1 desktop_id=org.freedesktop.weston.wayland-terminal.desktop' 2 \
    || ! wait_for_log_count 'ShapeBit shell rendered application inventory generation=1 toplevel_count=3 application_count=1 resolved_application_count=1 icon_application_count=1' 1 \
    || ! wait_for_log_count 'ShapeBit shell rendered Overview window miniatures generation=1 window_count=3 resolved_window_count=3 icon_window_count=3' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "Overview did not launch and render two additional controlled applications." >&2
    exit 1
fi

initial_shell_pid=$(sed -nE 's/.*started development shell.*pid=([0-9]+).*/\1/p' "${runtime_dir}/compositor.log" | head -n 1)
if [[ -z ${initial_shell_pid} ]]; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "Could not determine the supervised shell process ID." >&2
    exit 1
fi
kill -KILL "${initial_shell_pid}"

if ! wait_for_log_count 'shell client disconnected' 1 \
    || ! wait_for_log_count 'cleared shell bar policy' 1 \
    || ! wait_for_log_count 'cleared shell Overview policy' 1 \
    || ! wait_for_log_count 'started development shell' 2 \
    || ! wait_for_log_count 'registered shell bar policy' 2 \
    || ! wait_for_log_count 'registered shell Overview policy' 2 \
    || ! wait_for_log_count 'mapped shell Overview' 2; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The compositor did not restore the shell on a fresh connection." >&2
    exit 1
fi
if ! wait_for_log_count 'sent Workspace snapshot.*workspace_count=2.*active_id=Some\(1\)' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The replacement shell did not receive the preserved Workspace snapshot." >&2
    exit 1
fi
if ! wait_for_log_count 'sent toplevel snapshot.*toplevel_count=3' 1 \
    || ! wait_for_log_count 'ShapeBit shell rendered application inventory generation=2 toplevel_count=3 application_count=1 resolved_application_count=1 icon_application_count=1' 1 \
    || ! wait_for_log_count 'ShapeBit shell rendered Overview model generation=2 workspace_count=2 application_count=1' 1 \
    || ! wait_for_log_count 'ShapeBit shell rendered Overview window miniatures generation=2 window_count=3 resolved_window_count=3 icon_window_count=3' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The replacement shell did not rebuild its application inventory." >&2
    exit 1
fi
if ! wait_for_log_count 'unbound shell manager; shell unavailable' 1 \
    || ! wait_for_log_count 'ShapeBit shell processed initial snapshot barrier generation=2 workspace_count=2 toplevel_count=3' 1 \
    || ! wait_for_log_count 'shell became ready after initial snapshot barrier' 2; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The replacement shell did not repeat the readiness handshake after recovery." >&2
    exit 1
fi
if ! wait_for_log_count 'ShapeBit shell allocated bar controls generation=2 visible_controls=true bar=[1-9][0-9]*x[1-9][0-9]*' 1; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The replacement GTK shell did not allocate visible bar controls." >&2
    exit 1
fi
kill -0 "${terminal_pid}"

set +e
WAYLAND_DISPLAY=wayland-shapebit-parent \
LIBGL_ALWAYS_SOFTWARE=1 \
    target/debug/compositor --socket wayland-shapebit-child \
    >"${runtime_dir}/occupied-socket.log" 2>&1
occupied_status=$?
set -e
if [[ ${occupied_status} -eq 0 ]]; then
    cat "${runtime_dir}/occupied-socket.log" >&2
    echo "A second compositor unexpectedly acquired an occupied socket." >&2
    exit 1
fi

set +e
wait "${compositor_pid}"
status=$?
compositor_pid=
set -e

if [[ ${status} -ne 124 ]]; then
    cat "${runtime_dir}/compositor.log" >&2
    exit "${status}"
fi

mapped_windows=$(grep -c 'mapped xdg toplevel' "${runtime_dir}/compositor.log" || true)
if [[ ${mapped_windows} -lt 3 ]]; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "Expected the terminal to map as an application window." >&2
    exit 1
fi

registered_bars=$(grep -c 'registered shell bar policy' "${runtime_dir}/compositor.log" || true)
if [[ ${registered_bars} -lt 2 ]]; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The trusted GTK shell did not restore its bar policy." >&2
    exit 1
fi

mapped_bars=$(grep -Ec 'mapped shell bar|reclassified xdg toplevel as shell bar' "${runtime_dir}/compositor.log" || true)
if [[ ${mapped_bars} -lt 2 ]]; then
    cat "${runtime_dir}/compositor.log" >&2
    echo "The GTK shell bar did not remap as a reserved shell surface." >&2
    exit 1
fi

if [[ -e ${runtime_dir}/wayland-shapebit-child ]]; then
    echo "Child Wayland socket was not cleaned up." >&2
    exit 1
fi

kill -0 "${weston_pid}"
echo "Nested compositor smoke test passed with the shell readiness handshake, three-column application launching, icon-and-label quick apps, application search, compositor-rendered live window previews, expanded Overview selection, bounded keyboard navigation and select-then-activate behavior, visible bar controls, clickable application badges, application inventory, Workspace switching, shell recovery, and ${mapped_windows} surviving application window(s)."
