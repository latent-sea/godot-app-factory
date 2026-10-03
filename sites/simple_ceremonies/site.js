// Simple Ceremonies: a blog of psychology, anthropology and sociology, on
// gd-chime for the web. Its content is a template (content.js); this file
// is how it is laid out.
//
// Screens: the writing (home), every article, About, and Join. A members'
// article shows its opening, then an invitation to join; Join takes a name,
// an email and a plan, and stops where payment would begin - payment is
// not connected (a placeholder, said so on the page). The footer's template
// preview shows the members' view, so every article can be seen as a member
// would see it.
//
// Every article has its own address - the page's, with #its-slug - so it
// can be shared and opened straight from a link. Her TikTok, Instagram and
// YouTube are in the header, on the home screen, on About, at the end of
// every article and in the footer; every article can be shared by the
// phone's share sheet, a copied link, or a link to post it elsewhere.

import { ChimeApp, Chimes, Controller, Driver, Look, Phrase, Ui } from "./gd_chime/gd_chime.js";
import { ARTICLES, GLOSSARY, SITE, THREADS, THREAD_INTROS, minutesToRead, threadNamed, written } from "./content.js";

const HOME = "home";
const ABOUT = "about";
const JOIN = "join";
const ALL = "all";

const GOES_HOME = "goes_home";
const GOES_ABOUT = "goes_about";
const GOES_JOIN = "goes_join";
const JOINS_TO_READ = "joins_to_read";
const BACKS = "goes_back";
const DEFINES = "shows_the_meaning";
const PREVIEWS = "previews_the_members_view";
const SETS_NAME = "sets_the_name";
const SETS_EMAIL = "sets_the_email";
const CHOOSES_PLAN = "chooses_a_plan";
const CONTINUES = "continues_to_payment";
const SHARES = "shares_with_the_share_sheet";
const COPIES_LINK = "copies_the_link";

const PLANS = [
  { id: "monthly", name: "Monthly", price: "Price placeholder, a month" },
  { id: "yearly", name: "Yearly", price: "Price placeholder, a year" },
];

/**
 * The look by day and by night: one colour family. A clay-madder brand
 * colour and its scale, neutrals tinted from the same warmth, and an ochre
 * kept for the one small sun. Built in OKLCH so every step is even; every
 * text colour clears 4.5:1 on its ground. The rest of the system - type,
 * space, the few components - is in ceremonies.css.
 */
const LIGHT = { ground: "#fbf5ef", raised: "#f2e9e2", lit: "#e8ddd4", ink: "#221b15", ink_soft: "#6c6158", accent: "#913e23", accent_2: "#632916", warn: "#9a3b2b", edge: "#dcd2ca" };
const DARK = { ground: "#15110d", raised: "#1f1a15", lit: "#2a241e", ink: "#f1eae3", ink_soft: "#b2a9a1", accent: "#e2947c", accent_2: "#edb5a4", warn: "#e58c78", edge: "#352f29" };

const screenOf = (article) => `article_${article.slug}`;
/** Where an article lives, to be shared: this page's address with the article's slug after #. */
const addressOf = (article) => (typeof location === "undefined" ? `#${article.slug}` : `${location.origin}${location.pathname}#${article.slug}`);
const readsOf = (article) => `reads_${article.slug}`;

/** Whether the reader is a member. Joining is not connected, so only the template preview changes it. */
class Membership extends Controller {
  constructor(chimes) { super(chimes); this.member = this.value(false); }
  answers() { return [PREVIEWS]; }
  told() { this.member.update((member) => !member); return null; }
}

/** The sign-up form: a name, an email, a plan, and whether it was sent on. */
class Signup extends Controller {
  constructor(chimes) {
    super(chimes);
    this.name = this.value("");
    this.email = this.value("");
    this.plan = this.value("yearly");
    this.sent = this.value(false);
  }

  answers() { return [SETS_NAME, SETS_EMAIL, CHOOSES_PLAN, CONTINUES]; }

