extends RefCounted

## What gets copied: a prompt with its placeholders filled, then the question
## (unless the prompt placed it with {question}), then the cast, each part
## separated by a blank line, and any part that is empty left out.
##
## A placeholder is a name in curly brackets, {like_this}: letters, digits
## and underscores. The same name twice is one placeholder, filled twice.

const QUESTION := "question"

## A placeholder as a pattern: made per call, since a static one would outlive the app.
const PATTERN := "\\{([A-Za-z0-9_]+)\\}"


## The placeholder names in a prompt, each once, in the order they first appear.
static func placeholders(prompt: String) -> Array:
	var names: Array = []
	for found: RegExMatch in RegEx.create_from_string(PATTERN).search_all(prompt):
		var name := found.get_string(1)
		if not names.has(name):
			names.append(name)
	return names


## The prompt with each placeholder replaced by its value; any without a value are left as written.
static func fill(prompt: String, values: Dictionary) -> String:
	var filled := prompt
	for name: String in placeholders(prompt):
		if values.has(name):
			filled = filled.replace("{%s}" % name, str(values[name]))
	return filled


## The whole copied text. The prompt may be "" for none.
static func compose(prompt: String, values: Dictionary, question: String, cast: String) -> String:
	var parts: Array = []
	var asked := question.strip_edges()
	var filled_values := values.duplicate()
	filled_values[QUESTION] = asked
	if not prompt.strip_edges().is_empty():
		parts.append(fill(prompt, filled_values).strip_edges())
	if not asked.is_empty() and not placeholders(prompt).has(QUESTION):
		parts.append(asked)
	parts.append(cast)
	return "\n\n".join(parts)
