extends "res://addons/factory_testkit/check.gd"

## The notebook on its own: add, type, pin, copy, delete, search, tags, an
## empty note dropped, refusals, and what it saves and restores. Prints PASS
## test_notebook.gd, or every claim that did not hold.

const Notebook := preload("res://notebook.gd")


func _init() -> void:
	await process_frame
	var chimes := GdChime.Chimes.new(GdChime.Belfry.new())
	var book := Notebook.new(chimes)
	book.clock = func() -> int: return 1790517900
	root.add_child(book)

	expect(book.notes.read().is_empty(), "it starts with no notes")
	expect(book.would(Notebook.RETITLES, {"line": "x"}) != null, "nothing can be typed while no note is open")

	book.told(Notebook.ADDS, {})
	var first: int = book.editing.read()
	expect(book.open_note()["created"] == 1790517900 and book.open_note()["pinned"] == false, "a new note is stamped with now, unpinned")
	expect(book.would(Notebook.COPIES, {}) != null, "an empty note has nothing to copy")
	book.told(Notebook.RETITLES, {"line": "Moving"})
	book.told(Notebook.REWRITES, {"text": "Book the van #home"})
	expect(book.open_note()["title"] == "Moving" and book.open_note()["text"] == "Book the van #home", "title and text change as typed")
	book.told(Notebook.COPIES, {})
	expect(book.last_copied == "Moving\n\nBook the van #home" and book.copied.read(), "Copy copies the title and text, and says so")
	book.told(Notebook.PINS, {})
	expect(book.open_note()["pinned"], "Pin pins it")
	book.told(Notebook.PINS, {})
	expect(not book.open_note()["pinned"], "and again unpins it")
	book.drop_if_empty()
	expect(book.notes.read().size() == 1 and book.editing.read() == null, "closing a note with words keeps it")

	book.told(Notebook.ADDS, {})
	var second: int = book.editing.read()
	expect(second != first and not book.copied.read(), "each note has its own id, and a new one isn't copied yet")
	book.drop_if_empty()
	expect(book.notes.read().size() == 1, "closing a new note left empty drops it")

	book.told(Notebook.SEARCHES, {"line": "van"})
	expect(book.search.read() == "van", "the search is kept as typed")
	book.told(Notebook.PICKS_TAG, {"tag": "home"})
	expect(book.tag.read() == "home", "choosing a tag chooses it")
	book.told(Notebook.PICKS_TAG, {"tag": "home"})
	expect(book.tag.read() == "", "choosing it again shows every note")

	book.told(Notebook.OPENS, {"id": first})
	expect(book.editing.read() == first, "opening a note opens it")
	expect(book.would(Notebook.OPENS, {"id": 999}) != null, "opening a note that is gone is refused")
	book.told(Notebook.PICKS_TAG, {"tag": "home"})
	book.told(Notebook.DELETES, {"id": first})
	expect(book.notes.read().is_empty(), "delete removes the note")
	expect(book.tag.read() == "", "and the tag it alone carried is no longer chosen")
	book.told(Notebook.ADDS, {})
	expect(book.editing.read() > second, "ids are never reused")
	book.told(Notebook.REWRITES, {"text": "Kept"})
	book.told(Notebook.PINS, {})

	var saved: Dictionary = JSON.parse_string(JSON.stringify(book.saved()))
	var back := Notebook.new(chimes)
	root.add_child(back)
	back.restore(saved)
	expect(back.notes.read() == book.notes.read(), "saved then restored gives the same notes: %s" % [back.notes.read()])
	expect(typeof(back.notes.read()[0]["created"]) == TYPE_INT and back.notes.read()[0]["pinned"], "restored times are whole numbers, and pins stay")
	back.told(Notebook.ADDS, {})
	expect(back.editing.read() > book.notes.read()[0]["id"], "a restored notebook keeps handing out new ids")

	finish()
