# D-007: Phone sizing is done in the look, not in gd-chime

**Problem.** gd-chime draws a 1920x1080 canvas (1080x1920 upright)
stretched to the window, with sizes meant for a monitor. On a phone the same
canvas spans a few inches, so words and targets came out about a third of
the size they need (seen in a 1080x2400 render before any phone test).

**Decision.** The app's look multiplies its sizes by the screen's short side
in dp against the canvas's, on mobile only, and sets every pressable to at
least 48 dp (`apps/checklist/phone_look.gd`). Timings and shares are left
alone.

**Why.** Chosen by you over changing gd-chime: it stays out of gd-chime and
fits the coming factory-owned look (D-004).

**Alternatives.** Teaching gd-chime's canvas about screen density (fixes every
app and Lizarding at once, but changes gd-chime); overriding gd-chime's base
size on mobile (fights its required settings).

**Reconsider if** a look can't reach something that needs to grow, or
gd-chime gains density handling of its own.
