# The factory's canonical look: what it must fix

The apps' shared look will live in the factory, not in gd-chime (D-004).
This lists what real use of the Checklist showed it must get right. Each
entry: what was seen, where, and what "fixed" means.

## Chosen: dark navy glass (27 Sep 2026)

From a reference image you chose: a navy ground, cards a shade lighter with
thin cool outlines, light words, teal as the main accent (filled pill
buttons with a soft glow, links, the field being typed in) and violet as the
second (ticks, changing-line marks). Faded states are worked out from the
palette, so a disabled button reads as off on any ground. Splash screens and
icons match. Added after: filled buttons are a teal-to-cyan gradient with a soft glow
(`services/look/gradient_pill.gd`, since Godot's own boxes can't round a
gradient), and every word is in Manrope (SIL Open Font License), titles
bolder. Still to consider: gd-chime's own pieces (the drawer's close button, the radio's chosen bar) that don't
yet take the accent.

## Fixed: unequal side margins on lists

- **Seen:** on the phone, 27 Sep 2026: the margins either side weren't equal.
- **Cause:** gd-chime's scroll always reserves room for a vertical scroll
  bar, so list rows stopped short on the right.
- **Fixed:** the look gives scroll bars no size; lists are swiped, as on any
  phone. Measured in a render: 63 px either side.

## Rule: a disabled control just looks faded, with no reason shown

- **Seen:** on a phone, 27 Sep 2026. With nothing ticked, "Clear done" went
  grey with "Nothing is ticked yet" under it, and the two read as two
  separate things. A user can't tell which is the button.
- **Decided (you):** most disabled things don't need an explicit reason.
  A disabled button is faded grey, nearly white, and says nothing more.
- **Done in the Checklist:** the button is built from `ui.pressable` with
  its words only (gd-chime's `ui.button` always adds the reason line), and
  its `inert` and `refusing` states are faded. The probe checks that
  pressing it while disabled shows no reason.
- **For the shared look:** make this the default for every app's buttons,
  and use a visible reason only where a person couldn't otherwise work out
  why something is unavailable.

## Rule: no focus frames on a phone

- **Seen:** in phone renders of the I Ching, 27 Sep 2026. gd-chime puts
  focus on a screen's first press when it opens and draws a heavy ink ring
  round it, which reads as a frame round something nobody chose.
- **Done:** the look's LINK and CARD styles draw no focus frame. Fields keep
  theirs (the teal outline while typing), since that one means something.
- **Still open:** gd-chime's own recipes (a drawer's close button) keep the
  ring; they would need dressing type by type.

## Fixed: a count of letters was treated as a size

- **Seen:** the I Ching's notification tray was 1,500 px wide on a phone.
- **Cause:** phone sizing multiplied Notice `letters`, a count, as if it were
  pixels. Counts are now left alone, and a test says so.

## Carried over from the Checklist

- Phone sizing (`apps/checklist/phone_look.gd`, D-007).
- The palette, page margins, title size, tick boxes, add field and the
  filled button with its faded disabled state
  (`apps/checklist/checklist.gd`, `look()`).

## Fixed: links stayed faded after they could be used

- **Seen:** in Notes phone renders, 27 Sep 2026. The editor's "‹ Notes",
  Pin and Copy were drawn faded though they worked. The I Ching's Back had
  the same fault.
- **Cause:** gd-chime re-inks a press's words only when its box changes,
  and every LINK state shared one empty box. A link built while it could
  not be used (a screen's Back before the screen shows) kept its faded ink.
- **Done:** the faded states have a box of their own, and a test says so.

## Rule: a press has one ink

- A pressable inks every word on it alike, so words that matter less on a
  card or row are made smaller, not quieter. The Checklist's ticked items
  are marked by the tick for the same reason.

## Added: a loading screen

- **Asked:** 27 Sep 2026, "Latensea Productions" and a loading animation
  when an app opens, instead of a blank screen.
- **Done:** `FactoryLook.splash(self)` in describe(). It shows the name and a
  teal-to-violet wave on the navy ground for 1.6 s, then fades to the app
  (`services/look/splash.gd`). Godot's own boot splash stays plain navy, so
  the phone goes navy, then the name and wave, then the app. A probe gets
  no splash.
