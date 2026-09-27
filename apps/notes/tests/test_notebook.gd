extends SceneTree

## The notebook on its own: add, type, pin, copy, delete, search, tags, an
## empty note dropped, refusals, and what it saves and restores. Prints PASS
## test_notebook.gd, or every claim that did not hold.

const Notebook := preload("res://notebook.gd")

var _failed: Array[String] = []


func _init() -> void:
	await process_frame
	var chimes := GdChime.Chimes.new(GdChime.Belfry.new())
	var book := Notebook.new(chimes)
	book.clock = func() -> int: return 1790517900
	root.add_child(book)

	_claim(book.notes.read().is_empty(), "it starts with no notes")
	_claim(book.would(Notebook.RETITLES, {"line": "x"}) != null, "nothing can be typed while no note is open")

	book.told(Notebook.ADDS, {})
	var first: int = book.editing.read()
	_claim(book.open_note()["created"] == 1790517900 and book.open_note()["pinned"] == false, "a new note is stamped with now, unpinned")
	_claim(book.would(Notebook.COPIES, {}) != null, "an empty note has nothing to copy")
	book.told(Notebook.RETITLES, {"line": "Moving"})
	book.told(Notebook.REWRITES, {"text": "Book the van #home"})
	_claim(book.open_note()["title"] == "Moving" and book.open_note()["text"] == "Book the van #home", "title and text change as typed")
	book.told(Notebook.COPIES, {})
	_claim(book.last_copied == "Moving\n\nBook the van #home" and book.copied.read(), "Copy copies the title and text, and says so")
	book.told(Notebook.PINS, {})
	_claim(book.open_note()["pinned"], "Pin pins it")
	book.told(Notebook.PINS, {})
	_claim(not book.open_note()["pinned"], "and again unpins it")
	book.drop_if_empty()
	_claim(book.notes.read().size() == 1 and book.editing.read() == null, "closing a note with words keeps it")

	book.told(Notebook.ADDS, {})
	var second: int = book.editing.read()
	_claim(second != first and not book.copied.read(), "each note has its own id, and a new one isn't copied yet")
	book.drop_if_empty()
	_claim(book.notes.read().size() == 1, "closing a new note left empty drops it")

	book.told(Notebook.SEARCHES, {"line": "van"})
	_claim(book.search.read() == "van", "the search is kept as typed")
	book.told(Notebook.PICKS_TAG, {"tag": "home"})
	_claim(book.tag.read() == "home", "choosing a tag chooses it")
	book.told(Notebook.PICKS_TAG, {"tag": "home"})
	_claim(book.tag.read() == "", "choosing it again shows every note")

	book.told(Notebook.OPENS, {"id": first})
	_claim(book.editing.read() == first, "opening a note opens it")
	_claim(book.would(Notebook.OPENS, {"id": 999}) != null, "opening a note that is gone is refused")
	book.told(Notebook.DELETES, {"id": first})
	_claim(book.notes.read().is_empty(), "delete removes the note")
	book.told(Notebook.ADDS, {})
	_claim(book.editing.read() > second, "ids are never reused")
	book.told(Notebook.REWRITES, {"text": "Kept"})
	book.told(Notebook.PINS, {})

	var saved: Dictionary = JSON.parse_string(JSON.stringify(book.saved()))
	var back := Notebook.new(chimes)
	root.add_child(back)
	back.restore(saved)
	_claim(back.notes.read() == book.notes.read(), "saved then restored gives the same notes: %s" % [back.notes.read()])
	_claim(typeof(back.notes.read()[0]["created"]) == TYPE_INT and back.notes.read()[0]["pinned"], "restored times are whole numbers, and pins stay")
	back.told(Notebook.ADDS, {})
	_claim(back.editing.read() > book.notes.read()[0]["id"], "a restored notebook keeps handing out new ids")

	for sentence: String in _failed:
		print("NOT TRUE: %s" % sentence)
	if _failed.is_empty():
		print("PASS test_notebook.gd")
	quit(0 if _failed.is_empty() else 1)


func _claim(held: bool, what: String) -> void:
	if not held:
		_failed.append(what)
