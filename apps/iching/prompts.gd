extends GdChime.Controller

## The saved prompts: each {"id": int, "name": String, "text": String}, in the
## order they were made. The one place they live; the screens read them.
## Kept between runs by gd-chime's SettingsFile, through saved() and restore().
##
## ONE PROMPT IS OPEN FOR EDITING at a time, and its name and text change as
## they are typed. A new prompt starts empty and opens at once; a prompt
## left with no text when its editor closes is dropped (drop_if_empty).
## An id is never reused.

const ADDS := &"adds_a_prompt"
const OPENS := &"opens_a_prompt"
const RENAMES := &"renames_a_prompt"
const REWRITES := &"rewrites_a_prompt"
const DELETES := &"deletes_a_prompt"

var prompts := value([])
## The id of the prompt being edited, or null.
var editing := value(null)
var _next_id := 1
var _door: Object  # the app's commands, to open a new prompt's editor
var _edit_place: StringName


func _init(chimes: GdChime.Chimes, door: Object = null, edit_place: StringName = &"") -> void:
	super(chimes)
	_door = door
	_edit_place = edit_place


func answers() -> Array[StringName]:
	return [ADDS, OPENS, RENAMES, REWRITES, DELETES]


func would(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	match action:
		OPENS, DELETES:
			if index_of(payload.get("id")) < 0:
				return GdChime.Phrase.of("That prompt is gone")
		RENAMES, REWRITES:
			if index_of(editing.read()) < 0:
				return GdChime.Phrase.of("No prompt is open")
	return null


func told(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	var list: Array = prompts.read()
	match action:
		ADDS:
			var id := _next_id
			_next_id += 1
			list.append({"id": id, "name": "", "text": ""})
			prompts.set_value(list)
			editing.set_value(id)
			if _door != null:
				return _door.dispatch(GdChime.Chimes.GLOBAL, GdChime.Driver.GO, {"place": _edit_place, "parameter": id})
			return null
		OPENS:
			editing.set_value(int(payload["id"]))
			return null
		RENAMES:
			list[index_of(editing.read())]["name"] = str(payload.get("line", ""))
		REWRITES:
			list[index_of(editing.read())]["text"] = str(payload.get("text", ""))
		DELETES:
			list.remove_at(index_of(payload["id"]))
	prompts.set_value(list)
	return null


## When the editor closes: the prompt it held is dropped if it has no text.
func drop_if_empty() -> void:
	var at := index_of(editing.read())
	if at >= 0 and str(prompts.read()[at]["text"]).strip_edges().is_empty():
		var list: Array = prompts.read()
		list.remove_at(at)
		prompts.set_value(list)
	editing.set_value(null)


## A prompt's name as shown: as written, or its first words when it has none.
static func name_of(prompt: Dictionary) -> String:
	var name := str(prompt.get("name", "")).strip_edges()
	if not name.is_empty():
		return name
	var first_line := str(prompt.get("text", "")).strip_edges().get_slice("\n", 0)
	if first_line.is_empty():
		return "New prompt"
	return first_line if first_line.length() <= 40 else first_line.left(39) + "…"


## The prompt with this id, or {} when there is none.
func find(id: Variant) -> Dictionary:
	var at := index_of(id)
	return {} if at < 0 else prompts.read()[at]


func index_of(id: Variant) -> int:
	if id == null:
		return -1
	var list: Array = prompts.read()
	for at: int in list.size():
		if list[at]["id"] == int(id):
			return at
	return -1


## What SettingsFile writes: prompts with text only.
func saved() -> Dictionary:
	var kept: Array = prompts.read().filter(func(one: Dictionary) -> bool: return not str(one["text"]).strip_edges().is_empty())
	return {"prompts": kept.duplicate(true)}


## What SettingsFile read back. A save of the wrong shape is left unread.
func restore(save: Dictionary) -> void:
	var shape := GdChime.SaveShape as GDScript
	var one: Callable = shape.record({"id": shape.number(), "name": shape.words(), "text": shape.words()})
	if shape.refused(shape.record({"prompts": shape.list_of(one)}), save, "the prompts"):
		return
	var back: Array = []
	for kept: Dictionary in save["prompts"]:
		# JSON hands whole numbers back as floats.
		back.append({"id": int(kept["id"]), "name": kept["name"], "text": kept["text"]})
		_next_id = maxi(_next_id, int(kept["id"]) + 1)
	prompts.set_value(back)
