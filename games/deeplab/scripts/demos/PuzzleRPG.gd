extends MechDemo
## PUZZLE RPG — match-3 fuels combat (Puzzle & Dragons / Empires & Puzzles).
## Tap a gem then an adjacent gem to swap; matches of 3+ damage the foe by
## colour. The foe hits back every move. Beat it to face a tougher one. Score =
## foes defeated.

const COLS := 6
const ROWS := 5
const CS := 116.0
const OX := 12.0
const OY := 620.0
const PAL := [Color(0.9, 0.35, 0.35), Color(0.4, 0.6, 0.95), Color(0.45, 0.85, 0.45),
	Color(0.95, 0.8, 0.35), Color(0.75, 0.45, 0.9)]

var g: Array = []
var sel := Vector2i(-1, -1)
var php := 100
var pmax := 100
var ehp := 40
var emax := 40
var eatk := 8
var elvl := 1


func start() -> void:
	super.start()
	php = 100
	pmax = 100
	elvl = 1
	_new_enemy()
	_fill()
	queue_redraw()


func _new_enemy() -> void:
	emax = 40 + elvl * 18
	ehp = emax
	eatk = 7 + elvl * 3


func _fill() -> void:
	g = []
	for x in COLS:
		var col := []
		for y in ROWS:
			col.append(randi() % PAL.size())
		g.append(col)
	while not _find().is_empty():
		for c in _find():
			g[c.x][c.y] = randi() % PAL.size()


func _find() -> Array:
	var found := {}
	for y in ROWS:
		var run := 1
		for x in range(1, COLS + 1):
			if x < COLS and g[x][y] == g[x - 1][y] and g[x][y] != -1:
				run += 1
			else:
				if run >= 3:
					for k in run:
						found[Vector2i(x - 1 - k, y)] = true
				run = 1
	for x in COLS:
		var run := 1
		for y in range(1, ROWS + 1):
			if y < ROWS and g[x][y] == g[x][y - 1] and g[x][y] != -1:
				run += 1
			else:
				if run >= 3:
					for k in run:
						found[Vector2i(x, y - 1 - k)] = true
				run = 1
	return found.keys()


func _gravity() -> void:
	for x in COLS:
		var stack := []
		for y in ROWS:
			if g[x][y] != -1:
				stack.append(g[x][y])
		while stack.size() < ROWS:
			stack.push_front(randi() % PAL.size())
		for y in ROWS:
			g[x][y] = stack[y]


func _cell(pos: Vector2) -> Vector2i:
	var c := Vector2i(int((pos.x - OX) / CS), int((pos.y - OY) / CS))
	if c.x < 0 or c.x >= COLS or c.y < 0 or c.y >= ROWS:
		return Vector2i(-1, -1)
	return c


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var c := _cell(event.position)
	if c == Vector2i(-1, -1):
		return
	if sel == Vector2i(-1, -1):
		sel = c
	elif absi(sel.x - c.x) + absi(sel.y - c.y) == 1:
		_swap(sel, c)
		sel = Vector2i(-1, -1)
	else:
		sel = c
	queue_redraw()


func _swap(a: Vector2i, b: Vector2i) -> void:
	var t: int = g[a.x][a.y]
	g[a.x][a.y] = g[b.x][b.y]
	g[b.x][b.y] = t
	if _find().is_empty():
		g[b.x][b.y] = g[a.x][a.y]
		g[a.x][a.y] = t
		return
	var total := 0
	var m := _find()
	while not m.is_empty():
		total += m.size()
		for c in m:
			g[c.x][c.y] = -1
		_gravity()
		m = _find()
	ehp -= total * 4
	Juice.sfx("thud")
	if ehp <= 0:
		add_points(1)
		elvl += 1
		Juice.sfx("chime")
		_new_enemy()
		return
	php -= eatk
	if php <= 0:
		Juice.sfx("boom")
		end_demo()


func _bar(x: float, y: float, w: float, frac: float, col: Color) -> void:
	draw_rect(Rect2(x, y, w, 28), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(x, y, w * clampf(frac, 0, 1), 28), col)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.08, 0.13))
	draw_string(f(), Vector2(0, 150), "FOE  Lv%d" % elvl, HORIZONTAL_ALIGNMENT_CENTER, W, 34, Color.WHITE)
	draw_circle(Vector2(360, 280), 74.0, Color(0.8, 0.3, 0.35))
	_bar(160, 400, 400, float(ehp) / float(emax), Color(0.9, 0.35, 0.35))
	draw_string(f(), Vector2(160, 440), "hits you for %d each move" % eatk, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 0.7, 0.6))
	_bar(160, 500, 400, float(php) / float(pmax), Color(0.4, 0.85, 0.45))
	draw_string(f(), Vector2(160, 496), "YOU %d/%d" % [max(0, php), pmax], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color.WHITE)
	for x in COLS:
		for y in ROWS:
			var ctr := Vector2(OX + x * CS + CS * 0.5, OY + y * CS + CS * 0.5)
			if g[x][y] >= 0:
				draw_circle(ctr, CS * 0.4, PAL[g[x][y]])
	if sel != Vector2i(-1, -1):
		draw_rect(Rect2(OX + sel.x * CS + 2, OY + sel.y * CS + 2, CS - 4, CS - 4), Color(1, 1, 1, 0.9), false, 4.0)
	draw_string(f(), Vector2(20, H - 16), "swap adjacent gems · matches deal damage", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
