// backend.js with no network, under Node's own test runner: a stand-in
// answers its requests, a stand-in socket carries its live messages, and a
// stand-in clock decides when its waits are up. The same claims as the
// Godot service's tests/test_backend.gd. The same calls against the real
// platform: tests/online.mjs.

import assert from "node:assert/strict";
import { test } from "node:test";
import { Backend, HEARTBEAT, Reply } from "../backend.js";

const URL = "https://api.example.test";
const KEY = "sb_publishable_test";

/** Stands in for the platform: answers each request from a queue, and remembers what was asked. */
class Platform {
  constructor() { this.asked = []; this.answers = []; }
  answer(status, body = null) { this.answers.push([status, body]); }
  request = async (method, at, headers, body) => {
    this.asked.push({ method, at, headers, body });
    const next = this.answers.shift();
    if (!next) return { status: 0, text: "" };
    return { status: next[0], text: next[1] === null ? "" : JSON.stringify(next[1]) };
  };
  last() { return this.asked.at(-1); }
}

/** Stands in for the clock that runs waits: time moves only when told. */
class Timers {
  constructor() { this.now = 0; this.waiting = []; this.next = 1; }
  setTimeout = (fn, ms) => { const id = this.next++; this.waiting.push({ id, at: this.now + ms, fn }); return id; };
  clearTimeout = (id) => { this.waiting = this.waiting.filter((w) => w.id !== id); };
  pass(ms) {
    const until = this.now + ms;
    for (;;) {
      const due = this.waiting.filter((w) => w.at <= until).sort((a, b) => a.at - b.at)[0];
      if (!due) break;
      this.waiting = this.waiting.filter((w) => w !== due);
      this.now = due.at;
      due.fn();
    }
    this.now = until;
  }
}

/** Stands in for a WebSocket: keeps what was sent, and opens, speaks and closes when told. */
class Socket {
  constructor(at) { this.at = at; this.sent = []; this.readyState = 0; this.closed = false; }
  send(text) { this.sent.push(JSON.parse(text)); }
  close() { this.closed = true; this.readyState = 3; }
  open() { this.readyState = 1; this.onopen?.(); }
  say(message) { this.onmessage?.({ data: JSON.stringify(message) }); }
  drop() { this.readyState = 3; this.onclose?.(); }
}

function storage() {
  const kept = new Map();
  return { kept, get: (n) => kept.get(n) ?? null, set: (n, t) => kept.set(n, t), remove: (n) => kept.delete(n) };
}

function fresh({ now = 1000, kept = storage() } = {}) {
  const platform = new Platform();
  const timers = new Timers();
  const sockets = [];
  const backend = new Backend(URL + "/", KEY, {
    storage: kept, transport: platform.request, clock: () => now, timers,
    socket: (at) => { const s = new Socket(at); sockets.push(s); return s; },
  });
  return { backend, platform, timers, sockets, kept };
}

const session = (token, expiresAt, id = "player-1") => ({ access_token: token, refresh_token: `refresh-${token}`, expires_at: expiresAt, user: { id } });
const header = (asked, name) => asked.headers[name] ?? "";

test("signing in anonymously keeps the session and says who signed in", async () => {
  const { backend, platform, kept } = fresh();
  const heard = [];
  backend.on("signedIn", (id) => heard.push(id));
  platform.answer(200, { access_token: "t1", refresh_token: "r1", expires_in: 3600, user: { id: "player-1" } });
  const reply = await backend.signInAnonymously();
  assert.ok(reply.ok);
  assert.equal(platform.last().at, `${URL}/auth/v1/signup`, "the URL loses its trailing slash");
  assert.equal(header(platform.last(), "apikey"), KEY);
  assert.equal(backend.playerId(), "player-1");
  assert.equal(backend.session.expires_at, 1000 + 3600, "expires_in becomes a time");
  assert.deepEqual(heard, ["player-1"]);
  assert.equal(JSON.parse(kept.get("backend_session")).access_token, "t1", "kept for the next visit");
});

