import { existsSync } from "node:fs";
import { join } from "node:path";

const devtoolsPort = Math.max(1024, Math.min(65535,
  Number.parseInt(process.env.FAIYT_DEVTOOLS_PORT ?? "10503", 10) || 10503));
const chromiumPath = process.env.FAIYT_CHROMIUM_PATH?.trim() || "chromium";
const overlayEndpoint = process.env.IINACT_WS_URL ?? "ws://127.0.0.1:10501/ws";
const localBundle = join(import.meta.dir, "../../.deps/cactbot/dist/ui/raidboss/raidboss.bundle.js");
const localShell = join(import.meta.dir, "../cactbot-runtime.html");
const raidbossBase = existsSync(localBundle)
  ? `file://${localShell}`
  : "https://overlayplugin.github.io/cactbot/ui/raidboss/raidboss.html";
const cactbotUrl = raidbossBase
  + `?OVERLAY_WS=${encodeURIComponent(overlayEndpoint)}&alerts=1&timeline=1&audio=1&forceTTS=1`;
const profileDir = `/tmp/faiyt-qs-ffxiv-cactbot-${process.pid}`;

type RuntimeEvent =
  | { type: "state"; state: string; detail?: string }
  | { type: "alert"; severity: "info" | "alert" | "alarm"; text: string; ttsText?: string }
  | { type: "speech"; text: string }
  | { type: "sound"; cue: "info" | "alert" | "alarm" | "pull"; url: string }
  | { type: "timeline"; events: Array<{ id: string; text: string; startsIn: number; duration: number }> };

type Emit = (event: RuntimeEvent) => void;

export class CactbotRuntime {
  private browser?: ReturnType<typeof Bun.spawn>;
  private socket?: WebSocket;
  private requestId = 0;
  private pollTimer?: ReturnType<typeof setInterval>;
  private polling = false;
  private stopped = false;
  private previousTimeline = "";
  private timelineChangedAt = Date.now();
  private timelineClearedForStale = false;
  private pending = new Map<number, (value: any) => void>();

  constructor(private readonly emit: Emit) {}

  async start(): Promise<void> {
    this.emit({ type: "state", state: "starting" });
    this.browser = Bun.spawn([
      chromiumPath,
      "--headless=new",
      "--disable-gpu",
      "--disable-extensions",
      "--disable-session-crashed-bubble",
      "--autoplay-policy=no-user-gesture-required",
      "--no-first-run",
      "--no-default-browser-check",
      "--no-sandbox",
      `--remote-debugging-port=${devtoolsPort}`,
      `--user-data-dir=${profileDir}`,
      cactbotUrl,
    ], { stdout: "ignore", stderr: "ignore" });

    for (let attempt = 0; attempt < 50 && !this.stopped; attempt++) {
      try {
        // Chromium may bind its DevTools listener to IPv6 localhost only.
        // Using localhost follows the address family selected by Chromium and
        // remains compatible with hosts where it binds to IPv4.
        const targets = await fetch(`http://localhost:${devtoolsPort}/json/list`).then((r) => r.json()) as any[];
        const page = targets.find((target) => target.type === "page"
          && target.title === "Cactbot Raidboss"
          && String(target.url).startsWith(raidbossBase));
        if (page?.webSocketDebuggerUrl) {
          await this.connect(page.webSocketDebuggerUrl);
          return;
        }
      } catch (_) {}
      await Bun.sleep(200);
    }
    this.emit({ type: "state", state: "error", detail: "Chromium DevTools page unavailable" });
  }

