// The floor's core, under Node's own test runner: reads, bells, chimes,
// values, the door. Ported from the claims of gd-chime's test_commands,
// test_chimes, test_values and test_bound.

import assert from "node:assert/strict";
import { test } from "node:test";
import { Bound } from "../bound.js";
import { Chimes } from "../chimes.js";
import { Commands } from "../commands.js";
import { Controller } from "../controller.js";
import { Frames } from "../frames.js";
import { Phrase } from "../phrase.js";
import { Reads } from "../reads.js";

const quietly = (work) => { const said = []; const was = console.error; console.error = (m) => said.push(String(m)); try { work(); } finally { console.error = was; } return said; };

class Crates extends Controller {
  constructor(chimes) { super(chimes); this.counted = this.value(0); }
  answers() { return ["counts_a_crate"]; }
  would() { return this.counted.read() >= 2 ? Phrase.of("Two crates is all the stall holds") : null; }
  told() { this.counted.update((n) => n + 1); return null; }
}

test("a read is noted in the innermost work alone, and nowhere outside work", () => {
  Reads.note("r", "outside");
  const outer = Reads.tracked(() => {
    Reads.note("r", "a");
    const inner = Reads.tracked(() => Reads.note("r", "b"));
    assert.deepEqual([...inner], ["r/b"]);
  });
  assert.deepEqual([...outer], ["r/a"]);
  assert.equal(Reads.depth(), 0);
});

test("work kept with what it read is worked out again only when that moves", () => {
  let ran = 0;
  const held = [];
  const work = () => { ran++; Reads.note("kept", "x"); return ran; };
  assert.equal(Reads.worked(held, work), 1);
  assert.equal(Reads.worked(held, work), 1);
  Reads.moved("kept", "x");
  assert.equal(Reads.worked(held, work), 2);
});

test("a value set rings its bell once, at the frame's end, however many sets", async () => {
  const chimes = new Chimes();
  const crates = new Crates(chimes);
  let ran = 0;
  chimes.follow({ region: "global" }, "drawn", () => { crates.counted.read(); ran++; });
  assert.equal(ran, 1);
  crates.counted.setValue(1);
  crates.counted.setValue(2);
  assert.equal(ran, 1, "nothing rings before the frame ends");
  await Frames.passed();
  assert.equal(ran, 2);
});

test("a follower is wired to exactly what it read, and moves when what it reads moves", async () => {
  const chimes = new Chimes();
  const a = new Crates(chimes);
  const b = new Crates(chimes);
  const which = new Crates(chimes);
  const reader = { region: "global" };
  chimes.follow(reader, "drawn", () => (which.counted.read() === 0 ? a : b).counted.read());
  assert.equal(chimes.followedBy(reader, "drawn").length, 2);
  which.counted.setValue(1);
  await Frames.passed();
  const followed = chimes.followedBy(reader, "drawn").map(([region]) => region);
  assert.ok(followed.includes(b._values.getAddress()));
  assert.ok(!followed.includes(a._values.getAddress()));
});

test("a mapped bound reads through its source, and a constant reads nothing", () => {
  const chimes = new Chimes();
  const crates = new Crates(chimes);
  const said = crates.counted.map((n) => `${n} crates`);
  const read = Reads.tracked(() => assert.equal(said.read(), "0 crates"));
  assert.equal(read.size, 1);
  assert.equal(Reads.tracked(() => Bound.constant(3).read()).size, 0);
});

test("the door tells the model, keeps the last command and rings COMMAND_RAN, refused or not", () => {
  const chimes = new Chimes();
  const door = new Commands(chimes);
  const crates = new Crates(chimes);
  door.stand("global", crates);
  let rang = 0;
  const watcher = { region: "global", heard: () => rang++ };
  chimes.listen(watcher, "global", Commands.COMMAND_RAN);
  assert.equal(door.dispatch("global", "counts_a_crate", { n: 1 }), null);
  assert.equal(door.dispatch("global", "counts_a_crate", {}), null);
  const refused = door.dispatch("global", "counts_a_crate", {});
  assert.equal(String(refused), "Two crates is all the stall holds");
  assert.equal(rang, 3);
  const last = door.getLast();
  assert.equal(String(last.answer), "Two crates is all the stall holds");
  last.payload.changed = true;
  assert.equal(door.getLast().payload.changed, undefined, "the last command is read back as a copy");
});

