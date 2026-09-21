import QtQuick
import "../../theme"

Rectangle {
    id: root
    property alias text: input.text
    property string label: ""
    signal accepted(string value)

    implicitHeight: 48
    radius: 8
    color: Theme.highlightLow
    border.width: input.activeFocus ? 1 : 0
    border.color: Theme.iris

    Text {
        anchors.left: parent.left; anchors.leftMargin: 10; anchors.top: parent.top; anchors.topMargin: 5
        text: root.label
        color: Theme.muted
        font.family: Theme.uiFont; font.pixelSize: 9; font.weight: Font.Bold
    }
    TextInput {
        id: input
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.bottomMargin: 6
        color: Theme.text
        selectionColor: Theme.iris
        selectedTextColor: Theme.base
        font.family: Theme.monoFont; font.pixelSize: 11
        clip: true
        selectByMouse: true
        onEditingFinished: root.accepted(text.trim())
    }
}
