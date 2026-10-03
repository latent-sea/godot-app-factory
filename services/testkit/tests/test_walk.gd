extends "res://addons/factory_testkit/check.gd"

## walk.gd's bookkeeping, without an app: claims, failures once failed stay
## failed, and the square a pinned drawing uses. (Pressing and reading the
## screen are exercised by every app's probe.) Prints PASS test_walk.gd, or
## every claim that did not hold.

const Walk := preload("res://addons/factory_testkit/walk.gd")


func _init() -> void:
	var walk := Walk.new(Node.new())
	walk.claim("first", true)
	walk.claim("second", false)
	walk.claim("second", true)
	walk.claim("third", false)
	expect(walk.failures() == ["second", "third"], "failures are listed in order, and a failed claim stays failed: %s" % [walk.failures()])
	walk.app.free()

	var box := Control.new()
	box.size = Vector2(400, 200)
	expect(Walk.in_square(box, Vector2(0.5, 0.5)) == Vector2(200, 100), "the middle of the square is the middle of the box")
	expect(Walk.in_square(box, Vector2(0, 0)) == Vector2(100, 0), "the square is the largest the box holds, centred")
	box.free()

	finish()
