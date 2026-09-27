extends RefCounted

## What is said about a note, and nothing that draws it: its title, its tags,
## when it was written in words, whether it matches a search, what is copied.
##
## A note is {"id": int, "title": String, "text": String, "created": int
## (unix seconds), "pinned": bool}. Times are shown in the phone's own time
## zone; each function takes the zone's offset in minutes so a test can fix it.

const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const DAYS := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
## A tag: # then letters, digits, underscores or hyphens, not straight after a letter (so "a#b" isn't one).
const TAG_PATTERN := "(?<![\\w#])#([\\w-]+)"


## The phone's offset from UTC, in minutes.
static func local_offset() -> int:
	return int(Time.get_time_zone_from_system().get("bias", 0))


## The note's title, or its first line when it has none, or "Untitled".
static func title_of(note: Dictionary) -> String:
	var title := str(note.get("title", "")).strip_edges()
	if not title.is_empty():
		return title
	var first := str(note.get("text", "")).strip_edges().get_slice("\n", 0)
	return first if not first.is_empty() else "Untitled"


## A line of the text to show under the title: the first line not already shown as the title.
static func snippet(note: Dictionary) -> String:
	var lines := str(note.get("text", "")).strip_edges().split("\n", false)
	if lines.is_empty():
		return ""
	if str(note.get("title", "")).strip_edges().is_empty():
		return lines[1].strip_edges() if lines.size() > 1 else ""
	return lines[0].strip_edges()


## Its month, as a heading: "September 2026".
static func month_heading(created: int, offset: int = local_offset()) -> String:
	var when := Time.get_datetime_dict_from_unix_time(created + offset * 60)
	return "%s %d" % [MONTHS[when["month"] - 1], when["year"]]


## A key that sorts months newest first when compared as strings, reversed: "2026-09".
static func month_key(created: int, offset: int = local_offset()) -> String:
	var when := Time.get_datetime_dict_from_unix_time(created + offset * 60)
	return "%04d-%02d" % [when["year"], when["month"]]


## Its day and time: "Sun 27 Sep, 14:05".
static func stamp(created: int, offset: int = local_offset()) -> String:
	var when := Time.get_datetime_dict_from_unix_time(created + offset * 60)
	return "%s %d %s, %02d:%02d" % [DAYS[when["weekday"]], when["day"], MONTHS[when["month"] - 1].left(3), when["hour"], when["minute"]]


## Every #tag in the title and text, lower case, each once, in the order first used.
static func tags(note: Dictionary) -> Array:
	var found: Array = []
	var words := "%s\n%s" % [note.get("title", ""), note.get("text", "")]
	for tag: RegExMatch in RegEx.create_from_string(TAG_PATTERN).search_all(words):
		var name := tag.get_string(1).to_lower()
		if not found.has(name):
			found.append(name)
	return found


## Whether a note is shown: its title or text holds every word searched for,
## ignoring case, and it has the tag chosen, if one is.
static func matches(note: Dictionary, search: String, tag: String) -> bool:
	if not tag.is_empty() and not tags(note).has(tag):
		return false
	var haystack := "%s\n%s" % [note.get("title", ""), note.get("text", "")]
	haystack = haystack.to_lower()
	for word: String in search.to_lower().split(" ", false):
		if not haystack.contains(word):
			return false
	return true


## What Copy puts on the clipboard: the title, a blank line, the text. No title, just the text.
static func copied(note: Dictionary) -> String:
	var title := str(note.get("title", "")).strip_edges()
	var text := str(note.get("text", "")).strip_edges()
	if title.is_empty():
		return text
	if text.is_empty():
		return title
	return "%s\n\n%s" % [title, text]


## The list as shown: pinned notes under "Pinned", then the rest under their
## months, newest first within each. Each row is {"key", "heading"} or
## {"key", "note"}; keys are unique strings, so a list can be keyed by them.
static func arranged(notes: Array, search: String, tag: String, offset: int = local_offset()) -> Array:
	var shown := notes.filter(func(note: Dictionary) -> bool: return matches(note, search, tag))
	shown.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["created"] > b["created"] or (a["created"] == b["created"] and a["id"] > b["id"]))
	var rows: Array = []
	var pinned := shown.filter(func(note: Dictionary) -> bool: return note["pinned"])
	if not pinned.is_empty():
		rows.append({"key": "pinned", "heading": "Pinned"})
		for note: Dictionary in pinned:
			rows.append({"key": "n%d" % note["id"], "note": note})
	var month := ""
	for note: Dictionary in shown:
		if note["pinned"]:
			continue
		var this_month := month_key(note["created"], offset)
		if this_month != month:
			month = this_month
			rows.append({"key": "m" + month, "heading": month_heading(note["created"], offset)})
		rows.append({"key": "n%d" % note["id"], "note": note})
	return rows


## Every tag on any note, alphabetical.
static func all_tags(notes: Array) -> Array:
	var found: Array = []
	for note: Dictionary in notes:
		for tag: String in tags(note):
			if not found.has(tag):
				found.append(tag)
	found.sort()
	return found
