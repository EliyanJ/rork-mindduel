import { afterEach, expect, mock, spyOn, test } from "bun:test";
import { LEGACY_DEADLINE_MS } from "./security-rollout";
import { Database } from "bun:sqlite";
import { appConfig, pickQuestions, verifyAnswer, versionAtLeast, type GameCatalog } from "./game-security";

// Substitute only the Cloudflare host, not application logic. Hub SQL runs against real SQLite.
mock.module("cloudflare:workers", () => ({ DurableObject: class {
  constructor(protected ctx: unknown, protected env: unknown) {}
} }));
const { Hub } = await import("./hub");
const { MatchRoom } = await import("./match-room");
const { PartyRoom } = await import("./party-room");
const worker = (await import("./index")).default;
const cleanups: (() => void)[] = [];
afterEach(() => { for (const cleanup of cleanups.splice(0)) cleanup(); mock.restore(); });

function harness() {
  const database = new Database(":memory:");
  cleanups.push(() => database.close());
  const values = new Map<string, unknown>();
  const pending: Promise<unknown>[] = [];
  const sql = { exec(query: string, ...args: (string | number | null)[]) {
    const rows = database.prepare(query).all(...args);
    return { toArray: () => rows, [Symbol.iterator]: () => rows[Symbol.iterator]() };
  } };
  const ctx = { storage: { sql, get: async (key: string) => values.get(key), put: async (key: string, value: unknown) => { values.set(key, value); } },
    id: { name: "test-match", toString: () => "test-match" }, getWebSockets: () => [], waitUntil: (task: Promise<unknown>) => { pending.push(task); } };
  return { ctx, sql, values, pending };
}

const question = { id: "q1", type: "multipleChoice", answer: "Paris" };

for (const [name, Room] of [["duel", MatchRoom], ["party", PartyRoom]] as const) {
  test(`${name}: transport interruption cancels every result without settlement or flags`, async () => {
    const h = harness();
    const calls: string[] = [];
    const room = new Room(h.ctx as never, { DO: { fetch: async (r: Request) => { calls.push(new URL(r.url).pathname); return Response.json({}); }, setAlarm: async () => {} } } as never);
    const state = { seed: "123", phase: "playing", round: 0, globalIndex: 0, questions: [question], players: [{ id: "p1" }, { id: "p2" }], roundDuration: 10, scores: { p1: 100, p2: 0 }, answers: [{}], leftMidGame: [], settled: false, noResult: false };
    h.values.set("state", state);
    await room.webSocketClose({ deserializeAttachment: () => ({ userId: "p1" }) } as never);
    await Promise.all(h.pending);
    expect(state.phase).toBe("finished");
    expect(state.noResult).toBe(true);
    expect(state.leftMidGame).toEqual([]);
    expect(calls).toEqual([]);
    await room.webSocketClose({ deserializeAttachment: () => ({ userId: "p2" }) } as never);
    expect(calls).toEqual([]);
  });

  test(`${name}: approved legacy drain ends at the fixed deadline with no result`, async () => {
    const clock = spyOn(Date, "now").mockReturnValue(LEGACY_DEADLINE_MS - 1000);
    const h = harness();
    const calls: string[] = [];
    const alarms: number[] = [];
    const room = new Room(h.ctx as never, { DO: { fetch: async (r: Request) => { calls.push(new URL(r.url).pathname); return Response.json({}); }, setAlarm: async (_c: string, _id: string, time: number) => { alarms.push(time); } } } as never);
    const state = { seed: "123", partyId: "test-match", phase: "playing", round: 0, globalIndex: 0, players: [{ id: "p1" }, { id: "p2" }], roundDuration: 10, scores: {}, answers: [{}] as Record<string, { points: number }>[], leftMidGame: [], settled: false, noResult: false };
    h.values.set("state", state);
    await room.webSocketMessage({ deserializeAttachment: () => ({ userId: "p1" }) } as never, JSON.stringify({ type: "answer", index: 0, correct: true, timeMs: 1000 }));
    expect(state.answers[0]?.p1?.points).toBe(190);
    expect(alarms).toEqual([LEGACY_DEADLINE_MS]);
    clock.mockReturnValue(LEGACY_DEADLINE_MS);
    await room.onAlarm();
    expect(state.phase).toBe("finished");
    expect(state.noResult).toBe(true);
    expect(calls).toEqual([]);
  });
}

