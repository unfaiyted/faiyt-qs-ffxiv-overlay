pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root

    // "auto" follows the monitor containing FFXIV. Any screen name pins it.
    readonly property string mode: SettingsService.monitorMode
    property string detectedFfxivScreen: ""
    property string ffxivWindowClass: ""
    property bool ffxivFound: false
    property bool ffxivActive: false
    readonly property bool hideWhenInactive: SettingsService.hideWhenInactive
    property var monitorNames: Quickshell.screens.map(screen => screen.name)
    readonly property string resolvedName: mode === "auto" ? detectedFfxivScreen : mode
    readonly property var targetHyprlandMonitor: Hyprland.monitors.values.find(item => item.name === resolvedName)
    readonly property real targetX: targetHyprlandMonitor ? Number(targetHyprlandMonitor.x) : 0
    readonly property real targetY: targetHyprlandMonitor ? Number(targetHyprlandMonitor.y) : 0
    readonly property var targetScreen: {
        const desired = resolvedName
        for (const screen of Quickshell.screens) {
            if (screen.name === desired)
                return screen
        }
        return Quickshell.screens.length > 0 ? Quickshell.screens[0] : null
    }

    signal targetChanged(string screenName)

    function refresh() {
        if (!clientsProcess.running)
            clientsProcess.running = true
        if (!activeWindowProcess.running)
            activeWindowProcess.running = true
    }

    function setMode(value) {
        if (value !== "auto" && monitorNames.indexOf(value) < 0)
            return false
        SettingsService.monitorMode = value
        targetChanged(targetScreen ? targetScreen.name : "")
        return true
    }

    function findFfxiv(clients) {
        for (const client of clients) {
            const windowClass = String(client.class || client.initialClass || "")
            const title = String(client.title || client.initialTitle || "")
            if (/ffxiv(_dx11)?\.exe/i.test(windowClass) || /final fantasy xiv/i.test(title))
                return client
        }
        return null
    }

    function isFfxivWindow(windowData) {
        if (!windowData)
            return false
        const windowClass = String(windowData.class || windowData.initialClass || "")
        const title = String(windowData.title || windowData.initialTitle || "")
        return /ffxiv(_dx11)?\.exe/i.test(windowClass) || /final fantasy xiv/i.test(title)
    }

    Component.onCompleted: refresh()

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            refreshTimer.restart()
        }
    }

    Timer {
        id: refreshTimer
        interval: 150
        onTriggered: root.refresh()
    }

    Process {
        id: clientsProcess
        command: ["hyprctl", "clients", "-j"]
        property string output: ""

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => clientsProcess.output += data
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && clientsProcess.output.trim()) {
                try {
                    const clients = JSON.parse(clientsProcess.output)
                    const ffxiv = root.findFfxiv(clients)
                    root.ffxivFound = ffxiv !== null
                    root.ffxivWindowClass = ffxiv ? String(ffxiv.class || ffxiv.initialClass || "") : ""
                    if (ffxiv) {
                        const monitor = Hyprland.monitors.values.find(item => item.id === ffxiv.monitor)
                        const nextName = monitor ? monitor.name : ""
                        if (nextName && nextName !== root.detectedFfxivScreen) {
                            root.detectedFfxivScreen = nextName
                            if (root.mode === "auto")
                                root.targetChanged(nextName)
                        }
                    }
                } catch (error) {
                    console.warn("MonitorService: failed to parse hyprctl clients:", error)
                }
            }
            clientsProcess.output = ""
        }
    }

    Process {
        id: activeWindowProcess
        command: ["hyprctl", "activewindow", "-j"]
        property string output: ""

        stdout: SplitParser {
            splitMarker: ""
            onRead: data => activeWindowProcess.output += data
        }

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && activeWindowProcess.output.trim()) {
                try {
                    root.ffxivActive = root.isFfxivWindow(JSON.parse(activeWindowProcess.output))
                } catch (error) {
                    root.ffxivActive = false
                    console.warn("MonitorService: failed to parse active window:", error)
                }
            } else {
                root.ffxivActive = false
            }
            activeWindowProcess.output = ""
        }
    }

    IpcHandler {
        target: "monitor"

        function auto(): string {
            root.setMode("auto")
            root.refresh()
            return root.targetScreen ? root.targetScreen.name : "unresolved"
        }

        function set(name: string): string {
            return root.setMode(name) ? name : "unknown monitor: " + name
        }

        function status(): string {
            return "mode=" + root.mode + " | detected=" + (root.detectedFfxivScreen || "none")
                + " | target=" + (root.targetScreen ? root.targetScreen.name : "none")
                + " | ffxiv=" + (root.ffxivFound ? root.ffxivWindowClass : "not found")
                + " | active=" + root.ffxivActive
                + " | hideWhenInactive=" + root.hideWhenInactive
        }

        function visibility(): string {
            SettingsService.hideWhenInactive = !SettingsService.hideWhenInactive
            return root.hideWhenInactive ? "hide when inactive" : "always visible"
        }
    }
}
