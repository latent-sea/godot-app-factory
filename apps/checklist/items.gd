extends GdChime.Controller

## The checklist: every item's words and whether it is done, in the order
## they were added. The one place these facts live; the screen reads them.
##
## Each item is {"id": int, "words": String, "done": bool}. An id is never
## reused, so a press carrying one can never land on a different item.
## Kept between runs by gd-chime's SettingsFile, through saved() and restore().

const ADDS := &"adds_an_item"
const TOGGLES := &"ticks_an_item"
const DELETES := &"deletes_an_item"
const CLEARS := &"clears_the_done_items"

var items := value([])
var _next_id := 1


func answers() -> Array[StringName]:
	return [ADDS, TOGGLES, DELETES, CLEARS]


func would(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	match action:
		ADDS:
			if _words_of(payload).is_empty():
				return GdChime.Phrase.of("Type something to add")
		TOGGLES, DELETES:
			if _index_of(payload.get("id")) < 0:
				return GdChime.Phrase.of("That item is gone")
		CLEARS:
			if done_count() == 0:
				return GdChime.Phrase.of("Nothing is ticked yet")
	return null


func told(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	var list: Array = items.read()
	match action:
		ADDS:
			list.append({"id": _next_id, "words": _words_of(payload), "done": false})
			_next_id += 1
		TOGGLES:
			var one: Dictionary = list[_index_of(payload["id"])]
			one["done"] = not one["done"]
		DELETES:
			list.remove_at(_index_of(payload["id"]))
		CLEARS:
			list = list.filter(func(one: Dictionary) -> bool: return not one["done"])
	# Set again even when changed in place: setting is what rings the bell.
	items.set_value(list)
	return null


func done_count() -> int:
	return items.read().filter(func(one: Dictionary) -> bool: return one["done"]).size()


## What SettingsFile writes.
func saved() -> Dictionary:
	return {"items": items.read().duplicate(true)}


## What SettingsFile read back. A save of the wrong shape is left unread and the list starts empty.
func restore(save: Dictionary) -> void:
	var shape := GdChime.SaveShape as GDScript
	var item: Callable = shape.record({"id": shape.number(), "words": shape.words(), "done": shape.one_of([true, false])})
	if shape.refused(shape.record({"items": shape.list_of(item)}), save, "a checklist"):
		return
	var back: Array = []
	for one: Dictionary in save["items"]:
		# JSON hands whole numbers back as floats.
		back.append({"id": int(one["id"]), "words": one["words"], "done": one["done"]})
		_next_id = maxi(_next_id, int(one["id"]) + 1)
	items.set_value(back)


func _words_of(payload: Dictionary) -> String:
	return str(payload.get("line", "")).strip_edges()


func _index_of(id: Variant) -> int:
	if id == null:
		return -1
	var list: Array = items.read()
	for at: int in list.size():
		if list[at]["id"] == int(id):
			return at
	return -1
