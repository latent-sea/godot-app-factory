extends SceneTree

## prompt_text.gd: placeholders found and filled, and the copied text in its
## order - prompt, question, cast. Prints PASS test_prompt_text.gd, or every claim that did not hold.

const P := preload("res://prompt_text.gd")
const CAST := "Hexagram 3 changing lines 2, 5 and 6, changing to Hexagram 8"

var _failed: Array[String] = []


func _init() -> void:
	_claim(P.placeholders("About {question}, given {context} and {question} again") == ["question", "context"], "placeholders found once each, in order")
	_claim(P.placeholders("No placeholders, just {braces with spaces}") == [], "braces around anything but a name aren't placeholders")
	_claim(P.fill("Given {context}: {context}!", {"context": "work"}) == "Given work: work!", "a placeholder used twice is filled twice")
	_claim(P.fill("Given {context}", {}) == "Given {context}", "an unfilled placeholder is left as written")

	var none := P.compose("", {}, "", CAST)
	_claim(none == CAST, "no prompt and no question: just the cast")
	var asked := P.compose("", {}, "  Should I move?  ", CAST)
	_claim(asked == "Should I move?\n\n" + CAST, "no prompt: the question, then the cast: %s" % asked.c_escape())
	var plain := P.compose("Look at this cast.", {}, "Should I move?", CAST)
	_claim(plain == "Look at this cast.\n\nShould I move?\n\n" + CAST, "a prompt without {question}: prompt, question, cast: %s" % plain.c_escape())
	var placed := P.compose("My question is: {question}. Context: {context}.", {"context": "a new city"}, "Should I move?", CAST)
	_claim(placed == "My question is: Should I move?. Context: a new city.\n\n" + CAST, "a prompt with {question} places it, and it isn't repeated: %s" % placed.c_escape())
	var unasked := P.compose("Consider: {question}", {}, "", CAST)
	_claim(unasked == "Consider:\n\n" + CAST, "an empty question fills {question} with nothing: %s" % unasked.c_escape())

	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_prompt_text.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