  private connect(url: string): Promise<void> {
    return new Promise((resolve, reject) => {
      const socket = new WebSocket(url);
      this.socket = socket;
      socket.addEventListener("open", () => {
        this.emit({ type: "state", state: "connected", detail: cactbotUrl });
        this.pollTimer = setInterval(() => void this.poll(), 150);
        resolve();
      });
      socket.addEventListener("message", (event) => {
        const message = JSON.parse(String(event.data));
        const callback = this.pending.get(message.id);
        if (callback) {
          this.pending.delete(message.id);
          callback(message);
        }
      });
      socket.addEventListener("close", () => {
        if (!this.stopped)
          this.emit({ type: "state", state: "disconnected" });
      });
      socket.addEventListener("error", () => reject(new Error("DevTools websocket failed")));
    });
  }

  private request(method: string, params: Record<string, unknown>): Promise<any> {
    return new Promise((resolve) => {
      const id = ++this.requestId;
      this.pending.set(id, resolve);
      this.socket?.send(JSON.stringify({ id, method, params }));
    });
  }

  private async poll(): Promise<void> {
    if (this.polling || this.socket?.readyState !== WebSocket.OPEN)
      return;
    this.polling = true;
    try {
      const response = await this.request("Runtime.evaluate", {
        expression: `JSON.stringify({
          events: window.__faiytCactbotEvents?.splice(0) || [],
          timeline: [...document.querySelectorAll('#timeline .timer-bar timer-bar')].map((bar, index) => ({
            id: (bar.getAttribute('lefttext') || 'event') + '-' + index,
            text: bar.getAttribute('lefttext') || '',
            startsIn: Number(bar.value || 0),
            duration: Number(bar.duration || 30)
          })).filter((event) => event.text && event.startsIn > 0)
        })`,
        returnByValue: true,
      });
      const value = response?.result?.result?.value;
      if (typeof value !== "string")
        return;
      const current = JSON.parse(value) as {
        events: Array<{ type: string; severity?: "info" | "alert" | "alarm"; text?: string }>;
        timeline: Array<{ id: string; text: string; startsIn: number; duration: number }>;
      };
      const alerts: Array<{ severity: "info" | "alert" | "alarm"; text: string; ttsText?: string }> = [];
      const unpairedSpeech: string[] = [];
      const sounds: string[] = [];
      for (const event of current.events) {
        if (event.type === "alert" && event.severity && event.text) {
          alerts.push({ severity: event.severity, text: event.text });
        } else if (event.type === "tts" && event.text) {
          const candidate = [...alerts].reverse().find((alert) => alert.ttsText === undefined);
          if (candidate)
            candidate.ttsText = event.text;
          else
            unpairedSpeech.push(event.text);
        } else if (event.type === "sound" && event.text) {
          sounds.push(event.text);
        }
      }
      for (const alert of alerts)
        this.emit({ type: "alert", ...alert });
      for (const text of unpairedSpeech)
        this.emit({ type: "speech", text });
      for (const url of sounds) {
        const lower = url.toLowerCase();
        const cue = lower.includes("alarm") ? "alarm"
          : lower.includes("alert") || lower.includes("long") ? "alert"
          : lower.includes("pull") || lower.includes("sonar") ? "pull" : "info";
        this.emit({ type: "sound", cue, url });
      }
      const timelineSignature = JSON.stringify(current.timeline);
      if (timelineSignature !== this.previousTimeline) {
        this.previousTimeline = timelineSignature;
        this.timelineChangedAt = Date.now();
        this.timelineClearedForStale = false;
        this.emit({ type: "timeline", events: current.timeline });
      } else if (current.timeline.length > 0 && !this.timelineClearedForStale
        && Date.now() - this.timelineChangedAt > 2500) {
        // Cactbot leaves the last rendered bars in the DOM when its test or an
        // encounter ends. Live bars continually change their value attribute.
        this.timelineClearedForStale = true;
        this.emit({ type: "timeline", events: [] });
      }
    } catch (error) {
      this.emit({ type: "state", state: "error", detail: String(error) });
    } finally {
      this.polling = false;
    }
  }

  stop(): void {
    this.stopped = true;
    if (this.pollTimer)
      clearInterval(this.pollTimer);
    this.socket?.close();
    this.browser?.kill();
  }
}
