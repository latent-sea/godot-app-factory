extends GdChime.Controller

## The saved prompts: each {"id": int, "name": String, "text": String}, in the
## order they were made. The one place they live; the screens read them.
## Kept between runs by gd-chime's SettingsFile, through saved() and restore().
## An id is never reused.

const ADDS := &"adds_a_prompt"
const SAVES := &"saves_a_prompt"
const DELETES := &"deletes_a_prompt"

var prompts := value([])
var _next_id := 1


func answers() -> Array[StringName]:
	return [ADDS, SAVES, DELETES]


func would(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	match action:
		ADDS:
			if str(payload.get("text", "")).strip_edges().is_empty():
				return GdChime.Phrase.of("Write the prompt first")
		SAVES:
			if index_of(payload.get("id")) < 0:
				return GdChime.Phrase.of("That prompt is gone")
			if str(payload.get("text", "")).strip_edges().is_empty():
				return GdChime.Phrase.of("Write the prompt first")
		DELETES:
			if index_of(payload.get("id")) < 0:
				return GdChime.Phrase.of("That prompt is gone")
	return null


func told(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	var list: Array = prompts.read()
	match action:
		ADDS:
			list.append({"id": _next_id, "name": _name_of(payload), "text": str(payload["text"]).strip_edges()})
			_next_id += 1
		SAVES:
			var one: Dictionary = list[index_of(payload["id"])]
			one["name"] = _name_of(payload)
			one["text"] = str(payload["text"]).strip_edges()
		DELETES:
			list.remove_at(index_of(payload["id"]))
	prompts.set_value(list)
	return null


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


## What SettingsFile writes.
func saved() -> Dictionary:
	return {"prompts": prompts.read().duplicate(true)}


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


## A prompt's name as given, or its first words when none is.
func _name_of(payload: Dictionary) -> String:
	var name := str(payload.get("name", "")).strip_edges()
	if not name.is_empty():
		return name
	var first_line := str(payload["text"]).strip_edges().get_slice("\n", 0)
	return first_line if first_line.length() <= 40 else first_line.left(39) + "…"
