import QtQuick
import "../../theme"

Rectangle {
    id: root
    property real backgroundOpacity: 0.78
    property color accentColor: Theme.iris
    property bool framed: true

    color: framed ? Theme.alpha(Theme.surface, backgroundOpacity) : "transparent"
    radius: 12
    border.width: framed ? 1 : 0
    border.color: Theme.alpha(accentColor, 0.55)
}
