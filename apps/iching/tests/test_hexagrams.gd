extends "res://addons/factory_testkit/check.gd"

## hexagrams.gd: the King Wen table, which lines change, the sentence, and
## the odds of the map. Prints PASS test_hexagrams.gd, or every claim that did not hold.

const H := preload("res://hexagrams.gd")


## Every hexagram in King Wen order as its lines from the bottom, 1 yang:
## written out on its own, so the table in hexagrams.gd is checked against
## a second source rather than against itself.
const KING_WEN_LINES := [
	"111111", "000000", "100010", "010001", "111010", "010111", "010000", "000010",
	"111011", "110111", "111000", "000111", "101111", "111101", "001000", "000100",
	"100110", "011001", "110000", "000011", "100101", "101001", "000001", "100000",
	"100111", "111001", "100001", "011110", "010010", "101101", "001110", "011100",
	"001111", "111100", "000101", "101000", "101011", "110101", "001010", "010100",
	"110001", "100011", "111110", "011111", "000110", "011000", "010110", "011010",
	"101110", "011101", "100100", "001001", "001011", "110100", "101100", "001101",
	"011011", "110110", "010011", "110010", "110011", "001100", "101010", "010101",
]


func _init() -> void:
	# The table: every number from 1 to 64 exactly once.
	var seen: Array = []
	for row: Array in H.KING_WEN:
		seen += row
	seen.sort()
	expect(seen == range(1, 65), "the King Wen table holds 1 to 64 once each")

	# Every hexagram against the second source.
	for index: int in KING_WEN_LINES.size():
		var six: Array = []
		for bit: String in KING_WEN_LINES[index]:
			six.append(bit == "1")
		expect(H.number(six) == index + 1, "%s is Hexagram %d, not %d" % [KING_WEN_LINES[index], index + 1, H.number(six)])

	# Known hexagrams, lines from the bottom.
	expect(H.number([true, true, true, true, true, true]) == 1, "six yang lines are Hexagram 1")
	expect(H.number([false, false, false, false, false, false]) == 2, "six yin lines are Hexagram 2")
	expect(H.number([true, false, false, false, true, false]) == 3, "thunder under water is Hexagram 3")
	expect(H.number([true, false, true, false, true, false]) == 63, "fire under water is Hexagram 63")
	expect(H.number([false, true, false, true, false, true]) == 64, "water under fire is Hexagram 64")
	expect(H.number([true, true, true, false, false, false]) == 11, "heaven under earth is Hexagram 11")
	expect(H.number([false, false, false, true, true, true]) == 12, "earth under heaven is Hexagram 12")

	# Changing lines, and what they change to.
	expect(H.sentence([7, 7, 7, 7, 7, 7]) == "Hexagram 1, unchanging", "no changing lines: %s" % H.sentence([7, 7, 7, 7, 7, 7]))
	expect(H.sentence([9, 7, 7, 7, 7, 7]) == "Hexagram 1 changing line 1, changing to Hexagram 44", "one changing line: %s" % H.sentence([9, 7, 7, 7, 7, 7]))
	expect(H.sentence([6, 8, 8, 8, 8, 8]) == "Hexagram 2 changing line 1, changing to Hexagram 24", "old yin changes to yang: %s" % H.sentence([6, 8, 8, 8, 8, 8]))
	expect(H.sentence([9, 9, 9, 9, 9, 9]) == "Hexagram 1 changing lines 1, 2, 3, 4, 5 and 6, changing to Hexagram 2", "all changing: %s" % H.sentence([9, 9, 9, 9, 9, 9]))
	var two := H.sentence([7, 9, 8, 8, 6, 7])
	expect(two.begins_with("Hexagram ") and two.contains("changing lines 2 and 5, changing to Hexagram "), "two changing lines read 'lines 2 and 5': %s" % two)
	expect(H.changing_positions([7, 9, 8, 6, 8, 9]) == [2, 4, 6], "changing lines are counted from 1 at the bottom")
	expect(H.first([6, 7, 8, 9, 7, 8]) == [false, true, false, true, true, false], "old yin is yin and old yang is yang as cast")
	expect(H.changed([6, 7, 8, 9, 7, 8]) == [true, true, false, false, true, false], "old lines turn over, young lines stay")

	# The map: 64 cells at three-coin odds, a different order each time.
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var map := H.fresh_map(rng)
	expect(map.size() == 64, "the map has 64 cells")
	for line: int in H.ODDS:
		expect(map.count(line) == H.ODDS[line], "the map holds %d cells of %d" % [H.ODDS[line], line])
	expect(H.fresh_map(rng) != map, "a fresh map is shuffled again")
	# Over many maps, each cell is each line about as often as the odds say.
	var old_yang_at_corner := 0
	for time: int in 4000:
		if H.fresh_map(rng)[0] == H.OLD_YANG:
			old_yang_at_corner += 1
	expect(absf(old_yang_at_corner / 4000.0 - 0.125) < 0.02, "a cell is old yang about 1 time in 8: %d of 4000" % old_yang_at_corner)

	finish()
