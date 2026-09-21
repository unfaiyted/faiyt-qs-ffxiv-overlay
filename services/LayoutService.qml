pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/faiyt-qs-ffxiv-overlay"
    readonly property string configPath: configDir + "/layout.json"
    property bool loaded: false
    property var positions: ({})

    function screenName(screen) {
        return screen ? screen.name : "default"
    }

    function defaults(kind, screen, width, height) {
        const screenWidth = screen ? screen.width : 1920
        const screenHeight = screen ? screen.height : 1080
        if (kind === "raidboss")
            return { x: Math.round((screenWidth - width) / 2), y: 72 }
        if (kind === "timeline")
            return { x: Math.round((screenWidth - width) / 2), y: 160 }
        if (kind === "dps")
            return { x: Math.max(0, screenWidth - width - 22), y: 82 }
        return { x: 24, y: Math.max(24, screenHeight - height - 24) }
    }

    function offset(kind, screen) {
        const byScreen = positions[screenName(screen)] || {}
        return byScreen[kind] || { x: 0, y: 0 }
    }

    function x(kind, screen, width, height) {
        const base = defaults(kind, screen, width, height)
        const saved = offset(kind, screen)
        return Math.max(0, Math.min((screen ? screen.width : 1920) - width, base.x + saved.x))
    }

    function y(kind, screen, width, height) {
        const base = defaults(kind, screen, width, height)
        const saved = offset(kind, screen)
        return Math.max(0, Math.min((screen ? screen.height : 1080) - height, base.y + saved.y))
    }

    function savePosition(kind, screen, absoluteX, absoluteY, width, height) {
        const name = screenName(screen)
        const base = defaults(kind, screen, width, height)
        const next = JSON.parse(JSON.stringify(positions))
        if (!next[name])
            next[name] = {}
        next[name][kind] = {
            x: Math.round(absoluteX - base.x),
            y: Math.round(absoluteY - base.y)
        }
        positions = next
        saveTimer.restart()
    }

    function resetPosition(kind, screen) {
        const name = screenName(screen)
        const next = JSON.parse(JSON.stringify(positions))
        if (next[name])
            delete next[name][kind]
        positions = next
        saveTimer.restart()
    }

    function resetAll() {
        positions = ({})
        saveTimer.restart()
    }

    function load() {
        loadProcess.buffer = ""
        loadProcess.running = true
    }

    function save() {
        const payload = JSON.stringify({ version: 1, positions: positions }, null, 2)
        saveProcess.payload = payload
        saveProcess.stdinEnabled = true
        saveProcess.running = true
    }

    Component.onCompleted: {
        mkdirProcess.running = true
        load()
    }

    Process {
        id: mkdirProcess
        command: ["mkdir", "-p", root.configDir]
    }

    Process {
        id: loadProcess
        command: ["cat", root.configPath]
        property string buffer: ""
        stdout: SplitParser {
            splitMarker: ""
            onRead: data => loadProcess.buffer += data
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && loadProcess.buffer.trim()) {
                try {
                    const saved = JSON.parse(loadProcess.buffer)
                    root.positions = saved.positions || ({})
                } catch (error) {
                    console.warn("LayoutService: invalid saved layout:", error)
                }
            }
            root.loaded = true
        }
    }

    Timer {
        id: saveTimer
        interval: 250
        onTriggered: root.save()
    }

    Process {
        id: saveProcess
        command: ["tee", root.configPath]
        property string payload: ""
        stdout: SplitParser { onRead: data => {} }
        onStarted: {
            write(payload)
            payload = ""
            stdinEnabled = false
        }
    }

    IpcHandler {
        target: "layout"

        function toggle(): string {
            OverlayState.toggleLayout()
            return OverlayState.layoutMode ? "edit" : "locked"
        }

        function reset(): string {
            root.resetAll()
            return "reset all monitor positions"
        }

        function move(kind: string, x: int, y: int): string {
            if (kind !== "raidboss" && kind !== "timeline" && kind !== "dps")
                return "unknown overlay: " + kind
            const screen = MonitorService.targetScreen
            const count = Math.min(8, OverlayState.combatants.length)
            const dpsWidth = count > 0 ? 20 + count * 150 + Math.max(0, count - 1) * 5 : 320
            const width = kind === "dps" ? dpsWidth : kind === "timeline" ? 320 : 620
            const height = kind === "dps" ? 57 : 250
            root.savePosition(kind, screen, x, y, width, height)
            return kind + "=" + root.x(kind, screen, width, height) + ","
                + root.y(kind, screen, width, height)
        }

        function position(kind: string): string {
            if (kind !== "raidboss" && kind !== "timeline" && kind !== "dps")
                return "unknown overlay: " + kind
            const screen = MonitorService.targetScreen
            const count = Math.min(8, OverlayState.combatants.length)
            const dpsWidth = count > 0 ? 20 + count * 150 + Math.max(0, count - 1) * 5 : 320
            const width = kind === "dps" ? dpsWidth : kind === "timeline" ? 320 : 620
            const height = kind === "dps" ? 57 : 250
            return root.screenName(screen) + ":" + root.x(kind, screen, width, height)
                + "," + root.y(kind, screen, width, height)
        }

        function status(): string {
            return OverlayState.layoutMode ? "edit" : "locked"
        }
    }
}
