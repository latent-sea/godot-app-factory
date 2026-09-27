extends GdChime.Controller

## The cast in progress: the question, and the lines the taps have given so
## far, from the bottom. A tap picks a cell of the square; a map of 64 cells
## at three-coin odds is shuffled fresh for every tap, so the place tapped,
## not a pattern, chooses the line. After the sixth line the result opens.

const H := preload("res://hexagrams.gd")

const ASKS := &"asks_a_question"
const CASTS := &"casts_a_line"
const CASTS_AGAIN := &"casts_again"

var question := value("")
var lines := value([])
var _rng := RandomNumberGenerator.new()
var _door: Object  # the app's commands, to move on after the sixth line
var _cast_place: StringName
var _result_place: StringName


func _init(chimes: GdChime.Chimes, door: Object, cast_place: StringName, result_place: StringName) -> void:
	super(chimes)
	_door = door
	_cast_place = cast_place
	_result_place = result_place
	_rng.randomize()


func answers() -> Array[StringName]:
	return [ASKS, CASTS, CASTS_AGAIN]


func would(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	if action == CASTS:
		if lines.read().size() >= H.LINES:
			return GdChime.Phrase.of("Six lines are cast")
		var cell: Variant = payload.get("picked")
		if not (cell is int) or cell < 0 or cell >= 64:
			return GdChime.Phrase.of("Tap inside the square")
	return null


func told(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	match action:
		ASKS:
			question.set_value(str(payload.get("line", "")))
		CASTS:
			var map := H.fresh_map(_rng)
			lines.set_value(lines.read() + [map[payload["picked"]]])
			if lines.read().size() == H.LINES and _door != null:
				return _door.dispatch(GdChime.Chimes.GLOBAL, GdChime.Driver.GO, {"place": _result_place})
		CASTS_AGAIN:
			lines.set_value([])
			question.set_value("")
			if _door != null:
				_door.dispatch(GdChime.Chimes.GLOBAL, GdChime.Driver.GO, {"place": _cast_place})
				# Back from a fresh cast leaves the app rather than returning to the last result.
				_door.dispatch(GdChime.Chimes.GLOBAL, GdChime.Driver.FORGETS, {})
	return null


## The sentence for the cast, once all six lines are in; "" before.
func sentence() -> String:
	return H.sentence(lines.read()) if lines.read().size() == H.LINES else ""


## For a test: the same taps give the same lines.
func seed_with(seed_value: int) -> void:
	_rng.seed = seed_value