test("a captcha answer travels with the sign-in", async () => {
  const { backend, platform } = fresh();
  platform.answer(200, { access_token: "t", refresh_token: "r", expires_in: 3600, user: { id: "p" } });
  await backend.signInAnonymously("turnstile-answer");
  assert.deepEqual(JSON.parse(platform.last().body), { gotrue_meta_security: { captcha_token: "turnstile-answer" } });
});

test("Google's token signs in through the id_token grant", async () => {
  const { backend, platform } = fresh();
  platform.answer(200, { access_token: "g", refresh_token: "r", expires_in: 3600, user: { id: "google-player" } });
  await backend.signInWithGoogleToken("google-id-token", "raw-nonce");
  assert.equal(platform.last().at, `${URL}/auth/v1/token?grant_type=id_token`);
  assert.deepEqual(JSON.parse(platform.last().body), { provider: "google", id_token: "google-id-token", nonce: "raw-nonce" });
  assert.equal(backend.playerId(), "google-player");
});

test("an ok answer that signs nobody in says so", async () => {
  const { backend, platform } = fresh();
  platform.answer(200, { user: null });
  const reply = await backend.verifyCode("a@b.c", "123456");
  assert.equal(reply.ok, false);
  assert.equal(reply.error, "The server didn't sign anyone in");
});

test("calls carry the player's token, and refuse to change every row", async () => {
  const { backend, platform } = fresh();
  backend.session = session("tok", 99999);
  platform.answer(200, [{ id: 1 }]);
  const rows = await backend.select("notes", "done=eq.false");
  assert.deepEqual(rows.data, [{ id: 1 }]);
  assert.equal(platform.last().at, `${URL}/rest/v1/notes?select=*&done=eq.false`);
  assert.equal(header(platform.last(), "Authorization"), "Bearer tok");
  platform.answer(201, [{ id: 2, body: "x" }]);
  await backend.insert("notes", { body: "x" });
  assert.equal(header(platform.last(), "Prefer"), "return=representation");
  assert.equal((await backend.update("notes", "", { body: "y" })).status, 400);
  assert.equal((await backend.delete("notes", "")).status, 400);
  assert.equal(platform.asked.length, 2, "the refused ones never left");
  platform.answer(204);
  await backend.delete("notes", "id=eq.2");
  assert.equal(platform.last().method, "DELETE");
  platform.answer(200, 3);
  await backend.callRpc("count notes", { a: 1 });
  assert.equal(platform.last().at, `${URL}/rest/v1/rpc/count%20notes`);
  const unreachable = await backend.select("notes");
  assert.equal(unreachable.status, 0);
  assert.equal(unreachable.error, "Couldn't reach the server");
});

test("a failure answers the platform's own words", () => {
  assert.equal(new Reply(400, { msg: "Email not confirmed" }).error, "Email not confirmed");
  assert.equal(new Reply(500, "plain").error, "The server answered 500");
});

test("a session about to run out is refreshed before the call, and the player stays the same", async () => {
  const { backend, platform } = fresh();
  backend.session = session("old", 1030);
  platform.answer(200, { access_token: "new", refresh_token: "r-new", expires_in: 3600 });
  platform.answer(200, []);
  await backend.select("notes");
  assert.equal(platform.asked[0].at, `${URL}/auth/v1/token?grant_type=refresh_token`);
  assert.deepEqual(JSON.parse(platform.asked[0].body), { refresh_token: "refresh-old" });
  assert.equal(header(platform.last(), "Authorization"), "Bearer new");
  assert.equal(backend.playerId(), "player-1");
});

