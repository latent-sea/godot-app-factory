// Hello walked as a person would: open the page with ?probe. Add a claim
// for everything the site does; Walk has the presses and the reading of the
// screen. tooling/check_site.py runs it in a headless browser.

import { Walk } from "./gd_chime/gd_chime.js";

export class Probe extends Walk {
  async run() {
    await this.begin();
    this.claim("the home screen is open", this.top() === "home");
    this.claim("the title shows", this.shows("Hello"));
    this.claim("it says hello", this.shows("Hello, world."));
    this.claim("no wave is counted yet", !this.showsPart("You waved"));
    await this.press("waves");
    this.claim("one wave is counted", this.shows("You waved 1 time"));
    await this.press("waves");
    this.claim("two waves are counted", this.shows("You waved 2 times"));
    this.finish();
  }
}
