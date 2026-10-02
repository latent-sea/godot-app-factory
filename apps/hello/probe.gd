extends "res://addons/factory_testkit/walk.gd"

## Hello walked as a person would: run with `-- --probe`. Add a claim for
## everything the site does; the factory's testkit (walk.gd) has the presses,
## taps, swipes and reading of the screen.


func run() -> void:
	await begin()
	claim("the home screen is open", top() == &"home")
	claim("the title shows", shows("Hello"))
	claim("it says hello", shows("Hello, world."))
	# The gear, and every setting: the factory's testkit walks them.
	await walk_settings()
	finish()
