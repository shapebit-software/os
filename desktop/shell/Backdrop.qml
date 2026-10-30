// The wallpaper (Settings.wallpaper): Dusk, which is drawn, one of the demo's
// gradients, or a picture.
pragma ComponentBehavior: Bound
import QtQuick

Item {
    id: backdrop

    property string preset: Settings.wallpaper
    property string image: Settings.wallpaperImage

    // The gradients: a CSS angle, and stops of [position, OKLCH lightness,
    // chroma, hue].
    readonly property var gradients: ({
        "Slate": [160, [[0, 0.42, 0.02, 250], [1, 0.22, 0.015, 250]]],
        "Dune": [170, [[0, 0.82, 0.05, 70], [0.6, 0.62, 0.08, 45], [1, 0.38, 0.05, 30]]],
        "Fjord": [175, [[0, 0.70, 0.05, 220], [0.55, 0.42, 0.07, 210], [1, 0.24, 0.04, 230]]],
        "Moss": [165, [[0, 0.58, 0.06, 140], [1, 0.32, 0.05, 155]]],
    })
    readonly property var gradient: gradients[preset] ?? null
    readonly property bool showsImage: preset === "Image" && image !== "" && picture.status !== Image.Error

    clip: true

    Dusk {
        anchors.fill: parent
        visible: !backdrop.gradient && !backdrop.showsImage
    }

    // A gradient along a CSS angle: 180 runs from top to bottom. A vertical
    // gradient, turned to the angle, as long as CSS makes it, so its ends
    // touch the corners, and wide enough to cover the screen.
    Rectangle {
        id: gradientFill

        readonly property real angle: backdrop.gradient?.[0] ?? 180
        readonly property real radians: angle * Math.PI / 180

        function stop(i: int): var {
            const stops = backdrop.gradient?.[1] ?? [[0, 0, 0, 0]];
            return stops[Math.min(i, stops.length - 1)];
        }

        visible: backdrop.gradient !== null && !backdrop.showsImage
        anchors.centerIn: parent
        width: backdrop.width + backdrop.height
        height: Math.abs(backdrop.width * Math.sin(radians)) + Math.abs(backdrop.height * Math.cos(radians))
        rotation: angle - 180
        // Two stops or three; with two, the last repeats.
        gradient: Gradient {
            GradientStop { position: gradientFill.stop(0)[0]; color: Theme.oklch(...gradientFill.stop(0).slice(1)) }
            GradientStop { position: gradientFill.stop(1)[0]; color: Theme.oklch(...gradientFill.stop(1).slice(1)) }
            GradientStop { position: gradientFill.stop(2)[0]; color: Theme.oklch(...gradientFill.stop(2).slice(1)) }
        }
    }

    Image {
        id: picture

        anchors.fill: parent
        visible: backdrop.showsImage
        source: backdrop.preset === "Image" && backdrop.image ? "file://" + backdrop.image : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        // A picture as large as the screen at most.
        sourceSize.width: backdrop.width
    }
}
