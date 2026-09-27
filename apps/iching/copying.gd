extends GdChime.Controller

## Copying the cast: which prompt goes with it (none, or a saved one), what
## each of its placeholders is filled with, and the text that goes to the
## clipboard - prompt, question, cast (prompt_text.gd).
##
## {question} starts filled with the question asked before casting. Copy
## can't be pressed while a placeholder is still empty; like every disabled
## button in the factory's look, it just looks faded. Once copied, the
## result says so where it was tapped (copied), until the next cast.

const P := preload("res://prompt_text.gd")

const PICKS := &"picks_a_prompt"
const FILLS := &"fills_a_placeholder"
const COPIES := &"copies_the_cast"
## The choice that means no prompt: prompt ids start at 1.
const NO_PROMPT := 0

## The chosen prompt's id, or NO_PROMPT.
var picked := value(NO_PROMPT)
## What each placeholder is filled with, by name.
var filled := value({})
## The chosen prompt's placeholder names, in order.
var blanks: GdChime.Bound
## The prompt choices: "No prompt", then every saved prompt, as {value, words}.
var offers: GdChime.Bound
## Whether this cast has been copied.
var copied := value(false)
## What was copied last, for a probe that has no clipboard to read.
var last_copied := ""
var _cast: Object  # cast.gd
var _prompts: Object  # prompts.gd


func _init(chimes: GdChime.Chimes, cast: Object, prompts: Object) -> void:
	super(chimes)
	_cast = cast
	_prompts = prompts
	blanks = GdChime.Bound.both(picked, prompts.prompts, func(id: Variant, _all: Variant) -> Array:
		return P.placeholders(_prompt_text(id)))
	offers = prompts.prompts.map(func(all: Variant) -> Array:
		var choices: Array = [{"value": NO_PROMPT, "words": GdChime.Phrase.of("No prompt")}]
		for one: Dictionary in all:
			if not str(one["text"]).strip_edges().is_empty():
				choices.append({"value": one["id"], "words": prompts.name_of(one)})
		return choices)


func answers() -> Array[StringName]:
	return [PICKS, FILLS, COPIES]


func would(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	match action:
		PICKS:
			var id: Variant = payload.get("value")
			if id != NO_PROMPT and _prompts.index_of(id) < 0:
				return GdChime.Phrase.of("That prompt is gone")
		COPIES:
			if _cast.sentence().is_empty():
				return GdChime.Phrase.of("Cast six lines first")
			for name: String in P.placeholders(_prompt_text(picked.read())):
				if str(filled.read().get(name, "")).strip_edges().is_empty():
					return GdChime.Phrase.of("Fill in every placeholder")
	return null


func told(action: StringName, payload: Dictionary) -> GdChime.Phrase:
	match action:
		PICKS:
			picked.set_value(int(payload["value"]))
		FILLS:
			var now: Dictionary = filled.read()
			now[str(payload["name"])] = str(payload.get("line", ""))
			filled.set_value(now)
		COPIES:
			last_copied = composed()
			DisplayServer.clipboard_set(last_copied)
			copied.set_value(true)
	return null


## Ready for a new cast's result: no prompt chosen yet, {question} holding the question asked.
func start(question: String) -> void:
	picked.set_value(NO_PROMPT)
	filled.set_value({P.QUESTION: question})
	copied.set_value(false)


## The text Copy puts on the clipboard.
func composed() -> String:
	var values: Dictionary = filled.read().duplicate()
	var question := str(values.get(P.QUESTION, ""))
	return P.compose(_prompt_text(picked.read()), values, question, _cast.sentence())


func _prompt_text(id: Variant) -> String:
	return "" if id == null or id == NO_PROMPT else str(_prompts.find(id).get("text", ""))
