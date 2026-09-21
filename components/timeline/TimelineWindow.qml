import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../../theme"
import "../common"

PanelWindow {
    id: root
    screen: MonitorService.targetScreen
    visible: OverlayState.timelineVisible
        && (OverlayState.layoutMode || (!MonitorService.hideWhenInactive || MonitorService.ffxivActive)
            && OverlayState.timeline.length > 0)
    color: "transparent"
    implicitWidth: 320
    implicitHeight: 250
    anchors.left: true
    anchors.top: true
    margins.left: LayoutService.x("timeline", root.screen, root.implicitWidth, root.implicitHeight)
    margins.top: LayoutService.y("timeline", root.screen, root.implicitWidth, root.implicitHeight)
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "faiyt-ffxiv-timeline"
    mask: Region { item: OverlayState.layoutMode ? content : null }

    Column {
        id: content
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
                text: "DRAG TIMELINE · RELEASE TO SAVE"
                color: Theme.base
                font.family: Theme.uiFont
                font.pixelSize: 11
                font.weight: Font.Bold
                font.letterSpacing: 1.1
            }

            MouseArea {
                id: timelineDrag
                anchors.fill: parent
                cursorShape: Qt.SizeAllCursor
                property real pressGlobalX: 0
                property real pressGlobalY: 0
                property real originX: 0
                property real originY: 0
                onPressed: mouse => {
                    const global = timelineDrag.mapToGlobal(mouse.x, mouse.y)
                    pressGlobalX = global.x; pressGlobalY = global.y
                    originX = root.margins.left; originY = root.margins.top
                }
                onPositionChanged: mouse => {
                    if (!pressed) return
                    const global = timelineDrag.mapToGlobal(mouse.x, mouse.y)
                    root.margins.left = Math.max(0, Math.min(root.screen.width - root.implicitWidth,
                        originX + global.x - pressGlobalX))
                    root.margins.top = Math.max(0, Math.min(root.screen.height - root.implicitHeight,
                        originY + global.y - pressGlobalY))
                }
                onReleased: LayoutService.savePosition("timeline", root.screen,
                    root.margins.left, root.margins.top, root.implicitWidth, root.implicitHeight)
                onCanceled: LayoutService.savePosition("timeline", root.screen,
                    root.margins.left, root.margins.top, root.implicitWidth, root.implicitHeight)
            }
        }

        OverlayCard {
            width: parent.width
            height: Math.min(root.height - (OverlayState.layoutMode ? 38 : 0), timelineColumn.implicitHeight + 24)
            backgroundOpacity: OverlayState.surfaceOpacity
            accentColor: Theme.iris

            Column {
                id: timelineColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 7

                Repeater {
                    model: OverlayState.timeline
                        .filter(event => event.startsIn <= SettingsService.timelineHorizonSeconds)
                        .slice(0, SettingsService.timelineRows)
                    Item {
                        required property var modelData
                        width: parent.width
                        height: 27

                        Rectangle { anchors.fill: parent; radius: 5; color: Theme.alpha(Theme.overlay, 0.58) }
                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: Math.max(3, parent.width * Math.min(1, Math.max(0, modelData.startsIn / Math.max(1, modelData.duration))))
                            radius: 5
                            color: Theme.alpha(modelData.startsIn <= 5 ? Theme.love : Theme.iris, 0.32)
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 9
                            anchors.right: countdown.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.text
                            elide: Text.ElideRight
                            color: Theme.text
                            font.family: Theme.uiFont
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                        }
                        Text {
                            id: countdown
                            anchors.right: parent.right
                            anchors.rightMargin: 9
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.startsIn > 0 ? modelData.startsIn.toFixed(0) : "NOW"
                            color: modelData.startsIn <= 5 ? Theme.love : Theme.subtle
                            font.family: Theme.monoFont
                            font.pixelSize: 12
                            font.weight: Font.Bold
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: LayoutService
        function onPositionsChanged() {
            if (!timelineDrag.pressed) {
                root.margins.left = LayoutService.x("timeline", root.screen, root.implicitWidth, root.implicitHeight)
                root.margins.top = LayoutService.y("timeline", root.screen, root.implicitWidth, root.implicitHeight)
            }
        }
    }

    Connections {
        target: MonitorService
        function onTargetChanged(screenName) {
            root.margins.left = LayoutService.x("timeline", root.screen, root.implicitWidth, root.implicitHeight)
            root.margins.top = LayoutService.y("timeline", root.screen, root.implicitWidth, root.implicitHeight)
        }
    }
}
