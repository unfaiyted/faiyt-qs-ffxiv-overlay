import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../services"
import "../../theme"
import "../common"

PanelWindow {
    id: root
    screen: MonitorService.targetScreen
    visible: OverlayState.debugVisible
    color: "transparent"
    implicitWidth: 540
    implicitHeight: 790
    anchors.left: true
    anchors.bottom: true
    margins.left: 24
    margins.bottom: 24
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    WlrLayershell.namespace: "faiyt-ffxiv-settings"

    function cycleTtsMode() {
        const modes = ["off", "alarm", "important", "all"]
        SettingsService.ttsMode = modes[(modes.indexOf(SettingsService.ttsMode) + 1) % modes.length]
    }

    OverlayCard {
        anchors.fill: parent
        backgroundOpacity: 0.96
        accentColor: Theme.iris
        Flickable {
            id: scroll
            anchors.fill: parent
            anchors.margins: 18
            contentWidth: width
            contentHeight: content.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            Column {
                id: content
                width: scroll.width
                spacing: 14
                Row {
                    width: parent.width; height: 40
                    Column {
                        width: parent.width - closeButton.width
                        Text { text: "FFXIV OVERLAY SETTINGS"; color: Theme.iris; font.family: Theme.uiFont; font.pixelSize: 16; font.weight: Font.Bold; font.letterSpacing: 1.1 }
                        Text { text: "Preferences save automatically"; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 11 }
                    }
                    DebugButton { id: closeButton; text: "Close"; accentColor: Theme.love; onClicked: OverlayState.toggleDebug() }
                }
                Rectangle { width: parent.width; height: 1; color: Theme.highlightMed }

                Text { text: "AUDIO & SPEECH"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.4 }
                Flow {
                    width: parent.width; spacing: 8
                    DebugButton { text: SettingsService.soundsEnabled ? "Sounds: ON" : "Sounds: OFF"; accentColor: SettingsService.soundsEnabled ? Theme.foam : Theme.muted; onClicked: SettingsService.soundsEnabled = !SettingsService.soundsEnabled }
                    DebugButton { text: AudioService.ttsAvailable ? "Piper TTS: " + SettingsService.ttsMode.toUpperCase() : "Piper unavailable"; accentColor: SettingsService.ttsMode !== "off" && AudioService.ttsAvailable ? Theme.iris : Theme.muted; onClicked: if (AudioService.ttsAvailable) root.cycleTtsMode() }
                    DebugButton { text: "Test Piper"; accentColor: Theme.rose; onClicked: AudioService.speakSample() }
                }
                Text { width: parent.width; wrapMode: Text.WordWrap; text: "ALARM speaks alarms only. IMPORTANT adds alert callouts. ALL also speaks info and TTS-only cactbot cues. Speech always uses local Piper."; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 10 }
                Text { text: "VOLUME  " + Math.round(SettingsService.volume * 100) + "%"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold }
                Rectangle {
                    width: parent.width; height: 24; radius: 7; color: Theme.highlightLow
                    Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 5; height: 7; width: (parent.width - 10) * SettingsService.volume; radius: 4; color: Theme.foam }
                    MouseArea { anchors.fill: parent; onPressed: mouse => SettingsService.volume = Math.max(0, Math.min(1, mouse.x / width)); onPositionChanged: mouse => { if (pressed) SettingsService.volume = Math.max(0, Math.min(1, mouse.x / width)) } }
                }

                Text { text: "OVERLAYS"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.4 }
                Flow {
                    width: parent.width; spacing: 8
                    DebugButton { text: SettingsService.raidbossVisible ? "Raid alerts: ON" : "Raid alerts: OFF"; accentColor: SettingsService.raidbossVisible ? Theme.rose : Theme.muted; onClicked: OverlayState.toggleRaidboss() }
                    DebugButton { text: SettingsService.timelineVisible ? "Timeline: ON" : "Timeline: OFF"; accentColor: SettingsService.timelineVisible ? Theme.iris : Theme.muted; onClicked: OverlayState.toggleTimeline() }
                    DebugButton { text: SettingsService.dpsVisible ? "DPS meter: ON" : "DPS meter: OFF"; accentColor: SettingsService.dpsVisible ? Theme.pine : Theme.muted; onClicked: OverlayState.toggleDps() }
                    DebugButton {
                        text: "DPS idle: " + SettingsService.dpsIdleMode.toUpperCase()
                        accentColor: SettingsService.dpsIdleMode === "hide" ? Theme.love : SettingsService.dpsIdleMode === "dim" ? Theme.gold : Theme.foam
                        onClicked: {
                            const modes = ["show", "dim", "hide"]
                            SettingsService.dpsIdleMode = modes[(modes.indexOf(SettingsService.dpsIdleMode) + 1) % modes.length]
                        }
                    }
                    DebugButton {
                        text: SettingsService.dpsFrameEnabled ? "DPS frame: ON" : "DPS frame: OFF"
                        accentColor: SettingsService.dpsFrameEnabled ? Theme.pine : Theme.muted
                        onClicked: SettingsService.dpsFrameEnabled = !SettingsService.dpsFrameEnabled
                    }
                    DebugButton {
                        text: SettingsService.dpsHoverOpacityEnabled ? "DPS hover focus: ON" : "DPS hover focus: OFF"
                        accentColor: SettingsService.dpsHoverOpacityEnabled ? Theme.foam : Theme.muted
                        onClicked: SettingsService.dpsHoverOpacityEnabled = !SettingsService.dpsHoverOpacityEnabled
                    }
                    DebugButton { text: OverlayState.layoutMode ? "Finish layout" : "Edit layout"; accentColor: Theme.gold; onClicked: OverlayState.toggleLayout() }
                    DebugButton { text: "Timeline rows: " + SettingsService.timelineRows; accentColor: Theme.iris; onClicked: SettingsService.timelineRows = SettingsService.timelineRows >= 6 ? 1 : SettingsService.timelineRows + 1 }
                    DebugButton { text: "Look ahead: " + SettingsService.timelineHorizonSeconds + "s"; accentColor: Theme.iris; onClicked: SettingsService.timelineHorizonSeconds = SettingsService.timelineHorizonSeconds >= 30 ? 10 : SettingsService.timelineHorizonSeconds + 5 }
                }

                Text { text: "POSITIONS"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.4 }
                Flow {
                    width: parent.width; spacing: 8
                    DebugButton { text: "Reset alerts"; accentColor: Theme.rose; onClicked: LayoutService.resetPosition("raidboss", root.screen) }
                    DebugButton { text: "Reset timeline"; accentColor: Theme.iris; onClicked: LayoutService.resetPosition("timeline", root.screen) }
                    DebugButton { text: "Reset DPS"; accentColor: Theme.pine; onClicked: LayoutService.resetPosition("dps", root.screen) }
                }

                Text { text: "DISPLAY"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.4 }
                Flow {
                    width: parent.width; spacing: 8
                    DebugButton { text: SettingsService.hideWhenInactive ? "Hide off-game: ON" : "Hide off-game: OFF"; accentColor: SettingsService.hideWhenInactive ? Theme.foam : Theme.muted; onClicked: SettingsService.hideWhenInactive = !SettingsService.hideWhenInactive }
                    DebugButton { text: "Follow FFXIV"; accentColor: MonitorService.mode === "auto" ? Theme.rose : Theme.muted; onClicked: MonitorService.setMode("auto") }
                    Repeater { model: MonitorService.monitorNames; DebugButton { required property string modelData; text: modelData; accentColor: MonitorService.resolvedName === modelData && MonitorService.mode !== "auto" ? Theme.rose : Theme.muted; onClicked: MonitorService.setMode(modelData) } }
                }
                Text { text: "SURFACE OPACITY  " + Math.round(SettingsService.surfaceOpacity * 100) + "%"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold }
                Rectangle {
                    width: parent.width; height: 28; radius: 7; color: Theme.highlightLow
                    Rectangle { anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; anchors.leftMargin: 5; height: 8; width: (parent.width - 10) * SettingsService.surfaceOpacity; radius: 4; color: Theme.iris }
                    MouseArea { anchors.fill: parent; onPressed: mouse => SettingsService.surfaceOpacity = Math.max(0.05, Math.min(1, mouse.x / width)); onPositionChanged: mouse => { if (pressed) SettingsService.surfaceOpacity = Math.max(0.05, Math.min(1, mouse.x / width)) } }
                }

                Text { text: "RUNTIME & CONNECTIONS"; color: Theme.muted; font.family: Theme.uiFont; font.pixelSize: 10; font.weight: Font.Bold; font.letterSpacing: 1.4 }
                Flow {
                    width: parent.width; spacing: 8
                    DebugButton { text: SettingsService.healthAlertsEnabled ? "Health alerts: ON" : "Health alerts: OFF"; accentColor: SettingsService.healthAlertsEnabled ? Theme.foam : Theme.muted; onClicked: SettingsService.healthAlertsEnabled = !SettingsService.healthAlertsEnabled }
                    DebugButton { text: SettingsService.cactbotUpdateChecksEnabled ? "Cactbot checks: ON" : "Cactbot checks: OFF"; accentColor: SettingsService.cactbotUpdateChecksEnabled ? Theme.foam : Theme.muted; onClicked: SettingsService.cactbotUpdateChecksEnabled = !SettingsService.cactbotUpdateChecksEnabled }
                    DebugButton { text: "Restart runtime"; accentColor: Theme.pine; onClicked: OverlayState.restartBridge() }
                    DebugButton {
                        text: "Restore defaults"
                        accentColor: Theme.muted
                        onClicked: {
                            SettingsService.iinactEndpoint = "ws://127.0.0.1:10501/ws"
                            SettingsService.chromiumPath = "chromium"
                            SettingsService.devtoolsPort = 10503
                        }
                    }
                }
                Text { width: parent.width; wrapMode: Text.WordWrap; text: "Changes are saved immediately and take effect after Restart runtime."; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 10 }
                DebugTextField {
                    width: parent.width; label: "IINACT WEBSOCKET ENDPOINT"; text: SettingsService.iinactEndpoint
                    onAccepted: value => { if (/^wss?:\/\//.test(value)) SettingsService.iinactEndpoint = value }
                }
                Row {
                    width: parent.width; spacing: 8
                    DebugTextField {
                        width: parent.width - portField.width - parent.spacing; label: "CHROMIUM EXECUTABLE"; text: SettingsService.chromiumPath
                        onAccepted: value => { if (value.length > 0) SettingsService.chromiumPath = value }
                    }
                    DebugTextField {
                        id: portField; width: 120; label: "DEVTOOLS PORT"; text: String(SettingsService.devtoolsPort)
                        onAccepted: value => {
                            const port = Number(value)
                            if (Number.isInteger(port) && port >= 1024 && port <= 65535)
                                SettingsService.devtoolsPort = port
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Theme.highlightMed }
                Row {
                    width: parent.width; spacing: 10
                    DebugButton { text: "Open diagnostics"; accentColor: Theme.gold; onClicked: { OverlayState.toggleDiagnostics(); OverlayState.debugVisible = false } }
                    Text { anchors.verticalCenter: parent.verticalCenter; text: "Runtime tests and logs"; color: Theme.subtle; font.family: Theme.uiFont; font.pixelSize: 10 }
                }
            }
        }
    }
}
