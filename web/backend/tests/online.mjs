// backend.js against a real platform, over the internet: the same walk as
// the Godot service's tests/online.gd. Not run by check_site (its name doesn't
// start with test_): run it by hand with the platform's address and
// publishable key:
//
//   BACKEND_URL=https://... BACKEND_KEY=sb_publishable_... node web/backend/tests/online.mjs
//
// The platform needs anonymous sign-in on, and a table each player sees only
// their own rows of, published live: the platform's own platform_check
// (platform/sql/checks.sql) unless BACKEND_TABLE names another. Prints PASS
// online.mjs, or every claim that did not hold.

import { Backend } from "../backend.js";

const url = process.env.BACKEND_URL ?? "";
const key = process.env.BACKEND_KEY ?? "";
const table = process.env.BACKEND_TABLE || "platform_check";
if (!url || !key) {
  console.log("set BACKEND_URL and BACKEND_KEY");
  process.exit(2);
}

const failed = [];
const claim = (held, what) => { console.log(`${held ? "ok  " : "FAIL"} ${what}`); if (!held) failed.push(what); };
const memory = () => { const kept = new Map(); return { get: (n) => kept.get(n) ?? null, set: (n, t) => kept.set(n, t), remove: (n) => kept.delete(n) }; };
const until = async (done, ms) => { const start = Date.now(); while (!done() && Date.now() - start < ms) await new Promise((r) => setTimeout(r, 50)); return done(); };

const phoneStore = memory();
const phone = new Backend(url, key, { storage: phoneStore });
const signed = await phone.signInAnonymously();
claim(signed.ok && phone.playerId() !== "", `a new player signs in ${signed.error}`);

// A second device of the same player listens live.
const tablet = new Backend(url, key, { storage: memory() });
await tablet.useSession(phone.session);
const live = tablet.channel("online-check");
const arrived = [];
live.on("changed", (change) => arrived.push([change, Date.now()]));
live.onChanges(table, "INSERT").join();
claim(await until(() => live.isJoined, 15000), "the second device joins a live channel");
await new Promise((r) => setTimeout(r, 2000));

const body = `online check ${Date.now()}`;
const sentAt = Date.now();
const saved = await phone.insert(table, { body });
claim(saved.ok && Array.isArray(saved.data) && saved.data[0]?.body === body, `a row is saved ${saved.error}`);
await until(() => arrived.length > 0, 10000);
claim(arrived[0]?.[0].record.body === body, "the other device receives it live");
if (arrived.length) console.log(`live update in ${arrived[0][1] - sentAt} ms`);

const mine = await phone.select(table, `body=eq.${encodeURIComponent(body)}`);
claim(mine.ok && mine.data?.length === 1, "and reads it back");

const refreshed = await phone.refresh();
claim(refreshed.ok && phone.isSignedIn(), `the session refreshes ${refreshed.error}`);
const nextVisit = new Backend(url, key, { storage: phoneStore });
claim((await nextVisit.restore()) && nextVisit.playerId() === phone.playerId(), "the next visit is still the same player");

const stranger = new Backend(url, key, { storage: memory() });
await stranger.signInAnonymously();
const theirs = await stranger.select(table, `body=eq.${encodeURIComponent(body)}`);
claim(theirs.ok && Array.isArray(theirs.data) && theirs.data.length === 0, "a stranger can't read it");

live.leave();
await phone.signOut();
await stranger.signOut();
claim(!phone.isSignedIn(), "signing out forgets the player");
for (const sentence of failed) console.log(`NOT TRUE: ${sentence}`);
if (!failed.length) console.log("PASS online.mjs");
process.exit(failed.length ? 1 : 0);
