// Shivonne Dubarry: a counsellor's home page with a booking widget, on
// gd-chime for the web. What it says is in content.js; this file is how it
// is laid out.
//
// Two screens. The home page scrolls through who she works with, About,
// How I work, Fees and Questions; the header's links are addresses on it
// (#about, #how, #fees), so they work from the booking screen too. Booking
// (#book) goes in four steps - a session, a day and a time, the visitor's
// details, a check - and stops where a booking would be sent: no calendar is
// connected yet (a placeholder, said so on the page), and the times are
// placeholders, shown in the visitor's own time zone.

import { ChimeApp, Chimes, Controller, Driver, Look, Phrase } from "./gd_chime/gd_chime.js";
import { ABOUT, AREAS, FEES_NOTE, QUESTIONS, SESSIONS, SITE, STEPS, openings } from "./content.js";

const HOME = "home";
const BOOK = "book";
const SECTIONS = ["areas", "about", "how", "fees", "questions"];

const GOES_HOME = "goes_home";
const BOOKS = "books_a_session";
const CHOOSES_SESSION = "chooses_a_session";
const CHOOSES_DAY = "chooses_a_day";
const CHOOSES_TIME = "chooses_a_time";
const CHOOSES_MODE = "chooses_how_to_meet";
const SETS_NAME = "sets_the_name";
const SETS_EMAIL = "sets_the_email";
const SETS_PHONE = "sets_the_phone";
const CONTINUES = "continues";
const STEPS_BACK = "steps_back";
const REQUESTS = "requests_the_booking";
const STARTS_OVER = "starts_over";

const BOOKING_STEPS = ["Session", "Day and time", "Your details", "Confirm"];
const MODES = [{ id: "online", name: "Online" }, { id: "in_person", name: "In person" }];

/**
 * The look by day and by night: one colour family. A clay-madder brand
 * colour and its scale, neutrals tinted from the same warmth. Built in OKLCH
 * so every step is even; every text colour clears 4.5:1 on its ground. The
 * rest of the system - type, space, the few components - is in shivonne.css.
 */
const LIGHT = { ground: "#fbf5ef", raised: "#f2e9e2", lit: "#e8ddd4", ink: "#221b15", ink_soft: "#6c6158", accent: "#913e23", accent_2: "#632916", warn: "#9a3b2b", edge: "#dcd2ca" };
const DARK = { ground: "#15110d", raised: "#1f1a15", lit: "#2a241e", ink: "#f1eae3", ink_soft: "#b2a9a1", accent: "#e2947c", accent_2: "#edb5a4", warn: "#e58c78", edge: "#352f29" };

const said = (date, options) => new Intl.DateTimeFormat(undefined, options).format(date);
const dayWords = (date) => said(date, { weekday: "long", day: "numeric", month: "long" });
const timeWords = (date) => said(date, { hour: "numeric", minute: "2-digit" });
const zone = () => Intl.DateTimeFormat().resolvedOptions().timeZone ?? "";
const EMAIL = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** A booking, step by step: what was chosen, who is asking, and whether it was sent on. */
class Booking extends Controller {
  constructor(chimes, days) {
    super(chimes);
    this.days = days;
    this.step = this.value(1);
    this.session = this.value(null);
    this.day = this.value(null);
    this.time = this.value(null);
    this.mode = this.value("online");
    this.name = this.value("");
    this.email = this.value("");
    this.phone = this.value("");
    this.sent = this.value(false);
  }

  answers() { return [CHOOSES_SESSION, CHOOSES_DAY, CHOOSES_TIME, CHOOSES_MODE, SETS_NAME, SETS_EMAIL, SETS_PHONE, CONTINUES, STEPS_BACK, REQUESTS, STARTS_OVER]; }

  would(action, payload) {
    if (action === CHOOSES_DAY && !this.days.find((day) => day.day === payload.day)?.times.length) return Phrase.of("No times this day");
    if (action === STEPS_BACK && this.step.read() === 1) return Phrase.of("This is the first step");
    if (action === CONTINUES) {
      const step = this.step.read();
      if (step === 1 && !this.session.read()) return Phrase.of("Choose a session to continue");
      if (step === 2 && !this.time.read()) return Phrase.of("Choose a day and a time to continue");
      if (step === 3 && !this.name.read().trim()) return Phrase.of("Add your name to continue");
      if (step === 3 && !EMAIL.test(this.email.read().trim())) return Phrase.of("Add an email address to continue");
      if (step >= BOOKING_STEPS.length) return Phrase.of("This is the last step");
    }
    if (action === REQUESTS && this.sent.read()) return Phrase.of("Already requested");
    return null;
  }

