extends MechDemo
## MINESWEEPER — deduction (1989). Tap to reveal; numbers count adjacent
## mines. First tap is always safe. Clear the board to re-deal. Hit a mine =
## over. Score = safe cells revealed.

const CW := 9
const CH := 13
const CS := 76.0
const OX := 33.0
const OY := 200.0
const MINES := 16

var mine: Dictionary = {}
var shown: Dictionary = {}
var adj: Dictionary = {}
var placed := false


func start() -> void:
	super.start()
	mine = {}
	shown = {}
	adj = {}
	placed = false
	queue_redraw()


func _place(safe: Vector2i) -> void:
	var cells := []
	for x in CW:
		for y in CH:
			var c := Vector2i(x, y)
			if absi(c.x - safe.x) <= 1 and absi(c.y - safe.y) <= 1:
				continue
			cells.append(c)
	cells.shuffle()
	for i in mini(MINES, cells.size()):
		mine[cells[i]] = true
	for x in CW:
		for y in CH:
			var c := Vector2i(x, y)
			var n := 0
			for dx in [-1, 0, 1]:
				for dy in [-1, 0, 1]:
					if mine.has(c + Vector2i(dx, dy)):
						n += 1
			adj[c] = n
	placed = true


func _reveal(c: Vector2i) -> void:
	if shown.has(c) or c.x < 0 or c.x >= CW or c.y < 0 or c.y >= CH:
		return
	shown[c] = true
	add_points(1)
	if adj[c] == 0:
		for dx in [-1, 0, 1]:
			for dy in [-1, 0, 1]:
				_reveal(c + Vector2i(dx, dy))


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var cx := int((event.position.x - OX) / CS)
	var cy := int((event.position.y - OY) / CS)
	if cx < 0 or cx >= CW or cy < 0 or cy >= CH:
		return
	var c := Vector2i(cx, cy)
	if not placed:
		_place(c)
	if mine.has(c):
		shown[c] = true
		Juice.sfx("boom")
		Juice.haptic(60)
		end_demo()
		return
	_reveal(c)
	Juice.sfx("tick")
	if shown.size() >= CW * CH - MINES:
		add_points(30)
		start()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.11, 0.13))
	draw_string(f(), Vector2(30, 150), "MINESWEEPER — tap to reveal",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	for x in CW:
		for y in CH:
			var c := Vector2i(x, y)
			var rr := Rect2(OX + x * CS + 2, OY + y * CS + 2, CS - 4, CS - 4)
			if shown.has(c):
				if mine.has(c):
					draw_rect(rr, Color(0.85, 0.25, 0.25))
				else:
					draw_rect(rr, Color(0.2, 0.22, 0.26))
					if adj.get(c, 0) > 0:
						draw_string(f(), Vector2(rr.position.x, rr.get_center().y + 14), str(adj[c]),
							HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 38, Color(0.6, 0.85, 1.0))
			else:
				draw_rect(rr, Color(0.4, 0.44, 0.5))
