// The stall walked as a person would, through every primitive it uses.

import { Driver, Ui, Walk } from "../../gd_chime.js";
import { ASKS_TO_CLEAR, CLEARS, COUNTS, NAMES, OPENS, BACKS } from "./stall.js";

export class StallProbe extends Walk {
  async run() {
    await this.begin();
    this.claim("it opens on the counting screen", this.top() === "counting");
    this.claim("a count of none has words of its own", this.shows("No crates counted"));
    this.claim("a when shows nothing while it does not hold", !this.shows("The stall has crates"));

    await this.press(COUNTS);
    this.claim("a press counts a crate", this.shows("1 crate counted"));
    this.claim("a when shows its side once it holds", this.shows("The stall has crates"));
    await this.press(COUNTS);
    await this.press(COUNTS);
    this.claim("three crates are counted", this.shows("3 crates counted"));
    const counts = this.pressable(COUNTS);
    this.claim("a full stall's button is inert", counts?.getAttribute("aria-disabled") === "true");
    this.claim("and says why on its face", this.shows("Three crates is all the stall holds"));

    const field = this.fields()[0];
    this.claim("there is a field to name a crate in", !!field);
    await this.typeInto(field, "Apples");
    await this.enter(field);
    await this.typeInto(field, "Pears");
    await this.enter(field);
    this.claim("named crates are listed", this.shows("Apples") && this.shows("Pears"));
    this.claim("a named field is cleared once taken", field.value === "");
    await this.typeInto(field, "Apples");
    await this.enter(field);
    this.claim("a name taken is refused, and says why", this.shows("There is a crate called Apples already"));
    this.claim("the refused line stays to be mended", field.value === "Apples");

    const inARow = [...this.root().querySelectorAll("button")].find((b) => b.textContent === "In a row");
    inARow.click();
    await this.frames(3);
    this.claim("a local turns the list into a row", !this.pressable(OPENS) && this.shows("Apples"));
    [...this.root().querySelectorAll("button")].find((b) => b.textContent === "As a list").click();
    await this.frames(3);

    await this.press(OPENS);
    this.claim("a link goes to the crate's screen", this.top() === "crate");
    this.claim("carrying the crate it names", this.shows("The crate called Apples"));
    this.claim("the counting screen is hidden", !this.shows("3 crates counted"));
    await this.press(BACKS);
    this.claim("back returns to counting", this.top() === "counting" && this.shows("3 crates counted"));

    await this.press(ASKS_TO_CLEAR);
    this.claim("a pop-up is raised over the app", this.top() === "confirm 1" && this.shows("Clear every crate?"));
    this.claim("the app beneath is inert", this.app.driver.app.element.inert === true);
    this.claim("the pop-up's Close can be pressed, and says no reason", this.pressable(Ui.CLOSES)?.getAttribute("aria-disabled") === "false" && !this.shows("There is nothing to go back to"));
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
    await this.frames(3);
    this.claim("Escape lowers the pop-up", this.top() === "counting" && !this.shows("Clear every crate?"));
    this.claim("nothing was cleared", this.shows("3 crates counted"));

    await this.press(ASKS_TO_CLEAR);
    await this.press(CLEARS);
    this.claim("clearing goes back to counting", this.top() === "counting");
    this.claim("and the stall is empty", this.shows("No crates counted") && !this.shows("Apples"));
    await this.press(ASKS_TO_CLEAR);
    this.claim("clearing an empty stall is inert", this.pressable(CLEARS)?.getAttribute("aria-disabled") === "true");
    this.claim("and says why on its face", this.shows("The stall is already empty"));
    await this.press(Ui.CLOSES);
    this.claim("the pop-up's own Close lowers it", this.top() === "counting");

    document.activeElement?.blur?.();
    document.dispatchEvent(new KeyboardEvent("keydown", { key: "c", bubbles: true }));
    await this.frames(3);
    this.claim("a key the app declares presses its action", this.shows("1 crate counted"));

    const french = [...this.root().querySelectorAll("button")].find((b) => b.textContent === "Français");
    french.click();
    await this.frames(3);
    this.claim("a change of language reaches the words where they stand", this.shows("Compter une caisse"));
    [...this.root().querySelectorAll("button")].find((b) => b.textContent === "English").click();
    await this.frames(3);
    this.claim("and back", this.shows("Count a crate"));

    this.claim("the driver's own commands are no button's", !this.pressable(Driver.GO) && !!Ui.CLOSES);
    this.finish();
  }

  /** Enter pressed in a field, as the keyboard would. */
  async enter(field) {
    field.dispatchEvent(new KeyboardEvent("keydown", { key: "Enter", bubbles: true }));
    await this.frames(3);
  }
}
