extends "res://addons/factory_testkit/check.gd"

## note_text.gd: titles, snippets, dates in words, tags, search, what is
## copied, and the list's arrangement. Times are fixed to UTC (offset 0) or a
## stated offset. Prints PASS test_note_text.gd, or every claim that did not hold.

const T := preload("res://note_text.gd")

## Sun 27 Sep 2026, 14:05:00 UTC.
const SEP_27 := 1790517900
const DAY := 86400


func _init() -> void:
	expect(T.stamp(SEP_27, 0) == "Sun 27 Sep, 14:05", "a note's day and time in words: %s" % T.stamp(SEP_27, 0))
	expect(T.stamp(SEP_27, 60) == "Sun 27 Sep, 15:05", "shown in the phone's time zone: %s" % T.stamp(SEP_27, 60))
	expect(T.month_heading(SEP_27, 0) == "September 2026", "its month as a heading")
	expect(T.month_heading(SEP_27 + 4 * DAY, 0) == "October 2026", "four days on is October")
	expect(T.month_heading(1790812799, 0) == "September 2026" and T.month_heading(1790812799, 60) == "October 2026", "midnight at the month's end falls by the phone's own clock")

	expect(T.title_of({"title": " Moving ", "text": "x"}) == "Moving", "a title is its title, trimmed")
	expect(T.title_of({"title": "", "text": "First line\nSecond"}) == "First line", "no title: the first line")
	expect(T.title_of({"title": "", "text": ""}) == "Untitled", "nothing at all: Untitled")
	expect(T.snippet({"title": "Moving", "text": "Book the van\nPack"}) == "Book the van", "under a title, the text's first line")
	expect(T.snippet({"title": "", "text": "Book the van\nPack"}) == "Pack", "with no title, the line after the one shown as the title")

	var note := {"title": "Trip #Travel", "text": "See #family and #travel, not email@x.com or a#b.\n#to-do", "created": SEP_27, "pinned": false, "id": 1}
	expect(T.tags(note) == ["travel", "family", "to-do"], "tags: #words, lower case, each once, in order: %s" % [T.tags(note)])
	expect(T.matches(note, "", ""), "an empty search shows everything")
	expect(T.matches(note, "FAMILY trip", ""), "every word searched for, ignoring case, anywhere")
	expect(not T.matches(note, "family boat", ""), "a word it doesn't hold hides it")
	expect(T.matches(note, "", "travel") and not T.matches(note, "", "work"), "a chosen tag shows only its notes")

	expect(T.copied({"title": "Moving", "text": "Book the van"}) == "Moving\n\nBook the van", "copied: title, blank line, text")
	expect(T.copied({"title": "", "text": "Book the van"}) == "Book the van", "no title: just the text")
	expect(T.copied({"title": "Moving", "text": ""}) == "Moving", "no text: just the title")

	var notes := [
		{"id": 1, "title": "Old", "text": "#work", "created": SEP_27 - 40 * DAY, "pinned": false},
		{"id": 2, "title": "Newer", "text": "#home", "created": SEP_27 - DAY, "pinned": false},
		{"id": 3, "title": "Newest", "text": "", "created": SEP_27, "pinned": false},
		{"id": 4, "title": "Kept", "text": "#work", "created": SEP_27 - 80 * DAY, "pinned": true},
	]
	var rows := T.arranged(notes, "", "", 0)
	var keys: Array = rows.map(func(row: Dictionary) -> String: return row["key"])
	expect(keys == ["pinned", "n4", "m2026-09", "n3", "n2", "m2026-08", "n1"], "pinned first, then months newest first: %s" % [keys])
	expect(rows[2]["heading"] == "September 2026" and rows[5]["heading"] == "August 2026", "each month has its heading")
	var tagged := T.arranged(notes, "", "work", 0).map(func(row: Dictionary) -> String: return row["key"])
	expect(tagged == ["pinned", "n4", "m2026-08", "n1"], "a tag keeps only its notes, and their headings: %s" % [tagged])
	expect(T.arranged(notes, "nothing like this", "", 0).is_empty(), "no matches, no headings")
	expect(T.all_tags(notes) == ["home", "work"], "every tag, once, alphabetical")

	finish()
