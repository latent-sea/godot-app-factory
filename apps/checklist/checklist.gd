extends ChimeApp

const COUNTS := &"counts_a_crate"

class Crates extends GdChime.Controller:
	var counted := value(0)

	func answers() -> Array[StringName]:
		return [COUNTS]

	func told(_action: StringName, _payload: Dictionary) -> GdChime.Phrase:
		counted.set_value(counted.read() + 1)
		return null

func declare(register: GdChime.Actions) -> void:
	register.declare_all({COUNTS: ["Count a crate", GdChime.Actions.keys(KEY_C)]})

func describe() -> GdChime.Desc:
	var crates := Crates.new(chimes)
	var shown := crates.counted.map(func(count: Variant) -> GdChime.Phrase: return GdChime.Phrase.with("%d crates counted", [count]))
	return ui.app(&"stall", [ui.screen(&"counting", [ui.column([ui.text(shown), ui.button(COUNTS)])], crates)])
