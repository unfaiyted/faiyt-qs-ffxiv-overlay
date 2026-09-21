pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string repository: "https://github.com/OverlayPlugin/cactbot.git"
    readonly property string pinPath: Qt.resolvedUrl("../cactbot.version").toString().replace("file://", "")
    readonly property string updateScript: Qt.resolvedUrl("../scripts/update-cactbot.sh").toString().replace("file://", "")
    property string currentRevision: ""
    property string latestRevision: ""
    property string status: "loading"
    property string detail: "Reading pinned revision"
    property string lastChecked: "Never"
    property string notifiedRevision: ""
    property bool confirmationPending: false
    readonly property bool updateAvailable: currentRevision.length === 40
        && latestRevision.length === 40 && currentRevision !== latestRevision
    readonly property string currentShort: currentRevision ? currentRevision.slice(0, 8) : "unknown"
    readonly property string latestShort: latestRevision ? latestRevision.slice(0, 8) : "unknown"

    function checkNow() {
        if (checkProcess.running || updateProcess.running)
            return
        status = "checking"
        detail = "Checking upstream cactbot HEAD"
        checkProcess.output = ""
        checkProcess.running = true
    }

    function requestUpdate() {
        if (!updateAvailable || updateProcess.running)
            return
        confirmationPending = true
        confirmationTimer.restart()
    }

    function applyUpdate() {
        if (!confirmationPending || !updateAvailable || updateProcess.running)
            return
        confirmationPending = false
        confirmationTimer.stop()
        status = "updating"
        detail = "Building untested upstream revision " + latestShort
        updateProcess.output = ""
        updateProcess.command = [root.updateScript, root.latestRevision]
        updateProcess.running = true
        OverlayState.diagnostic("warning", "Updating cactbot to untested upstream revision " + latestShort)
    }

    Component.onCompleted: pinProcess.running = true

    Connections {
        target: SettingsService
        function onCactbotUpdateChecksEnabledChanged() {
            if (SettingsService.cactbotUpdateChecksEnabled)
                root.checkNow()
        }
    }

    Timer {
        id: initialCheck
        interval: 20000
        onTriggered: if (SettingsService.cactbotUpdateChecksEnabled) root.checkNow()
    }
    Timer {
        interval: 6 * 60 * 60 * 1000
        repeat: true
        running: SettingsService.cactbotUpdateChecksEnabled
        onTriggered: root.checkNow()
    }
    Timer {
        id: confirmationTimer
        interval: 15000
        onTriggered: root.confirmationPending = false
    }

    Process {
        id: pinProcess
        command: ["cat", root.pinPath]
        property string output: ""
        stdout: SplitParser { splitMarker: ""; onRead: data => pinProcess.output += data }
        onExited: (exitCode, exitStatus) => {
            const revision = output.trim()
            root.currentRevision = /^[0-9a-f]{40}$/i.test(revision) ? revision : ""
            output = ""
            if (!root.currentRevision) {
                root.status = "error"
                root.detail = "Invalid or missing cactbot.version"
            } else {
                root.status = "current"
                root.detail = "Pinned at " + root.currentShort
                initialCheck.restart()
            }
        }
    }

    Process {
        id: checkProcess
        command: ["git", "ls-remote", root.repository, "HEAD"]
        property string output: ""
        stdout: SplitParser { splitMarker: ""; onRead: data => checkProcess.output += data }
        onExited: (exitCode, exitStatus) => {
            root.lastChecked = Qt.formatDateTime(new Date(), "yyyy-MM-dd hh:mm")
            const revision = output.trim().split(/\s+/)[0] || ""
            output = ""
            if (exitCode !== 0 || !/^[0-9a-f]{40}$/i.test(revision)) {
                root.status = "error"
                root.detail = "Unable to check OverlayPlugin/cactbot"
                return
            }
            root.latestRevision = revision
            if (root.updateAvailable) {
                root.status = "available"
                root.detail = "Upstream " + root.latestShort + " is newer than pin " + root.currentShort
                if (root.notifiedRevision !== revision) {
                    root.notifiedRevision = revision
                    OverlayState.diagnostic("warning", "Cactbot update available: " + root.currentShort + " → " + root.latestShort + " (upstream revision is not yet tested here)")
                }
            } else {
                root.status = "current"
                root.detail = "Pinned revision matches upstream HEAD"
            }
        }
    }

    Process {
        id: updateProcess
        property string output: ""
        stdout: SplitParser { splitMarker: "\n"; onRead: data => updateProcess.output = data.trim() }
        stderr: SplitParser { splitMarker: "\n"; onRead: data => { if (data.trim()) updateProcess.output = data.trim() } }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root.currentRevision = root.latestRevision
                root.status = "current"
                root.detail = "Updated and repinned at " + root.currentShort
                OverlayState.diagnostic("info", "Cactbot updated and repinned at " + root.currentShort)
                OverlayState.restartBridge()
            } else {
                root.status = "error"
                root.detail = "Update failed; existing pin retained" + (output ? " — " + output : "")
                OverlayState.diagnostic("error", root.detail)
            }
            output = ""
        }
    }
}
