# The factory's canonical look: what it must fix

The apps' shared look will live in the factory, not in gd-chime (D-004).
This lists what real use of the Checklist showed it must get right. Each
entry: what was seen, where, and what "fixed" means.

## A refused button's reason looks like a second button

- **Seen:** on a phone, 27 Sep 2026. With nothing ticked, "Clear done" goes
  grey and "Nothing is ticked yet" appears under it. The two read as two
  separate buttons, as if they were the same kind of thing.
- **Where:** gd-chime's `ui.button` draws the reason under the action's
  words; the Checklist's look doesn't dress either state yet.
- **Fixed when:** a refused button reads as one control, clearly unusable,
  with its reason as a quiet note that can't be mistaken for something to
  press. Checked in a phone-sized render and on the phone.

## Carried over from the Checklist

- Phone sizing (`apps/checklist/phone_look.gd`, D-007).
- The palette, page margins, title size, tick boxes and add field
  (`apps/checklist/checklist.gd`, `look()`).
