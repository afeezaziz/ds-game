extends MechDemo
## FLOW — connect each pair of dots with a path; no crossing (Flow Free).
## Drag from a dot along cells to its twin. Connect all pairs to advance.
## Score = pairs connected. Puzzles cycle.

const CS := 128.0
const OX := 40.0
const OY := 300.0
const PAL := [Color(0.9, 0.3, 0.3), Color(0.35, 0.65, 0.95), Color(0.4, 0.85, 0.45),
	Color(0.95, 0.8, 0.3), Color(0.8, 0.45, 0.9)]
const PUZZLES := [
	{"n": 5, "pairs": [[Vector2i(0, 0), Vector2i(4, 4)], [Vector2i(4, 0), Vector2i(0, 4)],
		[Vector2i(2, 1), Vector2i(2, 3)]]},
	{"n": 5, "pairs": [[Vector2i(0, 0), Vector2i(2, 2)], [Vector2i(4, 0), Vector2i(2, 4)],
		[Vector2i(0, 4), Vector2i(4, 4)], [Vector2i(1, 1), Vector2i(3, 3)]]},
]

var pi := 0
var n := 5
var pairs: Array = []
var paths: Array = []      # per pair: Array[Vector2i]
var solved: Array = []
var drawing := -1


func start() -> void:
	super.start()
	pi = 0
	_load()
	queue_redraw()


func _load() -> void:
	var p: Dictionary = PUZZLES[pi % PUZZLES.size()]
	n = p.n
	pairs = p.pairs
	paths = []
	solved = []
	for i in pairs.size():
		paths.append([])
		solved.append(false)


func _cell(pos: Vector2) -> Vector2i:
	var c := Vector2i(int((pos.x - OX) / CS), int((pos.y - OY) / CS))
	if c.x < 0 or c.x >= n or c.y < 0 or c.y >= n:
		return Vector2i(-1, -1)
	return c


func _endpoint_color(c: Vector2i) -> int:
	for i in pairs.size():
		if pairs[i][0] == c or pairs[i][1] == c:
			return i
	return -1


func _occupied_by(c: Vector2i, ignore: int) -> bool:
	for i in paths.size():
		if i == ignore:
			continue
		if paths[i].has(c):
			return true
	var ec := _endpoint_color(c)
	return ec != -1 and ec != ignore


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch and event.pressed:
		var c := _cell(event.position)
		var ec := _endpoint_color(c)
		if ec != -1:
			drawing = ec
			paths[ec] = [c]
			solved[ec] = false
	elif event is InputEventScreenDrag and drawing >= 0:
		var c := _cell(event.position)
		if c == Vector2i(-1, -1) or _occupied_by(c, drawing):
			return
		var path: Array = paths[drawing]
		if path.is_empty():
			return
		var last: Vector2i = path[-1]
		if (c - last).length() == 1 and not path.has(c):
			path.append(c)
			var other: Vector2i = pairs[drawing][1] if pairs[drawing][0] == path[0] else pairs[drawing][0]
			if c == other:
				solved[drawing] = true
				Juice.sfx("chime")
				drawing = -1
				_check_win()
	elif event is InputEventScreenTouch and not event.pressed and drawing >= 0:
		if not solved[drawing]:
			paths[drawing] = []
		drawing = -1
	queue_redraw()


func _check_win() -> void:
	for s in solved:
		if not s:
			return
	add_points(pairs.size())
	pi += 1
	_load()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.08, 0.09, 0.12))
	draw_string(f(), Vector2(40, 250), "FLOW — connect the dots",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
	for x in n:
		for y in n:
			draw_rect(Rect2(OX + x * CS + 3, OY + y * CS + 3, CS - 6, CS - 6), Color(1, 1, 1, 0.05))
	for i in paths.size():
		for c in paths[i]:
			draw_rect(Rect2(OX + c.x * CS + 20, OY + c.y * CS + 20, CS - 40, CS - 40),
				Color(PAL[i].r, PAL[i].g, PAL[i].b, 0.5))
	for i in pairs.size():
		for c in pairs[i]:
			draw_circle(Vector2(OX + c.x * CS + CS * 0.5, OY + c.y * CS + CS * 0.5), CS * 0.32, PAL[i])
	draw_string(f(), Vector2(40, H - 16), "drag from a dot to its twin",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