  told(action, payload) {
    if (action === CHOOSES_SESSION) this.session.setValue(payload.session);
    if (action === CHOOSES_DAY && this.day.read() !== payload.day) { this.day.setValue(payload.day); this.time.setValue(null); }
    if (action === CHOOSES_TIME) this.time.setValue(payload.time);
    if (action === CHOOSES_MODE) this.mode.setValue(payload.mode);
    if (action === SETS_NAME) this.name.setValue(payload.line);
    if (action === SETS_EMAIL) this.email.setValue(payload.line);
    if (action === SETS_PHONE) this.phone.setValue(payload.line);
    if (action === CONTINUES) this.step.update((step) => step + 1);
    if (action === STEPS_BACK) this.step.update((step) => step - 1);
    if (action === REQUESTS) this.sent.setValue(true);
    if (action === STARTS_OVER) {
      for (const [value, empty] of [[this.session, null], [this.day, null], [this.time, null], [this.mode, "online"], [this.name, ""], [this.email, ""], [this.phone, ""], [this.sent, false], [this.step, 1]]) value.setValue(empty);
    }
    return null;
  }

  /** The chosen time, found among the openings. */
  chosenTime() {
    const id = this.time.read();
    for (const day of this.days) for (const time of day.times) if (time.id === id) return time;
    return null;
  }
}

export class ShivonneDubarry extends ChimeApp {
  look() {
    const dark = typeof matchMedia === "function" && matchMedia("(prefers-color-scheme: dark)").matches;
    return Look.make(dark ? DARK : LIGHT);
  }

  declare(register) {
    register.declareAll({
      [GOES_HOME]: ["Home"],
      [BOOKS]: ["Book a session"],
      [CHOOSES_SESSION]: ["Choose a session"],
      [CHOOSES_DAY]: ["Choose a day"],
      [CHOOSES_TIME]: ["Choose a time"],
      [CHOOSES_MODE]: ["Choose how to meet"],
      [SETS_NAME]: ["Name"],
      [SETS_EMAIL]: ["Email"],
      [SETS_PHONE]: ["Phone"],
      [CONTINUES]: ["Continue"],
      [STEPS_BACK]: ["Back"],
      [REQUESTS]: ["Request this booking"],
      [STARTS_OVER]: ["Start again"],
    });
  }

  describe() {
    const ui = this.ui;
    this.booking = this.model(new Booking(this.chimes, openings()));

    const header = ui.column([
      ui.row([
        ui.column([
          ui.link(GOES_HOME, null, SITE.name, { style: "Masthead", words_style: "MastheadWords" }).goesTo(HOME),
          ui.text(SITE.disciplines.join(" · "), "Disciplines"),
        ], "Brand").grow(),
        ui.row([
          this.anchor("about", Phrase.of("About"), "NavLink"),
          this.anchor("how", Phrase.of("How I work"), "NavLink"),
          this.anchor("fees", Phrase.of("Fees"), "NavLink"),
          ui.button(BOOKS, { goes_to: BOOK, style: "PrimaryButton" }),
        ], "Nav"),
      ], "MastRow"),
      ui.divider("Rule"),
    ], "Header");

    const footer = ui.column([
      ui.row([
        ui.column([ui.text(SITE.name, "FooterName"), ui.text(SITE.credentials, "Footer").wraps()], "FooterColumn"),
        ui.column([
          ui.text(Phrase.of("Contact"), "FooterLabel"),
          ui.hyperlink(`mailto:${SITE.email}`, [ui.text(SITE.email)], "FooterLink", { stays: true }),
          ui.text(SITE.location, "Footer").wraps(),
        ], "FooterColumn"),
        ui.column([ui.text(Phrase.of("Registration"), "FooterLabel"), ui.text(SITE.registration, "Footer").wraps()], "FooterColumn"),
      ], "FooterGrid"),
      ui.column([ui.text(Phrase.of("Not an emergency service"), "FooterLabel"), ui.text(SITE.crisis, "Footer Crisis").wraps()], "CrisisNote"),
      ui.text(SITE.land, "Footer").wraps(),
      ui.text(Phrase.with("© %s %s", [new Date().getFullYear(), SITE.name]), "Footer"),
    ], "FooterBlock");

    return ui.app("shivonne_dubarry", [header, ui.stack([this.home(), this.book()]), footer]);
  }