test("the region's handler is told before the global one, and dropping the region forgets it", () => {
  const chimes = new Chimes();
  const door = new Commands(chimes);
  const global = new Crates(chimes);
  const local = new Crates(chimes);
  door.stand("global", global);
  door.stand("stall", local);
  door.dispatch("stall", "counts_a_crate", {});
  assert.equal(local.counted._held, 1);
  assert.equal(global.counted._held, 0);
  door.dropRegion("stall");
  door.dispatch("stall", "counts_a_crate", {});
  assert.equal(global.counted._held, 1);
});

test("an action nothing handles is refused out loud, and a second handler is refused", () => {
  const chimes = new Chimes();
  const door = new Commands(chimes);
  let answer;
  const said = quietly(() => { answer = door.dispatch("global", "flies", {}); });
  assert.equal(String(answer), "Nothing handles flies in global");
  assert.deepEqual(said, ["Nothing handles flies in global"]);
  door.stand("global", new Crates(chimes));
  assert.deepEqual(quietly(() => door.stand("global", new Crates(chimes))), ["counts_a_crate in global already has a handler"]);
});

test("a dispatch made while a bell sounds is refused, and the other listeners still read the first command", () => {
  const chimes = new Chimes();
  const door = new Commands(chimes);
  door.stand("global", new Crates(chimes));
  const read = [];
  let nested;
  const first = { region: "global", heard: () => { quietly(() => { nested = door.dispatch("global", "counts_a_crate", {}); }); } };
  const second = { region: "global", heard: () => read.push(door.getLast().action) };
  chimes.listen(first, "global", Commands.COMMAND_RAN);
  chimes.listen(second, "global", Commands.COMMAND_RAN);
  door.dispatch("global", "counts_a_crate", { first: true });
  assert.equal(String(nested), "counts_a_crate was dispatched from inside heard(); defer it until the ring is over");
  assert.deepEqual(read, ["counts_a_crate"]);
  assert.equal(door.getLast().payload.first, true);
});

test("a disposed model stops hearing, its bell comes down, and the door forgets it", () => {
  const chimes = new Chimes();
  const door = new Commands(chimes);
  const crates = new Crates(chimes);
  door.stand("global", crates);
  const bells = chimes.belfry.count();
  crates.dispose();
  assert.equal(chimes.belfry.count(), bells - 1);
  assert.equal(door.handles("global", "counts_a_crate"), false);
});

test("listening twice to bells of one name is refused, and so is listening where nothing hangs", () => {
  const chimes = new Chimes();
  chimes.register("a", "rang");
  chimes.register("b", "rang");
  const listener = { region: "global", heard() {} };
  chimes.listen(listener, "a", "rang");
  assert.deepEqual(quietly(() => chimes.listen(listener, "b", "rang")), ["already listening to something called rang, in a; heard() gets the name alone, so a listener hearing both must be two listeners"]);
  assert.deepEqual(quietly(() => chimes.listen(listener, "c", "nothing")), ["nothing is hung at c/nothing to listen to"]);
});

test("dropping a region takes its bells and every wire into them", () => {
  const chimes = new Chimes();
  chimes.register("stall", "opened");
  const listener = { region: "global", heard() {} };
  chimes.listen(listener, "stall", "opened");
  assert.equal(chimes.count(), 1);
  chimes.dropRegion("stall");
  assert.equal(chimes.count(), 0);
  assert.equal(chimes.countListeners(), 0);
});
