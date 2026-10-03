// Frame by Frame walked as a reader would: open the page with ?probe.

import { Walk } from "./gd_chime/gd_chime.js";
import { ARTICLES } from "./articles.js";

const titlesShown = (walk) => ARTICLES.filter((article) => walk.shows(article.title)).map((article) => article.slug);

export class Probe extends Walk {
  async run() {
    await this.begin();
    this.claim("it opens on the home screen", this.top() === "home");
    this.claim("the masthead says the blog's name", this.shows("Frame by Frame"));
    this.claim("every article is listed", titlesShown(this).length === ARTICLES.length);
    const home = this.root().querySelector('[data-place="home"]');
    this.claim("every picture on the home screen says what it shows", [...home.querySelectorAll("img")].every((picture) => picture.alt.length > 10));

    await this.pressWords("Field notes");
    this.claim("narrowed to field notes, a film below the lead is hidden", !this.shows("Sintel and the long walk through snow") && this.shows("Seven mornings of drawing outdoors"));
    await this.pressWords("Films");
    this.claim("narrowed to films, the field notes are hidden", !this.shows("Seven mornings of drawing outdoors") && this.shows("Sintel and the long walk through snow"));
    await this.pressWords("All");
    this.claim("and all of them again", titlesShown(this).length === ARTICLES.length);

    await this.press("reads_big_buck_bunny");
    this.claim("a title goes to its article", this.top() === "article_big_buck_bunny");
    this.claim("which shows its title and its author", this.shows("The rabbit that proved a point") && this.shows("By Mara Quill"));
    this.claim("and not the home screen", !this.shows("More writing"));
    const page = this.root().querySelector('[data-place="article_big_buck_bunny"]');
    this.claim("its pictures are there, each saying what it shows", page.querySelectorAll("img.FigureImage, img.HeroImage").length === 2 && [...page.querySelectorAll("img.chime-image")].every((picture) => picture.alt));
    const poster = page.querySelector(".chime-embed-poster");
    this.claim("its video waits behind a poster", !!poster && !page.querySelector("iframe"));
    this.claim("the poster plays the film from YouTube", poster?.dataset.src.startsWith("https://www.youtube-nocookie.com/embed/aqz-KE-bpKQ"));
    this.claim("two more articles follow it", this.shows("Keep reading"));

    await this.press("reads_spring");
    this.claim("one article leads to another", this.top() === "article_spring" && this.shows("Spring, and the painterly turn"));
    await this.press("goes_back");
    this.claim("back returns to the article before", this.top() === "article_big_buck_bunny");
    await this.press("goes_home");
    this.claim("the masthead goes home", this.top() === "home" && this.shows("More writing"));
    this.finish();
  }

  /** Press the visible button with exactly these words, as a reader would. */
  async pressWords(words) {
    const button = [...this.root().querySelectorAll("button")].find((part) => this.visible(part) && part.textContent === words);
    this.claim(`there is a button saying ${words}`, !!button);
    button?.click();
    await this.frames(3);
  }
}
