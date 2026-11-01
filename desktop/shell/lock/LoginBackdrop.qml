// The backdrop: dusk behind soft ridges. It is drawn, not a picture, so it
// fits every screen size.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Rectangle {
    id: backdrop

    clip: true
    gradient: Gradient {
        GradientStop { position: 0.00; color: "#272140" }
        GradientStop { position: 0.175; color: "#2c2346" }
        GradientStop { position: 0.333; color: "#352551" }
        GradientStop { position: 0.412; color: "#492f4d" }
        GradientStop { position: 0.49; color: "#5c3444" }
        GradientStop { position: 0.57; color: "#703838" }
        GradientStop { position: 0.649; color: "#814130" }
        GradientStop { position: 0.73; color: "#854a30" }
    }

    // A soft light, placed by its center and radii as fractions of the screen.
    component Glow: Shape {
        id: glow

        property real centerX
        property real centerY
        property real radiusX
        property real radiusY
        property color tint

        x: (centerX - radiusX) * backdrop.width
        y: (centerY - radiusY) * backdrop.height
        width: 200
        height: 200
        transform: Scale {
            xScale: glow.radiusX * backdrop.width / 100
            yScale: glow.radiusY * backdrop.height / 100
        }

        ShapePath {
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: 100
                centerY: 100
                centerRadius: 100
                focalX: 100
                focalY: 100
                GradientStop { position: 0.0; color: glow.tint }
                GradientStop { position: 0.5; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, glow.tint.a * 0.55) }
                GradientStop { position: 1.0; color: Qt.rgba(glow.tint.r, glow.tint.g, glow.tint.b, 0) }
            }
            PathAngleArc { centerX: 100; centerY: 100; radiusX: 100; radiusY: 100; sweepAngle: 360 }
        }
    }

    // Haze at the top, and the sun low in the sky.
    Glow { centerX: 0.17; centerY: 0.05; radiusX: 0.55; radiusY: 0.4; tint: Qt.rgba(0.66, 0.6, 0.86, 0.13) }
    Glow { centerX: 0.88; centerY: 0.1; radiusX: 0.4; radiusY: 0.3; tint: Qt.rgba(0.75, 0.62, 0.8, 0.09) }
    Glow { centerX: 0.62; centerY: 0.66; radiusX: 0.33; radiusY: 0.2; tint: Qt.rgba(0.82, 0.62, 0.3, 0.52) }

    // The ridges are drawn small and blurred there, then stretched over the
    // screen, so the blur costs the same on every screen. The drawing reaches
    // a tenth past each edge of the screen, because the blur fades at its own
    // edges. Paths use a 1000 by 1000 grid for the screen.
    Item {
        id: ridges
        width: 600
        height: 600
        visible: false

        Shape {
            x: 50
            y: 50
            scale: 0.5
            transformOrigin: Item.TopLeft

            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    y1: 690
                    y2: 890
                    GradientStop { position: 0.0; color: "#994b445c" }
                    GradientStop { position: 1.0; color: "#991c2b5d" }
                }
                PathSvg {
                    path: "M-100 776 L-40 776 L57 734 L144 767 L252 686 L349 752 L468 710 L586 785 "
                        + "L694 722 L813 776 L921 740 L1040 794 L1100 794 V1100 H-100 Z"
                }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: "#d1221e33"
                PathSvg {
                    path: "M-100 961 L-40 961 L90 914 L198 956 L316 894 L446 951 L565 909 L673 961 "
                        + "L792 917 L910 964 L1040 925 L1100 925 V1100 H-100 Z"
                }
            }
        }
    }
    MultiEffect {
        source: ridges
        x: -0.1 * backdrop.width
        y: -0.1 * backdrop.height
        width: ridges.width
        height: ridges.height
        transform: Scale {
            xScale: 1.2 * backdrop.width / ridges.width
            yScale: 1.2 * backdrop.height / ridges.height
        }
        blurEnabled: true
        blur: 1
        blurMax: 40
    }
}
