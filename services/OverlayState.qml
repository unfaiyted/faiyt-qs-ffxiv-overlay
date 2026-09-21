pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string bridgeScript: Qt.resolvedUrl("../bridge/src/index.ts").toString().replace("file://", "")
    property string connectionState: "starting"
    property string endpoint: "ws://127.0.0.1:10501/ws"
    property string zoneName: "Waiting for IINACT"
    property string encounterName: "No encounter"
    property string playerName: "Unknown"
    property string dataMode: "live"
    property string bridgeRuntime: ""
    property string cactbotState: "starting"
    property string cactbotDetail: "Waiting for Chromium DevTools"
    property bool raidbossTestReady: false
    property bool raidbossTestRunning: false
    property int lastSequence: 0
    property bool inCombat: false
    property bool layoutMode: false
    readonly property bool raidbossVisible: SettingsService.raidbossVisible
    readonly property bool timelineVisible: SettingsService.timelineVisible
    readonly property bool dpsVisible: SettingsService.dpsVisible
    property bool debugVisible: false
    property bool diagnosticsVisible: false
    readonly property real surfaceOpacity: SettingsService.surfaceOpacity
    property int encounterSeconds: 0
    property real encounterDps: 0
    property int demoTick: 0
    property bool healthAlertsArmed: false
    readonly property var healthFailures: {
        const failures = []
        if (!healthAlertsArmed || dataMode !== "live"
                || !MonitorService.ffxivFound || !MonitorService.ffxivActive)
            return failures
        if (connectionState === "bridge stopped")
            failures.push({ title: "Overlay bridge process stopped", detail: "Automatic restart pending" })
        else if (connectionState !== "connected")
            failures.push({ title: "IINACT connection unavailable", detail: connectionState.toUpperCase() + " · " + endpoint })
        if (cactbotState !== "connected")
            failures.push({ title: "Cactbot runtime unavailable", detail: cactbotDetail })
        return failures
    }

    property var alerts: []

    property var timeline: []

    property var combatants: []

    signal diagnostic(string level, string message)

    function startLive() {
        dataMode = "live"
        demoTimer.stop()
        connectionState = "starting"
        healthAlertsArmed = false
        healthArmTimer.restart()
        if (!bridgeProcess.running)
            bridgeProcess.running = true
    }

    function restartBridge() {
        dataMode = "live"
        demoTimer.stop()
        reconnectTimer.stop()
        cactbotState = "starting"
        cactbotDetail = "Restarting bridge and Chromium DevTools"
        healthAlertsArmed = false
        healthArmTimer.restart()
        if (bridgeProcess.running) {
            bridgeProcess.running = false
            restartTimer.start()
        } else {
            bridgeProcess.running = true
        }
    }

    function startDemo() {
        dataMode = "mock"
        if (bridgeProcess.running)
            bridgeProcess.running = false
        connectionState = "mock"
        zoneName = "AAC Heavyweight M4 (Savage)"
        encounterName = "Mock encounter"
        encounterDps = 102788
        inCombat = true
        combatants = [
            { id: "1", job: "VPR", name: "You", dps: 31842, hps: 0, percent: 24.8, deaths: 0, self: true },
            { id: "2", job: "PCT", name: "Paint Enjoyer", dps: 29130, hps: 112, percent: 22.7, deaths: 0, self: false },
            { id: "3", job: "DRG", name: "Floor Inspector", dps: 25112, hps: 0, percent: 19.6, deaths: 1, self: false },
            { id: "4", job: "WAR", name: "Blue Damage", dps: 16704, hps: 842, percent: 13.0, deaths: 0, self: false }
        ]
        timeline = [
            { id: "tl-1", text: "Raidwide", startsIn: 4.2, duration: 5.0 },
            { id: "tl-2", text: "Protean Wave", startsIn: 11.8, duration: 4.0 },
            { id: "tl-3", text: "Tankbuster", startsIn: 19.4, duration: 6.0 }
        ]
        demoTimer.start()
        diagnostic("info", "Mock bridge started")
    }

    function handleBridgeLine(line) {
        if (!line.trim())
            return

        let message
        try {
            message = JSON.parse(line)
        } catch (error) {
            diagnostic("error", "Bridge sent invalid JSON")
            return
        }

        if (message.seq) {
            if (lastSequence > 0 && message.seq !== lastSequence + 1)
                diagnostic("warning", "Bridge sequence gap: " + lastSequence + " to " + message.seq)
            lastSequence = message.seq
        }

        if (message.type === "hello") {
            bridgeRuntime = message.runtime || ""
            endpoint = message.endpoint || endpoint
            diagnostic("info", "Bridge running with " + bridgeRuntime)
        } else if (message.type === "connection") {
            connectionState = message.state || "unknown"
            endpoint = message.endpoint || endpoint
        } else if (message.type === "diagnostic") {
            diagnostic(message.level || "info", message.message || "Bridge diagnostic")
        } else if (message.type === "cactbotState") {
            cactbotState = message.state || "unknown"
            cactbotDetail = message.detail || (cactbotState === "connected"
                ? "Cactbot raidboss page attached"
                : cactbotState === "starting"
                    ? "Waiting for Chromium DevTools"
                    : "No runtime detail reported")
            diagnostic(cactbotState === "error" ? "error" : "info",
                "Cactbot runtime: " + cactbotState + (message.detail ? " — " + message.detail : ""))
        } else if (message.type === "gameState") {
            if (message.zoneName !== undefined)
                zoneName = message.zoneName
            if (message.playerName !== undefined)
                playerName = message.playerName
            if (message.inCombat !== undefined)
                inCombat = message.inCombat
            if (message.encounterName !== undefined)
                encounterName = message.encounterName
            if (message.raidbossTestReady !== undefined)
                raidbossTestReady = message.raidbossTestReady
            if (message.raidbossTestRunning !== undefined)
                raidbossTestRunning = message.raidbossTestRunning
        } else if (message.type === "combatSnapshot") {
            inCombat = message.active
            combatants = message.combatants || []
            if (message.encounter) {
                encounterName = message.encounter.title || "Encounter"
                encounterSeconds = message.encounter.durationSeconds || 0
                encounterDps = message.encounter.dps || 0
                if (message.encounter.zoneName)
                    zoneName = message.encounter.zoneName
            }
        } else if (message.type === "raidAlert") {
            addRaidAlert(message)
            diagnostic("debug", "Playing " + (message.severity || "info") + " cue: " + (message.text || ""))
        } else if (message.type === "audioCue") {
            AudioService.playAlert(message.cue || "info", "", "")
            diagnostic("debug", "Playing timeline cue: " + (message.cue || "info"))
        } else if (message.type === "ttsCue") {
            AudioService.playTtsOnly(message.text || "")
            diagnostic("debug", "Cactbot TTS-only cue: " + (message.text || ""))
        } else if (message.type === "timelineSnapshot") {
            timeline = message.events || []
            if (message.encounter)
                encounterName = message.encounter
            raidbossTestRunning = timeline.length > 0
        }
    }

    function injectAlert(severity, text) {
        const next = alerts.slice()
        next.unshift({
            id: "debug-" + Date.now(),
            severity: severity,
            text: text,
            remaining: severity === "alarm" ? 5.0 : 7.0
        })
        alerts = next.slice(0, 4)
        AudioService.playAlert(severity, text, text)
        diagnostic("debug", "Injected " + severity + " alert")
    }

    function addRaidAlert(message) {
        const next = alerts.filter(alert => alert.id !== message.id)
        next.unshift({
            id: message.id || ("raid-" + Date.now()),
            severity: message.severity || "info",
            text: message.text || "",
            remaining: message.durationSeconds || 5,
            countdown: message.countdownSeconds || 0,
            source: message.source || "bridge"
        })
        alerts = next.slice(0, 5)
        if ((message.source || "").startsWith("cactbot"))
            AudioService.playCactbotAlert(message.severity || "info", message.text || "", message.ttsText || "")
        else
            AudioService.playAlert(message.severity || "info", message.text || "", message.ttsText || "")
    }

    function clearAlerts() {
        alerts = []
        diagnostic("debug", "Cleared alerts")
    }

    function resetDemo() {
        demoTick = 0
        encounterSeconds = 0
        encounterDps = 0
        inCombat = true
        alerts = []
        timeline = [
            { id: "reset-1", text: "Raidwide", startsIn: 8.0, duration: 5.0 },
            { id: "reset-2", text: "Spread", startsIn: 16.0, duration: 4.0 },
            { id: "reset-3", text: "Tankbuster", startsIn: 24.0, duration: 6.0 }
        ]
        diagnostic("info", "Mock encounter reset")
    }

    function toggleDebug() { debugVisible = !debugVisible }
    function toggleDiagnostics() { diagnosticsVisible = !diagnosticsVisible }
    function toggleLayout() { layoutMode = !layoutMode }
    function toggleRaidboss() { SettingsService.raidbossVisible = !SettingsService.raidbossVisible }
    function toggleTimeline() { SettingsService.timelineVisible = !SettingsService.timelineVisible }
    function toggleDps() { SettingsService.dpsVisible = !SettingsService.dpsVisible }

    function formatDuration(seconds) {
        const mins = Math.floor(seconds / 60)
        const secs = seconds % 60
        return mins + ":" + (secs < 10 ? "0" : "") + secs
    }

    Process {
        id: bridgeProcess
        command: [
            "env",
            "IINACT_WS_URL=" + SettingsService.iinactEndpoint,
            "FAIYT_CHROMIUM_PATH=" + SettingsService.chromiumPath,
            "FAIYT_DEVTOOLS_PORT=" + SettingsService.devtoolsPort,
            "bun", root.bridgeScript
        ]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.handleBridgeLine(data)
        }

        stderr: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (data.trim())
                    root.diagnostic("error", data.trim())
            }
        }

        onExited: (exitCode, exitStatus) => {
            if (root.dataMode !== "live")
                return
            root.connectionState = "bridge stopped"
            root.diagnostic("warning", "Bridge exited with code " + exitCode)
            reconnectTimer.start()
        }
    }

    Timer {
        id: reconnectTimer
        interval: 2000
        onTriggered: {
            if (root.dataMode === "live" && !bridgeProcess.running)
                bridgeProcess.running = true
        }
    }

    Timer {
        id: restartTimer
        interval: 250
        onTriggered: {
            if (root.dataMode === "live" && !bridgeProcess.running)
                bridgeProcess.running = true
        }
    }

    Timer {
        id: healthArmTimer
        interval: 12000
        onTriggered: root.healthAlertsArmed = true
    }

    Timer {
        interval: 250
        repeat: true
        running: true
        onTriggered: {
            const nextAlerts = []
            for (const alert of root.alerts) {
                const remaining = alert.remaining - 0.25
                if (remaining > 0) {
                    nextAlerts.push({
                        id: alert.id,
                        severity: alert.severity,
                        text: alert.text,
                        remaining: remaining,
                        countdown: alert.countdown || 0,
                        source: alert.source || "debug"
                    })
                }
            }
            root.alerts = nextAlerts
        }
    }

    property Timer demoTimer: Timer {
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.dataMode !== "mock")
                return
            root.demoTick++
            if (root.inCombat)
                root.encounterSeconds++

            const nextTimeline = []
            for (const event of root.timeline) {
                const startsIn = event.startsIn - 1
                if (startsIn > -event.duration)
                    nextTimeline.push({
                        id: event.id,
                        text: event.text,
                        startsIn: startsIn,
                        duration: event.duration
                    })
            }
            root.timeline = nextTimeline

            if (root.demoTick % 12 === 0)
                root.injectAlert("alert", "Move away")

            const nextCombatants = []
            for (let i = 0; i < root.combatants.length; i++) {
                const row = root.combatants[i]
                const delta = ((root.demoTick + i * 3) % 7 - 3) * 23
                nextCombatants.push({
                    id: row.id,
                    job: row.job,
                    name: row.name,
                    dps: Math.max(0, row.dps + delta),
                    hps: row.hps || 0,
                    percent: row.percent,
                    deaths: row.deaths,
                    self: row.self
                })
            }
            root.combatants = nextCombatants
        }
    }

    IpcHandler {
        target: "overlay"

        function debug(): string {
            root.toggleDebug()
            return root.debugVisible ? "open" : "closed"
        }

        function settings(): string {
            root.toggleDebug()
            return root.debugVisible ? "open" : "closed"
        }

        function diagnostics(): string {
            root.toggleDiagnostics()
            return root.diagnosticsVisible ? "open" : "closed"
        }

        function layout(): string {
            root.toggleLayout()
            return root.layoutMode ? "enabled" : "disabled"
        }

        function raidboss(): string {
            root.toggleRaidboss()
            return root.raidbossVisible ? "visible" : "hidden"
        }

        function timeline(): string {
            root.toggleTimeline()
            return root.timelineVisible ? "visible" : "hidden"
        }

        function dps(): string {
            root.toggleDps()
            return root.dpsVisible ? "visible" : "hidden"
        }

        function testAlert(): string {
            root.injectAlert("alarm", "Debug tankbuster on YOU")
            return "injected"
        }

        function live(): string {
            root.restartBridge()
            return "connecting"
        }

        function mock(): string {
            root.startDemo()
            return "mock"
        }

        function status(): string {
            return root.dataMode + " | " + root.connectionState + " | "
                + root.zoneName + " | " + root.playerName + " | "
                + root.combatants.length + " combatant(s) | raidTestReady="
                + root.raidbossTestReady + " | cactbot=" + root.cactbotState
        }
    }
}
