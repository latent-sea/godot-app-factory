// Simple Ceremonies' content: a TEMPLATE. Every word of an article here is
// placeholder - lorem ipsum, or a note saying what goes in the slot - and
// nothing is anyone's real writing. Replace an article by replacing its
// entry; add one by adding an entry. The threads are hers.
//
// An article: slug (its address), title, dek (the line under the title),
// date, threads (one or more), members (true: readers see the opening, then
// an invitation to join), note (a content note, or null), epigraph ([words,
// source] or null), hero ([picture, alt, caption]), body (blocks, below),
// notes (footnotes, by number), references, reading (further reading).
//
// A block: ["p", spans] - a paragraph, its spans plain words, {term} (a
// glossary word, pressed for its meaning) or {note} (a footnote's number);
// ["h", words]; ["quote", words]; ["img", picture, alt, caption, source];
// ["video", page, title, caption]; ["audio", page, title, caption];
// ["journey", [[place, when], ...]]; ["generations", [[who, place, years], ...]];
// ["cut"] - where a members' article stops for a reader who has not joined.

export const SITE = {
  name: "Simple Ceremonies",
  author: "Author Name",
  disciplines: ["Psychology", "Anthropology", "Sociology"],
  about: "Writing on migration, place, ancestry and repair.",
  // Where to follow her: replace each handle and address with hers.
  socials: [
    { id: "tiktok", name: "TikTok", handle: "@handle", url: "https://www.tiktok.com/" },
    { id: "instagram", name: "Instagram", handle: "@handle", url: "https://www.instagram.com/" },
    { id: "youtube", name: "YouTube", handle: "@handle", url: "https://www.youtube.com/" },
  ],
};

export const THREADS = [
  { id: "migration", name: "Migration" },
  { id: "place", name: "Place & ancestors" },
  { id: "trauma", name: "Family trauma" },
  { id: "post_indenture", name: "Post-indenture" },
  { id: "animism", name: "Animism" },
  { id: "indigeneity", name: "Indigeneity" },
];

/** Her introduction to each thread, a sentence or two in her words. */
export const THREAD_INTROS = Object.fromEntries(THREADS.map((thread) => [thread.id, `Placeholder introduction to ${thread.name}. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore.`]));

/** The words her glossary defines, each in her words. */
export const GLOSSARY = {
  "lorem term": "Placeholder definition. Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.",
  "ipsum term": "Placeholder definition. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
  "dolor term": "Placeholder definition. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur.",
};

const P = [
  "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.",
  "Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.",
  "Sed ut perspiciatis unde omnis iste natus error sit voluptatem accusantium doloremque laudantium, totam rem aperiam, eaque ipsa quae ab illo inventore veritatis et quasi architecto beatae vitae dicta sunt explicabo.",
  "Nemo enim ipsam voluptatem quia voluptas sit aspernatur aut odit aut fugit, sed quia consequuntur magni dolores eos qui ratione voluptatem sequi nesciunt. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet.",
  "At vero eos et accusamus et iusto odio dignissimos ducimus qui blanditiis praesentium voluptatum deleniti atque corrupti quos dolores et quas molestias excepturi sint occaecati cupiditate non provident.",
];

const hero = ["images/hero.svg", "Image placeholder", "Caption placeholder: what the picture shows, where and when."];
const notes = ["Footnote placeholder. Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Footnote placeholder. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua."];
const references = ["Surname, A. (Year). Title of the work. Publisher.", "Surname, B., & Surname, C. (Year). Title of the article. Journal Name, 12(3), 45–67."];
const reading = ["Further reading placeholder: a book, an article or a talk, with a line on why.", "Further reading placeholder: lorem ipsum dolor sit amet."];

