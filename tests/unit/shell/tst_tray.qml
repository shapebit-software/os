// The background apps' icons as data (desktop/shell/services/tray.js), run by
// test_shell_logic.py with qmltestrunner.
import QtQuick
import QtTest
import "../../../desktop/shell/services/tray.js" as Tray

TestCase {
    name: "Tray"

    function test_passive_icons_are_not_shown() {
        const items = [{ id: "a", status: 1 }, { id: "b", status: 0 }, { id: "c", status: 2 }];
        compare(Tray.shown(items, 0).map(i => i.id), ["a", "c"]);
    }

    function test_side_by_side_icons_stand_a_place_and_the_spacing_apart() {
        compare(Tray.pitch(24, 2, false, false), 26);
        compare(Tray.pitch(24, 2, false, true), 26);
    }

    function test_stacked_icons_overlap_until_open() {
        verify(Tray.pitch(24, 2, true, false) < 24);
        compare(Tray.pitch(24, 2, true, true), Tray.pitch(24, 2, false, true));
    }

    function test_length_along_the_bar() {
        compare(Tray.length(0, 24, 26), 0);
        compare(Tray.length(1, 24, 26), 24);
        compare(Tray.length(3, 24, 26), 76);
        // Stacked, three icons take less than two side by side.
        verify(Tray.length(3, 24, Tray.pitch(24, 2, true, false)) < Tray.length(2, 24, 26));
    }

    function test_icon_names() {
        compare(Tray.iconName("image://icon/folder-remote"), "folder-remote");
        compare(Tray.iconName("image://icon/app?path=/opt/app/icons"), "");
        compare(Tray.iconName("image://service.sni/1/2"), "");
    }

    function test_symbolic_icons() {
        verify(Tray.symbolic("image://icon/mail-unread-symbolic"));
        verify(Tray.symbolic("image://icon/app-symbolic?path=/opt/app/icons"));
        verify(!Tray.symbolic("image://icon/symbolic-links"));
    }

    function test_labels_lose_their_access_key_marks() {
        compare(Tray.label("_Quit"), "Quit");
        compare(Tray.label("Save _As…"), "Save As…");
        compare(Tray.label("snake__case"), "snake_case");
        compare(Tray.label("Plain"), "Plain");
    }
}
