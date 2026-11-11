// The notifications' rules as data (desktop/shell/services/notifications.js),
// run by test_shell_logic.py with qmltestrunner.
import QtQuick
import QtTest
import "../../../desktop/shell/services/notifications.js" as Rules

TestCase {
    name: "Notifications"

    readonly property var apps: ({
        chat: { name: "Chat", mode: "Banners" },
        mail: { name: "Mail", mode: "Center only" },
        game: { name: "Game", mode: "Off" },
    })

    function test_an_application_is_its_desktop_entry_or_its_name() {
        compare(Rules.keyOf({ desktopEntry: "org.chat", appName: "Chat" }), "org.chat");
        compare(Rules.keyOf({ desktopEntry: "", appName: "Chat" }), "Chat");
    }

    function test_an_application_not_chosen_for_shows_banners() {
        compare(Rules.modeOf(apps, "new"), "Banners");
        compare(Rules.modeOf({ odd: { name: "Odd", mode: "Loud" } }, "odd"), "Banners");
    }

    function test_off_keeps_nothing() {
        verify(!Rules.keeps(apps, "game"));
        verify(Rules.keeps(apps, "mail"));
        verify(!Rules.banners(apps, "game", Rules.critical, false));
    }

    function test_center_only_shows_no_banner() {
        verify(!Rules.banners(apps, "mail", 1, false));
        verify(!Rules.banners(apps, "mail", Rules.critical, false));
    }

    function test_low_urgency_shows_no_banner() {
        verify(!Rules.banners(apps, "chat", Rules.low, false));
        verify(Rules.banners(apps, "chat", 1, false));
    }

    function test_quiet_holds_all_but_critical() {
        verify(!Rules.banners(apps, "chat", 1, true));
        verify(Rules.banners(apps, "chat", Rules.critical, true));
    }

    function test_held_counts_only_what_the_quiet_held() {
        verify(Rules.held(apps, "chat", 1, true));
        verify(!Rules.held(apps, "chat", 1, false));
        verify(!Rules.held(apps, "chat", Rules.critical, true));
        verify(!Rules.held(apps, "chat", Rules.low, true));
        verify(!Rules.held(apps, "mail", 1, true));
    }

    function test_remember_adds_an_application_once() {
        const next = Rules.remember(apps, "org.new", "New");
        compare(next["org.new"], { name: "New", mode: "Banners" });
        compare(Rules.remember(next, "org.new", "New"), null);
        compare(Rules.remember(apps, "", ""), null);
        verify(apps["org.new"] === undefined);
    }

    function test_remember_keeps_the_choice_when_the_name_changes() {
        compare(Rules.remember(apps, "mail", "Post").mail, { name: "Post", mode: "Center only" });
    }

    function test_set_mode() {
        compare(Rules.setMode(apps, "chat", "Off").chat, { name: "Chat", mode: "Off" });
        compare(apps.chat.mode, "Banners");
        compare(Rules.setMode(apps, "org.new", "Off", "New")["org.new"], { name: "New", mode: "Off" });
    }

    function test_list_is_by_name() {
        compare(Rules.list(apps).map(a => a.key), ["chat", "game", "mail"]);
    }

    function test_groups_by_application_newest_first() {
        const a1 = { desktopEntry: "a", appName: "A", id: 1 };
        const b2 = { desktopEntry: "b", appName: "B", id: 2 };
        const a3 = { desktopEntry: "a", appName: "A", id: 3 };
        const grouped = Rules.groups([a3, b2, a1]);
        compare(grouped.map(g => g.key), ["a", "b"]);
        compare(grouped[0].name, "A");
        compare(grouped[0].items.map(n => n.id), [3, 1]);
        compare(grouped[1].items.map(n => n.id), [2]);
    }

    function test_quiet_for_an_hour() {
        compare(Rules.quietUntil("For 1 hour", 1000), 3601000);
        compare(Rules.quietUntil("Until turned off", 1000), 0);
    }

    function test_quiet_until_tomorrow_is_the_next_morning() {
        const evening = new Date(2026, 10, 11, 22, 0).getTime();
        compare(Rules.quietUntil("Until tomorrow", evening), new Date(2026, 10, 12, 7, 0).getTime());
        const night = new Date(2026, 10, 12, 1, 0).getTime();
        compare(Rules.quietUntil("Until tomorrow", night), new Date(2026, 10, 12, 7, 0).getTime());
    }

    function test_quiet_until_tomorrow_is_at_least_an_hour() {
        const early = new Date(2026, 10, 12, 6, 30).getTime();
        compare(Rules.quietUntil("Until tomorrow", early), new Date(2026, 10, 13, 7, 0).getTime());
    }

    function test_quiet_ends_once_its_time_has_come() {
        verify(!Rules.quietOver(0, 5000));
        verify(!Rules.quietOver(6000, 5000));
        verify(Rules.quietOver(5000, 5000));
    }

    function test_banners_show_nearest_the_bell() {
        compare(Rules.corner("Top", "end"), { top: true, side: "right" });
        compare(Rules.corner("Top", "start"), { top: true, side: "left" });
        compare(Rules.corner("Top", "center"), { top: true, side: "center" });
        compare(Rules.corner("Bottom", "center"), { top: false, side: "center" });
        compare(Rules.corner("Left", "end"), { top: false, side: "left" });
        compare(Rules.corner("Right", "center"), { top: true, side: "right" });
        compare(Rules.corner("", ""), { top: true, side: "right" });
    }
}
