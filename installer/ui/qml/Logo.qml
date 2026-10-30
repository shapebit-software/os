// The ShapeBit mark: a narrow accent bar beside a light block.
import QtQuick

Row {
    id: logo

    property real size: 20

    spacing: Math.max(1, size / 14)

    Rectangle { width: logo.size * 0.24; height: logo.size; color: Theme.accent }
    Rectangle { width: logo.size * 0.74; height: logo.size; color: Theme.text }
}
