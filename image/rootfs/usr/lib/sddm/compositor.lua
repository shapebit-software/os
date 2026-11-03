-- The compositor of the login screen: Hyprland, which the desktop runs too,
-- showing SDDM's greeter full screen (sddm.conf.d/10-login.conf). Weston,
-- SDDM's usual one, draws no cursor: it tells the greeter that the pointer
-- entered without a serial, and Qt sets a cursor only with one.
-- Nothing else is configured: no shortcuts, no animations, and the night color
-- of the boot splash behind the greeter until it draws.
hl.config({
    general    = { gaps_in = 0, gaps_out = 0, border_size = 0 },
    decoration = { rounding = 0, shadow = { enabled = false }, blur = { enabled = false } },
    animations = { enabled = false },
    ecosystem  = { no_update_news = true, no_donation_nag = true },
    misc = {
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
        force_default_wallpaper  = 0,
        background_color         = "rgb(1f1a3c)",
        disable_xdg_env_checks   = true,
    },
})

hl.window_rule({ match = { class = ".*" }, fullscreen = true })