test("legacy transport forfeits cannot mutate player accounts in Hub", async () => {
  const h = harness();
  const hub = new Hub(h.ctx as never, {});
  h.sql.exec("INSERT INTO players (user_id, name, emoji, elo, points, reputation, friend_code, last_seen_at) VALUES ('p1', 'Test', '', 1400, 1800, 50, 'Test#1', 0)");
  for (const [path, body] of [
    ["match-result", { matchId: "legacy", forfeitBy: "p1", results: [{ userId: "p1", score: 0 }, { userId: "p2", score: 100 }] }],
    ["party-result", { partyId: "legacy", mode: "solo", leftMidGame: ["p1"], results: [{ userId: "p1", score: 0 }] }],
  ] as const) {
    const response = await hub.fetch(new Request(`https://internal/internal/${path}`, { method: "POST", body: JSON.stringify(body) }));
    expect(await response.json()).toMatchObject({ noResult: true });
  }
  expect(h.sql.exec("SELECT elo, points, reputation, losses FROM players WHERE user_id='p1'").toArray()[0]).toEqual({ elo: 1400, points: 1800, reputation: 50, losses: 0 });
});

test("persisted legacy interruption cancels settlement for every participant", async () => {
  spyOn(Date, "now").mockReturnValue(LEGACY_DEADLINE_MS - 5000);
  const h = harness();
  const hub = new Hub(h.ctx as never, {});
  for (const id of ["p1", "p2"]) h.sql.exec("INSERT INTO players (user_id, name, emoji, elo, points, reputation, friend_code, last_seen_at) VALUES (?, 'Test', '', 1400, 1800, 50, ?, 0)", id, id);
  const room = new PartyRoom(h.ctx as never, { DO: { fetch: (r: Request) => hub.fetch(r), setAlarm: async () => {} } } as never);
  const state = { partyId: "legacy", seed: "123", mode: "solo", phase: "playing", players: [{ id: "p1" }, { id: "p2" }], scores: { p1: 100, p2: 0 }, leftMidGame: ["p1"], settled: false, noResult: false };
  h.values.set("state", state);
  await room.webSocketMessage({ deserializeAttachment: () => ({ userId: "p2" }) } as never, JSON.stringify({ type: "leave" }));
  expect(state.noResult).toBe(true);
  expect(h.sql.exec("SELECT points, reputation FROM players ORDER BY user_id").toArray()).toEqual([{ points: 1800, reputation: 50 }, { points: 1800, reputation: 50 }]);
});

