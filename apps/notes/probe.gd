extends "res://addons/factory_testkit/walk.gd"

## Notes walked as a person would: writes notes, finds them by search and
## by tag, pins one, copies one, deletes one with a swipe, and leaves a new
## note empty. The walking itself is the factory's testkit.

const T := preload("res://note_text.gd")
const Notebook := preload("res://notebook.gd")


func run() -> void:
	await begin()
	claim("it opens on the list", top() == &"list")
	claim("an empty notebook says how tags work", shows_part("No notes yet"))
	claim("the search isn't typing as the list opens (a phone's keyboard would rise)", not fields()[0].has_focus())

	await walk_settings()
	# Write a note: New note opens an empty editor.
	await press(Notebook.ADDS)
	claim("New note opens the editor", top() == &"edit")
	claim("the editor opens empty", fields()[0].text == "" and _area_text() == "")
	type_into(fields()[0], "Moving")
	type_into_area("Book the van #home")
	await frames()
	claim("the note is kept as typed", app.notebook.notes.read()[0]["title"] == "Moving" and app.notebook.notes.read()[0]["text"] == "Book the van #home")
	claim("the editor shows when it was written", shows(T.stamp(app.notebook.notes.read()[0]["created"])))
	await press(Notebook.COPIES)
	claim("Copy copies the title and the text", app.notebook.last_copied == "Moving\n\nBook the van #home")
	claim("and says it was copied", shows("Copied"))
	await _back()
	claim("back returns to the list", top() == &"list")
	claim("the list shows the note by its title", shows("Moving") and shows("Book the van #home"))
	claim("under this month's heading", shows(T.month_heading(app.notebook.notes.read()[0]["created"])))

	# A second note; then a new note left empty is dropped.
	await press(Notebook.ADDS)
	type_into_area("Garden ideas\nRaised beds #garden")
	await frames()
	await _back()
	await press(Notebook.ADDS)
	await _back()
	claim("a new note left empty is dropped", app.notebook.notes.read().size() == 2)
	claim("a note with no title is shown by its first line", shows("Garden ideas") and shows("Raised beds #garden"))
	claim("every tag is offered to choose", shows("#garden") and shows("#home"))

	# Newest first; pinning the older one lifts it under Pinned.
	claim("newest first", _titles() == ["Garden ideas", "Moving"])
	await _open("Moving")
	claim("tapping a note opens it, holding what was written", top() == &"edit" and fields()[0].text == "Moving" and _area_text() == "Book the van #home")
	claim("a note opened again isn't copied yet", shows("Copy"))
	await press(Notebook.PINS)
	claim("Pin becomes Unpin", shows("Unpin"))
	await _back()
	claim("a pinned note comes first, under Pinned", _titles() == ["Moving", "Garden ideas"] and shows("Pinned"))

	# Finding: a search, then a tag.
	type_into(fields()[0], "RAISED beds")
	await frames()
	claim("a search shows only the notes holding every word", _titles() == ["Garden ideas"])
	type_into(fields()[0], "nothing like this")
	await frames()
	claim("a search matching nothing says so", _titles().is_empty() and shows("No notes match."))
	type_into(fields()[0], "")
	await frames()
	await _choose_tag("#home")
	claim("choosing a tag shows only its notes", _titles() == ["Moving"])
	await _choose_tag("#home")
	claim("choosing it again shows every note", _titles().size() == 2)

	# Swipe the unpinned note away.
	await swipe_left(_row("Garden ideas"))
	claim("swiping left deletes that note", _titles() == ["Moving"] and app.notebook.notes.read().size() == 1)
	claim("and its tag is gone with it", not shows("#garden"))

	var kept: Variant = JSON.parse_string(FileAccess.get_file_as_string(app.saving.get_file_path()))
	var saved: Array = [] if kept == null else kept.get("notes", {}).get("notes", [])
	claim("the notes are saved as they change", saved.size() == 1 and saved[0]["title"] == "Moving" and saved[0]["pinned"])
	finish()


## The notes' rows, top to bottom, by the title each shows.
func _titles() -> Array:
	return pressables(Notebook.OPENS).map(func(row: Control) -> String: return _words_in(row)[0])


func _row(title: String) -> Control:
	for row: Control in pressables(Notebook.OPENS):
		if _words_in(row)[0] == title:
			return row
	claim("there is a row for %s" % title, false)
	return null


func _open(title: String) -> void:
	var row := _row(title)
	if row != null:
		row.pressed()
	await frames(4)


func _choose_tag(words: String) -> void:
	for chip: Control in pressables(Notebook.PICKS_TAG):
		if _words_in(chip) == [words]:
			chip.pressed()
			await frames(4)
			return
	claim("there is a tag %s to choose" % words, false)


func _words_in(part: Node) -> Array:
	return part.find_children("*", "Label", true, false).filter(func(label: Node) -> bool:
		return (label as Label).is_visible_in_tree() and not (label as Label).text.is_empty()).map(func(label: Node) -> String: return (label as Label).text)


func _area_text() -> String:
	for area: Node in app.find_children("*", "TextEdit", true, false):
		if (area as Control).is_visible_in_tree():
			return (area as TextEdit).text
	return "(no area)"


## The editor's back link, pressed.
func _back() -> void:
	var part := pressable(&"goes_back")
	claim("back can be pressed", part != null and part.is_usable())
	if part != null:
		part.pressed()
	await frames(4)
