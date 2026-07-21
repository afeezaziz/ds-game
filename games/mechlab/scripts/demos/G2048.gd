extends MechDemo
## 2048 — slide-and-merge (2014). Swipe to slide all tiles; equal tiles merge
## and double. No moves left = over. Score = sum of merges.

const N := 4
const CS := 150.0
const OX := 60.0
const OY := 340.0

var g: Array = []
var _ts := Vector2.ZERO


func start() -> void:
	super.start()
	g = []
	for i in N:
		var row := []
		for j in N:
			row.append(0)
		g.append(row)
	_spawn()
	_spawn()
	queue_redraw()


func _spawn() -> void:
	var empties := []
	for r in N:
		for c in N:
			if g[r][c] == 0:
				empties.append(Vector2i(c, r))
	if empties.is_empty():
		return
	var p: Vector2i = empties.pick_random()
	g[p.y][p.x] = 2 if randf() < 0.9 else 4


func _merge_line(line: Array) -> Array:
	var vals := []
	for v in line:
		if v != 0:
			vals.append(v)
	var out := []
	var i := 0
	while i < vals.size():
		if i + 1 < vals.size() and vals[i] == vals[i + 1]:
			out.append(vals[i] * 2)
			add_points(vals[i] * 2)
			i += 2
		else:
			out.append(vals[i])
			i += 1
	while out.size() < N:
		out.append(0)
	return out


func _slide(dx: int, dy: int) -> void:
	var before := str(g)
	for _pass in 1:
		if dx == -1:
			for r in N:
				g[r] = _merge_line(g[r])
		elif dx == 1:
			for r in N:
				var rev: Array = g[r].duplicate()
				rev.reverse()
				rev = _merge_line(rev)
				rev.reverse()
				g[r] = rev
		elif dy == -1:
			for c in N:
				var col := []
				for r in N:
					col.append(g[r][c])
				col = _merge_line(col)
				for r in N:
					g[r][c] = col[r]
		else:
			for c in N:
				var col := []
				for r in range(N - 1, -1, -1):
					col.append(g[r][c])
				col = _merge_line(col)
				var k := 0
				for r in range(N - 1, -1, -1):
					g[r][c] = col[k]
					k += 1
	if str(g) != before:
		_spawn()
		Juice.sfx("tick")
		if not _has_move():
			end_demo()
	queue_redraw()


func _has_move() -> bool:
	for r in N:
		for c in N:
			if g[r][c] == 0:
				return true
			if c + 1 < N and g[r][c] == g[r][c + 1]:
				return true
			if r + 1 < N and g[r][c] == g[r + 1][c]:
				return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch):
		return
	if event.pressed:
		_ts = event.position
		return
	var d: Vector2 = event.position - _ts
	if d.length() < 30.0:
		return
	if absf(d.x) > absf(d.y):
		_slide(signi(int(d.x)), 0)
	else:
		_slide(0, signi(int(d.y)))


func _tile_col(v: int) -> Color:
	if v == 0:
		return Color(1, 1, 1, 0.05)
	var t: float = clampf(log(float(v)) / log(2048.0), 0.0, 1.0)
	return Color(0.9, 0.75 - t * 0.5, 0.3 + t * 0.1)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.09, 0.08))
	draw_string(f(), Vector2(60, 260), "2048 — swipe to slide", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	for r in N:
		for c in N:
			var rr := Rect2(OX + c * CS + 6, OY + r * CS + 6, CS - 12, CS - 12)
			draw_rect(rr, _tile_col(g[r][c]))
			if g[r][c] != 0:
				draw_string(f(), Vector2(rr.position.x, rr.get_center().y + 16), str(g[r][c]),
					HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 44, Color(0.1, 0.1, 0.1))
