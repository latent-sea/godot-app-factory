// Shivonne Dubarry's page walked as a visitor would: open it with ?probe.

import { Walk } from "./gd_chime/gd_chime.js";
import { AREAS, QUESTIONS, SESSIONS } from "./content.js";

const settle = async (walk, ms = 100) => { await new Promise((resolve) => setTimeout(resolve, ms)); await walk.frames(3); };

export class Probe extends Walk {
  async run() {
    await this.begin();
    const root = this.root();
    this.claim("it opens on the home page", this.top() === "home");
    this.claim("the masthead names her", this.shows("Shivonne Dubarry"));
    this.claim("nothing of the blog is left", !this.showsPart("Simple Ceremonies") && !root.querySelector('a[href*="tiktok"], a[href*="instagram"], a[href*="youtube"]'));
    const nav = [...root.querySelectorAll(".Nav a.NavLink")].map((link) => link.getAttribute("href"));
    this.claim("the header links to About, How I work and Fees on the page", ["#about", "#how", "#fees"].every((href) => nav.includes(href)));
    this.claim("every section is there to link to", ["areas", "about", "how", "fees", "questions"].every((id) => !!document.getElementById(id)));
    this.claim("who she works with: every area", AREAS.every((area) => this.shows(area.name)));
    this.claim("how she works, in three steps", root.querySelectorAll(".Step").length === 3);
    this.claim("every session has its fee", SESSIONS.every((session) => this.shows(session.name)) && root.querySelectorAll(".Fee").length === SESSIONS.length);
    this.claim("the footer says it is not an emergency service", this.shows("Not an emergency service"));

    const [question, answer] = QUESTIONS[0];
    this.claim("a question's answer starts closed", this.shows(question) && !this.shows(answer));
    await this.pressWords(question);
    this.claim("pressed, it opens", this.shows(answer));
    await this.pressWords(question);
    this.claim("pressed again, it closes", !this.shows(answer));

    await this.press("books_a_session");
    this.claim("Book a session opens booking", this.top() === "book" && this.shows("Choose a session"));
    this.claim("and the address says so", location.hash === "#book");
    this.claim("in four steps", root.querySelectorAll(".Stepper .StepMark").length === 4);
    this.claim("there is no step before the first", !this.pressable("steps_back"));
    this.claim("a session must be chosen first", this.pressable("continues")?.getAttribute("aria-disabled") === "true" && this.shows("Choose a session to continue"));

    await this.pressWords(SESSIONS[1].name);
    this.claim("a session is chosen", root.querySelector(".SessionChoice.chime-current")?.textContent.includes(SESSIONS[1].name));
    this.claim("and shows in the booking so far", root.querySelector(".Summary.Aside")?.textContent.includes(SESSIONS[1].name));
    await this.press("continues");
    this.claim("then a day and a time", this.shows("Choose a day and a time") && root.querySelectorAll(".DayChoice").length === 14);
    this.claim("weekends have no times", [...root.querySelectorAll(".DayChoice")].some((day) => day.getAttribute("aria-disabled") === "true"));
    this.claim("a time must be chosen to go on", this.shows("Choose a day and a time to continue"));
    const open = [...root.querySelectorAll(".DayChoice")].find((day) => day.getAttribute("aria-disabled") === "false");
    open.click();
    await this.frames(3);
    const times = [...root.querySelectorAll(".TimeChoice")].filter((time) => this.visible(time));
    this.claim("a day shows its times", times.length > 0 && this.showsPart("Times on "));
    times[0].click();
    await this.frames(3);
    this.claim("a time is chosen", !!root.querySelector(".TimeChoice.chime-current"));
    this.claim("and the booking so far says when", !root.querySelector(".Summary.Aside")?.textContent.includes("Not chosen yet"));

    await this.press("steps_back");
    this.claim("Back goes to the step before, keeping the choice", this.shows("Choose a session") && !!root.querySelector(".SessionChoice.chime-current"));
    await this.press("continues");
    this.claim("and the day and time are kept", !!root.querySelector(".TimeChoice.chime-current"));
    await this.press("continues");

    this.claim("then their details", this.shows("Your details") && this.shows("Add your name to continue"));
    this.claim("asking for nothing about their health", this.showsPart("Please don't include anything about your health"));
    const [name, email, phone] = this.fields();
    await this.typeInto(name, "A Visitor");
    await this.frames(3);
    this.claim("then an email address", this.shows("Add an email address to continue"));
    await this.typeInto(email, "visitor@example.com");
    await this.frames(3);
    this.claim("the phone is optional", !!phone && this.pressable("continues")?.getAttribute("aria-disabled") === "false");
    await this.pressWords("In person");
    this.claim("they choose how to meet", root.querySelector(".ModeChoice.chime-current")?.textContent === "In person");
    await this.press("continues");

    this.claim("then a check of it all", this.shows("Check and confirm") && root.querySelector(".Summary.Check")?.textContent.includes("A Visitor"));
    this.claim("with no phone row when none was given", !root.querySelector(".Summary.Check")?.textContent.includes("Phone"));
    await this.press("requests_the_booking");
    this.claim("the request says plainly that booking isn't connected", this.shows("Booking isn't connected yet"));
    this.claim("and leaves only Start again to press", !this.pressable("requests_the_booking") && !this.pressable("steps_back"));
    await this.press("starts_over");
    this.claim("starting again clears it all", this.shows("Choose a session") && !root.querySelector(".SessionChoice.chime-current"));

    location.hash = "#fees";
    await settle(this);
    this.claim("a section's link from booking goes back to the page", this.top() === "home" && location.hash === "#fees");
    location.hash = "#book";
    await settle(this);
    this.claim("the booking address opens booking", this.top() === "book");
    await this.press("goes_home");
    this.claim("and leaving it gives the page its own address back", this.top() === "home" && location.hash === "");
    this.finish();
  }

  /** Press the visible button whose words begin so, as a visitor would. */
  async pressWords(words) {
    const button = [...this.root().querySelectorAll("button")].find((part) => this.visible(part) && part.textContent.startsWith(words));
    this.claim(`there is a button saying ${words}`, !!button);
    button?.click();
    await this.frames(3);
  }
}
