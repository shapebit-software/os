//! Generated bindings for ShapeBit's private Wayland protocols.
//!
//! The current XML contains only the experimental shell-bar subset.

#![allow(clippy::all)]

const _: &[u8] = include_bytes!("../shapebit-shell-v1.xml");

#[cfg(feature = "client")]
pub mod client {
    use wayland_client;
    use wayland_client::protocol::*;

    pub mod __interfaces {
        use wayland_client::protocol::__interfaces::*;

        wayland_scanner::generate_interfaces!("shapebit-shell-v1.xml");
    }

    use self::__interfaces::*;
    wayland_scanner::generate_client_code!("shapebit-shell-v1.xml");
}

#[cfg(feature = "server")]
pub mod server {
    use wayland_server;
    use wayland_server::protocol::*;

    pub mod __interfaces {
        use wayland_server::protocol::__interfaces::*;

        wayland_scanner::generate_interfaces!("shapebit-shell-v1.xml");
    }

    use self::__interfaces::*;
    wayland_scanner::generate_server_code!("shapebit-shell-v1.xml");
}
