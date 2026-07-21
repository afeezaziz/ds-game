extends MechDemo
## BLOCK BLAST — drag polyomino pieces onto the grid; fill a full row or
## column to clear it (2022 chart-topper). No piece fits anywhere = over.
## Score = cells placed + line-clear bonus.

const N := 8
const CS := 78.0
const OX := 48.0
const OY := 210.0
const SHAPES := [
	[Vector2i(0, 0)],
	[Vector2i(0, 0), Vector2i(1, 0)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0)],
	[Vector2i(0, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(0, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1)],
	[Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0), Vector2i(1, 1)]]

var grid: Array = []
var tray: Array = []       # up to 3 shape arrays (or null)
var drag_i := -1
var drag_pos := Vector2.ZERO


func start() -> void:
	super.start()
	grid = []
	for r in N:
		var row := []
		for c in N:
			row.append(false)
		grid.append(row)
	_refill()
	queue_redraw()


func _refill() -> void:
	tray = []
	for i in 3:
		tray.append(SHAPES[randi() % SHAPES.size()])


func _tray_rect(i: int) -> Rect2:
	return Rect2(40 + i * 220, 980, 200, 200)


func _fits(shape: Array, gx: int, gy: int) -> bool:
	for o in shape:
		var x: int = gx + o.x
		var y: int = gy + o.y
		if x < 0 or x >= N or y < 0 or y >= N or grid[y][x]:
			return false
	return true


func _any_fit() -> bool:
	for s in tray:
		if s == null:
			continue
		for gy in N:
			for gx in N:
				if _fits(s, gx, gy):
					return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch and event.pressed:
		for i in tray.size():
			if tray[i] != null and _tray_rect(i).has_point(event.position):
				drag_i = i
				drag_pos = event.position
				return
	elif event is InputEventScreenDrag and drag_i >= 0:
		drag_pos = event.position
	elif event is InputEventScreenTouch and not event.pressed and drag_i >= 0:
		_drop()
		drag_i = -1
	queue_redraw()


func _drop() -> void:
	var gx := int(round((drag_pos.x - OX - CS * 0.5) / CS))
	var gy := int(round((drag_pos.y - OY - CS * 0.5) / CS))
	var shape: Array = tray[drag_i]
	if not _fits(shape, gx, gy):
		return
	for o in shape:
		grid[gy + o.y][gx + o.x] = true
	add_points(shape.size())
	tray[drag_i] = null
	_clear_lines()
	var all_used := true
	for s in tray:
		if s != null:
			all_used = false
	if all_used:
		_refill()
	if not _any_fit():
		end_demo()


func _clear_lines() -> void:
	var rows := []
	var cols := []
	for r in N:
		var full := true
		for c in N:
			if not grid[r][c]:
				full = false
		if full:
			rows.append(r)
	for c in N:
		var full := true
		for r in N:
			if not grid[r][c]:
				full = false
		if full:
			cols.append(c)
	for r in rows:
		for c in N:
			grid[r][c] = false
	for c in cols:
		for r in N:
			grid[r][c] = false
	var n := rows.size() + cols.size()
	if n > 0:
		add_points(n * 20)
		Juice.sfx("chime")


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.1, 0.14))
	for r in N:
		for c in N:
			var rr := Rect2(OX + c * CS + 3, OY + r * CS + 3, CS - 6, CS - 6)
			draw_rect(rr, Color(0.5, 0.75, 0.95) if grid[r][c] else Color(1, 1, 1, 0.05))
	for i in tray.size():
		if tray[i] == null:
			continue
		if i == drag_i:
			continue
		var tr := _tray_rect(i)
		for o in tray[i]:
			draw_rect(Rect2(tr.position + Vector2(o.x, o.y) * 40 + Vector2(10, 10), Vector2(36, 36)), Color(0.9, 0.7, 0.3))
	if drag_i >= 0 and tray[drag_i] != null:
		for o in tray[drag_i]:
			draw_rect(Rect2(drag_pos + Vector2(o.x, o.y) * CS - Vector2(CS * 0.5, CS * 0.5), Vector2(CS - 6, CS - 6)), Color(0.9, 0.7, 0.3, 0.9))
	draw_string(f(), Vector2(20, 180), "drag pieces onto the grid · fill rows/cols",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
