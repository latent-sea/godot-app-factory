extends GdChime.Controller

## The notes, and how the list is being looked at: what is searched for and
## which tag is chosen. The one place these facts live; the screens read them.
## Kept between runs by gd-chime's SettingsFile, through saved() and restore()
## - the notes only; a search starts fresh.
##
## ONE NOTE IS OPEN FOR EDITING at a time; its title and text change as they
## are typed. A new note starts empty and opens at once; a note left empty
## when its editor closes is dropped (drop_if_empty). An id is never reused.

const T := preload("res://note_text.gd")

const ADDS := &"adds_a_note"
const OPENS := &"opens_a_note"
const RETITLES := &"retitles_a_note"
const REWRITES := &"rewrites_a_note"
const PINS := &"pins_a_note"
const COPIES := &"copies_a_note"
const DELETES := &"deletes_a_note"
## Deletes the note open in the editor, and leaves the editor.
const DELETES_OPEN := &"deletes_the_open_note"
const SEARCHES := &"searches_the_notes"
const PICKS_TAG := &"picks_a_tag"

var notes := value([])
## The id of the note being edited, or null.
var editing := value(null)
var search := value("")
## The tag chosen, or "" for every note.
var tag := value("")
## Whether the note open now has been copied since it was opened.
var copied := value(false)
## What was copied last, for a probe that has no clipboard to read.
var last_copied := ""
var _next_id := 1
var _door: Object  # the app's commands, to open a new note's editor
var _edit_place: StringName
## What time it is, in unix seconds; a test may fix it.
var clock: Callable = func() -> int: return int(Time.get_unix_time_from_system())


func _init(chimes: GdChime.Chimes, door: Object = null, edit_place: StringName = &"") -> void:
	super(chimes)
	_door = door
	_edit_place = edit_place


func answers() -> Array[StringName]:
	return [ADDS, OPENS, RETITLES, REWRITES, PINS, COPIES, DELETES, DELETES_OPEN, SEARCHES, PICKS_TAG]


func would(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	match action:
		OPENS, DELETES:
			if index_of(payload.get("id")) < 0:
				return GdChime.Phrase.of("That note is gone")
		RETITLES, REWRITES, PINS, DELETES_OPEN:
			if index_of(editing.read()) < 0:
				return GdChime.Phrase.of("No note is open")
		COPIES:
			if index_of(editing.read()) < 0 or T.copied(open_note()).is_empty():
				return GdChime.Phrase.of("Nothing to copy yet")
	return null


func told(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	var list: Array = notes.read()
	match action:
		ADDS:
			var id := _next_id
			_next_id += 1
			list.append({"id": id, "title": "", "text": "", "created": clock.call(), "pinned": false})
			notes.set_value(list)
			editing.set_value(id)
			copied.set_value(false)
			if _door != null:
				return _door.dispatch(GdChime.Chimes.GLOBAL, GdChime.Driver.GO, {"place": _edit_place, "parameter": id})
			return null
		OPENS:
			editing.set_value(int(payload["id"]))
			copied.set_value(false)
			return null
		RETITLES:
			list[index_of(editing.read())]["title"] = str(payload.get("line", ""))
		REWRITES:
			list[index_of(editing.read())]["text"] = str(payload.get("text", ""))
		PINS:
			var one: Dictionary = list[index_of(editing.read())]
			one["pinned"] = not one["pinned"]
		COPIES:
			last_copied = T.copied(open_note())
			DisplayServer.clipboard_set(last_copied)
			copied.set_value(true)
			return null
		DELETES:
			list.remove_at(index_of(payload["id"]))
		DELETES_OPEN:
			list.remove_at(index_of(editing.read()))
			notes.set_value(list)
			_forget_lost_tag()
			editing.set_value(null)
			# out of the editor once the question asked first has come down
			if _door != null:
				_door.dispatch.call_deferred(GdChime.Chimes.GLOBAL, GdChime.Driver.GOES_BACK, {})
			return null
		SEARCHES:
			search.set_value(str(payload.get("line", "")))
			return null
		PICKS_TAG:
			# Choosing the tag already chosen shows every note again.
			var chosen := str(payload.get("tag", ""))
			tag.set_value("" if chosen == tag.read() else chosen)
			return null
	notes.set_value(list)
	_forget_lost_tag()
	return null


## The tag chosen is let go once no note carries it, so the list can't stay filtered to nothing.
func _forget_lost_tag() -> void:
	if str(tag.read()) != "" and not T.all_tags(notes.read()).has(tag.read()):
		tag.set_value("")


## When the editor closes: the note it held is dropped if it has no title and no text.
func drop_if_empty() -> void:
	var at := index_of(editing.read())
	if at >= 0 and T.copied(notes.read()[at]).is_empty():
		var list: Array = notes.read()
		list.remove_at(at)
		notes.set_value(list)
		_forget_lost_tag()
	editing.set_value(null)


## The note open for editing, or {}.
func open_note() -> Dictionary:
	var at := index_of(editing.read())
	return {} if at < 0 else notes.read()[at]


func index_of(id: Variant) -> int:
	if id == null:
		return -1
	var list: Array = notes.read()
	for at: int in list.size():
		if list[at]["id"] == int(id):
			return at
	return -1


## What SettingsFile writes: notes with something in them.
func saved() -> Dictionary:
	var kept: Array = notes.read().filter(func(one: Dictionary) -> bool: return not T.copied(one).is_empty())
	return {"notes": kept.duplicate(true)}


## What SettingsFile read back. A save of the wrong shape is left unread.
func restore(save: Dictionary) -> void:
	var shape := GdChime.SaveShape as GDScript
	var one: Callable = shape.record({"id": shape.number(), "title": shape.words(), "text": shape.words(), "created": shape.number(), "pinned": shape.one_of([true, false])})
	if shape.refused(shape.record({"notes": shape.list_of(one)}), save, "the notes"):
		return
	var back: Array = []
	for kept: Dictionary in save["notes"]:
		# JSON hands whole numbers back as floats.
		back.append({"id": int(kept["id"]), "title": kept["title"], "text": kept["text"], "created": int(kept["created"]), "pinned": kept["pinned"]})
		_next_id = maxi(_next_id, int(kept["id"]) + 1)
	notes.set_value(back)
