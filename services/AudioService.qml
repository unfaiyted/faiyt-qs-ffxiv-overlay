pragma Singleton
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool soundsEnabled: SettingsService.soundsEnabled
    readonly property bool ttsEnabled: SettingsService.ttsEnabled
    property bool ttsAvailable: false
    property bool piperAvailable: false
    property bool piperReady: false
    property real piperLoadSeconds: 0
    property real lastSynthesisSeconds: 0
    property bool espeakAvailable: false
    readonly property string ttsEngine: piperAvailable ? "piper" : espeakAvailable ? "espeak-ng" : "none"
    readonly property real volume: SettingsService.volume
    readonly property string soundDirectory: Qt.resolvedUrl("../assets/sounds/").toString()
    readonly property string piperScript: Qt.resolvedUrl("../scripts/piper-speak.sh").toString().replace("file://", "")
    readonly property string piperDaemon: Qt.resolvedUrl("../scripts/piper-daemon.py").toString().replace("file://", "")
    readonly property string piperPython: Qt.resolvedUrl("../.venv-piper/bin/python").toString().replace("file://", "")
    readonly property string piperModel: Qt.resolvedUrl("../assets/voices/en_US-lessac-medium.onnx").toString().replace("file://", "")

    function restart(player) {
        player.stop()
        player.position = 0
        player.play()
    }

    function playAlert(severity, text, ttsText) {
        if (shouldSpeak(severity) && (ttsText || text)) {
            speak(ttsText || text)
            return
        }
        if (!soundsEnabled)
            return
        playSound(severity)
    }

    function shouldSpeak(severity) {
        const mode = SettingsService.ttsMode
        return mode === "all"
            || (mode === "important" && (severity === "alert" || severity === "alarm"))
            || (mode === "alarm" && severity === "alarm")
    }

    function playCactbotAlert(severity, text, ttsText) {
        if (ttsText && shouldSpeak(severity)) {
            speak(ttsText)
            return
        }
        if (soundsEnabled)
            playSound(severity)
    }

    function playTtsOnly(text) {
        if (SettingsService.ttsMode === "all")
            speak(text)
    }

    function playSound(severity) {
        if (severity === "pull")
            restart(pullPlayer)
        else if (severity === "alarm")
            restart(alarmPlayer)
        else if (severity === "alert")
            restart(alertPlayer)
        else
            restart(infoPlayer)
    }

    function speakSample() {
        speak("Cactbot text to speech test. Stack in the middle.")
    }

    function speak(text) {
        if (!ttsAvailable || !text)
            return false
        if (piperAvailable && piperProcess.running) {
            piperProcess.write(JSON.stringify({ text: String(text), volume: root.volume }) + "\n")
            return true
        } else {
            espeakProcess.command = [
                "espeak-ng",
                "-a", String(Math.round(root.volume * 180 + 20)),
                String(text)
            ]
            espeakProcess.running = true
            return true
        }
    }

    function stopAll() {
        alarmPlayer.stop()
        alertPlayer.stop()
        infoPlayer.stop()
        pullPlayer.stop()
        if (espeakProcess.running)
            espeakProcess.running = false
    }

    AudioOutput { id: alarmOutput; volume: root.volume }
    AudioOutput { id: alertOutput; volume: root.volume }
    AudioOutput { id: infoOutput; volume: root.volume * 0.75 }
    AudioOutput { id: pullOutput; volume: root.volume }

    MediaPlayer {
        id: alarmPlayer
        source: root.soundDirectory + "Alarm.webm"
        audioOutput: alarmOutput
    }

    MediaPlayer {
        id: alertPlayer
        source: root.soundDirectory + "Alert.webm"
        audioOutput: alertOutput
    }

    MediaPlayer {
        id: infoPlayer
        source: root.soundDirectory + "Info.webm"
        audioOutput: infoOutput
    }

    MediaPlayer {
        id: pullPlayer
        source: root.soundDirectory + "Pull.webm"
        audioOutput: pullOutput
    }

    Component.onCompleted: piperCheck.running = true

    Process {
        id: piperCheck
        command: [root.piperScript, "--check"]
        onExited: (exitCode, exitStatus) => {
            root.piperAvailable = exitCode === 0
            if (root.piperAvailable)
                piperProcess.running = true
            espeakCheck.running = true
        }
    }

    Process {
        id: espeakCheck
        command: ["which", "espeak-ng"]
        onExited: (exitCode, exitStatus) => {
            root.espeakAvailable = exitCode === 0
            root.ttsAvailable = root.piperAvailable || root.espeakAvailable
        }
    }

    Process {
        id: piperProcess
        command: [root.piperPython, root.piperDaemon, root.piperModel]
        stdinEnabled: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => {
                if (!data.trim())
                    return
                try {
                    const message = JSON.parse(data)
                    if (message.type === "ready") {
                        root.piperReady = true
                        root.piperLoadSeconds = message.loadSeconds || 0
                    } else if (message.type === "playing") {
                        root.lastSynthesisSeconds = message.synthSeconds || 0
                    } else if (message.type === "error") {
                        console.warn("Piper TTS:", message.message)
                    }
                } catch (error) {
                    console.warn("Piper TTS invalid response:", data)
                }
            }
        }

        onExited: (exitCode, exitStatus) => {
            root.piperReady = false
            if (root.piperAvailable)
                piperRestart.start()
        }
    }

    Timer {
        id: piperRestart
        interval: 1000
        onTriggered: {
            if (root.piperAvailable && !piperProcess.running)
                piperProcess.running = true
        }
    }

    Process {
        id: espeakProcess
    }

    IpcHandler {
        target: "audio"

        function test(severity: string): string {
            const level = severity === "alarm" || severity === "info" || severity === "pull" ? severity : "alert"
            root.playAlert(level, "Audio test", "Audio test")
            return "played " + level
        }

        function sounds(): string {
            SettingsService.soundsEnabled = !SettingsService.soundsEnabled
            return root.soundsEnabled ? "sounds enabled" : "sounds disabled"
        }

        function tts(): string {
            if (!root.ttsAvailable)
                return "tts unavailable: install espeak-ng"
            const modes = ["off", "alarm", "important", "all"]
            const next = (modes.indexOf(SettingsService.ttsMode) + 1) % modes.length
            SettingsService.ttsMode = modes[next]
            return "tts mode=" + SettingsService.ttsMode
        }

        function speak(): string {
            return root.speak("Cactbot text to speech test. Stack in the middle.")
                ? "speaking sample" : "tts unavailable: install espeak-ng"
        }

        function status(): string {
            return "sounds=" + root.soundsEnabled + " | tts=" + SettingsService.ttsMode
                + " | ttsAvailable=" + root.ttsAvailable
                + " | engine=" + root.ttsEngine
                + " | piperReady=" + root.piperReady
                + " | synth=" + root.lastSynthesisSeconds + "s"
                + " | volume=" + Math.round(root.volume * 100) + "%"
        }
    }
}
