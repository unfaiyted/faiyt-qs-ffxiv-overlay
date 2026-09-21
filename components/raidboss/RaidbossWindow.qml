import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../../theme"
import "../common"

PanelWindow {
    id: root
    screen: MonitorService.targetScreen
    visible: OverlayState.raidbossVisible
        && (OverlayState.layoutMode || !MonitorService.hideWhenInactive || MonitorService.ffxivActive)
    color: "transparent"
    implicitWidth: 620
    implicitHeight: 250
    anchors.left: true
    anchors.top: true
    margins.left: LayoutService.x("raidboss", root.screen, root.implicitWidth, root.implicitHeight)
    margins.top: LayoutService.y("raidboss", root.screen, root.implicitWidth, root.implicitHeight)
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "faiyt-ffxiv-raidboss"
    mask: Region { item: OverlayState.layoutMode ? raidContent : null }

    Column {
        id: raidContent
        anchors.fill: parent
        spacing: 8

        Rectangle {
            width: parent.width
            height: OverlayState.layoutMode ? 30 : 0
            visible: OverlayState.layoutMode
            radius: 8
            color: Theme.alpha(Theme.gold, 0.88)
            border.width: 1
            border.color: Theme.text
            z: 100

            Text {
                anchors.centerIn: parent
                text: "DRAG RAIDBOSS · RELEASE TO SAVE"
                color: Theme.base
                font.family: Theme.uiFont
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.1
            }

            MouseArea {
                id: raidDrag
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                property real pressGlobalX: 0
                property real pressGlobalY: 0
                property real originX: 0
                property real originY: 0
                onPressed: mouse => {
                    const global = raidDrag.mapToGlobal(mouse.x, mouse.y)
                    pressGlobalX = global.x
                    pressGlobalY = global.y
                    originX = root.margins.left
                    originY = root.margins.top
                }
                onPositionChanged: mouse => {
                    if (!pressed)
                        return
                    const global = raidDrag.mapToGlobal(mouse.x, mouse.y)
                    root.margins.left = Math.max(0, Math.min(root.screen.width - root.implicitWidth,
                        originX + global.x - pressGlobalX))
                    root.margins.top = Math.max(0, Math.min(root.screen.height - root.implicitHeight,
                        originY + global.y - pressGlobalY))
                }
                onReleased: LayoutService.savePosition("raidboss", root.screen,
                    root.margins.left, root.margins.top, root.implicitWidth, root.implicitHeight)
                onCanceled: LayoutService.savePosition("raidboss", root.screen,
                    root.margins.left, root.margins.top, root.implicitWidth, root.implicitHeight)
            }
        }

        Repeater {
            model: OverlayState.alerts

            Rectangle {
                required property var modelData
                width: parent.width
                height: 48
                radius: 10
                color: Theme.alpha(modelData.severity === "alarm" ? Theme.love
                    : modelData.severity === "alert" ? Theme.gold : Theme.foam, 0.18)
                border.width: 1
                border.color: modelData.severity === "alarm" ? Theme.love
                    : modelData.severity === "alert" ? Theme.gold : Theme.foam

                Text {
                    anchors.centerIn: parent
                    text: modelData.text
                    color: Theme.text
                    font.family: Theme.uiFont
                    font.pixelSize: modelData.severity === "alarm" ? 22 : 18
                    font.weight: Font.Bold
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.remaining.toFixed(0)
                    color: Theme.subtle
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                }
            }
        }

    }

    Connections {
        target: LayoutService
        function onPositionsChanged() {
            if (!raidDrag.pressed) {
                root.margins.left = LayoutService.x("raidboss", root.screen, root.implicitWidth, root.implicitHeight)
                root.margins.top = LayoutService.y("raidboss", root.screen, root.implicitWidth, root.implicitHeight)
            }
        }
    }

    Connections {
        target: MonitorService
        function onTargetChanged(screenName) {
            root.margins.left = LayoutService.x("raidboss", root.screen, root.implicitWidth, root.implicitHeight)
            root.margins.top = LayoutService.y("raidboss", root.screen, root.implicitWidth, root.implicitHeight)
        }
    }
}