  would(action) {
    if (action !== CONTINUES) return null;
    if (!this.name.read().trim()) return Phrase.of("Add your name to continue");
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(this.email.read().trim())) return Phrase.of("Add an email address to continue");
    return null;
  }

  told(action, payload) {
    if (action === SETS_NAME) this.name.setValue(payload.line);
    if (action === SETS_EMAIL) this.email.setValue(payload.line);
    if (action === CHOOSES_PLAN) this.plan.setValue(payload.plan);
    if (action === CONTINUES) this.sent.setValue(true);
    return null;
  }
}

/** Text copied by selecting it in a hidden field: what browsers without a clipboard to ask still do. */
function copyTheOldWay(text) {
  const field = document.createElement("textarea");
  field.value = text;
  field.setAttribute("readonly", "");
  field.style.cssText = "position:fixed;opacity:0;pointer-events:none";
  document.body.appendChild(field);
  field.select();
  let worked = false;
  try { worked = document.execCommand("copy"); } catch { worked = false; }
  field.remove();
  return worked;
}

/** Sharing an article: the phone's share sheet, and copying its link, with what came of the last copy. */
class Sharing extends Controller {
  constructor(chimes) { super(chimes); this.copied = this.value(null); }

  answers() { return [SHARES, COPIES_LINK]; }

  would(action) {
    if (action === SHARES && (typeof navigator === "undefined" || typeof navigator.share !== "function")) return Phrase.of("This browser has no share sheet");
    return null;
  }

  told(action, payload) {
    if (action === SHARES) {
      navigator.share({ title: payload.title, url: payload.url }).catch(() => {});
    } else if (action === COPIES_LINK) {
      const done = (worked) => this.copied.setValue({ slug: payload.slug, worked });
      // the clipboard, given a second to answer - some browsers never do - else the older way of copying
      const asked = navigator.clipboard ? navigator.clipboard.writeText(payload.url) : Promise.reject(new Error("no clipboard"));
      const late = new Promise((_, refuse) => setTimeout(() => refuse(new Error("no answer")), 1000));
      Promise.race([asked, late]).then(() => done(true), () => done(copyTheOldWay(payload.url)));
    }
    return null;
  }
}

export class SimpleCeremonies extends ChimeApp {
  look() {
    const dark = typeof matchMedia === "function" && matchMedia("(prefers-color-scheme: dark)").matches;
    return Look.make(dark ? DARK : LIGHT);
  }

  declare(register) {
    const table = {
      [GOES_HOME]: ["Writing"],
      [GOES_ABOUT]: ["About"],
      [GOES_JOIN]: ["Join"],
      [JOINS_TO_READ]: ["Become a member"],
      [BACKS]: ["Back"],
      [DEFINES]: ["Show the meaning"],
      [PREVIEWS]: ["Preview the members' view"],
      [SETS_NAME]: ["Name"],
      [SETS_EMAIL]: ["Email"],
      [CHOOSES_PLAN]: ["Choose a plan"],
      [CONTINUES]: ["Continue to payment"],
      [SHARES]: ["Share…"],
      [COPIES_LINK]: ["Copy link"],
    };
    for (const article of ARTICLES) table[readsOf(article)] = ["Read"];
    register.declareAll(table);
  }

