// The framework's own page: a market stall that counts crates, names them,
// opens one, asks before clearing them and speaks French - every primitive
// the builder has, in one app, walked by stall_probe.js in a headless
// browser (tooling/check_site.py). Not shipped: it stays in tests/.

import { ChimeApp, Controller, Language, Phrase, Pressables, Themes } from "../../gd_chime.js";

const COUNTING = "counting";
const POSTER = "data:image/svg+xml," + encodeURIComponent('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 9"><rect width="16" height="9" fill="#8a5a2b"/><rect x="5" y="2" width="6" height="5" fill="#c8915a"/></svg>');
const CRATE = "crate";
export const COUNTS = "counts_a_crate";
export const NAMES = "names_a_crate";
export const OPENS = "opens_a_crate";
export const CLEARS = "clears_the_stall";
export const ASKS_TO_CLEAR = "asks_to_clear";
export const BACKS = "goes_back";
export const SPEAKS_FRENCH = "speaks_french";
export const SPEAKS_ENGLISH = "speaks_english";

/** The stall's crates: how many, and their names; ten is all it holds. */
export class Crates extends Controller {
  constructor(chimes) {
    super(chimes);
    this.counted = this.value(0);
    this.names = this.value([]);
  }

  answers() { return [COUNTS, NAMES, CLEARS]; }

  would(action, payload) {
    if (action === COUNTS && this.counted.read() >= 3) return Phrase.of("Three crates is all the stall holds");
    if (action === CLEARS && this.counted.read() === 0 && this.names.read().length === 0) return Phrase.of("The stall is already empty");
    return null;
  }

  told(action, payload) {
    if (action === COUNTS) this.counted.update((n) => n + 1);
    if (action === NAMES) {
      const name = payload.line.trim();
      if (!name) return Phrase.of("A crate needs a name");
      if (this.names._held.includes(name)) return Phrase.with("There is a crate called %s already", [name]);
      this.names.setValue([...this.names._held, name]);
    }
    if (action === CLEARS) { this.counted.setValue(0); this.names.setValue([]); }
    return null;
  }
}

export class Stall extends ChimeApp {
  sources() {
    return { fr: { "Count a crate": "Compter une caisse", "Three crates is all the stall holds": "Trois caisses, c'est tout ce que tient l'étal" } };
  }

  declare(register) {
    register.declareAll({
      [COUNTS]: ["Count a crate", { key: "c", ctrl: false, shift: false, alt: false }],
      [NAMES]: ["Name a crate"],
      [OPENS]: ["Open"],
      [ASKS_TO_CLEAR]: ["Clear the stall"],
      [CLEARS]: ["Clear it"],
      [BACKS]: ["Back"],
      [SPEAKS_FRENCH]: ["Français"],
      [SPEAKS_ENGLISH]: ["English"],
      [Language.CHANGES_LANGUAGE]: ["Language"],
    });
  }

  describe() {
    const ui = this.ui;
    const crates = this.model(new Crates(this.chimes));
    const shown = crates.counted.map((n) => Phrase.counted("%d crate counted", "%d crates counted", n, "No crates counted"));
    const view = ui.local("list");
    const confirm = ui.popUp("confirm", () => ui.column([
      ui.text(Phrase.of("Clear every crate?"), Themes.WORDS),
      ui.row([ui.button(CLEARS, { goes_to: COUNTING }), ui.button(Ui.CLOSES)]),
    ]));
    const counting = ui.screen(COUNTING, [
      ui.text(Phrase.of("The stall"), Themes.TITLE),
      ui.text(shown, Themes.WORDS),
      ui.row([ui.button(COUNTS), ui.button(ASKS_TO_CLEAR, { opens: confirm })]),
      ui.when(crates.counted, ui.text(Phrase.of("The stall has crates"), "Quiet")),
      ui.field(NAMES, "", { placeholder: Phrase.of("Name a crate") }),
      ui.row([ui.pressLocal(view, "list", [ui.text(Phrase.of("As a list"))]), ui.pressLocal(view, "row", [ui.text(Phrase.of("In a row"))])]),
      ui.when(view.map((v) => v === "list"),
        ui.each(crates.names, (name) => ui.row([ui.text(name), ui.link(OPENS, name, Phrase.of("Open")).goesTo(CRATE)]), (name) => name),
        ui.eachAcross(crates.names, (name) => ui.text(name), (name) => name)),
      ui.row([
        ui.pressable(Language.CHANGES_LANGUAGE, { value: "fr" }, [ui.text(ui.words(SPEAKS_FRENCH))], Pressables.CHOICE),
        ui.pressable(Language.CHANGES_LANGUAGE, { value: "en" }, [ui.text(ui.words(SPEAKS_ENGLISH))], Pressables.CHOICE),
      ]),
    ]);
    const crate = ui.screen(CRATE, [
      ui.text(ui.parameter(CRATE).map((name) => Phrase.with("The crate called %s", [name ?? ""])), Themes.WORDS),
      ui.image(POSTER, "", Phrase.of("A wooden crate")),
      ui.embed("embedded.html", { title: Phrase.of("A crate in motion"), poster: POSTER }),
      ui.button(BACKS, { goes_to: Driver.BACK }),
    ]);
    return ui.app("stall", [ui.stack([counting, crate])]);
  }

  probe() { return import("./stall_probe.js").then((made) => new made.StallProbe(this)); }
}

import { Driver, Ui } from "../../gd_chime.js";

ChimeApp.start(Stall, document.getElementById("app"));
