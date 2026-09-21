//@ pragma UseQApplication
import QtQuick
import Quickshell
import "components/raidboss"
import "components/timeline"
import "components/dps"
import "components/debug"
import "services"

ShellRoot {
    Component.onCompleted: OverlayState.startLive()

    RaidbossWindow {}
    TimelineWindow {}
    DpsWindow {}
    DebugWindow {}
    DiagnosticWindow {}
    HealthAlertWindow {}
}