export const ARTICLES = [
  {
    slug: "template_every_block",
    title: "Lorem ipsum dolor sit amet, consectetur adipiscing",
    dek: "Template article showing every kind of block the blog has. Placeholder dek: one or two sentences on what the piece is about.",
    date: "2026-09-30",
    threads: ["migration", "post_indenture"],
    members: false,
    note: "Content note placeholder: this piece discusses lorem ipsum and dolor sit amet.",
    epigraph: ["Epigraph placeholder. Lorem ipsum dolor sit amet, consectetur adipiscing elit.", "Source of the epigraph, Year"],
    hero,
    body: [
      ["p", [P[0], " Ut enim ad minim veniam, quis ", { term: "lorem term" }, " nostrud exercitation.", { note: 1 }]],
      ["p", [P[1]]],
      ["journey", [["Place of departure", "Year"], ["A place on the way", "Year"], ["Place of arrival", "Year"]]],
      ["h", "Subheading placeholder"],
      ["p", [P[2], " Neque porro quisquam est, qui ", { term: "ipsum term" }, " dolorem ipsum."]],
      ["img", "images/archival.svg", "Archival photograph placeholder", "Caption placeholder: who and what the photograph shows.", "Source placeholder: the archive or family collection, the date, and the permission given to share it."],
      ["quote", "Pull quote placeholder: a line from the piece worth lifting out. Lorem ipsum dolor sit amet."],
      ["p", [P[3], { note: 2 }]],
      ["generations", [["Great-grandparent", "Place", "Years"], ["Grandparent", "Place", "Years"], ["Parent", "Place", "Years"], ["The writer", "Place", "Year born"]]],
      ["video", "media/video.html", "Video placeholder", "Caption placeholder: what the recording is, who is speaking, and when it was made."],
      ["audio", "media/audio.html", "Audio placeholder", "Caption placeholder: an oral history or interview, with the speaker's consent noted."],
      ["p", [P[4], " Similique sunt in culpa qui officia ", { term: "dolor term" }, " deserunt mollitia animi."]],
    ],
    notes, references, reading,
  },
  {
    slug: "template_members_one",
    title: "Sed ut perspiciatis unde omnis iste natus error",
    dek: "Template members' article. Placeholder dek: what the piece is about, in a sentence or two.",
    date: "2026-09-16",
    threads: ["trauma", "place"],
    members: true,
    note: "Content note placeholder: this piece discusses lorem ipsum.",
    epigraph: null,
    hero,
    body: [
      ["p", [P[2]]],
      ["p", [P[0]]],
      ["cut"],
      ["h", "Subheading placeholder"],
      ["p", [P[1], { note: 1 }]],
      ["generations", [["Grandparent", "Place", "Years"], ["Parent", "Place", "Years"], ["The writer", "Place", "Year born"]]],
      ["p", [P[3]]],
      ["quote", "Pull quote placeholder. Neque porro quisquam est, qui dolorem ipsum quia dolor sit amet."],
      ["p", [P[4]]],
    ],
    notes: notes.slice(0, 1), references, reading,
  },
  {
    slug: "template_animism",
    title: "Nemo enim ipsam voluptatem quia voluptas",
    dek: "Template article. Placeholder dek: lorem ipsum dolor sit amet, consectetur adipiscing elit.",
    date: "2026-08-28",
    threads: ["animism", "indigeneity"],
    members: false,
    note: null,
    epigraph: ["Epigraph placeholder. Sed do eiusmod tempor incididunt.", "Source, Year"],
    hero,
    body: [
      ["p", [P[3]]],
      ["p", [P[1], " Quis autem vel eum iure ", { term: "dolor term" }, " reprehenderit."]],
      ["img", "images/archival.svg", "Archival photograph placeholder", "Caption placeholder.", "Source placeholder: archive, date, permission."],
      ["p", [P[0]]],
      ["audio", "media/audio.html", "Audio placeholder", "Caption placeholder: the recording and the speaker's consent."],
      ["p", [P[4]]],
    ],
    notes: [], references: references.slice(0, 1), reading,
  },
  {
    slug: "template_members_two",
    title: "At vero eos et accusamus et iusto odio",
    dek: "Template members' article. Placeholder dek: lorem ipsum dolor sit amet.",
    date: "2026-08-10",
    threads: ["post_indenture", "migration"],
    members: true,
    note: null,
    epigraph: null,
    hero,
    body: [
      ["p", [P[4]]],
      ["journey", [["Place of departure", "Year"], ["Place of arrival", "Year"]]],
      ["cut"],
      ["p", [P[0]]],
      ["h", "Subheading placeholder"],
      ["p", [P[2]]],
      ["video", "media/video.html", "Video placeholder", "Caption placeholder."],
      ["p", [P[3]]],
    ],
    notes: [], references, reading: [],
  },
  {
    slug: "template_place",
    title: "Quis autem vel eum iure reprehenderit",
    dek: "Template article. Placeholder dek: one or two sentences.",
    date: "2026-07-22",
    threads: ["place", "indigeneity"],
    members: false,
    note: null,
    epigraph: null,
    hero,
    body: [
      ["p", [P[1]]],
      ["p", [P[2]]],
      ["quote", "Pull quote placeholder. Lorem ipsum dolor sit amet."],
      ["p", [P[0]]],
    ],
    notes: [], references: [], reading,
  },
  {
    slug: "template_members_three",
    title: "Temporibus autem quibusdam et aut officiis",
    dek: "Template members' article. Placeholder dek.",
    date: "2026-07-03",
    threads: ["trauma"],
    members: true,
    note: "Content note placeholder: this piece discusses lorem ipsum dolor.",
    epigraph: null,
    hero,
    body: [
      ["p", [P[0]]],
      ["cut"],
      ["p", [P[3]]],
      ["p", [P[4]]],
    ],
    notes: [], references, reading: [],
  },
];

/** How long an article takes to read, in whole minutes, at 220 words a minute. */
export function minutesToRead(article) {
  const words = article.body.flatMap(([kind, given]) => (kind === "p" ? given : kind === "h" || kind === "quote" ? [given] : []))
    .map((span) => (typeof span === "string" ? span : span.term ?? "")).join(" ").split(/\s+/).length;
  return Math.max(1, Math.round(words / 220));
}

/** A date written the way the reader's language writes it. */
export function written(date) {
  return new Date(`${date}T12:00:00Z`).toLocaleDateString(undefined, { day: "numeric", month: "long", year: "numeric" });
}

/** The thread an id names. */
export const threadNamed = (id) => THREADS.find((thread) => thread.id === id);
