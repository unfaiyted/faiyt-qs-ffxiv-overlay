# Implementation plan

## 1. Product boundary

This repository is an independent application. It must not import runtime
state from, install files into, or share a Quickshell process with `faiyt-qs`.
Rosé Pine tokens may be adapted into this repository, but they are owned here
afterward.

The application owns:

- the Quickshell windows and all visible presentation;
- a local TypeScript bridge process;
- configuration and saved window placement;
- cactbot integration and compatibility patches;
- installation, startup, logging, and diagnostics;
- replay fixtures and tests.

IINACT remains responsible for game log parsing, OverlayPlugin event
production, and combat calculations. The project will not duplicate an ACT
parser.

## 2. Architecture

```text
┌───────────┐      OverlayPlugin WS       ┌──────────────────────────┐
│  IINACT   │ ──────────────────────────► │ TypeScript bridge        │
│ :10501/ws │ ◄────────────────────────── │                          │
└───────────┘      requests/replies       │ - connection lifecycle   │
                                         │ - cactbot raid runtime   │
                                         │ - combat normalization   │
                                         │ - replay mode            │
                                         └────────────┬─────────────┘
                                              NDJSON │ stdin/stdout
                                                    ▼
                                         ┌──────────────────────────┐
                                         │ Quickshell application   │
                                         │                          │
                                         │ - RaidbossWindow.qml     │
                                         │ - TimelineWindow.qml     │
                                         │ - DpsWindow.qml          │
                                         │ - SettingsWindow.qml     │
                                         └──────────────────────────┘
```

### Why the bridge is separate

Cactbot trigger files contain executable TypeScript/JavaScript and rely on a
runtime scheduler. QML should receive normalized view models, not evaluate
cactbot triggers. This gives the QML UI a small stable protocol even when
cactbot internals change.

The initial transport will be newline-delimited JSON over a managed
Quickshell `Process`. It avoids an additional local port and works with the
same streaming-process pattern already proven in `faiyt-qs`. If bidirectional
traffic becomes awkward, it can be replaced with a Unix socket without
changing the message schema.

### Proposed repository layout

```text
.
├── shell.qml
├── components/
│   ├── raidboss/
│   ├── timeline/
│   ├── dps/
│   ├── settings/
│   └── common/
├── services/
│   ├── OverlayBridge.qml
│   ├── RaidbossState.qml
│   ├── CombatState.qml
│   └── ConfigService.qml
├── theme/
│   ├── Colors.qml
│   ├── Fonts.qml
│   └── Metrics.qml
├── bridge/
│   ├── src/
│   │   ├── iinact/
│   │   ├── cactbot/
│   │   ├── combat/
│   │   └── protocol/
│   └── test/
├── fixtures/
├── scripts/
└── docs/
```

## 3. UI and compositor behavior

Each overlay is its own transparent `PanelWindow` using the Wayland layer
shell overlay layer and `ExclusionMode.Ignore`. Normal gameplay mode has an
empty input region so the windows are click-through. An explicit layout mode
enables input, outlines each window, and provides drag/resize handles.

Settings are applied independently per overlay:

- enabled;
- monitor;
- anchor and offset;
- scale;
- content opacity;
- background opacity;
- font scale;
- click-through versus layout mode;
- hide outside combat;
- hide when FFXIV is not focused.

Transparency is split into content and surface values. Text and progress bars
can remain fully opaque while card backgrounds range from fully transparent to
solid. Blur will not be required for the MVP because compositor-specific blur
rules are less portable.

The initial theme is Rosé Pine Moon, with semantic aliases rather than colors
embedded in components:

- alarm: love;
- alert: gold;
- info: foam;
- active timeline: iris;
- local player: rose;
- friendly DPS rows: pine/foam rotation;
- surface/background/border: overlay/base/highlight variants.

## 4. Bridge protocol

All messages are versioned JSON objects with a monotonic sequence number:

```json
{"v":1,"seq":42,"type":"connection","state":"connected"}
```

Initial bridge-to-QML messages:

