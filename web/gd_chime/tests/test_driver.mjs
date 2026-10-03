// The driver: moves between places, refused with a reason or carried out,
// places shown and hidden, NAVIGATED rung, history walked back.

import assert from "node:assert/strict";
import { test } from "node:test";
import { Chimes } from "../chimes.js";
import { Commands } from "../commands.js";
import { Driver } from "../driver.js";
import { Place } from "../place.js";

const element = () => ({ hidden: true, inert: false, ownerDocument: { activeElement: null }, querySelector: () => null });

function stall() {
  const chimes = new Chimes();
  const driver = new Driver(chimes);
  const door = new Commands(chimes, driver);
  const app = new Place("stall", "app", element());
  const counting = new Place("counting", "screen", element());
  const crate = new Place("crate", "screen", element());
  const confirm = new Place("confirm 1", "pop_up", element());
  counting.parent = crate.parent = app;
  app.children = [counting, crate];
  for (const place of [app, counting, crate, confirm]) driver.addPlace(place);
  counting.performs.set("opens_a_crate", "crate");
  crate.performs.set("goes_back", Driver.BACK);
  return { chimes, driver, door, app, counting, crate, confirm };
}

test("going to the app lands on its first screen, shown, its siblings hidden", () => {
  const { driver, door, counting, crate } = stall();
  assert.equal(door.dispatch("global", Driver.GO, { place: "stall" }), null);
  assert.deepEqual(driver.getTop(), ["stall", "counting"]);
  assert.equal(counting.element.hidden, false);
  assert.equal(crate.element.hidden, true);
});

test("a press goes where its place declares, carrying its parameter, and back walks the history", () => {
  const { driver, door, crate } = stall();
  door.dispatch("global", Driver.GO, { place: "stall" });
  let filled = null;
  crate.onFill = () => { filled = crate.parameter; };
  assert.equal(door.dispatch("counting", "opens_a_crate", { parameter: 7 }), null);
  assert.deepEqual(driver.getTop(), ["stall", "crate"]);
  assert.equal(driver.getParameter("crate"), 7);
  assert.equal(filled, 7);
  assert.equal(String(door.refusal("counting", "opens_a_crate", { parameter: 7 })), "Already at crate");
  assert.equal(door.dispatch("crate", "goes_back", {}), null);
  assert.deepEqual(driver.getTop(), ["stall", "counting"]);
  assert.equal(driver.getParameter("crate"), null);
  assert.equal(String(door.dispatch("global", Driver.GOES_BACK, {})), "There is nothing to go back to");
});

test("a pop-up is raised over the app, which goes inert, and back lowers it", () => {
  const { driver, door, app } = stall();
  door.dispatch("global", Driver.GO, { place: "stall" });
  door.dispatch("global", Driver.GO, { place: "confirm 1", parameter: "crate 3" });
  assert.deepEqual(driver.getTop(), ["confirm 1"]);
  assert.equal(driver.getParameter("confirm 1"), "crate 3");
  assert.equal(app.element.inert, true);
  door.dispatch("global", Driver.GOES_BACK, {});
  assert.deepEqual(driver.getTop(), ["stall", "counting"]);
  assert.equal(app.element.inert, false);
});

test("going to no place is refused, and every move rings NAVIGATED", () => {
  const { chimes, driver, door } = stall();
  let rang = 0;
  chimes.listen({ region: "global", heard: () => rang++ }, "global", Driver.NAVIGATED);
  assert.equal(String(driver.wouldMove("nowhere", null)), "nowhere is no place to go to");
  door.dispatch("global", Driver.GO, { place: "stall" });
  door.dispatch("counting", "opens_a_crate", {});
  assert.equal(rang, 2);
});
