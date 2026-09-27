extends RefCounted

## The arithmetic of a cast, and nothing of what it means: which lines the
## taps gave, which hexagram they make, which it changes to, and the one
## sentence that says so. No names, no texts, no interpretation.
##
## A LINE is its traditional number: 6 old yin (changing), 7 young yang,
## 8 young yin, 9 old yang (changing). Lines are counted from the bottom:
## line 1 is the first cast and the lowest drawn.

const OLD_YIN := 6
const YOUNG_YANG := 7
const YOUNG_YIN := 8
const OLD_YANG := 9
const LINES := 6

## Three coins: how many of 64 cells hold each line. 1/8, 3/8, 3/8, 1/8.
const ODDS := {OLD_YIN: 8, YOUNG_YANG: 24, YOUNG_YIN: 24, OLD_YANG: 8}

## A trigram as its three lines from the bottom, yang true.
const QIAN := [true, true, true]
const DUI := [true, true, false]
const LI := [true, false, true]
const ZHEN := [true, false, false]
const XUN := [false, true, true]
const KAN := [false, true, false]
const GEN := [false, false, true]
const KUN := [false, false, false]
const TRIGRAMS := [QIAN, ZHEN, KAN, GEN, KUN, XUN, LI, DUI]
## King Wen numbers: KING_WEN[upper][lower], both in TRIGRAMS' order.
const KING_WEN := [
	[1, 25, 6, 33, 12, 44, 13, 10],
	[34, 51, 40, 62, 16, 32, 55, 54],
	[5, 3, 29, 39, 8, 48, 63, 60],
	[26, 27, 4, 52, 23, 18, 22, 41],
	[11, 24, 7, 15, 2, 46, 36, 19],
	[9, 42, 59, 53, 20, 57, 37, 61],
	[14, 21, 64, 56, 35, 50, 30, 38],
	[43, 17, 47, 31, 45, 28, 49, 58],
]


static func is_yang(line: int) -> bool:
	return line == YOUNG_YANG or line == OLD_YANG


static func is_changing(line: int) -> bool:
	return line == OLD_YIN or line == OLD_YANG


## The lines as they are: yang true, from the bottom.
static func first(lines: Array) -> Array:
	return lines.map(func(line: int) -> bool: return is_yang(line))


## The lines once the changing ones have changed.
static func changed(lines: Array) -> Array:
	return lines.map(func(line: int) -> bool: return is_yang(line) != is_changing(line))


## The King Wen number of six lines, yang true, from the bottom.
static func number(six: Array) -> int:
	assert(six.size() == LINES)
	var lower := TRIGRAMS.find(six.slice(0, 3))
	var upper := TRIGRAMS.find(six.slice(3, 6))
	return KING_WEN[upper][lower]


## Which lines change, counted from 1 at the bottom.
static func changing_positions(lines: Array) -> Array:
	var at: Array = []
	for index: int in lines.size():
		if is_changing(lines[index]):
			at.append(index + 1)
	return at


## The cast in one sentence:
##   Hexagram 3, unchanging
##   Hexagram 3 changing line 4, changing to Hexagram 17
##   Hexagram 3 changing lines 2, 5 and 6, changing to Hexagram 8
static func sentence(lines: Array) -> String:
	var from := number(first(lines))
	var moving := changing_positions(lines)
	if moving.is_empty():
		return "Hexagram %d, unchanging" % from
	var which := "line %d" % moving[0] if moving.size() == 1 else "lines %s" % _listed(moving)
	return "Hexagram %d changing %s, changing to Hexagram %d" % [from, which, number(changed(lines))]


## A cell's line in a fresh map: the 64 cells shuffled, holding each line as often as the odds say.
static func fresh_map(rng: RandomNumberGenerator) -> Array:
	var cells: Array = []
	for line: int in ODDS:
		for count: int in ODDS[line]:
			cells.append(line)
	# Fisher-Yates, with the rng handed in, so a test can seed it.
	for index: int in range(cells.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held: int = cells[index]
		cells[index] = cells[other]
		cells[other] = held
	return cells


## "2", "2 and 5", "2, 5 and 6".
static func _listed(numbers: Array) -> String:
	var words: Array = numbers.map(func(n: int) -> String: return str(n))
	if words.size() == 1:
		return words[0]
	return ", ".join(words.slice(0, -1)) + " and " + words[-1]
