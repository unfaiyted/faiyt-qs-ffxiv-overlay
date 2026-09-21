import { appendFileSync, mkdirSync, readdirSync, statSync, unlinkSync } from "node:fs";
import { join } from "node:path";
import { CactbotRuntime } from "./cactbot-runtime";

const endpoint = process.env.IINACT_WS_URL ?? "ws://127.0.0.1:10501/ws";
const protocolVersion = 1;
const legacySummerfordEnabled = process.env.FAIYT_LEGACY_SUMMERFORD === "1";

let sequence = 0;
let socket: WebSocket | undefined;
let selfName = "YOU";
let selfJob = "---";
let selfId = "";
let currentZoneId = 0;
let currentZoneName = "";
let lastCombatJournalKey = "";
let lastCombatJournalAt = 0;
let shuttingDown = false;
let summerfordStartAt: number | undefined;
let summerfordGeneration = 0;
let cactbotSummerfordUntil = 0;
let nativeTimelinePopulated = false;
let lastTimelineJournalAt = 0;
const firedSummerfordAlerts = new Set<string>();
const stateDir = join(process.env.XDG_STATE_HOME ?? join(process.env.HOME ?? "/tmp", ".local/state"), "faiyt-qs-ffxiv-overlay");
mkdirSync(stateDir, { recursive: true });

function journal(kind: string, data: unknown): void {
  const now = new Date();
  const path = join(stateDir, `events-${now.toISOString().slice(0, 10)}.jsonl`);
  appendFileSync(path, `${JSON.stringify({ timestamp: now.toISOString(), kind, data })}\n`);
}

function pruneJournal(): void {
  const cutoff = Date.now() - 14 * 24 * 60 * 60 * 1000;
  for (const name of readdirSync(stateDir)) {
    if (!name.startsWith("events-") || !name.endsWith(".jsonl"))
      continue;
    const path = join(stateDir, name);
    if (statSync(path).mtimeMs < cutoff)
      unlinkSync(path);
  }
}
pruneJournal();

const summerfordTimeline = [
  { id: "summerford-almagest", text: "Almagest", at: 3, duration: 0 },
  { id: "summerford-angry-dummy", text: "Angry Dummy", at: 6, duration: 0 },
  { id: "summerford-long-castbar", text: "Long Castbar", at: 10, duration: 10 },
  { id: "summerford-final-sting", text: "Final Sting", at: 15, duration: 0 },
  { id: "summerford-pentacle", text: "Pentacle Sac (DPS)", at: 18, duration: 0 },
  { id: "summerford-tankbuster", text: "Super Tankbuster", at: 25, duration: 0 },
  { id: "summerford-still", text: "Dummy Stands Still", at: 30, duration: 0 },
  { id: "summerford-death", text: "Death", at: 40, duration: 0 },
];

type BridgeMessage = Record<string, unknown> & { type: string };

function emit(message: BridgeMessage): void {
  // Combat snapshots already have a compact journal entry below. Avoid
  // duplicating their full combatant payload every second.
  if (message.type !== "combatSnapshot")
    journal("outbound", message);
  process.stdout.write(`${JSON.stringify({ v: protocolVersion, seq: ++sequence, ...message })}\n`);
}

function diagnostic(level: string, message: string): void {
  emit({ type: "diagnostic", level, message });
}

function numberValue(value: unknown, fallback = 0): number {
  const parsed = Number.parseFloat(String(value ?? ""));
  return Number.isFinite(parsed) ? parsed : fallback;
}

function percentValue(value: unknown): number {
  return numberValue(String(value ?? "").replace("%", ""));
}

function normalizeJob(value: unknown): string {
  const job = String(value ?? "---").trim();
  if (!job)
    return "---";
  return job.toUpperCase();
}

function isTank(job: string): boolean {
  return ["GLA", "PLD", "MRD", "WAR", "DRK", "GNB"].includes(job);
}

function isHealer(job: string): boolean {
  return ["CNJ", "WHM", "SCH", "AST", "SGE"].includes(job);
}

function handlePartyChanged(message: any): void {
  const party = Array.isArray(message.party) ? message.party : [];
  const self = party.find((member: any) => {
    const memberId = String(member.id ?? member.ID ?? "").toLowerCase();
    return Boolean(member.isSelf ?? member.isUser)
      || (selfId !== "" && memberId === selfId.toLowerCase())
      || (selfName !== "YOU" && member.name === selfName);
  });
  if (self?.name)
    selfName = String(self.name);
  if (self?.id ?? self?.ID)
    selfId = String(self.id ?? self.ID);

  emit({
    type: "gameState",
    playerName: selfName,
    partySize: party.length,
    party: party.map((member: any) => ({
      id: String(member.id ?? ""),
      name: String(member.name ?? ""),
      job: numberValue(member.job),
      level: numberValue(member.level),
      inParty: Boolean(member.inParty),
    })),
  });
}

