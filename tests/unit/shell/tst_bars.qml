// The bars' layout as data (desktop/shell/services/bars.js), run by
// test_shell_bars.py with qmltestrunner.
import QtQuick
import QtTest
import "../../../desktop/shell/services/bars.js" as Bars

TestCase {
    name: "Bars"

    function layout() {
        return {
            system: { start: ["clock"], center: [], end: ["sound", "network", "account"] },
            dock: { start: ["apps", "workspaces"], center: [], end: ["capture", "dictation", "assistant"] },
        };
    }

    function test_move_later_in_the_same_zone() {
        // Dropped before "account", "sound" lands just before it.
        const moved = Bars.move(layout(), [], "sound", "system", "end", 2);
        compare(moved.zones.system.end, ["network", "sound", "account"]);
    }

    function test_move_earlier_in_the_same_zone() {
        const moved = Bars.move(layout(), [], "account", "system", "end", 0);
        compare(moved.zones.system.end, ["account", "sound", "network"]);
    }

    function test_move_last_and_to_another_bar() {
        const moved = Bars.move(layout(), [], "clock", "dock", "center", -1);
        compare(moved.zones.system.start, []);
        compare(moved.zones.dock.center, ["clock"]);
    }

    function test_move_to_hidden_and_back() {
        const hidden = Bars.move(layout(), [], "network", "", "", -1);
        compare(hidden.hidden, ["network"]);
        compare(hidden.zones.system.end, ["sound", "account"]);
        const shown = Bars.move(hidden.zones, hidden.hidden, "network", "system", "end", 1);
        compare(shown.hidden, []);
        compare(shown.zones.system.end, ["sound", "network", "account"]);
    }

    function test_move_changes_nothing_given() {
        const zones = layout();
        Bars.move(zones, [], "sound", "dock", "start", 0);
        compare(zones.system.end, ["sound", "network", "account"]);
    }

    function test_step_within_a_zone() {
        compare(Bars.step(layout(), [], "sound", 1).zones.system.end, ["network", "sound", "account"]);
        compare(Bars.step(layout(), [], "account", -1).zones.system.end, ["sound", "account", "network"]);
    }

    function test_step_into_the_next_zone() {
        const later = Bars.step(layout(), [], "workspaces", 1);
        compare(later.zones.dock.start, ["apps"]);
        compare(later.zones.dock.center, ["workspaces"]);
        const earlier = Bars.step(layout(), [], "sound", -1);
        compare(earlier.zones.system.center, ["sound"]);
    }

    function test_step_stops_at_the_bar_ends() {
        compare(Bars.step(layout(), [], "clock", -1), null);
        compare(Bars.step(layout(), [], "assistant", 1), null);
        compare(Bars.step(layout(), ["battery"], "battery", 1), null);
    }

    function test_half_size_items_pair_up() {
        compare(Bars.slots(["capture", "dictation", "assistant"], ["capture", "dictation"]),
            [["capture", "dictation"], ["assistant"]]);
        compare(Bars.slots(["a", "b", "c"], ["a", "b", "c"]), [["a", "b"], ["c"]]);
        compare(Bars.slots(["a", "b", "c"], ["a", "c"]), [["a"], ["b"], ["c"]]);
    }

    function test_clock_and_workspaces_stay_whole() {
        compare(Bars.slots(["clock", "sound"], ["clock", "sound"]), [["clock"], ["sound"]]);
        verify(!Bars.canHalve("workspaces"));
        verify(Bars.canHalve("apps"));
    }

    function test_home_of_a_hidden_item() {
        compare(Bars.home(layout(), "network"), { bar: "system", zone: "end", index: 1 });
        compare(Bars.home(layout(), "unknown").bar, "dock");
    }

    function test_quick_actions_become_three_buttons() {
        const saved = { system: { start: [], center: [], end: [] }, dock: { start: ["apps"], center: [], end: ["quick"] } };
        const migrated = Bars.migrate(saved, [], layout(), true);
        verify(migrated.changed);
        compare(migrated.zones.dock.end, ["capture", "dictation", "assistant"]);
    }

    function test_dictation_button_off_stays_off() {
        const saved = { system: { start: [], center: [], end: [] }, dock: { start: [], center: [], end: ["quick"] } };
        const migrated = Bars.migrate(saved, [], layout(), false);
        compare(migrated.zones.dock.end, ["capture", "assistant"]);
        compare(migrated.hidden, ["dictation"]);
    }

    function test_hidden_quick_actions_stay_hidden() {
        const saved = { system: { start: [], center: [], end: [] }, dock: { start: [], center: [], end: [] } };
        const migrated = Bars.migrate(saved, ["quick"], layout(), true);
        compare(migrated.hidden, ["capture", "dictation", "assistant"]);
        compare(migrated.zones.dock.end, []);
    }

    function test_new_items_go_where_they_are_by_default() {
        const saved = { system: { start: ["clock"], center: [], end: ["sound", "account"] },
            dock: { start: [], center: [], end: [] } };
        const migrated = Bars.migrate(saved, ["apps"], layout(), true);
        compare(migrated.zones.system.end, ["sound", "network", "account"]);
        compare(migrated.zones.dock.start, ["workspaces"]);
        compare(migrated.hidden, ["apps"]);
    }

    function test_first_start_takes_the_default_zones() {
        const migrated = Bars.migrate({}, [], layout(), true);
        verify(migrated.changed);
        compare(migrated.zones, layout());
    }

    function test_nothing_to_migrate() {
        verify(!Bars.migrate(layout(), [], layout(), true).changed);
    }
}
