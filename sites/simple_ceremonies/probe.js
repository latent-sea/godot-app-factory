// Simple Ceremonies walked as a reader would: open the page with ?probe.

import { Ui, Walk } from "./gd_chime/gd_chime.js";
import { ARTICLES, THREADS } from "./content.js";

const listed = (walk) => ARTICLES.filter((article) => walk.shows(article.title)).length;

export class Probe extends Walk {
  async run() {
    await this.begin();
    this.claim("it opens on the writing", this.top() === "home");
    this.claim("the masthead names the blog", this.shows("Simple Ceremonies"));
    this.claim("every article is listed", listed(this) === ARTICLES.length);
    const header = this.root().querySelector(".Header");
    const followed = [...header.querySelectorAll("a.Social")];
    this.claim("the header links to her TikTok, Instagram and YouTube", ["tiktok.com", "instagram.com", "youtube.com"].every((site) => followed.some((link) => link.href.includes(site))));
    this.claim("each opens in a new tab and says where it goes", followed.every((link) => link.target === "_blank" && /^Follow on /.test(link.getAttribute("aria-label"))));
    this.claim("the home screen asks readers to follow along", this.shows("Follow along") && this.root().querySelectorAll('[data-place="home"] .FollowBand a.Social').length === 3);
    this.claim("members' articles are marked", this.root().querySelectorAll('[data-place="home"] .MembersBadge').length === ARTICLES.filter((a) => a.members).length);

    await this.pressWords("Animism");
    this.claim("a thread narrows the list to its articles", listed(this) === ARTICLES.filter((a) => a.threads.includes("animism")).length);
    this.claim("and says what the thread is", this.showsPart("Placeholder introduction to Animism"));
    await this.pressWords("All writing");
    this.claim("all writing shows every article again", listed(this) === ARTICLES.length);
    this.claim("every thread has a chip", THREADS.every((thread) => this.shows(thread.name)));

    await this.press("reads_template_every_block");
    const page = this.root().querySelector('[data-place="article_template_every_block"]');
    this.claim("a title opens its article", this.top() === "article_template_every_block");
    this.claim("and the address names it, so it can be shared", location.hash === "#template_every_block");
    const shares = [...page.querySelectorAll(".ShareBar")];
    this.claim("it can be shared at its top and at its end", shares.length === 2);
    const whatsapp = shares[0].querySelector('a[href^="https://wa.me/"]');
    this.claim("a share link carries the article's own address", !!whatsapp && decodeURIComponent(whatsapp.href).includes("#template_every_block"));
    this.claim("to WhatsApp, Facebook, X, LinkedIn and email", ["wa.me", "facebook.com", "x.com", "linkedin.com", "mailto:"].every((to) => shares[0].querySelector(`a[href*="${to}"]`)));
    await this.press("copies_the_link");
    await new Promise((resolve) => setTimeout(resolve, 1500));
    await this.frames(3);
    this.claim("copying the link says what came of it", this.shows("Link copied") || this.showsPart("Couldn't copy the link"));
    this.claim("the end of an article asks readers to follow her", this.shows("Follow Author Name") && page.querySelectorAll(".EndShare a.Social").length === 3);
    this.claim("a content note comes first", this.shows("Content note") && this.showsPart("Content note placeholder"));
    this.claim("an epigraph, with its source", this.showsPart("Epigraph placeholder") && this.showsPart("— Source of the epigraph"));
    this.claim("a journey, its stops in order", this.shows("Place of departure") && this.shows("Place of arrival"));
    this.claim("generations, oldest first", this.shows("Great-grandparent") && this.shows("The writer"));
    this.claim("an archival photograph with its source", this.showsPart("Source placeholder: the archive"));
    this.claim("a video waiting behind its poster, and an audio player", !!page.querySelector(".chime-embed-poster") && page.querySelectorAll("iframe").length === 1);
    this.claim("notes, references and further reading", this.shows("Notes") && this.shows("References") && this.shows("Further reading"));
    this.claim("footnote marks in the running words", page.querySelectorAll(".NoteMark").length === 2);

    await this.press("shows_the_meaning");
    this.claim("a glossary word opens its meaning", this.top() === "meaning 1" && this.shows("lorem term") && this.showsPart("Placeholder definition"));
    await this.press(Ui.CLOSES);
    this.claim("and closes back to the article", this.top() === "article_template_every_block");

    await this.press("goes_home");
    await this.press("reads_template_members_one");
    this.claim("a members' article shows its opening", this.top() === "article_template_members_one" && this.shows("This piece is for members"));
    this.claim("and not what follows the cut", !this.shows("Subheading placeholder"));
    await this.press("joins_to_read");
    this.claim("becoming a member goes to Join", this.top() === "join" && this.shows("Join Simple Ceremonies"));

    const go = this.pressable("continues_to_payment");
    this.claim("payment waits for a name and an email", go?.getAttribute("aria-disabled") === "true" && this.shows("Add your name to continue"));
    const [name, email] = this.fields();
    await this.typeInto(name, "A Reader");
    await this.frames(3);
    this.claim("then for an email address", this.shows("Add an email address to continue"));
    await this.typeInto(email, "reader@example.com");
    await this.frames(3);
    await this.pressWords("Monthly");
    this.claim("a plan is chosen", this.root().querySelector(".Plan.chime-current")?.textContent.includes("Monthly"));
    await this.press("continues_to_payment");
    this.claim("payment says plainly that it is not connected", this.shows("Payment isn't connected yet"));

    await this.press("previews_the_members_view");
    await this.press("goes_home");
    await this.press("reads_template_members_one");
    this.claim("as a member, the whole article shows", this.shows("Subheading placeholder") && !this.shows("This piece is for members"));

    location.hash = "#template_place";
    await new Promise((resolve) => setTimeout(resolve, 100));
    await this.frames(3);
    this.claim("an article's address opens it", this.top() === "article_template_place");
    await this.press("goes_home");
    this.claim("and leaving it gives the page its own address back", location.hash === "");

    await this.press("goes_about");
    this.claim("About asks readers to follow her", this.root().querySelectorAll('[data-place="about"] a.Social').length === 3);
    this.claim("About has her portrait and disciplines", this.top() === "about" && this.shows("Psychology") && this.shows("Anthropology") && this.shows("Sociology") && !!this.root().querySelector('[data-place="about"] img.Portrait'));
    this.finish();
  }

  /** Press the visible button whose words begin so, as a reader would. */
  async pressWords(words) {
    const button = [...this.root().querySelectorAll("button")].find((part) => this.visible(part) && part.textContent.startsWith(words));
    this.claim(`there is a button saying ${words}`, !!button);
    button?.click();
    await this.frames(3);
  }
}
