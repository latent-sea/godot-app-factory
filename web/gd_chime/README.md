# gd-chime for the web

gd-chime rewritten in JavaScript for the browser: the same described
interface, the same floor, built into the DOM instead of Godot's controls.
No build step, no dependencies, about 100 KB unminified. Every file is an
ES module a browser loads as it is.

An application says what its screens hold, and the floor builds them. A
model rings a bell that carries nothing when a fact changes, and every piece
reading that fact draws again, so a fact lives in one place. A press goes
through one door, which may refuse it with a reason shown on the button.

MIT licensed, as gd-chime is; see `LICENCE`.

## A first screen

The crate counter from gd-chime's README, in JavaScript:

```js
import { ChimeApp, Controller, Phrase } from "./gd_chime/gd_chime.js";

const COUNTS = "counts_a_crate";

class Crates extends Controller {
  constructor(chimes) { super(chimes); this.counted = this.value(0); }
  answers() { return [COUNTS]; }
  would() { return this.counted.read() >= 10 ? Phrase.of("Ten crates is all the stall holds") : null; }
  told() { this.counted.update((n) => n + 1); return null; }
}

class Stall extends ChimeApp {
  declare(register) { register.declareAll({ [COUNTS]: ["Count a crate"] }); }
  describe() {
    const ui = this.ui;
    const crates = this.model(new Crates(this.chimes));
    const shown = crates.counted.map((n) => Phrase.with("%d crates counted", [n]));
    return ui.app("stall", [ui.screen("counting", [ui.text(shown), ui.button(COUNTS)])]);
  }
}

ChimeApp.start(Stall, document.getElementById("app"));
```

`tooling/create_site.py` makes a site like this, ready to build on.

## What is ported

The floor, faithfully, from the GDScript and its tests:

| Here | gd-chime | What it is |
| --- | --- | --- |
| `reads.js` | `reads.gd` | what a piece of work read, noted as it is read |
| `bell.js`, `belfry.js`, `chimes.js` | the same | bells, and who hears which; `follow` re-runs work when what it read moves |
| `own_bell.js`, `value.js`, `bound.js` | the same | a model's values, rung once at the frame's end; bound values and `map` |
| `controller.js` | `controller.gd` | a model: `value`, `answers`, `would`, `told` |
| `commands.js` | `commands.gd` | the door: one handler, refusals, the last command, `COMMAND_RAN`, no dispatch inside a ring |
| `actions.js` | `actions.gd` | the register: an action's words and keys |
| `driver.js`, `place.js` | `driver.gd`, `chart.gd`, `place.gd` | places, moves, pop-ups over the app, history and Back |
| `phrase.js`, `language.js` | the same | English as the key, counts by the language's plural rule, catalogues |
| `ui.js`, `desc.js` | `describe*.gd`, `desc.gd` | the vocabulary, below, built into the DOM |
| `chime_app.js` | `chime_app.gd` | the app: `look`, `sources`, `declare`, `describe`, `probe`, `broken` |
| `look.js`, `themes.js` | `theme*.gd` | one neutral look as CSS custom properties, and the style names |
| `walk.js` | the factory's `walk.gd` | a probe: presses, reading the screen, claims, `PROBE OK` |

The vocabulary: `text`, `image` (with alt text), `embed` (another page in a frame, a video above all, shown as a poster until pressed), `surface`, `paragraph`, `link`, `divider` (with a style),
`pressable`, `pressLocal`, `reason`, `button`, `field` (with a visible label and autocomplete), `area`, `row`,
`column`, `grid`, `stack`, `scroll`, `each`, `eachAcross`, `when`, `local`,
`bound`, `parameter`, and the places `app`, `screen`, `tabs`, `popUp`. The
chained marks: `grow`, `basis`, `atMost`, `span`, `wraps`, `hidesEmpty`,
`keeps`, `takesFocus`, `blocksNothing`, `noFocus`, `absentWhenRefused`,
`currentWhile`, `goesTo`, `opens`, `named`.

The rules kept: a bell carries nothing; a fact lives in one model; a
command goes through one door with one handler; a refusal is a phrase shown
where the press happened; nothing dispatches inside a ring; English is the
key and data is never translated; a description with a fault is reported
and the app stands empty.

## What is not ported yet

Each is a gd-chime feature with no web counterpart here yet. Port one when
a site needs it.

- **The looks.** One neutral look ships; gd-chime has ten, and a theme per
  component family.
- **The recipes.** Shell, AdaptiveNav, Tabs as a strip, Sheet, Drawer,
  Table, DataGrid, the charts, the form recipes, the notification tray and
  the rest of `gd_chime_recipes.gd`.
- **Motion.** No transitions, keyframes or pulse.
- **Prompts and glow**, notifications, sounds, and remapping the keys.
- **Touch gestures** (swipe, pull to refresh) and the pad.
- **Long lists**: `virtual_list`, `cells`; and drawing: `canvas`,
  `pan_zoom`, `pinned`.
- **The leave guard** (`asks_before_leaving`), kept locals, and
  `SettingsFile` (saving would be the browser's storage).
- **The browser's Back button** does not yet go back a screen.
- **The startup check** names undeclared actions, the driver's own
  commands on a button, moves to no place, and actions nothing answers; not
  the rest of gd-chime's list.

## How it is checked

- `tests/test_*.mjs`: the floor under Node's own test runner (`node --test`),
  ported from the claims of gd-chime's own tests.
- `tests/ui/`: a stall using every primitive above, walked by its probe in
  a headless Chrome: refusals on a button's face, a field's refusal, a
  keyed list, a link carrying its parameter, a pop-up closed by Escape and
  by its own Close, a key the app declares, a change of language.

`tooling/check_site.py` runs both, then every site's own probe.

## Where it lives

Here, in the factory, for now (D-012). It is gd-chime's, not the factory's:
it belongs beside the addon in gd-chime's own folder, mirrored and pinned
the way the addon is (D-001). Moving it is a copy of this folder and a pin
in `dependencies.json`; `tooling/install_site.py` is the only thing that
reads its path.