test("calls made during a refresh wait for it rather than refreshing again", async () => {
  const { backend, platform } = fresh();
  backend.session = session("old", 1030);
  let release;
  const held = new Promise((r) => { release = r; });
  const answer = platform.request;
  backend.transport = async (...asked) => { if (asked[1].includes("refresh_token")) await held; return answer(...asked); };
  platform.answer(200, { access_token: "once", refresh_token: "r", expires_in: 3600 });
  platform.answer(200, []);
  platform.answer(200, []);
  const both = Promise.all([backend.select("a"), backend.select("b")]);
  release();
  await both;
  assert.equal(platform.asked.filter((a) => a.at.includes("refresh_token")).length, 1);
  assert.equal(header(platform.last(), "Authorization"), "Bearer once");
});

test("a refresh refused during a call signs the player out", async () => {
  const { backend, platform, kept } = fresh();
  backend.session = session("old", 1030);
  backend._keep(backend.session);
  const out = [];
  backend.on("signedOut", () => out.push(true));
  platform.answer(400, { error_description: "Invalid Refresh Token" });
  platform.answer(401, { message: "JWT expired" });
  await backend.select("notes");
  assert.equal(backend.isSignedIn(), false);
  assert.equal(kept.get("backend_session"), null);
  assert.deepEqual(out, [true]);
});

test("the next visit restores the session; a run-out one kept offline stays; a refused one doesn't", async () => {
  const kept = storage();
  kept.set("backend_session", JSON.stringify(session("kept", 5000)));
  const again = fresh({ kept, now: 1000 });
  assert.equal(await again.backend.restore(), true);
  assert.equal(again.platform.asked.length, 0, "a session with time left needs no request");

  const later = fresh({ kept, now: 9000 });
  const heard = [];
  later.backend.on("signedIn", (id) => heard.push(id));
  assert.equal(await later.backend.restore(), true, "no answer at all keeps the session for later");
  assert.deepEqual(heard, ["player-1"]);

  const refused = fresh({ kept, now: 9000 });
  refused.platform.answer(400, { error_description: "Invalid Refresh Token" });
  assert.equal(await refused.backend.restore(), false);
  assert.equal(kept.get("backend_session"), null);

  kept.set("backend_session", "not json");
  assert.equal(await fresh({ kept }).backend.restore(), false, "a damaged session is passed over");
});

test("live: a channel joins once the socket opens, hears changes and broadcasts, and follows the token", async () => {
  const { backend, platform, sockets } = fresh();
  backend.session = session("live-token", 99999);
  const room = backend.channel("notes");
  assert.equal(backend.channel("notes"), room, "a name always gives the same channel");
  const changes = [], messages = [];
  let joins = 0;
  room.on("changed", (c) => changes.push(c));
  room.on("broadcast", (event, payload) => messages.push([event, payload]));
  room.on("joined", () => joins++);
  room.onChanges("notes", "INSERT").join();
  assert.equal(sockets.length, 1);
  assert.equal(sockets[0].at, "wss://api.example.test/realtime/v1/websocket?apikey=sb_publishable_test&vsn=1.0.0");
  assert.equal(sockets[0].sent.length, 0, "it waits for the socket to open");
  sockets[0].open();
  const join = sockets[0].sent.at(-1);
  assert.equal(join.event, "phx_join");
  assert.equal(join.topic, "realtime:notes");
  assert.equal(join.payload.access_token, "live-token");
  assert.deepEqual(join.payload.config.postgres_changes, [{ event: "INSERT", schema: "public", table: "notes" }]);
  assert.equal(join.ref, join.join_ref);
  sockets[0].say({ topic: "realtime:notes", event: "phx_reply", ref: "999", payload: { status: "ok" } });
  assert.equal(room.isJoined, false, "a reply to something else isn't joining");
  sockets[0].say({ topic: "realtime:notes", event: "phx_reply", ref: join.ref, payload: { status: "ok", response: {} } });
  assert.equal(room.isJoined, true);
  assert.equal(joins, 1);
  sockets[0].say({ topic: "realtime:notes", event: "postgres_changes", payload: { data: { type: "INSERT", table: "notes", record: { id: 5, body: "new" }, old_record: {} } } });
  assert.equal(changes[0].record.body, "new");
  sockets[0].say({ topic: "realtime:notes", event: "postgres_changes", payload: { data: null } });
  assert.equal(changes.length, 1, "a change with no data is passed over");
  sockets[0].say({ topic: "realtime:notes", event: "broadcast", payload: { type: "broadcast", event: "move", payload: { x: 3 } } });
  sockets[0].say({ topic: "realtime:elsewhere", event: "broadcast", payload: { event: "move", payload: {} } });
  assert.deepEqual(messages, [["move", { x: 3 }]]);
  room.sendBroadcast("move", { x: 4 });
  assert.equal(sockets[0].sent.at(-1).payload.payload.x, 4);
  assert.equal(sockets[0].sent.at(-1).join_ref, join.ref);

  platform.answer(200, { access_token: "fresher", refresh_token: "r", expires_in: 3600 });
  await backend.refresh();
  assert.equal(sockets[0].sent.at(-1).event, "access_token");
  assert.equal(sockets[0].sent.at(-1).payload.access_token, "fresher");

  platform.answer(204);
  await backend.signOut();
  const [leave, rejoin] = sockets[0].sent.slice(-2);
  assert.equal(leave.event, "phx_leave");
  assert.equal(rejoin.event, "phx_join");
  assert.equal(rejoin.payload.access_token, undefined, "signed out, it joins again as nobody");
});