test("current party explicit departure is distinguished from a transport close", async () => {
  const h = harness();
  const calls: string[] = [];
  const room = new PartyRoom(h.ctx as never, { DO: { fetch: async (r: Request) => { calls.push(r.url); return Response.json({}); } } } as never);
  const state = { seed: "123", phase: "playing", questions: [question], players: [{ id: "p1" }, { id: "p2" }], leftMidGame: [] as string[], voluntaryLeaves: [] as string[], settled: false };
  h.values.set("state", state);
  const ws = { deserializeAttachment: () => ({ userId: "p1" }) };
  await room.webSocketMessage(ws as never, JSON.stringify({ type: "leave" }));
  await room.webSocketClose(ws as never);
  expect(state.phase).toBe("playing");
  expect(state.leftMidGame).toEqual(["p1"]);
  expect(state.voluntaryLeaves).toEqual(["p1"]);
  expect(calls).toEqual([]);
});
for (const [name, Room] of [["duel", MatchRoom], ["party", PartyRoom]] as const) {
  for (const scenario of ["forged", "fast", "missing", "correct", "late"] as const) {
    test(`${name}: ${scenario} answer uses the authoritative question and clock`, async () => {
      const h = harness();
      const hub = new Hub(h.ctx as never, {});
      const env = { DO: { fetch: (req: Request) => hub.fetch(req) } };
      const room = new Room(h.ctx as never, env as never);
      const state = { seed: "123", partyId: "test-match", players: [{ id: "p1" }, { id: "p2" }], roundDuration: 10,
        phase: "playing", round: 0, globalIndex: 0, roundStartedAt: Date.now() - (scenario === "fast" ? 10 : scenario === "late" ? 13000 : 1000),
        questions: [question], answers: [{}] as Record<string, { correct: boolean; points: number; timeMs: number }>[], scores: { p1: 0, p2: 0 }, leftMidGame: [] };
      h.values.set("state", state);
      const ws = { deserializeAttachment: () => ({ userId: "p1" }) };
      await room.webSocketMessage(ws as never, JSON.stringify({ type: "answer", index: 0, correct: scenario !== "correct", timeMs: 0,
        ...(scenario !== "missing" ? { answer: scenario === "forged" ? "Lyon" : "Paris" } : {}) }));
      await Promise.all(h.pending);
      const answer = state.answers[0]?.p1;
      expect(answer?.correct).toBe(scenario === "correct");
      expect(answer?.points ?? -1).toBe(scenario === "correct" ? 190 : 0);
      if (scenario === "correct") expect(answer?.timeMs).toBeGreaterThanOrEqual(1000);
      const flags = h.sql.exec("SELECT * FROM cheat_flags").toArray();
      expect(flags.length).toBe(scenario === "correct" ? 0 : 1);
      if (scenario === "fast") expect(flags[0]).toMatchObject({ raison: "answer_too_fast", user_id: "p1", match_id: "test-match" });
      // A second answer cannot turn a refused answer into points or multiply flags.
      await room.webSocketMessage(ws as never, JSON.stringify({ type: "answer", index: 0, answer: "Paris", correct: true }));
      await Promise.all(h.pending);
      expect(state.answers[0]?.p1).toEqual(answer);
      expect(h.sql.exec("SELECT * FROM cheat_flags").toArray().length).toBe(flags.length);
    });
  }
  test(`${name}: fabricated client ticket cannot initialize a room`, async () => {
    const h = harness();
    const hub = new Hub(h.ctx as never, {});
    const room = new Room(h.ctx as never, { DO: { fetch: (r: Request) => hub.fetch(r) } } as never);
    const route = name === "duel" ? "match" : "party";
    const url = new URL(`https://test/api/${route}/invented/ws?userId=p1`);
    url.searchParams.set("init", JSON.stringify({ seed: "123", partyId: "invented", you: { id: "p1" }, opponent: { id: "p2" }, players: [{ id: "p1" }] }));
    const response = await room.fetch(new Request(url, { headers: { Upgrade: "websocket" } }));
    expect(response.status).toBe(400);
    expect(h.values.get("state")).toBeUndefined();
  });
}

for (const version of [undefined, "0.9.9", "garbage", "999.0", "1.0.1-extra"]) {
  for (const path of ["queue/join", "custom/create", "custom/join"]) {
    test(`party ${path} refuses version ${version ?? "absent"} before any write`, async () => {
      const h = harness();
      const hub = new Hub(h.ctx as never, {});
      const response = await hub.fetch(new Request(`https://test/api/hub/party/${path}`, { method: "POST", headers: version ? { "X-App-Version": version } : {}, body: "{}" }));
      expect(response.status).toBe(426);
      expect(await response.json()).toEqual({ error: "Mets à jour Minduel pour jouer en groupe.", code: "party_update_required" });
      expect(h.sql.exec("SELECT * FROM players").toArray()).toHaveLength(0);
      expect(h.sql.exec("SELECT * FROM party_queue").toArray()).toHaveLength(0);
    });
  }
}

test("current party version gets past the gate; duel without version is not version-blocked", async () => {
  const h = harness();
  const hub = new Hub(h.ctx as never, {});
  for (const [path, headers] of [["party/queue/join", { "X-App-Version": "1.0.1" }], ["queue/join", {}]] as const) {
    const response = await hub.fetch(new Request(`https://test/api/hub/${path}`, { method: "POST", headers, body: "{}" }));
    expect(response.status).toBe(401); // Authentication, not an update gate.
  }
});

