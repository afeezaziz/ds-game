extends MechDemo
## TETRIS — falling tetromino packing (1984). Tap left/right third to move,
## tap middle to rotate, swipe down to hard-drop. Clear lines for score.

const COLS := 10
const ROWS := 20
const CS := 58.0
const OX := 70.0
const OY := 70.0
const COLORS := [
	Color(0, 0, 0, 0), Color(0.3, 0.8, 0.9), Color(0.9, 0.85, 0.3),
	Color(0.7, 0.45, 0.9), Color(0.9, 0.6, 0.3), Color(0.4, 0.5, 0.9),
	Color(0.4, 0.85, 0.45), Color(0.9, 0.4, 0.4)]
const SHAPES := [
	[Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(2, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(-1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 1)],
	[Vector2i(0, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 1)]]

var board: Array = []
var piece: Array = []
var pcol := 1
var fall_t := 0.0
var interval := 0.5
var _ts := Vector2.ZERO


func start() -> void:
	super.start()
	board = []
	for r in ROWS:
		var row := []
		for c in COLS:
			row.append(0)
		board.append(row)
	interval = 0.5
	fall_t = 0.0
	_spawn()
	queue_redraw()


func _spawn() -> void:
	var si := randi() % SHAPES.size()
	pcol = si + 1
	piece = []
	for o in SHAPES[si]:
		piece.append(Vector2i(o.x + 4, o.y))
	if _collide(piece):
		end_demo()


func _collide(cells: Array) -> bool:
	for c in cells:
		if c.x < 0 or c.x >= COLS or c.y >= ROWS:
			return true
		if c.y >= 0 and board[c.y][c.x] != 0:
			return true
	return false


func _move(dx: int, dy: int) -> bool:
	var nc := []
	for c in piece:
		nc.append(c + Vector2i(dx, dy))
	if _collide(nc):
		return false
	piece = nc
	return true


func _rotate() -> void:
	var pivot: Vector2i = piece[0]
	var nc := []
	for c in piece:
		var rel: Vector2i = c - pivot
		nc.append(pivot + Vector2i(-rel.y, rel.x))
	if not _collide(nc):
		piece = nc
		Juice.sfx("tick")


func _lock() -> void:
	for c in piece:
		if c.y >= 0:
			board[c.y][c.x] = pcol
	var cleared := 0
	var r := ROWS - 1
	while r >= 0:
		var full := true
		for c in COLS:
			if board[r][c] == 0:
				full = false
				break
		if full:
			board.remove_at(r)
			var nr := []
			for c in COLS:
				nr.append(0)
			board.insert(0, nr)
			cleared += 1
		else:
			r -= 1
	if cleared > 0:
		add_points(cleared * cleared * 10)
		interval = maxf(0.12, interval - 0.008 * cleared)
		Juice.sfx("chime")
	else:
		Juice.sfx("thud")
	_spawn()


func _process(delta: float) -> void:
	if not running:
		return
	fall_t += delta
	if fall_t >= interval:
		fall_t = 0.0
		if not _move(0, 1):
			_lock()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch):
		return
	if event.pressed:
		_ts = event.position
		return
	var d: Vector2 = event.position - _ts
	if d.length() < 26.0:
		if event.position.x < W * 0.33:
			_move(-1, 0)
		elif event.position.x > W * 0.66:
			_move(1, 0)
		else:
			_rotate()
	elif d.y > 50.0 and absf(d.y) > absf(d.x):
		while _move(0, 1):
			pass
		_lock()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(OX, OY, COLS * CS, ROWS * CS), Color(0.06, 0.07, 0.1))
	for r in ROWS:
		for c in COLS:
			if board[r][c] != 0:
				_cell(c, r, COLORS[board[r][c]])
	for c in piece:
		if c.y >= 0:
			_cell(c.x, c.y, COLORS[pcol])
	draw_rect(Rect2(OX, OY, COLS * CS, ROWS * CS), Color(1, 1, 1, 0.15), false, 3.0)
	draw_string(f(), Vector2(OX, H - 20), "tap L/mid/R = move/rotate · swipe down = drop",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))


func _cell(c: int, r: int, col: Color) -> void:
	draw_rect(Rect2(OX + c * CS + 2, OY + r * CS + 2, CS - 4, CS - 4), col)
