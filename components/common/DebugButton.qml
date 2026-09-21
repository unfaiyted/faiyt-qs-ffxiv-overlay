import QtQuick
import "../../theme"

Rectangle {
    id: root
    property string text: "Button"
    property color accentColor: Theme.iris
    signal clicked

    implicitWidth: label.implicitWidth + 24
    implicitHeight: 34
    radius: 8
    color: mouse.containsMouse ? Theme.alpha(accentColor, 0.34) : Theme.highlightMed
    border.width: 1
    border.color: Theme.alpha(accentColor, 0.75)

    Text {
        id: label
        anchors.centerIn: parent
        text: root.text
        color: Theme.text
        font.family: Theme.uiFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