test("live: a dropped channel waits before rejoining; a dropped socket reconnects with growing waits", () => {
  const { backend, sockets, timers } = fresh();
  const room = backend.channel("notes").join();
  sockets[0].open();
  const first = sockets[0].sent.at(-1);
  sockets[0].say({ topic: "realtime:notes", event: "phx_reply", ref: first.ref, payload: { status: "ok" } });
  sockets[0].say({ topic: "realtime:notes", event: "phx_error", payload: {} });
  assert.equal(room.isJoined, false);
  const sentBefore = sockets[0].sent.length;
  timers.pass(500);
  assert.equal(sockets[0].sent.length, sentBefore, "not at once");
  timers.pass(600);
  assert.equal(sockets[0].sent.at(-1).event, "phx_join", "then joins again");

  sockets[0].drop();
  assert.equal(sockets.length, 1);
  timers.pass(1000);
  assert.equal(sockets.length, 2, "tried again after a second");
  sockets[1].drop();
  timers.pass(1000);
  assert.equal(sockets.length, 2, "the second wait is longer");
  timers.pass(1000);
  assert.equal(sockets.length, 3);
  sockets[2].open();
  assert.equal(sockets[2].sent.at(-1).event, "phx_join", "the wanted channel joins on the new socket");
});

test("live: an unanswered heartbeat means a dead connection, and the socket is replaced", () => {
  const { backend, sockets, timers } = fresh();
  backend.channel("notes").join();
  sockets[0].open();
  timers.pass(HEARTBEAT * 1000);
  const beat = sockets[0].sent.at(-1);
  assert.equal(beat.topic, "phoenix");
  assert.equal(beat.event, "heartbeat");
  sockets[0].say({ topic: "phoenix", event: "phx_reply", ref: beat.ref, payload: { status: "ok" } });
  timers.pass(HEARTBEAT * 1000);
  assert.equal(sockets[0].closed, false, "an answered heartbeat keeps the socket");
  timers.pass(HEARTBEAT * 1000);
  assert.equal(sockets[0].closed, true, "an unanswered one closes it");
  timers.pass(1000);
  assert.equal(sockets.length, 2, "and a new one is opened");
});

test("live: leaving the last channel closes the socket and stops trying", () => {
  const { backend, sockets, timers } = fresh();
  const room = backend.channel("notes").join();
  sockets[0].open();
  room.leave();
  assert.equal(sockets[0].closed, true);
  assert.notEqual(backend.channel("notes"), room, "a left channel is let go");
  sockets[0].drop();
  timers.pass(60000);
  assert.equal(sockets.length, 1, "no reconnecting once nothing is wanted");
});