test("migrations preserve player balances/rating and isolate old lobbies", async () => {
  const h = harness();
  new Hub(h.ctx as never, {});
  h.sql.exec("INSERT INTO players (user_id, name, emoji, elo, points, wins, friend_code, last_seen_at) VALUES ('p1', 'Test', '', 1400, 1800, 12, 'Test#1', 0)");
  h.sql.exec("INSERT INTO party_lobbies (lobby_id, mode, created_at, room_code) VALUES ('legacy', 'solo', ?, 'OLD01')", Date.now());
  const hub = new Hub(h.ctx as never, {});
  expect(h.sql.exec("SELECT elo, points, wins FROM players WHERE user_id = 'p1'").toArray()[0]).toEqual({ elo: 1400, points: 1800, wins: 12 });
  const rejected = await hub.fetch(new Request("https://test/api/hub/party/custom/join", { method: "POST", headers: { "X-Rork-User-Id": "p1", "X-App-Version": "1.0.1" }, body: JSON.stringify({ roomCode: "OLD01" }) }));
  expect(rejected.status).toBe(426);
  const accepted = await hub.fetch(new Request("https://test/api/hub/party/queue/join", { method: "POST", headers: { "X-Rork-User-Id": "p1", "X-App-Version": "1.0.1" }, body: JSON.stringify({ mode: "solo" }) }));
  expect(accepted.status).toBe(200);
  expect((await accepted.json() as { lobbyId: string }).lobbyId).not.toBe("legacy");
  expect(h.sql.exec("SELECT * FROM party_lobbies WHERE lobby_id = 'legacy'").toArray()).toHaveLength(1);
});

test("public configuration, localhost CORS and internal-route isolation", async () => {
  const h = harness();
  const hub = new Hub(h.ctx as never, { MIN_APP_VERSION: "1.0.0", MIN_PARTY_VERSION: "1.0.2" });
  const env = { DO: { fetch: (r: Request) => hub.fetch(r) } };
  const config = await worker.fetch(new Request("https://test/api/app/config"), env as never);
  expect(await config.json()).toEqual({ min_version: "1.0.0", min_version_party: "1.0.2" });
  const options = await worker.fetch(new Request("https://test/api/hub/party/queue/join", { method: "OPTIONS", headers: { Origin: "http://localhost:5173" } }), env as never);
  expect(options.headers.get("Access-Control-Allow-Headers")).toContain("X-App-Version");
  for (const path of ["room-ticket", "cheat-flag"]) {
    expect((await worker.fetch(new Request(`https://test/internal/${path}`, { method: "POST", body: "{}" }), env as never)).status).toBe(404);
  }
});

test("admin allow-list is private and requires verified identity", async () => {
  const h = harness();
  const hub = new Hub(h.ctx as never, { ADMIN_ALLOWED_EMAILS: "owner@example.test" });
  for (const [id, email, allowed] of [["p1", "owner@example.test", true], ["p2", "other@example.test", false], ["", "owner@example.test", false]] as const) {
    const response = await hub.fetch(new Request("https://test/api/admin/access", { headers: { "X-Rork-User-Id": id, "X-Rork-User-Email": email } }));
    expect(await response.json()).toEqual({ allowed });
  }
});

test("version ordering and 300 ms boundary", () => {
  expect(versionAtLeast("1.0.10", "1.0.2")).toBe(true);
  expect(versionAtLeast("1.0.1", "1.0.1")).toBe(true);
  expect(versionAtLeast(null, "1.0.1")).toBe(false);
  expect(appConfig({})).toEqual({ min_version: "1.0.0", min_version_party: "1.0.0" });
  expect(verifyAnswer(question, "Paris", 0, 299, 10000).correct).toBe(false);
  expect(verifyAnswer(question, " pÀRis ", 0, 300, 10000).correct).toBe(true);
});

test("question picker deterministic fixture for cross-platform parity", () => {
  const catalog: GameCatalog = { disciplines: [{ id: "histoire", chapters: [{ questions: [
    { id: "q1", type: "multipleChoice", answer: "A" }, { id: "q2", type: "multipleChoice", answer: "B" },
    { id: "q3", type: "trueFalse", answer: "Vrai" }, { id: "q4", type: "multipleChoice", answer: "D" },
    { id: "excluded", type: "anagram", answer: "XYZ" },
  ] }] }] };
  expect(pickQuestions(catalog, "123", 4, ["all"], 1000).map(q => q.id)).toEqual(["q2", "q3", "q1", "q4"]);
});