  describe() {
    const ui = this.ui;
    this.membership = this.model(new Membership(this.chimes));
    this.signup = this.model(new Signup(this.chimes));
    this.sharing = this.model(new Sharing(this.chimes));
    this.meaning = ui.popUp("meaning", (which) => ui.column([
      ui.text(Phrase.of("Glossary"), "Kicker"),
      ui.text(which, "TermWord"),
      ui.text(which.map((term) => GLOSSARY[term] ?? ""), "TermMeaning").wraps(),
      ui.button(Ui.CLOSES, { style: "Quiet" }),
    ], "Meaning"));

    const header = ui.column([
      ui.row([
        ui.column([
          ui.link(GOES_HOME, null, SITE.name, { style: "Masthead", words_style: "MastheadWords" }).goesTo(HOME),
          ui.text(SITE.disciplines.join(" · "), "Disciplines"),
        ], "Brand").grow(),
        ui.row([
          this.navLink(GOES_HOME, HOME),
          this.navLink(GOES_ABOUT, ABOUT),
          this.follow("Icons"),
          ui.button(GOES_JOIN, { goes_to: JOIN, style: "JoinButton" }),
        ], "Nav"),
      ], "MastRow"),
      ui.divider("Horizon"),
    ], "Header");

    const footer = ui.column([
      ui.divider("Horizon"),
      ui.row([ui.text(Phrase.of("Follow her"), "FooterLabel"), this.follow("Icons")], "FooterFollow"),
      ui.text(Phrase.of("Land acknowledgement placeholder: her words, if she chooses to include one."), "Footer").wraps(),
      ui.text(Phrase.with("© %s %s", [new Date().getFullYear(), SITE.author]), "Footer"),
      ui.row([
        ui.text(Phrase.of("Template preview:"), "Footer"),
        ui.pressable(PREVIEWS, {}, [ui.text(this.membership.member.map((member) => Phrase.of(member ? "Show the reader's view" : "Show the members' view")), "PreviewWords")], "PreviewToggle"),
      ], "Preview"),
    ], "FooterBlock");

    const screens = [this.home(), this.about(), this.join(), ...ARTICLES.map((article) => this.article(article))];
    return ui.app("simple_ceremonies", [header, ui.stack(screens), footer]);
  }

  // loaded only when the page is walked (?probe), so an export leaves it out
  probe() { return import("./probe.js").then((made) => new made.Probe(this)); }

  /** The app mounted, then its address kept: an article opened from a link, and the address following the reader. */
  mount(element) {
    super.mount(element);
    this.started.then((stood) => { if (stood) this.keepAddress(); });
    return this;
  }

  keepAddress() {
    const open = () => {
      const article = ARTICLES.find((each) => `#${each.slug}` === location.hash);
      if (article && !this.driver.isActive(screenOf(article))) this.commands.dispatch(Chimes.GLOBAL, Driver.GO, { place: screenOf(article) });
    };
    open();
    addEventListener("hashchange", open);
    // the address follows the reader: an article's own while it is open, the page's otherwise
    this.chimes.follow({ region: Chimes.GLOBAL }, "address", () => {
      const top = this.driver.getTop();
      const article = ARTICLES.find((each) => screenOf(each) === top[top.length - 1]);
      const wanted = article ? `#${article.slug}` : "";
      if (location.hash !== wanted) history.replaceState(null, "", wanted || `${location.pathname}${location.search}`);
    });
  }

  // --- pieces ---

  /** Her TikTok, Instagram and YouTube: as icons, or as buttons with their handles. */
  follow(style) {
    const ui = this.ui;
    return ui.row(SITE.socials.map((social) => ui.hyperlink(social.url, style === "Icons"
      ? [ui.text(social.name, "SocialName")]
      : [ui.column([ui.text(social.name, "SocialName"), ui.text(social.handle, "SocialHandle")], "SocialWords")],
    `Social ${social.id}`, { label: Phrase.with("Follow on %s", [social.name]) })), `Follow ${style}`);
  }

  /** Every way to share an article: the share sheet, a copied link, and links to post it elsewhere. */
  shareBar(article) {
    const ui = this.ui;
    const url = addressOf(article);
    const said = encodeURIComponent(url);
    const titled = encodeURIComponent(article.title);
    const out = [
      ["WhatsApp", `https://wa.me/?text=${titled}%20${said}`],
      ["Facebook", `https://www.facebook.com/sharer/sharer.php?u=${said}`],
      ["X", `https://x.com/intent/post?url=${said}&text=${titled}`],
      ["LinkedIn", `https://www.linkedin.com/sharing/share-offsite/?url=${said}`],
      ["Email", `mailto:?subject=${titled}&body=${said}`],
    ];
    const status = this.sharing.copied.map((copied) => (copied?.slug === article.slug
      ? Phrase.of(copied.worked ? "Link copied" : "Couldn't copy the link. Copy it from the address bar instead.") : null));
    return ui.column([
      ui.row([
        ui.text(Phrase.of("Share this piece"), "ShareLabel"),
        ui.pressable(SHARES, { title: article.title, url }, [ui.text(ui.words(SHARES))], "ShareButton").absentWhenRefused(),
        ui.pressable(COPIES_LINK, { slug: article.slug, url }, [ui.text(ui.words(COPIES_LINK))], "ShareButton"),
        ...out.map(([name, href]) => ui.hyperlink(href, [ui.text(name)], "ShareOut", { label: Phrase.with("Share on %s", [name]), stays: href.startsWith("mailto:") })),
      ], "ShareRow"),
      ui.text(status, "ShareStatus").hidesEmpty(),
    ], "ShareBar");
  }

