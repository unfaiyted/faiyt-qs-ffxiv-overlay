pragma Singleton
import QtQuick

QtObject {
    readonly property color base: "#232136"
    readonly property color surface: "#2a273f"
    readonly property color overlay: "#393552"
    readonly property color muted: "#6e6a86"
    readonly property color subtle: "#908caa"
    readonly property color text: "#e0def4"
    readonly property color love: "#eb6f92"
    readonly property color gold: "#f6c177"
    readonly property color rose: "#ea9a97"
    readonly property color pine: "#3e8fb0"
    readonly property color foam: "#9ccfd8"
    readonly property color iris: "#c4a7e7"
    readonly property color highlightLow: "#2a283e"
    readonly property color highlightMed: "#44415a"
    readonly property color highlightHigh: "#56526e"

    readonly property string uiFont: "Inter"
    readonly property string monoFont: "JetBrains Mono"

    function alpha(color, opacity) {
        return Qt.rgba(color.r, color.g, color.b, opacity)
    }
}

