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

## Carried over from the Checklist

- Phone sizing (`apps/checklist/phone_look.gd`, D-007).
- The palette, page margins, title size, tick boxes, add field and the
  filled button with its faded disabled state
  (`apps/checklist/checklist.gd`, `look()`).