  threadTag(id) { return this.ui.text(threadNamed(id).name, `ThreadTag t-${id}`); }

  navLink(action, place) {
    return this.ui.pressable(action, { parameter: null }, [this.ui.text(this.ui.words(action), "NavWords")], "NavLink").goesTo(place);
  }

  threadTags(article) {
    return this.ui.row(article.threads.map((id) => this.threadTag(id)), "ThreadTags");
  }

  meta(article) {
    const ui = this.ui;
    return ui.row([
      ui.text(Phrase.with("%s · %d min read", [written(article.date), minutesToRead(article)]), "Meta"),
      article.members ? ui.text(Phrase.of("Members"), "MembersBadge") : null,
    ].filter(Boolean), "MetaRow");
  }

  titleLink(article, words) {
    return this.ui.link(readsOf(article), article.slug, article.title, { style: "TitleLink", words_style: words }).goesTo(screenOf(article));
  }

  /** An article in the list of writing: the first one larger. */
  entry(article, lead) {
    const ui = this.ui;
    return ui.surface(lead ? "Entry LeadEntry" : "Entry", [
      ui.image(lead ? article.hero[0] : "images/card.svg", "EntryImage", article.hero[1]),
      ui.column([this.threadTags(article), this.titleLink(article, lead ? "LeadTitle" : "EntryTitle"), ui.text(article.dek, "Dek").wraps(), this.meta(article)], "EntryText"),
    ]);
  }

  home() {
    const ui = this.ui;
    const showing = ui.local(ALL);
    const chip = (value, words) => ui.pressLocal(showing, value, [ui.text(words)], `Chip t-${value}`);
    return ui.screen(HOME, [
      ui.column([
        ui.text(SITE.about, "Intro").wraps(),
        ui.paragraph([Phrase.with("Writing by %s. ", [SITE.author]), ui.link(GOES_ABOUT, null, Phrase.of("More about her work"), { style: "InlineLink", words_style: "InlineWords" }).goesTo(ABOUT)], "IntroSmall"),
      ], "IntroBlock"),
      ui.surface("FollowBand", [
        ui.column([ui.text(Phrase.of("Follow along"), "Kicker"), ui.text(Phrase.with("Find %s on TikTok, Instagram and YouTube.", [SITE.author]), "FollowWords").wraps()], "FollowText"),
        this.follow("Buttons"),
      ]),
      ui.column([
        ui.text(Phrase.of("Threads"), "Kicker"),
        ui.row([chip(ALL, Phrase.of("All writing")), ...THREADS.map((thread) => chip(thread.id, thread.name))], "Chips"),
        ui.text(showing.map((id) => THREAD_INTROS[id] ?? null), "ThreadIntro").wraps().hidesEmpty(),
      ], "Threads"),
      ui.column(ARTICLES.map((article, index) => ui.when(showing.map((id) => id === ALL || article.threads.includes(id)), this.entry(article, index === 0))), "Entries"),
    ]);
  }

