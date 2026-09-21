import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../../theme"
import "../common"

PanelWindow {
    id: root
    screen: MonitorService.targetScreen
    visible: OverlayState.diagnosticsVisible
    color: "transparent"
    implicitWidth: 600
    implicitHeight: 790
    anchors.right: true
    anchors.bottom: true
    margins.right: 24
    margins.bottom: 24
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "faiyt-ffxiv-diagnostics"

    property var logs: []
    Connections {
        target: OverlayState
        function onDiagnostic(level, message) {
            const next = root.logs.slice()
            next.unshift({ level: level, message: message, time: Qt.formatTime(new Date(), "hh:mm:ss") })
            root.logs = next.slice(0, 16)
        }
    }

    OverlayCard {
        anchors.fill: parent
        backgroundOpacity: 0.96
        accentColor: Theme.gold
        Flickable {
            id: diagnosticScroll
            anchors.fill: parent
            anchors.margins: 18
            contentWidth: width
            contentHeight: diagnosticContent.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
        Column {
            id: diagnosticContent
            width: diagnosticScroll.width; spacing: 13
            Row {
                width: parent.width; height: 40
                Column {
                    width: parent.width - closeButton.width
                    Text { text: "FFXIV OVERLAY DIAGNOSTICS"; color: Theme.gold; font.family: Theme.uiFont; font.pixelSize: 16; font.weight: Font.Bold; font.letterSpacing: 1.1 }
                    Text { text: "Runtime health, event probes, and logs"; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 11 }
                }
                DebugButton { id: closeButton; text: "Close"; accentColor: Theme.love; onClicked: OverlayState.toggleDiagnostics() }
            }
            Rectangle { width: parent.width; height: 1; color: Theme.highlightMed }
            Grid {
                width: parent.width; columns: 2; columnSpacing: 12; rowSpacing: 7
                Text { text: "IINACT bridge"; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 12 }
                Text { text: OverlayState.connectionState.toUpperCase(); color: OverlayState.connectionState === "connected" ? Theme.foam : Theme.gold; font.family: Theme.monoFont; font.pixelSize: 12; font.weight: Font.Bold }
                Text { text: "Cactbot"; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 12 }
                Text { text: OverlayState.cactbotState.toUpperCase(); color: OverlayState.cactbotState === "connected" ? Theme.foam : Theme.love; font.family: Theme.monoFont; font.pixelSize: 12; font.weight: Font.Bold }
                Text { text: "Chromium DevTools"; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 12 }
                Text {
                    text: OverlayState.cactbotState === "connected" ? "REACHABLE" : OverlayState.cactbotState === "starting" ? "STARTING" : "UNAVAILABLE"
                    color: OverlayState.cactbotState === "connected" ? Theme.foam : OverlayState.cactbotState === "starting" ? Theme.gold : Theme.love
                    font.family: Theme.monoFont; font.pixelSize: 12; font.weight: Font.Bold
                }
                Text { text: "Endpoint"; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 12 }
                Text { text: OverlayState.endpoint; color: Theme.text; font.family: Theme.monoFont; font.pixelSize: 12 }
                Text { text: "Player / zone"; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 12 }
                Text { width: 390; text: OverlayState.playerName + " · " + OverlayState.zoneName; elide: Text.ElideRight; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 12 }
                Text { text: "State"; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 12 }
                Text { text: OverlayState.dataMode.toUpperCase() + " · " + (OverlayState.inCombat ? "IN COMBAT" : "IDLE") + " · " + (MonitorService.ffxivActive ? "FOCUSED" : "UNFOCUSED"); color: OverlayState.inCombat ? Theme.love : Theme.muted; font.family: Theme.monoFont; font.pixelSize: 12; font.weight: Font.Bold }
                Text { text: "Summerford test"; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 12 }
                Text { text: OverlayState.raidbossTestRunning ? "RUNNING" : OverlayState.raidbossTestReady ? "READY — /countdown 5" : "NOT READY"; color: OverlayState.raidbossTestRunning ? Theme.love : OverlayState.raidbossTestReady ? Theme.gold : Theme.muted; font.family: Theme.monoFont; font.pixelSize: 12; font.weight: Font.Bold }
            }
            Rectangle {
                width: parent.width
                height: cactbotDetailText.implicitHeight + 16
                radius: 7
                color: Theme.alpha(OverlayState.cactbotState === "error" ? Theme.love : Theme.highlightLow, OverlayState.cactbotState === "error" ? 0.18 : 0.7)
                border.width: OverlayState.cactbotState === "error" ? 1 : 0
                border.color: Theme.alpha(Theme.love, 0.65)
                Text {
                    id: cactbotDetailText
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 8
                    text: "Cactbot runtime: " + OverlayState.cactbotDetail
                    color: OverlayState.cactbotState === "error" ? Theme.love : Theme.subtle
                    font.family: Theme.monoFont; font.pixelSize: 10; wrapMode: Text.Wrap
                }
            }

            Text { text: "CACTBOT UPSTREAM"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.4 }
            Rectangle {
                width: parent.width
                height: updateDetails.implicitHeight + 18
                radius: 7
                color: Theme.alpha(CactbotUpdateService.updateAvailable ? Theme.gold : Theme.highlightLow, CactbotUpdateService.updateAvailable ? 0.18 : 0.7)
                border.width: CactbotUpdateService.updateAvailable ? 1 : 0
                border.color: Theme.alpha(Theme.gold, 0.7)
                Column {
                    id: updateDetails
                    anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: 9
                    spacing: 3
                    Text {
                        text: CactbotUpdateService.status.toUpperCase() + " · pinned " + CactbotUpdateService.currentShort + " · upstream " + CactbotUpdateService.latestShort
                        color: CactbotUpdateService.updateAvailable ? Theme.gold : CactbotUpdateService.status === "error" ? Theme.love : Theme.foam
                        font.family: Theme.monoFont; font.pixelSize: 10; font.weight: Font.Bold
                    }
                    Text { width: parent.width; text: CactbotUpdateService.detail; color: Theme.subtle; font.family: Theme.monoFont; font.pixelSize: 10; wrapMode: Text.Wrap }
                    Text { visible: CactbotUpdateService.updateAvailable; width: parent.width; text: "New upstream revisions have not been tested with this adapter and may contain breaking changes."; color: Theme.gold; font.family: Theme.uiFont; font.pixelSize: 10; wrapMode: Text.Wrap }
                }
            }
            Flow {
                width: parent.width; spacing: 8
                DebugButton { text: CactbotUpdateService.status === "checking" ? "Checking…" : "Check upstream"; accentColor: Theme.iris; onClicked: CactbotUpdateService.checkNow() }
                DebugButton {
                    visible: CactbotUpdateService.updateAvailable
                    text: CactbotUpdateService.confirmationPending ? "Confirm untested update" : CactbotUpdateService.status === "updating" ? "Building update…" : "Update cactbot"
                    accentColor: CactbotUpdateService.confirmationPending ? Theme.love : Theme.gold
                    onClicked: CactbotUpdateService.confirmationPending ? CactbotUpdateService.applyUpdate() : CactbotUpdateService.requestUpdate()
                }
                Text { text: "Last check: " + CactbotUpdateService.lastChecked; color: Theme.muted; font.family: Theme.monoFont; font.pixelSize: 9 }
            }

            Text { text: "BRIDGE & DATA"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.4 }
            Flow {
                width: parent.width; spacing: 8
                DebugButton { text: "Restart cactbot runtime"; accentColor: OverlayState.cactbotState === "error" ? Theme.love : Theme.pine; onClicked: OverlayState.restartBridge() }
                DebugButton { text: "Use mock data"; accentColor: Theme.muted; onClicked: OverlayState.startDemo() }
                DebugButton { text: "Reset mock fight"; accentColor: Theme.iris; onClicked: OverlayState.resetDemo() }
            }
            Text { text: "EVENT PROBES"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.4 }
            Flow {
                width: parent.width; spacing: 8
                DebugButton { text: "Alarm"; accentColor: Theme.love; onClicked: OverlayState.injectAlert("alarm", "Tankbuster on YOU") }
                DebugButton { text: "Alert"; accentColor: Theme.gold; onClicked: OverlayState.injectAlert("alert", "Spread") }
                DebugButton { text: "Info"; accentColor: Theme.foam; onClicked: OverlayState.injectAlert("info", "Stack middle") }
                DebugButton { text: "Clear alerts"; accentColor: Theme.muted; onClicked: OverlayState.clearAlerts() }
            }
            Text { text: "AUDIO PROBES  ·  PIPER " + (AudioService.ttsAvailable ? "READY" : "MISSING"); color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.2 }
            Flow {
                width: parent.width; spacing: 8
                DebugButton { text: "Info cue"; accentColor: Theme.foam; onClicked: AudioService.playAlert("info", "Info test", "Info test") }
                DebugButton { text: "Alert cue"; accentColor: Theme.gold; onClicked: AudioService.playAlert("alert", "Alert test", "Alert test") }
                DebugButton { text: "Alarm cue"; accentColor: Theme.love; onClicked: AudioService.playAlert("alarm", "Alarm test", "Alarm test") }
                DebugButton { text: "Pull cue"; accentColor: Theme.pine; onClicked: AudioService.playAlert("pull", "", "") }
                DebugButton { text: "Piper sample"; accentColor: Theme.iris; onClicked: AudioService.speakSample() }
            }

            Text { text: "SESSION LOG"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.4 }
            Rectangle {
                width: parent.width; height: 205; radius: 8; color: Theme.alpha(Theme.base, 0.72); border.width: 1; border.color: Theme.highlightMed
                Flickable {
                    id: sessionLog
                    anchors.fill: parent
                    anchors.margins: 10
                    anchors.rightMargin: 16
                    contentWidth: width
                    contentHeight: logEntries.implicitHeight
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    flickableDirection: Flickable.VerticalFlick

                    Column {
                        id: logEntries
                        width: sessionLog.width
                        spacing: 4
                        Repeater {
                            model: root.logs
                            Text {
                                required property var modelData
                                width: logEntries.width
                                text: modelData.time + "  " + modelData.level.toUpperCase() + "  " + modelData.message
                                color: modelData.level === "error" ? Theme.love : modelData.level === "warning" ? Theme.gold : modelData.level === "debug" ? Theme.subtle : Theme.foam
                                font.family: Theme.monoFont
                                font.pixelSize: 10
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
                Rectangle {
                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    y: 10 + (sessionLog.visibleArea.yPosition * sessionLog.height)
                    width: 3
                    height: Math.max(18, sessionLog.visibleArea.heightRatio * sessionLog.height)
                    radius: 2
                    color: Theme.alpha(Theme.gold, 0.75)
                    visible: sessionLog.contentHeight > sessionLog.height
                }
            }
            Text { width: parent.width; wrapMode: Text.WordWrap; text: "Persistent history: ~/.local/state/faiyt-qs-ffxiv-overlay/events-YYYY-MM-DD.jsonl"; color: Theme.muted; font.family: Theme.monoFont; font.pixelSize: 10 }
        }
        }
    }
}
