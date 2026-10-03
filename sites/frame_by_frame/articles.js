// The articles: the blog's content, as data. Words written here are the
// articles' own and shown as they are; only the site's chrome - its buttons
// and labels - is said through phrases (site.js).
//
// Every article is invented, and so is its author. The films are real: the
// Blender Foundation's open movies, released under Creative Commons
// Attribution. The photos are from Unsplash, through Lorem Picsum.
//
// A body is a list of blocks: ["p", words], ["h", a heading],
// ["quote", words], ["img", picture, alt, caption], ["video", YouTube id, title, caption].

export const AUTHOR = "Mara Quill";

export const FILMS = "films";
export const NOTES = "notes";

const unsplash = (who) => `Photo: ${who} / Unsplash`;

export const ARTICLES = [
  {
    slug: "spring",
    title: "Spring, and the painterly turn",
    dek: "A shepherd girl, her dog, and a mountain that wakes up. Eight minutes that look like a storybook come to life.",
    date: "2026-09-28",
    tag: FILMS,
    hero: ["images/photo-1018.jpg", "Green hills under low cloud, a road winding between them", unsplash("Andrew Ridley")],
    body: [
      ["p", "Spring came out of the Blender Animation Studio in 2019, directed by Andy Goralczyk. It follows a shepherd girl and her dog as they face the ancient spirits of the season. On paper that is a very small story. On screen it feels enormous."],
      ["p", "What struck me first was the texture. Every frame looks as if it has been painted over, with soft edges and light that pools in the grass instead of bouncing off it. Earlier open movies chased realism. This one chases a feeling."],
      ["video", "WhWc3b3KhnY", "Spring, Blender Open Movie", "Spring (2019), Blender Animation Studio. CC BY."],
      ["h", "Why it works"],
      ["p", "The camera rarely hurries. It lets the girl look before she acts, and it lets us look with her. When the spirits arrive the film does not explain them. It trusts you to be as awed and as frightened as she is."],
      ["quote", "A short film has no time to explain itself, so the best ones don't try."],
      ["p", "I have watched it a dozen times now, mostly with the sound up and the lights off. If you only watch one film from this list, make it this one."],
    ],
  },
  {
    slug: "seven_mornings",
    title: "Seven mornings of drawing outdoors",
    dek: "A week away from the screen, a sketchbook, and the stubborn business of getting water to look wet.",
    date: "2026-09-14",
    tag: NOTES,
    hero: ["images/photo-1015.jpg", "A deep blue fjord between grey cliffs, seen from high above", unsplash("Alexey Topolyanskiy")],
    body: [
      ["p", "Every autumn I take a week to draw from life. No reference photos, no undo, just a sketchbook, a tin of watercolours and whatever is in front of me. It is the best thing I do for my animation all year."],
      ["h", "Day one: the fjord"],
      ["p", "I started big, which was a mistake. A fjord from above is mostly distance, and distance is the hardest thing to draw. My first page was a muddle of blue. My second was better because I gave up on the far cliffs entirely and drew only the rock under my feet."],
      ["img", "images/photo-1039.jpg", "A tall waterfall dropping into a green, mossy gorge", unsplash("Andrew Coelho")],
      ["h", "Day three: falling water"],
      ["p", "Water is all timing. Drawn still, a waterfall looks like a white ribbon. The trick, which every animator learns eventually, is to draw what the water does rather than what it is: the break at the lip, the mist at the base, the dark rock showing through."],
      ["img", "images/photo-15.jpg", "A thin waterfall falling into a rocky stream between dark cliffs", unsplash("Paul Jarvis")],
      ["h", "Day seven: the lake"],
      ["p", "By the last morning I had stopped trying to finish anything. I drew the same lake six times in an hour, each one smaller and faster than the last. The sixth is the only one I kept."],
      ["img", "images/photo-10.jpg", "A forest of pines running down to a calm blue lake", unsplash("Paul Jarvis")],
      ["p", "I came home with forty pages and perhaps five good drawings. That is about the usual rate, and it is enough."],
    ],
  },
  {
    slug: "tears_of_steel",
    title: "Tears of Steel: when the render farm met a film set",
    dek: "Real actors, real Amsterdam streets, and a lot of robots added afterwards.",
    date: "2026-08-30",
    tag: FILMS,
    hero: ["images/photo-1067.jpg", "A city skyline at sunset, towers lit gold against the lake", unsplash("Kevin Young")],
    body: [
      ["p", "Tears of Steel was the Blender Foundation's fourth open movie, released in 2012 and directed by Ian Hubert. Where the earlier films were fully animated, this one was shot with live actors in Amsterdam and finished with visual effects."],
      ["p", "That made it a test of a different kind. Could free software track a handheld camera, clean up green screen and composite a robot into a real street? The answer, a little roughly in places, was yes."],
      ["video", "R6MlUcmOul8", "Tears of Steel, Blender VFX Open Movie", "Tears of Steel (2012), Blender Foundation. CC BY."],
      ["h", "Rough edges, honest work"],
      ["p", "The film is not perfect, and I like it more for that. You can see where the shots were hard. The acting is earnest, the dialogue is a little stiff, and the effects are ambitious beyond their budget. It feels like a film made by people learning in public."],
      ["img", "images/photo-1047.jpg", "A narrow brick alley with fire escapes and ivy, city towers beyond", unsplash("sergee bee")],
      ["p", "If you work in effects, watch it for the tracking shots. If you don't, watch it for the giant robot hand in the old church."],
    ],
  },
  {
    slug: "sintel",
    title: "Sintel and the long walk through snow",
    dek: "A girl, a baby dragon, and fifteen minutes that still break my heart.",
    date: "2026-08-12",
    tag: FILMS,
    hero: ["images/photo-29.jpg", "Jagged snow-covered mountains under a clear sky", unsplash("Go Wild")],
    body: [
      ["p", "Sintel was the Blender Foundation's third open movie, released in 2010 and directed by Colin Levy. A young woman named Sintel searches the world for a baby dragon she once rescued. I won't say how it ends, but I have never watched it without going quiet afterwards."],
      ["video", "eRsGyueVLvQ", "Sintel, Open Movie by Blender Foundation", "Sintel (2010), Blender Foundation. CC BY."],
      ["h", "A journey told in landscapes"],
      ["p", "Most of the film is walking. Snow, then marketplace, then desert, then mountain. Each landscape carries the mood of its part of the story, so the journey does the work that dialogue might have done in a longer film."],
      ["img", "images/photo-1036.jpg", "A snowy mountain camp with yellow tents against white peaks", unsplash("Wolfgang Lutz")],
      ["quote", "Sintel spends most of its running time walking, and the landscape tells the story."],
      ["p", "It is also a reminder of how much a short film can hold. Fifteen minutes, one character, one promise kept and one broken. Nothing more is needed."],
    ],
  },
  {
    slug: "big_buck_bunny",
    title: "The rabbit that proved a point",
    dek: "Big Buck Bunny is a slapstick cartoon about a very large rabbit. It is also the reason a whole generation of artists tried free software.",
    date: "2026-07-25",
    tag: FILMS,
    hero: ["images/photo-1043.jpg", "A sunny valley with tall pines and a granite cliff beside a river", unsplash("Christian Joudrey")],
    body: [
      ["p", "In 2008 the Blender Institute released Big Buck Bunny, a ten-minute comedy directed by Sacha Goedegebure. A gentle giant of a rabbit is bullied by three rodents, Frank, Rinky and Gimera, until they go one step too far."],
      ["p", "The story is classic cartoon revenge. The point of the project was something else: to show that a polished animated short could be made with free software, and then to give everything away. The film, the models and the production files were all released under Creative Commons."],
      ["video", "aqz-KE-bpKQ", "Big Buck Bunny, Blender Foundation Short Film", "Big Buck Bunny (2008), Blender Foundation. CC BY."],
      ["h", "Fur, grass and a lot of patience"],
      ["p", "Watch the meadow. Every blade of grass and every hair on the rabbit had to be rendered on hardware that would struggle with a phone game today. The team improved the software as they went, and those improvements stayed in Blender for everyone."],
      ["img", "images/photo-28.jpg", "A green forested gorge with a rocky stream bed and blue sky", unsplash("Jerry Adney")],
      ["p", "It is still the film I show people who ask what an open movie is. It is funny, it is generous, and it is a little bit mean, which is how a good cartoon should be."],
    ],
  },
];

/** How long an article takes to read, in whole minutes, at a steady 220 words a minute. */
export function minutesToRead(article) {
  const words = article.body.filter(([kind]) => kind === "p" || kind === "quote" || kind === "h").map(([, text]) => text).join(" ").split(/\s+/).length;
  return Math.max(1, Math.round((words + article.dek.split(/\s+/).length) / 220));
}

/** A date written the way the reader's language writes it. */
export function written(date) {
  return new Date(`${date}T12:00:00Z`).toLocaleDateString(undefined, { day: "numeric", month: "long", year: "numeric" });
}