  about() {
    const ui = this.ui;
    const lorem = "Placeholder. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.";
    return ui.screen(ABOUT, [
      ui.surface("AboutGrid", [
        ui.image("images/portrait.svg", "Portrait", "Portrait placeholder"),
        ui.column([
          ui.text(Phrase.of("About"), "Kicker"),
          ui.text(SITE.author, "PageTitle").wraps(),
          ui.row(SITE.disciplines.map((discipline) => ui.text(discipline, "ThreadTag Discipline")), "ThreadTags"),
          ui.text(Phrase.of("A short introduction in her words: who she is, where she writes from, and why. Lorem ipsum dolor sit amet."), "Dek").wraps(),
          ui.text(lorem, "Body").wraps(),
          ui.text(Phrase.of("How she works"), "Subhead"),
          ui.text(lorem, "Body").wraps(),
          ui.text(Phrase.of("What she writes about"), "Subhead"),
          ui.row(THREADS.map((thread) => this.threadTag(thread.id)), "ThreadTags"),
          ui.text(Phrase.of("Follow her"), "Subhead"),
          this.follow("Buttons"),
          ui.text(Phrase.of("Get in touch"), "Subhead"),
          ui.text(Phrase.of("Contact placeholder: an email address, or a note on how to reach her."), "Body").wraps(),
          ui.button(GOES_JOIN, { goes_to: JOIN, style: "JoinButton" }),
        ], "AboutText"),
      ]),
    ]);
  }

  join() {
    const ui = this.ui;
    const signup = this.signup;
    const plan = (option) => ui.pressable(CHOOSES_PLAN, { plan: option.id }, [
      ui.text(option.name, "PlanName"),
      ui.text(option.price, "PlanPrice"),
    ], "Plan").currentWhile(signup.plan.map((chosen) => chosen === option.id));
    return ui.screen(JOIN, [
      ui.column([
        ui.text(Phrase.of("Membership"), "Kicker"),
        ui.text(Phrase.with("Join %s", [SITE.name]), "PageTitle").wraps(),
        ui.text(Phrase.of("Members receive the newsletter and can read every article, including the members-only pieces."), "Dek").wraps(),
        ui.column([
          ui.text(Phrase.of("✓ Every article, including members-only pieces"), "Benefit").wraps(),
          ui.text(Phrase.of("✓ The newsletter, by email"), "Benefit").wraps(),
          ui.text(Phrase.of("✓ Placeholder: anything else members receive"), "Benefit").wraps(),
        ], "Benefits"),
        ui.text(Phrase.of("Choose a plan"), "Subhead"),
        ui.row(PLANS.map(plan), "Plans"),
        ui.field(SETS_NAME, "", { label: Phrase.of("Your name"), changes: SETS_NAME, shows: signup.name, autocomplete: "name" }),
        ui.field(SETS_EMAIL, "", { label: Phrase.of("Email address"), changes: SETS_EMAIL, shows: signup.email, kind: "email", autocomplete: "email" }),
        ui.button(CONTINUES, { style: "JoinButton" }),
        ui.when(signup.sent, ui.surface("Notice", [
          ui.text(Phrase.of("Payment isn't connected yet"), "NoticeTitle"),
          ui.text(Phrase.of("This is where payment would begin. Nothing was charged, and your details were not sent anywhere."), "Body").wraps(),
        ])),
        ui.text(Phrase.of("Placeholder: cancellation, refunds and privacy terms."), "SmallPrint").wraps(),
      ], "JoinForm"),
    ]);
  }

  // --- an article ---

  figure(media, caption, source = null) {
    const ui = this.ui;
    return ui.column([media, ui.text(caption, "Caption").wraps(), source ? ui.text(source, "Provenance").wraps() : null].filter(Boolean), "Figure");
  }

  /** A paragraph's spans: words, glossary terms pressed for their meaning, and footnote marks. */
  paragraph(spans) {
    const ui = this.ui;
    return ui.paragraph(spans.map((span) => {
      if (typeof span === "string") return span;
      if (span.term) return ui.pressable(DEFINES, { parameter: span.term }, [ui.text(span.term, "TermWords")], "Term").opens(this.meaning);
      return ui.text(String(span.note), "NoteMark");
    }), "Body");
  }

