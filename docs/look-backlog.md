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
- **Fixed:** the look gave scroll bars no size; lists are swiped, as on any
  phone. Measured in a render: 63 px either side.
- **Fixed properly in gd-chime 4e454ab** (asked for 29 Sep 2026, when a long
  prompt in I Ching showed no sign of more below). A scroll keeps equal room
  either side, and where the reader is shows as a thin mark over the right
  padding that takes no room. Text areas get the same mark. The look no
  longer hides anything; it makes the mark 6 base pixels thick and in the
  accent, and keeps it shown while there is more.
- **Then, gd-chime 09eeb7c** (asked 30 Sep 2026): a finger drawn up a text
  area selected words instead of scrolling it, and the mark couldn't be
  grabbed. Now a swipe scrolls a text area as it does a list, and the mark
  can be dragged. The I Ching probe swipes a long prompt and checks it moved.

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
- **First try, wrong:** the screen was built by the app itself, so it only
  appeared once the app had loaded, flashed for a second, and left the
  blank wait as it was.
- **Done:** Godot's boot splash is now the name (`services/look/splash.png`,
  drawn by `tooling/make_splash.py`), shown the moment the engine starts.
  The main scene is `opening.tscn`, which draws the same image in the same
  place with the wave moving while `main.tscn` loads on another thread,
  then fades to the app. A probe gets the app at once.

## Rule: every button looks like a button

- **Asked:** 28 Sep 2026: "I don't like buttons that look like labels/words.
  Make them different colour with glow." and "I see no gradients."
- **Done:**
  - Every button is a glowing gradient pill. ACTION is teal, LINK (lesser
    buttons: Back, New note, Pin, Copy, Prompts) is violet, and DANGER is red.
    The gear is a round glowing button.
  - Cards have an edge running teal to violet. Titles are a teal-to-violet
    gradient (a shader, `enliven.gd`).
  - The page ground deepens from navy to violet, with two slowly drifting
    pools of light (`backdrop.gd`).

## Fixed: the gear didn't always answer a tap

- **Cause:** the text-size setting scaled the touch minimum along with the
  words, so every button's least size fell from 48 dp to about 31 dp. The
  gear, with no words, fell to a sliver of that.
- **Done:** the touch minimum is always 48 dp (`Phone.dp_scale()`), and the
  gear's box asks for a finger-sized square. The probe now taps the gear as
  a finger does and checks its size.

## Added: animation and long press

- Screens push each other over 0.32 s, and list rows slide in from the right
  and out again (gd-chime's Motion tokens, set in the look).
- A button shrinks as it is touched and springs back as it is let go.
- A finger held on a row for half a second opens the row's menu (Open,
  Delete). gd-chime has no long press, so `enliven.gd` turns one into the
  right press gd-chime's menus open on.
- Words on a button sit in its middle, since buttons are a finger tall.
- **Seen in renders:** gd-chime skips animations while frames run long,
  as on this software-rendered desktop. Stepping its clock by hand shows
  the push working.

## Moved into gd-chime (T-615, gd-chime 886d9d9)

The factory asked gd-chime for six things; all landed, and `shell/enliven.gd`
is gone. The factory now only sets the tokens:
- **Long press** opens a row's menu (Touch `long_press`, 500 ms by default).
- **A press gives under a finger** (Motion `press_scale`: the look sets 940).
- **Words sit in the middle of a press** taller than them (gd-chime's default).
- **A press re-inks its words** on a state change even when its box is the same.
- **Gradient words** from the Theme (`gradient_from` / `gradient_to` on Title).
- **A ground that moves** on gd-chime's clock (`moves` on the page's type;
  `backdrop.gd` draws at the time it is handed). It holds still under
  reduced motion, over the frame budget, and when a test steps the clock.

Not yet: a buzz on a long press. gd-chime rings its `held` bell but hangs it
for no one, and the settings service can't hang it without clashing in tests.

## Still gd-chime candidates (not asked for yet)

- **Screen density.** gd-chime's sizes are for a monitor, and every phone
  app would need them scaled (`look/phone.gd`, D-007).
- **A question's cancel is "Close"**, where "Cancel" reads better.