- `connection`: connecting, connected, reconnecting, or failed;
- `gameState`: zone, encounter, player, combat state;
- `raidAlert`: severity, text, duration, replacement key, sound/TTS metadata;
- `raidAlertRemove`: remove or replace a displayed alert;
- `timelineSnapshot`: authoritative ordered list of upcoming events;
- `combatSnapshot`: encounter metadata and normalized combatant rows;
- `diagnostic`: structured warning or error safe to show in the settings UI.

Initial QML-to-bridge commands:

- `ready`: protocol and client capabilities;
- `reload`: reconnect and reload encounter definitions;
- `setConfig`: endpoint, locale, player-name behavior, and feature flags;
- `requestSnapshot`: recover after a QML reload or detected sequence gap;
- `shutdown`: graceful bridge termination.

Timeline and combat updates are snapshots for the MVP. Their data sets are
small, and authoritative snapshots avoid complicated incremental recovery.

## 5. Delivery phases

### Phase 0 — runnable shell skeleton

Goal: prove an independent Quickshell process can reliably render over FFXIV.

Work:

1. Create the QML application, theme tokens, configuration service, and IPC.
2. Add mock raid alert and DPS windows.
3. Add layout mode and click-through gameplay mode.
4. Add opacity, anchor, offset, scale, and monitor configuration.
5. Add a launcher script and development command.

Acceptance criteria:

- It runs concurrently with `faiyt-qs` as a distinct Quickshell instance.
- Both mock overlays remain visible above FFXIV under Hyprland.
- Gameplay mode never captures mouse or keyboard input.
- Layout mode can reposition both overlays and persists their settings.
- Reloading this app does not reload or disturb `faiyt-qs`.

Expected effort: 2–4 days.

### Phase 1 — IINACT connection and DPS MVP

Status: live transport and normalized DPS snapshots are implemented. Remaining
work is configuration persistence, richer columns, anonymized fixtures, and
combat-end behavior validation in a party encounter.

Goal: display accurate live encounter data without cactbot integration yet.

Work:

1. Scaffold the Bun/TypeScript bridge.
2. Implement the OverlayPlugin WebSocket request/subscription protocol.
3. Add reconnect with bounded exponential backoff and visible status.
4. Normalize combatant data, including stable IDs and numeric values.
5. Render encounter duration and configurable DPS rows.
6. Add self highlighting, job icons/colors, sorting, and reset behavior.
7. Capture sanitized protocol fixtures for offline tests.

Default DPS columns:

- job/player;
- DPS;
- contribution percentage;
- deaths.

Later columns such as HPS, damage taken, crit/direct-hit rates, and encounter
totals should be supported by configuration rather than baked into the layout.

Acceptance criteria:

- Connects to `ws://127.0.0.1:10501/ws` on the current machine.
- Displays and sorts live party combatants without visible jitter.
- Shows disconnected/reconnecting state without freezing QML.
- Clears or freezes encounter data according to a documented combat-end rule.
- Recorded fixtures reproduce deterministic snapshots in automated tests.

Expected effort: 3–6 days after Phase 0.

### Phase 2 — raidboss alert MVP

Goal: preserve cactbot encounter logic while replacing its visible browser UI.

Work:

1. Pin a cactbot revision and document the update procedure.
2. Inventory browser and OverlayPlugin dependencies used by raidboss.
3. Extract or adapt the raidboss runtime behind renderer interfaces.
4. Replace popup DOM writes with `raidAlert` protocol messages.
5. Support zone changes, combat changes, wipes, trigger suppression, delays,
   duration, replacement, and cleanup.
6. Render alarm, alert, and info queues in QML.
7. Route TTS through a configurable host implementation.
8. Validate with recorded encounter logs and cactbot trigger test cases.

Acceptance criteria:

- A supported encounter selects the correct upstream cactbot trigger set.
- Alert text, severity, timing, replacement, and expiry match reference cactbot.
- A wipe removes stale alerts and timers immediately.
- At least one complete encounter can be replayed without FFXIV.
- Unsupported zones fail quietly and do not create persistent errors.

Expected effort: 1–3 weeks. The variance depends on how much of the cactbot
runtime can run outside a browser without invasive patches.

### Phase 3 — timeline MVP