function handlePlayerChanged(message: any): void {
  const player = message.detail ?? message;
  const name = player.name ?? player.charName ?? player.playerName;
  const id = player.id ?? player.ID ?? player.charID ?? player.charId;
  const job = player.job ?? player.jobAbbr;

  if (name)
    selfName = String(name);
  if (id !== undefined && id !== null)
    selfId = String(id);
  if (job)
    selfJob = normalizeJob(job);

  emit({ type: "gameState", playerName: selfName });
  diagnostic("info", `Local player identified as ${selfName}`);
}

function handleChangeZone(message: any): void {
  currentZoneId = numberValue(message.zoneID ?? message.zoneId);
  currentZoneName = String(message.zoneName ?? "Unknown zone");
  cactbotSummerfordUntil = 0;
  nativeTimelinePopulated = false;
  emit({ type: "timelineSnapshot", encounter: currentZoneName, events: [] });
  journal("zone", { zoneId: currentZoneId, zoneName: currentZoneName });
  if (currentZoneId !== 134)
    stopSummerfordTest("zone changed");
  emit({
    type: "gameState",
    zoneId: currentZoneId,
    zoneName: currentZoneName,
    raidbossTestReady: legacySummerfordEnabled && currentZoneId === 134,
  });
}

function handleCombatData(message: any): void {
  const encounter = message.Encounter ?? {};
  const combatantMap = message.Combatant ?? {};
  const active = String(message.isActive ?? "false").toLowerCase() === "true";
  const combatJournal = {
    active,
    title: String(encounter.title ?? "Encounter"),
    zoneName: String(encounter.CurrentZoneName ?? currentZoneName),
    duration: String(encounter.duration ?? "0:00"),
  };
  const combatKey = `${combatJournal.active}|${combatJournal.title}|${combatJournal.zoneName}`;
  if (combatKey !== lastCombatJournalKey || Date.now() - lastCombatJournalAt >= 30000) {
    journal("combat", combatJournal);
    lastCombatJournalKey = combatKey;
    lastCombatJournalAt = Date.now();
  }

  const combatants = Object.entries(combatantMap).map(([key, raw]: [string, any]) => {
    const actorId = String(raw.ID ?? raw.id ?? key);
    const isSelf = key === "YOU" || raw.name === "YOU"
      || (selfId !== "" && actorId.toLowerCase() === selfId.toLowerCase());
    return {
      id: actorId,
      job: normalizeJob(raw.Job),
      name: isSelf ? selfName : String(raw.name ?? key),
      dps: numberValue(raw.ENCDPS ?? raw.encdps ?? raw.DPS ?? raw.dps),
      damage: numberValue(raw.damage),
      percent: percentValue(raw["damage%"]),
      deaths: numberValue(raw.deaths),
      hps: numberValue(raw.ENCHPS ?? raw.enchps),
      healed: numberValue(raw.healed),
      self: isSelf,
    };
  }).sort((left, right) => right.dps - left.dps);

  const self = combatants.find((row) => row.self);
  if (self)
    selfJob = self.job;

  if (encounter.CurrentZoneName) {
    currentZoneName = String(encounter.CurrentZoneName);
    // IINACT immediately sends CombatData on subscription but may not replay
    // ChangeZone until the player teleports again. Preserve Summerford test
    // readiness across bridge/shell restarts by recognizing its zone name.
    if (legacySummerfordEnabled && currentZoneName === "Middle La Noscea" && currentZoneId !== 134) {
      currentZoneId = 134;
      emit({
        type: "gameState",
        zoneId: currentZoneId,
        zoneName: currentZoneName,
        raidbossTestReady: true,
      });
    }
  }

  const totalDamage = combatants.reduce((sum, row) => sum + row.damage, 0);
  for (const row of combatants) {
    if (row.percent <= 0 && totalDamage > 0)
      row.percent = row.damage / totalDamage * 100;
  }

  emit({
    type: "combatSnapshot",
    active,
    encounter: {
      title: String(encounter.title ?? "Encounter"),
      zoneName: String(encounter.CurrentZoneName ?? ""),
      durationSeconds: numberValue(encounter.DURATION),
      duration: String(encounter.duration ?? "0:00"),
      dps: numberValue(encounter.ENCDPS ?? encounter.encdps),
      damage: numberValue(encounter.damage),
    },
    combatants,
  });
}

