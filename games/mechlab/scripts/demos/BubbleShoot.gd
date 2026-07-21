extends MechDemo
## BUBBLE SHOOTER — aim and shoot; 3+ same-colour touching pop (Puzzle Bobble,
## 1994). Drag to aim, release to fire. Clear the board to re-rack. 20 shots;
## a shot that pops nothing costs one. Score = bubbles popped.

const COLS := 9
const CS := 80.0
const OX := 0.0
const TOP := 150.0
const MAXR := 9
const PAL := [Color(0.9, 0.35, 0.35), Color(0.35, 0.6, 0.95),
	Color(0.4, 0.85, 0.45), Color(0.95, 0.8, 0.3), Color(0.75, 0.45, 0.9)]

var grid: Array = []   # MAXR x COLS, -1 empty
var shots := 20
var cur := 0
var aim := Vector2(0, -1)
var flying := false
var bpos := Vector2.ZERO
var bvel := Vector2.ZERO
var launch := Vector2(360, 1120)


func start() -> void:
	super.start()
	shots = 20
	_rack()
	cur = randi() % PAL.size()
	flying = false
	queue_redraw()


func _rack() -> void:
	grid = []
	for r in MAXR:
		var row := []
		for c in COLS:
			row.append(randi() % PAL.size() if r < 4 else -1)
		grid.append(row)


func _cell_center(r: int, c: int) -> Vector2:
	return Vector2(OX + c * CS + CS * 0.5, TOP + r * CS + CS * 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if not running or flying:
		return
	if event is InputEventScreenDrag or (event is InputEventScreenTouch and event.pressed):
		var d: Vector2 = event.position - launch
		if d.y < -10.0:
			aim = d.normalized()
	if event is InputEventScreenTouch and not event.pressed:
		flying = true
		bpos = launch
		bvel = aim * 900.0
		queue_redraw()


func _process(delta: float) -> void:
	if not running or not flying:
		return
	bpos += bvel * delta
	if bpos.x < CS * 0.5:
		bpos.x = CS * 0.5
		bvel.x = absf(bvel.x)
	elif bpos.x > W - CS * 0.5:
		bpos.x = W - CS * 0.5
		bvel.x = -absf(bvel.x)
	var hit := bpos.y < TOP + CS * 0.5
	if not hit:
		for r in MAXR:
			for c in COLS:
				if grid[r][c] != -1 and bpos.distance_to(_cell_center(r, c)) < CS * 0.85:
					hit = true
					break
			if hit:
				break
	if hit:
		_snap()
	queue_redraw()


func _snap() -> void:
	flying = false
	var c := clampi(int(round((bpos.x - OX - CS * 0.5) / CS)), 0, COLS - 1)
	var r := clampi(int(round((bpos.y - TOP - CS * 0.5) / CS)), 0, MAXR - 1)
	if grid[r][c] != -1:
		r = mini(r + 1, MAXR - 1)
	grid[r][c] = cur
	var cluster := _cluster(r, c, cur)
	if cluster.size() >= 3:
		for p in cluster:
			grid[p.y][p.x] = -1
		add_points(cluster.size())
		Juice.sfx("chime")
	else:
		shots -= 1
		Juice.sfx("thud")
	cur = randi() % PAL.size()
	if _empty():
		add_points(30)
		_rack()
	if shots <= 0:
		end_demo()


func _cluster(r: int, c: int, col: int) -> Array:
	var seen := {}
	var stack := [Vector2i(c, r)]
	var out := []
	while not stack.is_empty():
		var p: Vector2i = stack.pop_back()
		if seen.has(p) or p.x < 0 or p.x >= COLS or p.y < 0 or p.y >= MAXR:
			continue
		if grid[p.y][p.x] != col:
			continue
		seen[p] = true
		out.append(p)
		stack.append(p + Vector2i(1, 0))
		stack.append(p + Vector2i(-1, 0))
		stack.append(p + Vector2i(0, 1))
		stack.append(p + Vector2i(0, -1))
	return out


func _empty() -> bool:
	for r in MAXR:
		for c in COLS:
			if grid[r][c] != -1:
				return false
	return true


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.08, 0.09, 0.13))
	for r in MAXR:
		for c in COLS:
			if grid[r][c] != -1:
				draw_circle(_cell_center(r, c), CS * 0.42, PAL[grid[r][c]])
	if not flying:
		draw_line(launch, launch + aim * 260.0, Color(1, 1, 1, 0.4), 3.0)
	draw_circle(bpos if flying else launch, CS * 0.42, PAL[cur])
	draw_string(f(), Vector2(20, 130), "SHOTS %d" % shots, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.85))
	draw_string(f(), Vector2(20, H - 16), "drag to aim, release to fire",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
