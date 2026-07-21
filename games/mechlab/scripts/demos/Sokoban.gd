extends MechDemo
## SOKOBAN — push-block logic puzzles. Swipe to move; push crates onto goals.

const LEVELS := [
	["#####",
	 "#@$.#",
	 "#####"],
	["######",
	 "#    #",
	 "# $$ #",
	 "# .. #",
	 "#  @ #",
	 "######"],
	["#######",
	 "# ..  #",
	 "# $$  #",
	 "#  @  #",
	 "#######"],
]

var level_i := 0
var walls: Dictionary = {}
var goals: Array = []
var crates: Array = []
var player := Vector2i.ZERO
var moves := 0
var cs := 90.0
var off := Vector2.ZERO
var _touch_start := Vector2.ZERO


func start() -> void:
	super.start()
	level_i = 0
	_load_level()


func _load_level() -> void:
	walls.clear()
	goals.clear()
	crates.clear()
	moves = 0
	var rows: Array = LEVELS[level_i]
	var h := rows.size()
	var w := 0
	for row in rows:
		w = maxi(w, (row as String).length())
	cs = minf(90.0, minf(640.0 / w, 800.0 / h))
	off = Vector2((W - w * cs) * 0.5, (H - h * cs) * 0.45)
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			var c := Vector2i(x, y)
			if ch == "#":
				walls[c] = true
			elif ch == ".":
				goals.append(c)
			elif ch == "$":
				crates.append(c)
			elif ch == "@":
				player = c
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
		else:
			var d: Vector2 = event.position - _touch_start
			if d.length() < 34.0:
				return
			var dir := Vector2i(signi(int(d.x)), 0) if absf(d.x) > absf(d.y) \
				else Vector2i(0, signi(int(d.y)))
			_try_move(dir)


func _try_move(dir: Vector2i) -> void:
	var np := player + dir
	if walls.has(np):
		return
	if crates.has(np):
		var nnp := np + dir
		if walls.has(nnp) or crates.has(nnp):
			return
		crates[crates.find(np)] = nnp
	player = np
	moves += 1
	queue_redraw()
	# solved?
	for c in crates:
		if not goals.has(c):
			return
	add_points(maxi(20, 150 - moves * 2))
	level_i += 1
	if level_i >= LEVELS.size():
		end_demo()
	else:
		_load_level()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.09, 0.12))
	for c in walls.keys():
		draw_rect(_r(c), Color(0.3, 0.3, 0.38))
	for g in goals:
		draw_circle(_r(g).get_center(), cs * 0.16, Color(0.4, 0.9, 0.5, 0.7))
	for c in crates:
		var col := Color(0.4, 0.85, 0.45) if goals.has(c) else Color(0.85, 0.6, 0.3)
		draw_rect(Rect2(_r(c).position + Vector2(6, 6), Vector2(cs - 12, cs - 12)), col)
	draw_circle(_r(player).get_center(), cs * 0.32, Color(0.95, 0.95, 1.0))
	draw_string(f(), Vector2(20, 100), "LEVEL %d/%d   moves %d" % [level_i + 1, LEVELS.size(), moves],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.7))
	draw_string(f(), Vector2(20, H - 16), "swipe to move · push crates onto green dots",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))


func _r(c: Vector2i) -> Rect2:
	return Rect2(off + Vector2(c.x * cs, c.y * cs), Vector2(cs, cs))