function emitRaidAlert(
  id: string,
  severity: "alarm" | "alert" | "info",
  text: string,
  durationSeconds: number,
  countdownSeconds?: number,
): void {
  emit({
    type: "raidAlert",
    id,
    severity,
    text,
    durationSeconds,
    countdownSeconds,
    source: "cactbot-summerford-test",
  });
  diagnostic("debug", `Raid alert audio cue: ${severity} (${text})`);
}

function stopSummerfordTest(reason: string): void {
  if (summerfordStartAt === undefined)
    return;
  summerfordStartAt = undefined;
  summerfordGeneration++;
  firedSummerfordAlerts.clear();
  emit({ type: "timelineSnapshot", encounter: "Cactbot Test", events: [] });
  diagnostic("info", `Stopped Summerford test: ${reason}`);
}

function startSummerfordTest(countdownSeconds: number, player: string): void {
  stopSummerfordTest("new countdown");
  const generation = ++summerfordGeneration;
  firedSummerfordAlerts.clear();
  emitRaidAlert(
    `summerford-countdown-${generation}`,
    "info",
    `${player || selfName} started ${countdownSeconds}s countdown`,
    Math.max(5, countdownSeconds),
    countdownSeconds,
  );
  diagnostic("info", `Summerford raidboss test starts in ${countdownSeconds}s`);

  setTimeout(() => {
    if (generation !== summerfordGeneration)
      return;
    summerfordStartAt = Date.now();
    emit({
      type: "gameState",
      encounterName: "Cactbot Summerford Test",
      raidbossTestRunning: true,
    });
    emit({ type: "audioCue", cue: "pull", source: "cactbot-summerford-test" });
    diagnostic("info", "Summerford raidboss test timeline started");
  }, countdownSeconds * 1000);
}

function handleLogLine(message: any): void {
  const line = Array.isArray(message.line) ? message.line : [];
  const type = String(line[0] ?? "");
  // 261/270 are continuous movement/position telemetry. They are still fed to
  // cactbot live, but excluding them keeps fourteen days of diagnostics sane.
  if (type !== "261" && type !== "270")
    journal("logLine", { type, line });

  // FFXIV log type 02 identifies the local/primary player. Unlike party order,
  // this is authoritative and remains correct in every party composition.
  if (type === "02") {
    if (line[2])
      selfId = String(line[2]);
    if (line[3])
      selfName = String(line[3]);
    emit({ type: "gameState", playerName: selfName });
    diagnostic("info", `Local player identified as ${selfName}`);
  } else if (type === "268") {
    const countdownSeconds = numberValue(line[4]);
    const result = String(line[5] ?? "");
    const player = String(line[6] ?? selfName);
    if (result !== "00") {
      if (legacySummerfordEnabled)
        emitRaidAlert("summerford-countdown-failed", "info", `${player} failed to start countdown`, 5);
      return;
    }
    if (currentZoneId === 134) {
      // Upstream's test timeline loops forever by design. Bound the native
      // presentation to one complete test cycle (last event is at ~40s).
      cactbotSummerfordUntil = Date.now() + (countdownSeconds + 46) * 1000;
      nativeTimelinePopulated = false;
    }
    if (legacySummerfordEnabled && currentZoneId === 134)
      startSummerfordTest(countdownSeconds, player);
  } else if (type === "269" && currentZoneId === 134) {
    const player = String(line[4] ?? selfName);
    cactbotSummerfordUntil = 0;
    if (nativeTimelinePopulated) {
      emit({ type: "timelineSnapshot", encounter: currentZoneName, events: [] });
      nativeTimelinePopulated = false;
    }
    if (legacySummerfordEnabled) {
      emitRaidAlert("summerford-countdown-cancel", "info", `${player} cancelled countdown`, 5);
      stopSummerfordTest("countdown cancelled");
    }
  }
}

setInterval(() => {
  if (!legacySummerfordEnabled)
    return;
  if (summerfordStartAt === undefined)
    return;

  const elapsed = (Date.now() - summerfordStartAt) / 1000;
  const events = summerfordTimeline
    .map((event) => ({
      id: event.id,
      text: event.id === "summerford-death" ? `Death To ${selfName}!!` : event.text,
      startsIn: event.at - elapsed,
      duration: event.duration,
    }))
    .filter((event) => event.startsIn > -Math.max(1, event.duration) && event.startsIn < 35);

  emit({ type: "timelineSnapshot", encounter: "Cactbot Test", events });

  const scheduledAlerts = [
    { id: "angry", at: 4, severity: "info" as const, text: "Stack for Angry Dummy", duration: 5 },
    { id: "long", at: 9, severity: "alert" as const, text: "Long Castbar", duration: 5 },
    { id: "sting", at: 11, severity: "alert" as const, text: "Oh no, Final Sting in 4", duration: 5 },
    ...(isTank(selfJob) || isHealer(selfJob)
      ? [{ id: "tankbuster", at: 23, severity: "alarm" as const, text: "Super Tankbuster", duration: 5 }]
      : []),
  ];

  for (const alert of scheduledAlerts) {
    if (elapsed >= alert.at && !firedSummerfordAlerts.has(alert.id)) {
      firedSummerfordAlerts.add(alert.id);
      emitRaidAlert(`summerford-${alert.id}`, alert.severity, alert.text, alert.duration);
    }
  }

  if (elapsed >= 45)
    stopSummerfordTest("test completed");
}, 250);