Goal: render synchronized upcoming encounter mechanics in native QML.

Work:

1. Adapt cactbot timeline output into authoritative snapshots.
2. Support sync, resync, jumps, durations, styles, and encounter reset.
3. Render a configurable number of upcoming events and progress bars.
4. Add replay tests around phase transitions and timeline resynchronization.

Acceptance criteria:

- Timeline entries agree with reference cactbot during fixture playback.
- Resynchronization does not leave duplicate or stale bars.
- Animation remains smooth while combat snapshots update.

Expected effort: 1–2 weeks after raid alerts.

### Phase 4 — hardening and release

Work:

- settings UI and config migration/versioning;
- structured rotating logs and a diagnostics view;
- startup integration and graceful shutdown;
- Arch package and generic install script;
- cactbot license/notice compliance and pinned-source update tooling;
- CPU/memory profiling during a full encounter;
- end-user setup and troubleshooting documentation.

Acceptance criteria:

- A clean install can be configured without editing source files.
- Missing IINACT, missing cactbot data, and protocol mismatch have actionable
  error messages.
- The bridge restarts after a crash without multiplying processes.
- Release artifacts contain the exact pinned cactbot revision and notices.

Expected effort: 3–5 days for the first release pass, then ongoing maintenance.

## 6. Testing strategy

Live FFXIV sessions must not be required for routine development.

- Protocol unit tests validate IINACT requests, replies, and normalization.
- Recorded logs/fixtures drive combat and raidboss replay tests.
- Golden protocol streams verify alert timing and timeline snapshots.
- QML mock mode renders deterministic alerts and combat rows.
- A manual Hyprland checklist covers fullscreen visibility, click-through,
  monitor changes, scaling, workspace changes, and coexistence with `faiyt-qs`.

Player names and world information in committed fixtures must be anonymized.

## 7. Initial technical decisions

- Runtime: Bun with TypeScript, already available on the target system.
- UI: Quickshell/QML using the installed Quickshell 0.3.x API surface.
- Source of combat truth: IINACT, not a new parser.
- Source of raid mechanics: a pinned upstream cactbot revision.
- Local transport: NDJSON over stdin/stdout for the first implementation.
- Default endpoint: `ws://127.0.0.1:10501/ws`.
- Configuration directory: `$XDG_CONFIG_HOME/faiyt-qs-ffxiv-overlay/`.
- State/cache directory: the corresponding XDG state/cache locations.
- Application identity and Quickshell configuration name:
  `faiyt-qs-ffxiv-overlay`.

## 8. Risks and mitigations

### Cactbot is browser-oriented

First build a narrow adapter around raidboss only. Keep compatibility changes
isolated under `bridge/src/cactbot`, pin upstream, and test against replay
fixtures before updating it.

If direct extraction blocks the MVP, use a temporary headless-browser adapter
to validate the complete data/UI path. It must remain behind the same protocol
and should not become the permanent rendering layer.

### Upstream event/schema changes

Validate every external message, expose protocol versions, log unknown fields,
and keep captured fixtures from known IINACT/cactbot versions.

### Overlay focus and fullscreen behavior

Prove compositor behavior in Phase 0 before investing in encounter logic. Keep
interactive layout controls in a separate explicit mode.

### High-frequency updates

Rate-limit DPS snapshots in the bridge (initial target: 4 updates/second) and
only animate row order/value changes in QML. Raid alerts remain event-driven.

### Process lifecycle

Quickshell owns exactly one bridge child. The bridge handles WebSocket
reconnection; QML handles bridge restart with a capped retry rate. Both sides
emit state changes that are visible in diagnostics.

## 9. First implementation slice

The first code milestone should be Phase 0 plus a fake bridge:

1. `shell.qml` starts as an independent Quickshell application.
2. A mock bridge emits connection, raid alert, timeline, and combat messages.
3. QML models consume the same protocol intended for production.
4. Raid and DPS windows render the mock stream using Rosé Pine Moon.
5. IPC commands toggle layout mode and individual overlays.
6. A short manual runbook verifies placement over FFXIV.

This gets the actual windows on screen early and freezes the UI/bridge boundary
before cactbot extraction begins.
