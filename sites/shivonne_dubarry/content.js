// What the page says: every word of it here, so it can be filled in without
// touching the layout (site.js). Everything marked placeholder is waiting for
// her own words; nothing here is written for her.

export const SITE = {
  name: "Shivonne Dubarry",
  disciplines: ["Psychology", "Anthropology", "Sociology"],
  headline: "Headline placeholder: who she works with, in one sentence.",
  intro: "Introduction placeholder: two or three sentences in her words on how she works and what someone can expect. Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor.",
  credentials: "Credentials placeholder: her qualifications.",
  email: "hello@example.com",
  location: "Location placeholder: where she practises, and whether sessions are online, in person or both.",
  registration: "Registration placeholder: her professional body and registration number.",
  crisis: "This page and its booking are not for emergencies. If you are in crisis or at risk, call your local emergency number. Crisis line placeholder: the number to call where she practises.",
  land: "Land acknowledgement placeholder: her words, if she chooses to include one.",
};

const LOREM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.";

/** The areas she works with: from the subjects she has written on; the words under each are hers to write. */
export const AREAS = [
  { id: "migration", name: "Migration and belonging", text: `Placeholder: a sentence or two in her words. ${LOREM}` },
  { id: "trauma", name: "Family and intergenerational trauma", text: `Placeholder: a sentence or two in her words. ${LOREM}` },
  { id: "place", name: "Place and ancestry", text: `Placeholder: a sentence or two in her words. ${LOREM}` },
  { id: "post_indenture", name: "Post-indenture histories", text: `Placeholder: a sentence or two in her words. ${LOREM}` },
  { id: "identity", name: "Identity and indigeneity", text: `Placeholder: a sentence or two in her words. ${LOREM}` },
];

export const ABOUT = {
  paragraphs: [
    `Biography placeholder: who she is, her background and why she does this work. ${LOREM}`,
    `Placeholder: her approach and the traditions she draws on. ${LOREM}`,
  ],
  training: "Training placeholder: her qualifications, training and memberships.",
};

/** How working with her goes, in three steps. */
export const STEPS = [
  { name: "Get in touch", text: "Placeholder: how to make a first booking or ask a question." },
  { name: "A first session", text: "Placeholder: what happens in the first session." },
  { name: "Working together", text: "Placeholder: how sessions continue from there, and how often." },
];

/** The sessions she offers, booked and priced: names, lengths and fees all placeholders. */
export const SESSIONS = [
  { id: "consultation", name: "Initial consultation", minutes: 50, fee: "Fee placeholder", text: "Placeholder: what the first session is for." },
  { id: "individual", name: "Individual session", minutes: 50, fee: "Fee placeholder", text: "Placeholder: an ongoing session." },
];

export const FEES_NOTE = "Placeholder: cancellation policy, reduced-fee places, and any rebates or insurance.";

export const QUESTIONS = [
  ["Is what I say confidential?", "Answer placeholder: confidentiality and its limits, in her words."],
  ["Do you work online?", "Answer placeholder: how online sessions work, and in-person ones if she offers them."],
  ["How many sessions will I need?", "Answer placeholder: how long people usually work with her."],
  ["What if I'm not sure counselling is for me?", "Answer placeholder: what she suggests for someone unsure."],
  ["How do I cancel or move a session?", "Answer placeholder: her cancellation policy."],
];

/**
 * When she can be booked: a placeholder until a real calendar is connected.
 * The next fourteen days from tomorrow, weekdays only, some hours taken, in
 * the visitor's own time.
 */
export function openings(from = new Date()) {
  const hours = [9, 10, 11, 13, 14, 15, 16];
  const days = [];
  for (let ahead = 1; ahead <= 14; ahead++) {
    const date = new Date(from.getFullYear(), from.getMonth(), from.getDate() + ahead);
    const weekday = date.getDay();
    const open = weekday !== 0 && weekday !== 6;
    const times = open ? hours
      .filter((hour) => (date.getDate() * 3 + hour) % 4 !== 0)
      .map((hour) => new Date(date.getFullYear(), date.getMonth(), date.getDate(), hour)) : [];
    days.push({ day: dayId(date), date, times: times.map((at) => ({ id: `${dayId(at)}T${String(at.getHours()).padStart(2, "0")}:00`, at })) });
  }
  return days;
}

function dayId(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;
}
