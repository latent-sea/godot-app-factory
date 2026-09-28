# D-008: Every app has the same Settings, and text size is one of them

**Problem.** At full phone sizing (D-007) every word came out about 28 dp,
twice Android's usual 14-16 dp: "everything is too chunky". Asked to pick a
smaller size, you asked for a setting instead, common to every app.

**Decision.** A settings service (`services/settings/`) that every app
installs. A gear in the first screen's title row opens it:
- **Text size** is a slider, 50-100% of gd-chime's monitor sizes, 65% at first.
- **Haptics** gives a short buzz on each tap, on at first.
- **Reset app data** asks first, deletes the app's data files, and starts the app again.
- **About** gives the app's name and version, and Latensea Productions.

The settings are kept in `user://factory_settings.json`, apart from the
app's data, so a reset keeps them. The look reads the text size as it is
made (`look/phone.gd`). A change makes the look again and puts it on the
canvas, so every screen resizes at once.

**Why.** One setting in one place reaches every app. The look already owns
sizing (D-007), so text size is one more number in it.

**Alternatives.** A fixed smaller size (no choice), or three steps (Small,
Medium, Large); you chose a slider.

**Reconsider if** an app needs settings of its own. The service would then
take extra rows from the app.