  // loaded only when the page is walked (?probe), so an export leaves it out
  probe() { return import("./probe.js").then((made) => new made.Probe(this)); }

  /** The app mounted, then its address kept: #book opens booking, a section's address scrolls to it. */
  mount(element) {
    super.mount(element);
    this.started.then((stood) => { if (stood) this.keepAddress(); });
    return this;
  }

  keepAddress() {
    const go = (place) => this.commands.dispatch(Chimes.GLOBAL, Driver.GO, { place });
    const open = () => {
      const wanted = location.hash.slice(1);
      if (wanted === BOOK) { if (!this.driver.isActive(BOOK)) go(BOOK); return; }
      if (this.driver.isActive(BOOK)) go(HOME);
      // the section once the home page stands again: two frames, past the driver's own scroll
      if (SECTIONS.includes(wanted)) requestAnimationFrame(() => requestAnimationFrame(() => document.getElementById(wanted)?.scrollIntoView()));
    };
    open();
    addEventListener("hashchange", open);
    // the address follows the reader: #book while booking, so the phone's back button leaves it
    this.chimes.follow({ region: Chimes.GLOBAL }, "address", () => {
      const booking = this.driver.getTop().includes(BOOK);
      if (booking && location.hash !== `#${BOOK}`) history.pushState(null, "", `#${BOOK}`);
      else if (!booking && location.hash === `#${BOOK}`) history.replaceState(null, "", `${location.pathname}${location.search}`);
    });
  }

  // --- pieces ---

  /** A link to a section of the home page, by its address. */
  anchor(section, words, style) {
    return this.ui.hyperlink(`#${section}`, [this.ui.text(words, style === "NavLink" ? "NavWords" : "")], style, { stays: true });
  }

  section(id, kicker, title, content, style = "") {
    const ui = this.ui;
    return ui.column([
      ui.column([ui.text(kicker, "Kicker"), title ? ui.text(title, "SectionTitle").wraps() : null].filter(Boolean), "SectionHead"),
      ...content,
    ], `Section ${style}`).named(id);
  }

  bookButton() { return this.ui.button(BOOKS, { goes_to: BOOK, style: "PrimaryButton" }); }

  // --- the home page ---

  home() {
    const ui = this.ui;
    return ui.screen(HOME, [
      ui.surface("Hero", [
        ui.column([
          ui.text(SITE.headline, "Headline").wraps(),
          ui.text(SITE.intro, "Lead").wraps(),
          ui.row([this.bookButton(), this.anchor("how", Phrase.of("How I work"), "SecondaryButton")], "Actions"),
        ], "HeroText"),
        ui.image("images/hero.svg", "HeroImage", "Image placeholder"),
      ]),

      this.section("areas", Phrase.of("Who I work with"), Phrase.of("Areas placeholder: a line introducing the people she works with."), [
        ui.grid(AREAS.map((area) => ui.surface(`Area a-${area.id}`, [
          ui.text(area.name, "AreaName").wraps(),
          ui.text(area.text, "AreaText").wraps(),
        ])), [], "Areas"),
      ]),

      this.section("about", Phrase.of("About"), null, [
        ui.surface("AboutGrid", [
          ui.image("images/portrait.svg", "Portrait", "Portrait placeholder"),
          ui.column([
            ui.text(SITE.name, "SectionTitle").wraps(),
            ui.row(SITE.disciplines.map((discipline) => ui.text(discipline, "Discipline")), "Disciplines Row"),
            ...ABOUT.paragraphs.map((words) => ui.text(words, "Body").wraps()),
            ui.text(Phrase.of("Training and registration"), "Subhead"),
            ui.text(ABOUT.training, "Body").wraps(),
          ], "AboutText"),
        ]),
      ]),

      this.section("how", Phrase.of("How I work"), Phrase.of("How sessions work placeholder: a line in her words."), [
        ui.row(STEPS.map((step, index) => ui.column([
          ui.text(String(index + 1), "StepNumber"),
          ui.text(step.name, "StepName"),
          ui.text(step.text, "StepText").wraps(),
        ], "Step")), "Steps"),
      ]),

      this.section("fees", Phrase.of("Fees"), Phrase.of("Sessions and fees"), [
        ui.column(SESSIONS.map((session) => ui.row([
          ui.column([ui.text(session.name, "FeeName"), ui.text(session.text, "FeeText").wraps()], "FeeWords").grow(),
          ui.text(Phrase.with("%d min", [session.minutes]), "FeeLength"),
          ui.text(session.fee, "FeeAmount"),
        ], "Fee")), "Fees"),
        ui.text(FEES_NOTE, "SmallPrint").wraps(),
      ]),

      this.section("questions", Phrase.of("Questions"), Phrase.of("Common questions"), [
        ui.column(QUESTIONS.map(([question, answer]) => this.question(question, answer)), "Questions"),
      ]),

      ui.surface("Invitation", [
        ui.column([
          ui.text(Phrase.of("When you're ready"), "InvitationTitle").wraps(),
          ui.text(Phrase.of("Placeholder: a line inviting people to book, in her words."), "Lead").wraps(),
        ], "InvitationText"),
        this.bookButton(),
      ]),
    ]);
  }