  block([kind, ...given]) {
    const ui = this.ui;
    if (kind === "p") return this.paragraph(given[0]);
    if (kind === "h") return ui.text(given[0], "Subhead").wraps();
    if (kind === "quote") return ui.text(given[0], "PullQuote").wraps();
    if (kind === "img") return this.figure(ui.image(given[0], "FigureImage", given[1]), given[2], given[3]);
    if (kind === "video") return this.figure(ui.embed(given[0], { title: given[1], poster: "images/video.svg" }), given[2]);
    if (kind === "audio") return this.figure(ui.embed(given[0], { title: given[1], ratio: "6 / 1" }), given[2]);
    if (kind === "journey") {
      return ui.column([
        ui.text(Phrase.of("The journey"), "Kicker"),
        ui.row(given[0].map(([place, when]) => ui.column([ui.text(place, "StopPlace").wraps(), ui.text(when, "StopWhen")], "Stop")), "Route"),
      ], "Journey");
    }
    if (kind === "generations") {
      return ui.column([
        ui.text(Phrase.of("Generations"), "Kicker"),
        ui.column(given[0].map(([who, place, years]) => ui.row([ui.text(who, "GenWho").grow(), ui.text(place, "GenPlace"), ui.text(years, "GenYears")], "Generation")), "GenerationList"),
      ], "Generations");
    }
    throw new Error(`an article has no block called ${kind}`);
  }

  /** Notes, references and further reading, each only where the article has some. */
  endMatter(article) {
    const ui = this.ui;
    const list = (heading, items, numbered) => (items.length ? ui.column([
      ui.text(heading, "EndHeading"),
      ...items.map((item, index) => ui.row([numbered ? ui.text(String(index + 1), "EndNumber") : null, ui.text(item, "EndItem").wraps().grow()].filter(Boolean), "EndRow")),
    ], "EndList") : null);
    return [list(Phrase.of("Notes"), article.notes, true), list(Phrase.of("References"), article.references, false), list(Phrase.of("Further reading"), article.reading, false)].filter(Boolean);
  }

  article(article) {
    const ui = this.ui;
    const at = ARTICLES.indexOf(article);
    const cut = article.body.findIndex(([kind]) => kind === "cut");
    const opening = (cut < 0 ? article.body : article.body.slice(0, cut)).map((block) => this.block(block));
    const rest = cut < 0 ? [] : article.body.slice(cut + 1).map((block) => this.block(block));
    const next = [1, 2].map((step) => ARTICLES[(at + step) % ARTICLES.length]);
    const ending = ui.surface("EndShare", [
      this.shareBar(article),
      ui.column([ui.text(Phrase.with("Follow %s", [SITE.author]), "ShareLabel"), this.follow("Buttons")], "EndFollow"),
    ]);
    const keepReading = [ending, ui.divider("Horizon"), ui.text(Phrase.of("Keep reading"), "Kicker"), ui.column(next.map((other) => this.entry(other, false)), "Entries")];
    const after = [...rest, ...this.endMatter(article)];
    const paywall = ui.surface("Paywall", [
      ui.text(Phrase.of("This piece is for members"), "PaywallTitle"),
      ui.text(Phrase.of("Members receive the newsletter and can read every article."), "Body").wraps(),
      ui.button(JOINS_TO_READ, { goes_to: JOIN, style: "JoinButton" }),
    ]);
    return ui.screen(screenOf(article), [
      ui.column([
        ui.pressable(BACKS, {}, [ui.text(Phrase.with("← %s", [ui.words(BACKS)]), "BackWords")], "BackLink").goesTo(Driver.BACK),
        article.note ? ui.surface("ContentNote", [ui.text(Phrase.of("Content note"), "Kicker"), ui.text(article.note, "NoteWords").wraps()]) : null,
        this.threadTags(article),
        ui.text(article.title, "ArticleTitle").wraps(),
        ui.text(article.dek, "Dek").wraps(),
        ui.row([ui.text(Phrase.with("By %s", [SITE.author]), "Byline"), this.meta(article)], "BylineRow"),
        this.shareBar(article),
        article.epigraph ? ui.column([ui.text(article.epigraph[0], "EpigraphWords").wraps(), ui.text(Phrase.with("— %s", [article.epigraph[1]]), "EpigraphSource")], "Epigraph") : null,
        this.figure(ui.image(article.hero[0], "HeroImage", article.hero[1]), article.hero[2]),
        ...opening,
        article.members ? ui.when(this.membership.member, ui.column(after, "Rest"), paywall) : ui.column(after, "Rest"),
        ...keepReading,
      ].filter(Boolean), "Article"),
    ]);
  }
}

ChimeApp.start(SimpleCeremonies, document.getElementById("app"));
