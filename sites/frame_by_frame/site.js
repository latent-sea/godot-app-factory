// Frame by Frame: a blog about short films and drawing, on gd-chime for the
// web. Made from tooling/create_site.py's hello site.
//
// The home screen leads with the newest article, then the rest as cards a
// reader can narrow to films or field notes. Every article is a screen of its
// own, described from its data (articles.js): pictures with captions, videos
// that load only when pressed, and two more articles to keep reading. The
// masthead goes home from anywhere; Back goes where the reader was, at the
// same place down the page.

import { ChimeApp, Driver, Look, Phrase } from "./gd_chime/gd_chime.js";
import { ARTICLES, AUTHOR, FILMS, NOTES, minutesToRead, written } from "./articles.js";

const HOME = "home";
const GOES_HOME = "goes_home";
const BACKS = "goes_back";
const ALL = "all";

/** The words each kind of article goes by. */
const TAGS = { [FILMS]: "Films", [NOTES]: "Field notes" };

/** The blog's look in daylight, and after dark. */
const LIGHT = { ground: "#f3f4f1", raised: "#ffffff", lit: "#e7eae5", ink: "#1a201e", ink_soft: "#58635e", accent: "#245c8a", accent_2: "#a8621c", warn: "#b3402e", edge: "#d5dad3" };
const DARK = { ground: "#121517", raised: "#1a1e21", lit: "#252a2e", ink: "#e7eae6", ink_soft: "#9aa39e", accent: "#86b6e0", accent_2: "#e0a361", warn: "#e0745e", edge: "#30363a" };

const screenOf = (article) => `article_${article.slug}`;
const readsOf = (article) => `reads_${article.slug}`;

export class Blog extends ChimeApp {
  look() {
    const dark = typeof matchMedia === "function" && matchMedia("(prefers-color-scheme: dark)").matches;
    return Look.make(dark ? DARK : LIGHT);
  }

  declare(register) {
    const table = { [GOES_HOME]: ["All articles"], [BACKS]: ["Back"] };
    for (const article of ARTICLES) table[readsOf(article)] = ["Read the article"];
    register.declareAll(table);
  }

  describe() {
    const ui = this.ui;
    const [lead, ...rest] = ARTICLES;
    const showing = ui.local(ALL);

    const masthead = ui.column([
      ui.link(GOES_HOME, null, "Frame by Frame", { style: "Masthead", words_style: "MastheadWords" }).goesTo(HOME),
      ui.text(Phrase.of("Notes on short films, open movies and drawing from life"), "Tagline").wraps(),
    ], "Header");

    const chip = (value, words) => ui.pressLocal(showing, value, [ui.text(Phrase.of(words))], "Chip");
    const home = ui.screen(HOME, [
      this.lead(lead),
      ui.row([ui.text(Phrase.of("More writing"), "SectionLabel").grow(), chip(ALL, "All"), chip(FILMS, TAGS[FILMS]), chip(NOTES, TAGS[NOTES])], "Filters"),
      ui.grid(rest.map((article) => ui.when(showing.map((tag) => tag === ALL || tag === article.tag), this.card(article))), [], "Cards"),
    ]);

    const footer = ui.column([
      ui.divider(),
      ui.text(Phrase.of("Frame by Frame is a made-up blog, and its author is invented too. The films are real: open movies by the Blender Foundation, released under Creative Commons Attribution. Photos from Unsplash, through Lorem Picsum."), "Footer").wraps(),
      ui.text(Phrase.of("Made with gd-chime for the web."), "Footer"),
    ], "FooterBlock");

    return ui.app("frame_by_frame", [masthead, ui.stack([home, ...ARTICLES.map((article) => this.article(article))]), footer]);
  }

  // loaded only when the page is walked (?probe), so an export leaves it out
  probe() { return import("./probe.js").then((made) => new made.Probe(this)); }

  /** What kind of article, when, and how long it takes to read. */
  meta(article) {
    return this.ui.text(Phrase.with("%s · %s · %d min read", [Phrase.of(TAGS[article.tag]), written(article.date), minutesToRead(article)]), "Meta");
  }

  /** The way into an article: its title, pressed. */
  titleLink(article, words) {
    return this.ui.link(readsOf(article), article.slug, article.title, { style: "TitleLink", words_style: words }).goesTo(screenOf(article));
  }

  /** The newest article, given the room at the top of the home screen. */
  lead(article) {
    const ui = this.ui;
    const [picture, alt] = article.hero;
    return ui.surface("Lead", [
      ui.image(picture, "LeadImage", alt),
      ui.column([
        ui.text(Phrase.of("Latest"), "Kicker"),
        this.titleLink(article, "LeadTitle"),
        ui.text(article.dek, "Dek").wraps(),
        this.meta(article),
      ], "LeadText"),
    ]);
  }

  /** An article as a card among others. */
  card(article) {
    const ui = this.ui;
    const [picture, alt] = article.hero;
    return ui.surface("ArticleCard", [
      ui.image(picture, "CardImage", alt),
      ui.column([this.meta(article), this.titleLink(article, "CardTitle"), ui.text(article.dek, "CardDek").wraps()], "CardText"),
    ]);
  }

  /** A picture, or a video, with the words under it. */
  figure(media, caption) {
    return this.ui.column([media, this.ui.text(caption, "Caption").wraps()], "Figure");
  }

  /** One block of an article's body. */
  block([kind, ...given]) {
    const ui = this.ui;
    if (kind === "p") return ui.text(given[0], "Body").wraps();
    if (kind === "h") return ui.text(given[0], "Subhead").wraps();
    if (kind === "quote") return ui.text(given[0], "PullQuote").wraps();
    if (kind === "img") {
      const [picture, alt, caption] = given;
      return this.figure(ui.image(picture, "FigureImage", alt), caption);
    }
    if (kind === "video") {
      const [id, title, caption] = given;
      const video = ui.embed(`https://www.youtube-nocookie.com/embed/${id}?autoplay=1&rel=0`, { title, poster: `images/film-${id}.jpg` });
      return this.figure(video, caption);
    }
    throw new Error(`an article has no block called ${kind}`);
  }

  /** An article's own screen, and two more to read after it. */
  article(article) {
    const ui = this.ui;
    const [picture, alt, credit] = article.hero;
    const at = ARTICLES.indexOf(article);
    const next = [1, 2].map((step) => ARTICLES[(at + step) % ARTICLES.length]);
    return ui.screen(screenOf(article), [
      ui.column([
        ui.pressable(BACKS, {}, [ui.text(Phrase.with("← %s", [ui.words(BACKS)]), "BackWords")], "BackLink").goesTo(Driver.BACK),
        this.meta(article),
        ui.text(article.title, "ArticleTitle").wraps(),
        ui.text(article.dek, "Dek").wraps(),
        ui.text(Phrase.with("By %s", [AUTHOR]), "Byline"),
        this.figure(ui.image(picture, "HeroImage", alt), credit),
        ...article.body.map((block) => this.block(block)),
        ui.divider(),
        ui.text(Phrase.of("Keep reading"), "SectionLabel"),
        ui.grid(next.map((other) => this.card(other)), [], "Cards"),
      ], "Article"),
    ]);
  }
}

ChimeApp.start(Blog, document.getElementById("app"));