function handleMessage(event: MessageEvent): void {
  let message: any;
  try {
    message = JSON.parse(String(event.data));
  } catch (error) {
    diagnostic("warning", `Ignored invalid IINACT JSON: ${String(error)}`);
    return;
  }

  switch (message.type) {
    case "PartyChanged":
      handlePartyChanged(message);
      break;
    case "onPlayerChangedEvent":
      handlePlayerChanged(message);
      break;
    case "ChangeZone":
      handleChangeZone(message);
      break;
    case "CombatData":
      handleCombatData(message);
      break;
    case "onInCombatChangedEvent":
      emit({
        type: "gameState",
        inCombat: Boolean(message.detail?.inGameCombat),
      });
      break;
    case "LogLine":
      handleLogLine(message);
      break;
  }
}

function connect(): void {
  emit({ type: "connection", state: "connecting", endpoint });
  socket = new WebSocket(endpoint);

  socket.addEventListener("open", () => {
    emit({ type: "connection", state: "connected", endpoint });
    socket?.send(JSON.stringify({
      call: "subscribe",
      events: [
        "CombatData",
        "ChangeZone",
        "PartyChanged",
        "onPlayerChangedEvent",
        "onInCombatChangedEvent",
        "LogLine",
      ],
    }));
    diagnostic("info", "Subscribed to live IINACT events");
  });

  socket.addEventListener("message", handleMessage);

  socket.addEventListener("error", () => {
    emit({ type: "connection", state: "error", endpoint });
  });

  socket.addEventListener("close", (event) => {
    emit({
      type: "connection",
      state: shuttingDown ? "stopped" : "disconnected",
      endpoint,
      code: event.code,
      reason: event.reason,
    });
    if (!shuttingDown)
      setTimeout(connect, 2000);
  });
}

function shutdown(): void {
  shuttingDown = true;
  cactbot.stop();
  socket?.close(1000, "Bridge shutting down");
  setTimeout(() => process.exit(0), 100);
}

process.on("SIGINT", shutdown);
process.on("SIGTERM", shutdown);

emit({
  type: "hello",
  bridge: "faiyt-qs-ffxiv-overlay",
  runtime: `Bun ${Bun.version}`,
  endpoint,
});
const cactbot = new CactbotRuntime((event) => {
  if (event.type === "alert") {
    emit({
      type: "raidAlert",
      id: `cactbot-${Date.now()}`,
      severity: event.severity,
      text: event.text,
      ttsText: event.ttsText ?? "",
      durationSeconds: 5,
      source: "cactbot-structured",
    });
    journal("cactbotAlert", event);
  } else if (event.type === "speech") {
    emit({ type: "ttsCue", text: event.text, source: "cactbot-structured" });
    journal("cactbotTts", event);
  } else if (event.type === "sound") {
    emit({ type: "audioCue", cue: event.cue, source: "cactbot-structured", url: event.url });
    journal("cactbotSound", event);
  } else if (event.type === "timeline") {
    let events = event.events;
    if (currentZoneId === 134) {
      // Upstream's Summerford test includes an intentionally looping group of
      // synthetic timer-bar exercises. They are useful to cactbot developers,
      // but are not meaningful upcoming mechanics for this native overlay.
      const syntheticTestEntries = new Set([
        "Two",
        "Three",
        "Four",
        "Six",
        "Ten",
        "Fifteen",
        "Force Jump Three",
      ]);
      events = events.filter((entry) => !syntheticTestEntries.has(entry.text));
    }
    if (currentZoneId === 134 && (cactbotSummerfordUntil === 0 || Date.now() > cactbotSummerfordUntil))
      events = [];
    if (events.length > 0 || nativeTimelinePopulated) {
      emit({ type: "timelineSnapshot", encounter: currentZoneName || "Cactbot", events });
      if (events.length === 0 || Date.now() - lastTimelineJournalAt >= 5000) {
        journal("cactbotTimeline", { encounter: currentZoneName, events });
        lastTimelineJournalAt = Date.now();
      }
    }
    nativeTimelinePopulated = events.length > 0;
  } else {
    emit({ type: "cactbotState", state: event.state, detail: event.detail ?? "" });
    journal("cactbotState", event);
  }
});
void cactbot.start();
connect();
