extends MechDemo
## MATCH-3 — swap adjacent gems, clear runs of 3+, cascades multiply.
## 25 moves, Candy Crush rules at their core. Tap a gem, tap its neighbor.

const COLS := 7
const ROWS := 9
const CS := 92.0
const OX := (720.0 - COLS * CS) * 0.5
const OY := 190.0
const PALETTE := [Color(0.9, 0.3, 0.3), Color(0.3, 0.6, 0.95), Color(0.35, 0.85, 0.4),
	Color(0.95, 0.8, 0.25), Color(0.75, 0.4, 0.9)]

var g: Array = []
var sel := Vector2i(-1, -1)
var moves_left := 25


func start() -> void:
	super.start()
	moves_left = 25
	sel = Vector2i(-1, -1)
	g = []
	for x in COLS:
		var col := []
		for y in ROWS:
			col.append(randi() % PALETTE.size())
		g.append(col)
	# reroll starting matches so the board opens stable
	var m := _matches()
	while not m.is_empty():
		for c in m:
			g[c.x][c.y] = randi() % PALETTE.size()
		m = _matches()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var cx := int((event.position.x - OX) / CS)
	var cy := int((event.position.y - OY) / CS)
	if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS:
		return
	var cell := Vector2i(cx, cy)
	if sel == Vector2i(-1, -1):
		sel = cell
	elif absi(sel.x - cell.x) + absi(sel.y - cell.y) == 1:
		_try_swap(sel, cell)
		sel = Vector2i(-1, -1)
	else:
		sel = cell
	queue_redraw()


func _try_swap(a: Vector2i, b: Vector2i) -> void:
	var tmp: int = g[a.x][a.y]
	g[a.x][a.y] = g[b.x][b.y]
	g[b.x][b.y] = tmp
	var m := _matches()
	if m.is_empty():
		g[b.x][b.y] = g[a.x][a.y]
		g[a.x][a.y] = tmp
		return
	moves_left -= 1
	var mult := 1
	while not m.is_empty():
		add_points(m.size() * 10 * mult)
		for c in m:
			g[c.x][c.y] = -1
		_gravity()
		mult += 1
		m = _matches()
	if moves_left <= 0:
		end_demo()


func _matches() -> Array:
	var found := {}
	for y in ROWS:
		var run := 1
		for x in range(1, COLS + 1):
			if x < COLS and g[x][y] != -1 and g[x][y] == g[x - 1][y]:
				run += 1
			else:
				if run >= 3:
					for k in run:
						found[Vector2i(x - 1 - k, y)] = true
				run = 1
	for x in COLS:
		var run := 1
		for y in range(1, ROWS + 1):
			if y < ROWS and g[x][y] != -1 and g[x][y] == g[x][y - 1]:
				run += 1
			else:
				if run >= 3:
					for k in run:
						found[Vector2i(x, y - 1 - k)] = true
				run = 1
	return found.keys()


func _gravity() -> void:
	for x in COLS:
		var write := ROWS - 1
		for y in range(ROWS - 1, -1, -1):
			if g[x][y] != -1:
				g[x][write] = g[x][y]
				write -= 1
		for y in range(write, -1, -1):
			g[x][y] = randi() % PALETTE.size()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.08, 0.14))
	for x in COLS:
		for y in ROWS:
			var r := Rect2(OX + x * CS + 4, OY + y * CS + 4, CS - 8, CS - 8)
			draw_rect(r, Color(1, 1, 1, 0.05))
			if g[x][y] >= 0:
				draw_circle(r.get_center(), CS * 0.36, PALETTE[g[x][y]])
	if sel != Vector2i(-1, -1):
		draw_rect(Rect2(OX + sel.x * CS + 2, OY + sel.y * CS + 2, CS - 4, CS - 4),
			Color(1, 1, 1, 0.9), false, 5.0)
	draw_string(f(), Vector2(20, 150), "MOVES %d" % moves_left,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.8))
	draw_string(f(), Vector2(20, H - 16), "tap a gem, then a neighbour to swap",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
