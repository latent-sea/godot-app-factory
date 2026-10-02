// Phrases, the register and the language: what is said, and in which words.

import assert from "node:assert/strict";
import { test } from "node:test";
import { Actions } from "../actions.js";
import { Chimes } from "../chimes.js";
import { Language } from "../language.js";
import { Phrase } from "../phrase.js";

test("a phrase is its English, with its data put in", () => {
  assert.equal(String(Phrase.of("Save the day")), "Save the day");
  assert.equal(String(Phrase.with("Expecting %s, got %d", ["crates", 3])), "Expecting crates, got 3");
  assert.equal(String(Phrase.with("Now %s", [Phrase.within("Recovering")])), "Now recovering");
});

test("a count says its form, and none has words of its own", () => {
  const counted = (n) => String(Phrase.counted("%d crate", "%d crates", n, "No crates"));
  assert.equal(counted(0), "No crates");
  assert.equal(counted(1), "1 crate");
  assert.equal(counted(2), "2 crates");
});

test("data is shown as it is, a phrase in the language on", () => {
  const chimes = new Chimes();
  const language = new Language(chimes);
  Language.read({ fr: { "Save": "Enregistrer", "%d crate": "%d caisse", "%d crates": "%d caisses" } });
  assert.equal(Language.said("Save"), "Save", "a string is data, never a key");
  assert.equal(language.would("changes_language", { value: "xx" }).toString(), "There are no words in xx");
  language.told("changes_language", { value: "fr" });
  assert.equal(Language.said(Phrase.of("Save")), "Enregistrer");
  assert.equal(Language.said(Phrase.counted("%d crate", "%d crates", 1)), "1 caisse");
  assert.equal(Language.said(Phrase.counted("%d crate", "%d crates", 0)), "0 caisse", "French says 0 as it says 1");
  assert.equal(Language.said(Phrase.of("Not in the catalogue")), "Not in the catalogue");
  language.told("changes_language", { value: "en" });
  language.dispose();
});

test("the register keeps an action's words and keys, refusing a second declaration and empty words", () => {
  const register = new Actions();
  register.declareAll({ saves: ["Save", Actions.keys("s", { ctrl: true })] });
  assert.equal(register.getWords("saves"), "Save");
  assert.equal(register.actionOf({ key: "S", ctrlKey: true, metaKey: false, shiftKey: false, altKey: false }), "saves");
  assert.equal(register.actionOf({ key: "s", ctrlKey: false, metaKey: false, shiftKey: false, altKey: false }), "");
  const said = [];
  const was = console.error;
  console.error = (m) => said.push(m);
  register.declareAll({ saves: ["Keep"], quiet: [""] });
  console.error = was;
  assert.deepEqual(said, ['saves is already declared, as "Save"', "quiet needs the words that say what it does"]);
  assert.equal(register.getWords("saves"), "Save");
});
