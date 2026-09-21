import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../services"
import "../../theme"
import "../common"

PanelWindow {
    id: root
    screen: MonitorService.targetScreen
    visible: OverlayState.dpsVisible
        && (OverlayState.layoutMode || SettingsService.dpsIdleMode !== "hide" || OverlayState.inCombat)
        && (OverlayState.layoutMode || !MonitorService.hideWhenInactive || MonitorService.ffxivActive)
    color: "transparent"
    readonly property int combatantCount: visibleCombatants.length
    readonly property real combatantSpacing: 5
    readonly property real combatantMinWidth: 118
    readonly property real combatantMaxWidth: 150
    readonly property real combatantWidth: combatantCount > 0
        ? Math.max(combatantMinWidth, Math.min(combatantMaxWidth,
            ((screen ? screen.width : 1920) - 20 - Math.max(0, combatantCount - 1) * combatantSpacing) / combatantCount))
        : combatantMaxWidth
    implicitWidth: combatantCount > 0
        ? Math.round(20 + combatantCount * combatantWidth + Math.max(0, combatantCount - 1) * combatantSpacing)
        : 320
    implicitHeight: 57
    anchors.left: true
    anchors.top: true
    margins.left: LayoutService.x("dps", root.screen, root.implicitWidth, root.implicitHeight)
    margins.top: LayoutService.y("dps", root.screen, root.implicitWidth, root.implicitHeight)
    exclusiveZone: -1
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "faiyt-ffxiv-dps"
    mask: Region { item: OverlayState.layoutMode ? meter : null }

    readonly property var visibleCombatants: OverlayState.combatants.slice(0, 8)
    readonly property real maxDps: visibleCombatants.length > 0 ? Math.max(1, visibleCombatants[0].dps) : 1
    readonly property bool idleDimmed: !OverlayState.layoutMode && !OverlayState.inCombat
        && SettingsService.dpsIdleMode === "dim"
    property bool cursorHovered: false
    property real lastCursorX: 0
    property real lastCursorY: 0

    function role(job) {
        if (["GLA", "PLD", "MRD", "WAR", "DRK", "GNB"].includes(job)) return "tank"
        if (["CNJ", "WHM", "SCH", "AST", "SGE"].includes(job)) return "healer"
        return "dps"
    }
    function roleColor(job) {
        const value = role(job)
        return value === "tank" ? Theme.pine : value === "healer" ? Theme.foam : Theme.love
    }
    function jobIcon(job) {
        const key = String(job || "").toLowerCase()
        const available = ["acn", "ast", "blm", "blu", "brd", "cnj", "dnc", "drg", "drk", "gla", "gnb", "lnc", "mch", "mnk", "mrd", "nin", "pct", "pgl", "pld", "rdm", "rog", "rpr", "sam", "sch", "sge", "smn", "thm", "vpr", "war", "whm"]
        return Qt.resolvedUrl("../../assets/jobs/" + (available.includes(key) ? key : "empty") + ".png")
    }
    function shortNumber(value) {
        const number = Number(value || 0)
        if (number >= 1000000) return (number / 1000000).toFixed(2) + "m"
        if (number >= 1000) return (number / 1000).toFixed(1) + "k"
        return Math.round(number).toString()
    }

    OverlayCard {
        id: meter
        anchors.fill: parent
        backgroundOpacity: root.cursorHovered ? 1 : OverlayState.surfaceOpacity
        accentColor: Theme.pine
        framed: SettingsService.dpsFrameEnabled && !root.idleDimmed

        Rectangle {
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
            height: 26; visible: OverlayState.layoutMode; radius: 8
            color: Theme.alpha(Theme.gold, 0.9); border.width: 1; border.color: Theme.text; z: 100
            Text { anchors.centerIn: parent; text: "DRAG DAMAGE METER · RELEASE TO SAVE"; color: Theme.base; font.family: Theme.uiFont; font.pixelSize: 11; font.weight: Font.Bold; font.letterSpacing: 1.1 }
            MouseArea {
                id: drag
                anchors.fill: parent; cursorShape: Qt.SizeAllCursor
                property real pressGlobalX: 0
                property real pressGlobalY: 0
                property real originX: 0
                property real originY: 0
                onPressed: mouse => {
                    const global = drag.mapToGlobal(mouse.x, mouse.y)
                    pressGlobalX = global.x; pressGlobalY = global.y
                    originX = root.margins.left; originY = root.margins.top
                }
                onPositionChanged: mouse => {
                    if (!pressed) return
                    const global = drag.mapToGlobal(mouse.x, mouse.y)
                    root.margins.left = Math.max(0, Math.min(root.screen.width - root.implicitWidth, originX + global.x - pressGlobalX))
                    root.margins.top = Math.max(0, Math.min(root.screen.height - root.implicitHeight, originY + global.y - pressGlobalY))
                }
                onReleased: LayoutService.savePosition("dps", root.screen, root.margins.left, root.margins.top, root.implicitWidth, root.implicitHeight)
                onCanceled: LayoutService.savePosition("dps", root.screen, root.margins.left, root.margins.top, root.implicitWidth, root.implicitHeight)
            }
        }

        Column {
            anchors.fill: parent
            anchors.leftMargin: 10; anchors.rightMargin: 10; anchors.topMargin: 4; anchors.bottomMargin: 4
            spacing: 2
            opacity: root.cursorHovered ? 1 : root.idleDimmed ? 0.38 : 1
            Behavior on opacity { NumberAnimation { duration: 120 } }
            Row {
                width: parent.width; height: 13
                Text { width: parent.width - summary.implicitWidth; text: OverlayState.encounterName; elide: Text.ElideRight; color: Theme.text; font.family: Theme.uiFont; font.pixelSize: 9; font.weight: Font.DemiBold }
                Text { id: summary; text: root.shortNumber(OverlayState.encounterDps) + " raid DPS  ·  " + OverlayState.formatDuration(OverlayState.encounterSeconds); color: Theme.subtle; font.family: Theme.monoFont; font.pixelSize: 8; font.weight: Font.Bold }
            }

            Row {
                width: parent.width; height: 34; spacing: root.combatantSpacing
                Repeater {
                    model: root.visibleCombatants
                    Item {
                        required property var modelData
                        required property int index
                        width: root.combatantWidth
                        height: parent.height
                        readonly property color accent: root.roleColor(modelData.job)

                        Rectangle {
                            anchors.fill: parent
                            radius: 5
                            color: Theme.alpha(Theme.base, 0.48)
                            border.width: modelData.self ? 1 : 0; border.color: Theme.alpha(Theme.iris, 0.75)
                            Rectangle {
                                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                                width: parent.width * Math.max(0, Math.min(1, modelData.dps / root.maxDps))
                                radius: 5
                                color: Theme.alpha(modelData.self ? Theme.iris : parent.parent.accent, modelData.self ? 0.42 : 0.36)
                            }
                            Text {
                                anchors.left: jobIcon.right; anchors.leftMargin: 3; anchors.top: parent.top; anchors.topMargin: 5
                                width: parent.width - jobIcon.width - dpsValue.width - 16
                                elide: Text.ElideRight
                                text: (index + 1) + ". " + modelData.name
                                color: modelData.self ? Theme.text : Theme.text
                                font.family: Theme.uiFont; font.pixelSize: 9; font.weight: modelData.self ? Font.Bold : Font.Medium
                            }
                            Image {
                                id: jobIcon
                                anchors.left: parent.left; anchors.leftMargin: 4; anchors.verticalCenter: parent.verticalCenter
                                width: 21; height: 21
                                source: root.jobIcon(modelData.job)
                                sourceSize.width: 32; sourceSize.height: 32
                                fillMode: Image.PreserveAspectFit
                                smooth: true
                            }
                            Text {
                                anchors.left: jobIcon.right; anchors.leftMargin: 3; anchors.bottom: parent.bottom; anchors.bottomMargin: 3
                                text: Number(modelData.percent || 0).toFixed(1) + "%" + (modelData.deaths > 0 ? "  · " + modelData.deaths + " KO" : "")
                                color: modelData.deaths > 0 ? Theme.gold : parent.parent.accent
                                font.family: Theme.monoFont; font.pixelSize: 7; font.weight: Font.Bold
                            }
                            Row {
                                id: dpsValue
                                anchors.right: parent.right; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter
                                spacing: 3
                                Text {
                                    id: dpsNumber
                                    text: root.shortNumber(modelData.dps)
                                    color: Theme.text; font.family: Theme.monoFont; font.pixelSize: 14; font.weight: Font.Black
                                }
                                Text {
                                    anchors.baseline: dpsNumber.baseline
                                    text: "DPS"
                                    color: modelData.self ? Theme.iris : parent.parent.parent.accent
                                    font.family: Theme.monoFont; font.pixelSize: 7; font.weight: Font.Bold
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections {
        target: LayoutService
        function onPositionsChanged() { if (!drag.pressed) { root.margins.left = LayoutService.x("dps", root.screen, root.implicitWidth, root.implicitHeight); root.margins.top = LayoutService.y("dps", root.screen, root.implicitWidth, root.implicitHeight) } }
    }
    Connections {
        target: MonitorService
        function onTargetChanged(screenName) { root.margins.left = LayoutService.x("dps", root.screen, root.implicitWidth, root.implicitHeight); root.margins.top = LayoutService.y("dps", root.screen, root.implicitWidth, root.implicitHeight) }
    }

    Timer {
        interval: 200
        repeat: true
        running: root.visible && SettingsService.dpsHoverOpacityEnabled && !OverlayState.layoutMode
        onTriggered: {
            if (!cursorPosition.running) {
                cursorPosition.output = ""
                cursorPosition.running = true
            }
        }
        onRunningChanged: if (!running) root.cursorHovered = false
    }

    Process {
        id: cursorPosition
        command: ["hyprctl", "cursorpos", "-j"]
        property string output: ""
        stdout: SplitParser { splitMarker: ""; onRead: data => cursorPosition.output += data }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0 && SettingsService.dpsHoverOpacityEnabled) {
                try {
                    const cursor = JSON.parse(output)
                    root.lastCursorX = Number(cursor.x)
                    root.lastCursorY = Number(cursor.y)
                    const panelX = MonitorService.targetX + root.margins.left
                    const panelY = MonitorService.targetY + root.margins.top
                    root.cursorHovered = root.lastCursorX >= panelX && root.lastCursorY >= panelY
                        && root.lastCursorX < panelX + root.implicitWidth
                        && root.lastCursorY < panelY + root.implicitHeight
                } catch (error) {
                    root.cursorHovered = false
                }
            } else {
                root.cursorHovered = false
            }
            output = ""
        }
    }
}