  /** A question that opens to its answer, and closes again. */
  question(question, answer) {
    const ui = this.ui;
    const open = ui.local(false);
    return ui.column([
      ui.pressLocal(open, (held) => !held, [
        ui.text(question, "QuestionWords").wraps(),
        ui.text(open.map((held) => (held ? "−" : "+")), "QuestionMark"),
      ], "Question"),
      ui.when(open, ui.text(answer, "Answer").wraps()),
    ], "QuestionItem");
  }

  // --- booking ---

  book() {
    const ui = this.ui;
    const booking = this.booking;
    const at = (step) => booking.step.map((now) => now === step);
    const stepper = ui.row(BOOKING_STEPS.map((name, index) => {
      const words = Phrase.with("%d. %s", [index + 1, name]);
      return ui.when(at(index + 1), ui.text(words, "StepMark Now"),
        ui.when(booking.step.map((now) => now > index + 1), ui.text(words, "StepMark Done"), ui.text(words, "StepMark Ahead")));
    }), "Stepper");

    const choices = ui.column(SESSIONS.map((session) => ui.pressable(CHOOSES_SESSION, { session: session.id }, [
      ui.text(session.name, "ChoiceName"),
      ui.text(Phrase.with("%d min · %s", [session.minutes, session.fee]), "ChoiceDetail"),
      ui.text(session.text, "ChoiceDetail").wraps(),
    ], "Choice SessionChoice").currentWhile(booking.session.map((chosen) => chosen === session.id))), "Choices");

    const days = ui.grid(booking.days.map((day) => ui.pressable(CHOOSES_DAY, { day: day.day }, [
      ui.text(said(day.date, { weekday: "short" }), "DayName"),
      ui.text(said(day.date, { day: "numeric" }), "DayNumber"),
      ui.text(said(day.date, { month: "short" }), "DayMonth"),
    ], "Choice DayChoice").currentWhile(booking.day.map((chosen) => chosen === day.day))), [1, 1, 1, 1, 1, 1, 1], "Days");

    const times = booking.days.filter((day) => day.times.length).map((day) => ui.when(booking.day.map((chosen) => chosen === day.day), ui.column([
      ui.text(Phrase.with("Times on %s", [dayWords(day.date)]), "Subhead"),
      ui.row(day.times.map((time) => ui.pressable(CHOOSES_TIME, { time: time.id }, [ui.text(timeWords(time.at))], "Choice TimeChoice")
        .currentWhile(booking.time.map((chosen) => chosen === time.id))), "Times"),
    ], "DayTimes")));

    const details = ui.column([
      ui.field(SETS_NAME, "", { label: Phrase.of("Your name"), changes: SETS_NAME, shows: booking.name, autocomplete: "name" }),
      ui.field(SETS_EMAIL, "", { label: Phrase.of("Email address"), changes: SETS_EMAIL, shows: booking.email, kind: "email", autocomplete: "email" }),
      ui.field(SETS_PHONE, "", { label: Phrase.of("Phone (optional)"), changes: SETS_PHONE, shows: booking.phone, kind: "tel", autocomplete: "tel" }),
      ui.text(Phrase.of("How would you like to meet?"), "FieldLabel"),
      ui.row(MODES.map((mode) => ui.pressable(CHOOSES_MODE, { mode: mode.id }, [ui.text(mode.name)], "Choice ModeChoice")
        .currentWhile(booking.mode.map((chosen) => chosen === mode.id))), "Modes"),
      ui.text(Phrase.of("Please don't include anything about your health here. There will be time to talk about what brings you in."), "SmallPrint").wraps(),
    ], "Details");

    const summary = (style) => ui.column([
      this.summaryRow(Phrase.of("Session"), ui.bound(() => SESSIONS.find((session) => session.id === booking.session.read())?.name ?? Phrase.of("Not chosen yet"))),
      this.summaryRow(Phrase.of("When"), ui.bound(() => {
        const time = booking.chosenTime();
        return time ? `${dayWords(time.at)}, ${timeWords(time.at)}` : Phrase.of("Not chosen yet");
      })),
      this.summaryRow(Phrase.of("How"), booking.mode.map((id) => MODES.find((mode) => mode.id === id).name)),
      style === "Check" ? this.summaryRow(Phrase.of("Name"), booking.name) : null,
      style === "Check" ? this.summaryRow(Phrase.of("Email"), booking.email) : null,
      style === "Check" ? ui.when(booking.phone.map((phone) => phone.trim() !== ""), this.summaryRow(Phrase.of("Phone"), booking.phone)) : null,
    ].filter(Boolean), `Summary ${style}`);

    const check = ui.column([
      summary("Check"),
      ui.when(booking.sent, ui.surface("Notice", [
        ui.text(Phrase.of("Booking isn't connected yet"), "NoticeTitle"),
        ui.text(Phrase.of("This is where your request would be sent. Nothing was booked, and your details were not sent anywhere."), "NoticeWords").wraps(),
        ui.button(STARTS_OVER, { style: "SecondaryButton" }),
      ])),
    ], "CheckStep");

    return ui.screen(BOOK, [
      ui.column([
        ui.column([
          ui.text(Phrase.of("Booking"), "Kicker"),
          ui.text(Phrase.of("Book a session"), "PageTitle").wraps(),
          ui.text(Phrase.with("Times are shown in your time zone (%s). Placeholder times until her calendar is connected.", [zone()]), "SmallPrint").wraps(),
        ], "BookingHead"),
        stepper,
        ui.surface("BookingGrid", [
          ui.column([
            ui.when(at(1), ui.column([ui.text(Phrase.of("Choose a session"), "StepTitle"), choices], "StepBody")),
            ui.when(at(2), ui.column([ui.text(Phrase.of("Choose a day and a time"), "StepTitle"), days, ...times], "StepBody")),
            ui.when(at(3), ui.column([ui.text(Phrase.of("Your details"), "StepTitle"), details], "StepBody")),
            ui.when(at(4), ui.column([ui.text(Phrase.of("Check and confirm"), "StepTitle"), check], "StepBody")),
            // once sent, the notice's Start again is the only way on
            ui.when(booking.sent.map((sent) => !sent), ui.row([
              ui.pressable(STEPS_BACK, {}, [ui.text(Phrase.with("← %s", [ui.words(STEPS_BACK)]))], "SecondaryButton BackStep").absentWhenRefused(),
              ui.when(at(4), ui.button(REQUESTS, { style: "PrimaryButton" }), ui.button(CONTINUES, { style: "PrimaryButton" })),
            ], "StepActions")),
          ], "BookingMain"),
          // the booking so far, beside the steps until the last, which shows it all
          ui.when(booking.step.map((now) => now < BOOKING_STEPS.length), ui.column([ui.text(Phrase.of("Your booking"), "Kicker"), summary("Aside")], "BookingAside")),
        ]),
      ], "Booking"),
    ]);
  }

  summaryRow(label, value) {
    return this.ui.row([this.ui.text(label, "SummaryLabel"), this.ui.text(value, "SummaryValue").wraps()], "SummaryRow");
  }
}

ChimeApp.start(ShivonneDubarry, document.getElementById("app"));
