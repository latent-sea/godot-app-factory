# The factory's canonical look: what it must fix

The apps' shared look will live in the factory, not in gd-chime (D-004).
This lists what real use of the Checklist showed it must get right. Each
entry: what was seen, where, and what "fixed" means.

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
