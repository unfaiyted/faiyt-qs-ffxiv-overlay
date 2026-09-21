pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/faiyt-qs-ffxiv-overlay"
    readonly property string configPath: configDir + "/settings.json"
    property bool loaded: false
    property bool soundsEnabled: true
    property string ttsMode: "off"
    readonly property bool ttsEnabled: ttsMode !== "off"
    property real volume: 0.8
    property bool raidbossVisible: true
    property bool timelineVisible: true
    property int timelineRows: 6
    property int timelineHorizonSeconds: 30
    property bool dpsVisible: true
    property string dpsIdleMode: "dim"
    property bool dpsFrameEnabled: false
    property bool dpsHoverOpacityEnabled: true
    property bool hideWhenInactive: true
    property real surfaceOpacity: 0.78
    property string monitorMode: "auto"
    property bool healthAlertsEnabled: true
    property string iinactEndpoint: "ws://127.0.0.1:10501/ws"
    property string chromiumPath: "chromium"
    property int devtoolsPort: 10503
    property bool cactbotUpdateChecksEnabled: true

    function scheduleSave() { if (loaded) saveTimer.restart() }
    function load() { loadProcess.buffer = ""; loadProcess.running = true }
    function save() {
        saveProcess.payload = JSON.stringify({
            version: 8, soundsEnabled, ttsMode, volume, raidbossVisible,
            timelineVisible, timelineRows, timelineHorizonSeconds,
            dpsVisible, dpsIdleMode, dpsFrameEnabled, dpsHoverOpacityEnabled, hideWhenInactive, surfaceOpacity, monitorMode,
            healthAlertsEnabled, iinactEndpoint, chromiumPath, devtoolsPort, cactbotUpdateChecksEnabled
        }, null, 2)
        saveProcess.stdinEnabled = true
        saveProcess.running = true
    }

    Component.onCompleted: { mkdirProcess.running = true; load() }
    onSoundsEnabledChanged: scheduleSave()
    onTtsModeChanged: scheduleSave()
    onVolumeChanged: scheduleSave()
    onRaidbossVisibleChanged: scheduleSave()
    onTimelineVisibleChanged: scheduleSave()
    onTimelineRowsChanged: scheduleSave()
    onTimelineHorizonSecondsChanged: scheduleSave()
    onDpsVisibleChanged: scheduleSave()
    onDpsIdleModeChanged: scheduleSave()
    onDpsFrameEnabledChanged: scheduleSave()
    onDpsHoverOpacityEnabledChanged: scheduleSave()
    onHideWhenInactiveChanged: scheduleSave()
    onSurfaceOpacityChanged: scheduleSave()
    onMonitorModeChanged: scheduleSave()
    onHealthAlertsEnabledChanged: scheduleSave()
    onIinactEndpointChanged: scheduleSave()
    onChromiumPathChanged: scheduleSave()
    onDevtoolsPortChanged: scheduleSave()
    onCactbotUpdateChecksEnabledChanged: scheduleSave()

    Process { id: mkdirProcess; command: ["mkdir", "-p", root.configDir] }
    Process {
        id: loadProcess
        command: ["cat", root.configPath]
        property string buffer: ""
        stdout: SplitParser { splitMarker: ""; onRead: data => loadProcess.buffer += data }
        onExited: (exitCode, exitStatus) => {
            let needsMigration = false
            if (exitCode === 0 && loadProcess.buffer.trim()) {
                try {
                    const saved = JSON.parse(loadProcess.buffer)
                    needsMigration = (saved.version || 1) < 8
                    if (saved.soundsEnabled !== undefined) root.soundsEnabled = saved.soundsEnabled
                    if (saved.ttsMode !== undefined)
                        root.ttsMode = ["off", "alarm", "important", "all"].includes(saved.ttsMode) ? saved.ttsMode : "off"
                    else if (saved.ttsEnabled === true)
                        root.ttsMode = "all"
                    if (saved.volume !== undefined) root.volume = Math.max(0, Math.min(1, saved.volume))
                    if (saved.raidbossVisible !== undefined) root.raidbossVisible = saved.raidbossVisible
                    if (saved.timelineVisible !== undefined) root.timelineVisible = saved.timelineVisible
                    if (saved.timelineRows !== undefined) root.timelineRows = Math.max(1, Math.min(6, saved.timelineRows))
                    if (saved.timelineHorizonSeconds !== undefined) root.timelineHorizonSeconds = Math.max(5, Math.min(30, saved.timelineHorizonSeconds))
                    if (saved.dpsVisible !== undefined) root.dpsVisible = saved.dpsVisible
                    if (saved.dpsIdleMode !== undefined && ["show", "dim", "hide"].includes(saved.dpsIdleMode))
                        root.dpsIdleMode = saved.dpsIdleMode
                    if (saved.dpsFrameEnabled !== undefined) root.dpsFrameEnabled = saved.dpsFrameEnabled
                    if (saved.dpsHoverOpacityEnabled !== undefined) root.dpsHoverOpacityEnabled = saved.dpsHoverOpacityEnabled
                    if (saved.hideWhenInactive !== undefined) root.hideWhenInactive = saved.hideWhenInactive
                    if (saved.surfaceOpacity !== undefined) root.surfaceOpacity = Math.max(0.05, Math.min(1, saved.surfaceOpacity))
                    if (saved.monitorMode !== undefined && typeof saved.monitorMode === "string" && saved.monitorMode.length > 0)
                        root.monitorMode = saved.monitorMode
                    if (saved.healthAlertsEnabled !== undefined) root.healthAlertsEnabled = saved.healthAlertsEnabled
                    if (typeof saved.iinactEndpoint === "string" && saved.iinactEndpoint.length > 0)
                        root.iinactEndpoint = saved.iinactEndpoint
                    if (typeof saved.chromiumPath === "string" && saved.chromiumPath.length > 0)
                        root.chromiumPath = saved.chromiumPath
                    if (saved.devtoolsPort !== undefined)
                        root.devtoolsPort = Math.max(1024, Math.min(65535, Number(saved.devtoolsPort) || 10503))
                    if (saved.cactbotUpdateChecksEnabled !== undefined)
                        root.cactbotUpdateChecksEnabled = saved.cactbotUpdateChecksEnabled
                } catch (error) { console.warn("SettingsService: invalid settings:", error) }
            }
            root.loaded = true
            if (needsMigration)
                saveTimer.restart()
        }
    }
    Timer { id: saveTimer; interval: 300; onTriggered: root.save() }
    Process {
        id: saveProcess
        command: ["tee", root.configPath]
        property string payload: ""
        stdout: SplitParser { onRead: data => {} }
        onStarted: { write(payload); payload = ""; stdinEnabled = false }
    }
}
