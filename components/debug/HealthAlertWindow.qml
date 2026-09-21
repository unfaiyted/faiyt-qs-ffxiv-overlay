import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../../theme"
import "../common"

PanelWindow {
    id: root
    screen: MonitorService.targetScreen
    visible: SettingsService.healthAlertsEnabled && OverlayState.healthFailures.length > 0
    color: "transparent"
    implicitWidth: 430
    implicitHeight: alertContent.implicitHeight + 24
    anchors.left: true
    anchors.top: true
    margins.left: 18
    margins.top: 18
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "faiyt-ffxiv-health-alert"

    Rectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.alpha(Theme.base, 0.94)
        border.width: 1
        border.color: Theme.alpha(Theme.love, 0.85)

        Column {
            id: alertContent
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            anchors.margins: 12
            spacing: 7
            Row {
                width: parent.width; height: 22; spacing: 8
                Text { text: "!"; color: Theme.love; font.family: Theme.uiFont; font.pixelSize: 16; font.weight: Font.Bold }
                Text { text: "OVERLAY HEALTH ISSUE"; color: Theme.love; font.family: Theme.uiFont; font.pixelSize: 12; font.weight: Font.Bold; font.letterSpacing: 1.0 }
            }
            Repeater {
                model: OverlayState.healthFailures
                Column {
                    required property var modelData
                    width: alertContent.width
                    spacing: 2
                    Text { text: modelData.title; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 12; font.weight: Font.DemiBold }
                    Text { width: parent.width; text: modelData.detail; color: Theme.subtle; font.family: Theme.monoFont; font.pixelSize: 10; elide: Text.ElideMiddle }
                }
            }
            Row {
                spacing: 8
                DebugButton { text: "Restart runtime"; accentColor: Theme.love; onClicked: OverlayState.restartBridge() }
                DebugButton { text: "Diagnostics"; accentColor: Theme.gold; onClicked: OverlayState.diagnosticsVisible = true }
            }
        }
    }
}
