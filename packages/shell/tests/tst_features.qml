// What features add to the shell, merged into its own
// (packages/shell/src/services/features.js), run with qmltestrunner by the
// testing plugin.
import QtQuick
import QtTest
import "features.js" as Merge

TestCase {
    name: "Features"

    readonly property var own: [{ id: "account", rows: [] }, { id: "network", rows: [] }, { id: "apps", rows: [] }]
    readonly property var ownGroups: [["account"], ["network"], ["apps"]]
    readonly property var page: Component { Item {} }
    readonly property var assistant: ({
        sections: [{ id: "assistant", rows: [], group: 0, after: "account" }],
        pages: {
            "assistant-models": { title: "Models", section: "assistant", component: page },
            "assistant-permissions": { title: "Permissions", section: "assistant", rows: [{ label: "Web" }] },
        },
        shortcuts: { "super-up": () => "assistant" },
        items: { assistant: { icon: "M1 1", component: page } },
        actions: [{ name: "assistant", icon: "M1 1" }],
        provides: { tidy: text => `tidied ${text}` },
    })
    readonly property var capture: ({
        sections: [{ id: "capture", rows: [] }],
        shortcuts: { "screenshot": () => "capture", "super-up": () => "capture" },
        actions: [{ name: "capture", icon: "M2 2" }],
        rows: { network: [{ label: "Capture" }], "assistant-permissions": [{ label: "Screen" }] },
    })
    readonly property var dictation: ({
        rows: { network: [{ label: "Dictation" }], nowhere: [{ label: "Lost" }] },
    })

    function test_without_features_the_shell_is_its_own() {
        compare(Merge.sections(own, []), own);
        compare(Merge.groups(ownGroups, []), ownGroups);
        compare(Merge.pages({ wifi: ["Wi-Fi", "network"] }, []), { wifi: ["Wi-Fi", "network"] });
        compare(Merge.pageComponents([]), []);
        compare(Merge.shortcuts([]), {});
    }

    function test_a_features_sections_follow_the_shells() {
        compare(Merge.sections(own, [assistant, capture]).map(s => s.id), ["account", "network", "apps", "assistant", "capture"]);
    }

    function test_a_section_goes_after_the_one_it_names_or_last_of_the_last_group() {
        compare(Merge.groups(ownGroups, [assistant, capture]), [["account", "assistant"], ["network"], ["apps", "capture"]]);
    }

    function test_a_section_goes_before_the_one_it_names() {
        const store = { sections: [{ id: "store", group: 2, before: "apps" }] };
        compare(Merge.groups(ownGroups, [capture, store]), [["account"], ["network"], ["store", "apps", "capture"]]);
    }

    function test_the_shells_groups_are_not_changed() {
        Merge.groups(ownGroups, [assistant]);
        compare(ownGroups, [["account"], ["network"], ["apps"]]);
    }

    function test_pages_are_titled_and_rows_or_their_own() {
        compare(Merge.pages({}, [assistant]), {
            "assistant-models": ["Models", "assistant"],
            "assistant-permissions": ["Permissions", "assistant"],
        });
        compare(Merge.pageRows({}, [assistant]), { "assistant-permissions": [{ label: "Web" }] });
        const own = Merge.pageComponents([assistant]);
        compare(own.length, 1);
        compare(own[0].id, "assistant-models");
        verify(own[0].component === page);
    }

    function test_a_later_features_shortcut_takes_the_name() {
        const shortcuts = Merge.shortcuts([assistant, capture]);
        compare(Object.keys(shortcuts).sort(), ["screenshot", "super-up"]);
        compare(shortcuts["super-up"](), "capture");
    }

    function test_items_and_actions_are_every_features() {
        compare(Object.keys(Merge.items([assistant, capture])), ["assistant"]);
        compare(Merge.actions([assistant, capture]).map(a => a.name), ["assistant", "capture"]);
        compare(Merge.items([]), {});
        compare(Merge.actions([]), []);
    }

    function test_a_feature_does_for_others_what_it_provides() {
        compare(Merge.provided([capture, assistant], "tidy")("words"), "tidied words");
        compare(Merge.provided([capture], "tidy"), null);
    }

    function test_features_add_rows_to_others_sections_and_pages_after_theirs() {
        const own = [{ id: "account", rows: [] }, { id: "network", rows: [{ label: "Wi-Fi" }] }];
        const sections = Merge.sections(own, [capture, dictation]);
        compare(sections[1].rows.map(r => r.label), ["Wi-Fi", "Capture", "Dictation"]);
        compare(own[1].rows.length, 1);
        compare(Merge.pageRows({}, [assistant, capture])["assistant-permissions"].map(r => r.label), ["Web", "Screen"]);
        compare(Object.keys(Merge.pageRows({}, [dictation])), []);
    }

    function test_actions_go_by_their_order_then_by_feature() {
        const first = { actions: [{ name: "late", order: 2 }, { name: "none" }] };
        const second = { actions: [{ name: "early", order: 0 }, { name: "also-late", order: 2 }] };
        compare(Merge.actions([first, second]).map(a => a.name), ["early", "late", "also-late", "none"]);
    }

    function test_portals_are_every_features() {
        const handler = { ask: () => {} };
        compare(Merge.portals([assistant, { portals: { screenshot: handler } }]), { screenshot: handler });
        compare(Merge.portals([]), {});
    }
}
