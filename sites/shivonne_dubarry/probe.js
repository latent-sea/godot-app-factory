// Shivonne Dubarry's page walked as a visitor would: open it with ?probe.
// Booking goes to a stand-in desk, which keeps nothing: weekdays 9 to 5 for
// four weeks from tomorrow, and the platform's answers when a time has gone
// meanwhile or can't be reached.

import { Walk } from "./gd_chime/gd_chime.js";
import { AREAS, QUESTIONS, SESSIONS } from "./content.js";

/** The desk as the platform answers, kept in memory. */
class StandInDesk {
  constructor() {
    this.requests = [];
    this.goneNext = false;   // the next request finds its time taken meanwhile
    this.downNext = false;   // the next look for times can't reach the platform
    const now = new Date();
    this.times = [];
    for (let ahead = 1; ahead < 28; ahead++) {
      const date = new Date(now.getFullYear(), now.getMonth(), now.getDate() + ahead);
      if (date.getDay() === 0 || date.getDay() === 6) continue;
      for (let hour = 9; hour < 17; hour++) {
        const at = new Date(date.getFullYear(), date.getMonth(), date.getDate(), hour);
        this.times.push({ at, ends: new Date(at.getTime() + 3600000) });
      }
    }
  }

  async openings() {
    if (this.downNext) { this.downNext = false; return { ok: false, times: [], error: "The booking service can't be reached. Please check your connection and try again." }; }
    const held = new Set(this.requests.map((request) => request.at.getTime()));
    return { ok: true, times: this.times.filter((time) => !held.has(time.at.getTime())), error: "" };
  }

  async request(request) {
    if (this.goneNext) {
      this.goneNext = false;
      this.times = this.times.filter((time) => time.at.getTime() !== request.at.getTime());
      return { ok: false, taken: true, error: "That time has just been taken. Please choose another." };
    }
    this.requests.push(request);
    return { ok: true, taken: false, error: "" };
  }
}

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

    const desk = new StandInDesk();
    desk.downNext = true;
    this.app.booking.desk = desk;
    this.app.booking.load();
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
    this.claim("then a day and a time, but her times couldn't be found", this.shows("Choose a day and a time") && this.showsPart("can't be reached"));
    await this.press("reloads_the_times");
    await settle(this);
    this.claim("trying again finds them: four weeks of days", root.querySelectorAll(".DayChoice").length === 28 && !this.showsPart("can't be reached"));
    this.claim("today and weekends have no times", [...root.querySelectorAll(".DayChoice")].some((day) => day.getAttribute("aria-disabled") === "true"));
    this.claim("a time must be chosen to go on", this.shows("Choose a day and a time to continue"));
    this.claim("today has none (a day's notice)", root.querySelector(".DayChoice")?.getAttribute("aria-disabled") === "true");
    const open = [...root.querySelectorAll(".DayChoice")].find((day) => day.getAttribute("aria-disabled") === "false");
    open.click();
    await this.frames(3);
    const times = [...root.querySelectorAll(".TimeChoice")].filter((time) => this.visible(time));
    this.claim("a day shows its times: eight, nine to five", times.length === 8 && this.showsPart("Times on "));
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
    this.claim("sessions are online only: nothing asks how to meet", !this.showsPart("In person") && !root.querySelector(".ModeChoice"));
    await this.press("continues");

    this.claim("then a check of it all", this.shows("Check and confirm") && root.querySelector(".Summary.Check")?.textContent.includes("A Visitor"));
    this.claim("with no phone row when none was given", !root.querySelector(".Summary.Check")?.textContent.includes("Phone"));
    this.claim("and says it's online", root.querySelector(".Summary.Check")?.textContent.includes("Online"));

    // someone else took the time meanwhile
    const first = this.app.booking.chosenTime().at.getTime();
    desk.goneNext = true;
    await this.press("requests_the_booking");
    await settle(this);
    this.claim("a time taken meanwhile goes back to choosing, saying so", this.shows("Choose a day and a time") && this.showsPart("just been taken") && desk.requests.length === 0);
    this.claim("and isn't offered again", !this.app.booking.openings.read().some((time) => time.at.getTime() === first));
    [...root.querySelectorAll(".DayChoice")].find((day) => day.getAttribute("aria-disabled") === "false").click();
    await this.frames(3);
    [...root.querySelectorAll(".TimeChoice")].find((time) => this.visible(time)).click();
    await this.frames(3);
    await this.press("continues");
    await this.press("continues");
    this.claim("their details are kept", root.querySelector(".Summary.Check")?.textContent.includes("A Visitor"));

    await this.press("requests_the_booking");
    await settle(this);
    const sent = desk.requests[0];
    this.claim("the request is sent: the session, the time, a name and an email, and nothing else",
      desk.requests.length === 1 && sent.session === SESSIONS[1].id && sent.name === "A Visitor" && sent.email === "visitor@example.com" && sent.phone === ""
      && Object.keys(sent).sort().join() === "at,email,name,phone,session");
    this.claim("and the page says so, and that the time is held", this.shows("Your request is sent") && this.showsPart("time is held for you") && this.showsPart("visitor@example.com"));
    this.claim("leaving only the way home", !this.pressable("requests_the_booking") && !this.pressable("steps_back"));

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
