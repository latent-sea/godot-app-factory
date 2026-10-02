// {{title}}: a site of one screen, saying hello. Made by tooling/create_site.py.
//
// A site is a web app on gd-chime for the web (gd_chime/, installed by
// tooling/install_site.py). It declares its actions and their words
// (declare), says what its screens hold (describe), and keeps its facts in
// models - controllers made in describe and handed to the app (model) or the
// screen that reads them. See gd_chime/gd_chime.js for the vocabulary.

import { ChimeApp, Controller, Phrase, Themes } from "./gd_chime/gd_chime.js";

const HOME = "home";
const WAVES = "waves";

/** How many times the reader has waved back: the site's one fact. */
export class Waves extends Controller {
  constructor(chimes) {
    super(chimes);
    this.count = this.value(0);
  }

  answers() { return [WAVES]; }

  told(_action, _payload) {
    this.count.update((n) => n + 1);
    return null;
  }
}

export class Site extends ChimeApp {
  declare(register) {
    register.declareAll({ [WAVES]: ["Wave back"] });
  }

  describe() {
    const ui = this.ui;
    const waves = this.model(new Waves(this.chimes));
    const waved = waves.count.map((n) => (n === 0 ? null : Phrase.counted("You waved %d time", "You waved %d times", n)));
    return ui.app("{{name}}", [
      ui.screen(HOME, [
        ui.text(Phrase.of("{{title}}"), Themes.TITLE),
        ui.text(Phrase.of("Hello, world."), Themes.WORDS),
        ui.row([ui.button(WAVES), ui.text(waved, "Quiet").hidesEmpty()]),
      ]),
    ]);
  }

  // loaded only when the page is walked (?probe), so an export leaves it out
  probe() { return import("./probe.js").then((made) => new made.Probe(this)); }
}

ChimeApp.start(Site, document.getElementById("app"));
