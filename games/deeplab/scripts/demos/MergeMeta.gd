extends MechDemo
## MERGE META — a merge board wrapped in the energy + chapter economy that makes
## Merge Mansion a game, not a toy. Tap the generator (spends energy) to spawn;
## drag matching tiers together to merge up; deliver the ordered tier to advance
## the chapter. Endless; score = chapters completed.

const COLS := 5
const ROWS := 6
const CS := 124.0
const OX := 50.0
const OY := 360.0
const GEN_R := Rect2(40, 200, 200, 130)
const ORDER_R := Rect2(280, 200, 400, 130)
const TCOL := [Color(0.6, 0.6, 0.6), Color(0.45, 0.75, 0.5), Color(0.35, 0.65, 0.95),
	Color(0.8, 0.55, 0.9), Color(0.95, 0.75, 0.3), Color(0.95, 0.4, 0.35), Color(1.0, 0.9, 0.5)]

var g: Array = []
var energy := 15
var max_energy := 15
var regen := 0.0
var chapter := 1
var order_tier := 3
var order_need := 2
var order_done := 0
var drag_from := Vector2i(-1, -1)
var drag_pos := Vector2.ZERO


func start() -> void:
	super.start()
	g = []
	for x in COLS:
		var col := []
		for y in ROWS:
			col.append(0)
		g.append(col)
	energy = 15
	chapter = 1
	_new_order()
	queue_redraw()


func _new_order() -> void:
	order_tier = 2 + (chapter % 4)
	order_need = 2 + chapter / 2
	order_done = 0


func _cell(pos: Vector2) -> Vector2i:
	var cx := int((pos.x - OX) / CS)
	var cy := int((pos.y - OY) / CS)
	if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS or pos.x < OX or pos.y < OY:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch and event.pressed:
		if GEN_R.has_point(event.position):
			_spawn()
			return
		var c := _cell(event.position)
		if c != Vector2i(-1, -1) and g[c.x][c.y] > 0:
			drag_from = c
			drag_pos = event.position
	elif event is InputEventScreenDrag and drag_from != Vector2i(-1, -1):
		drag_pos = event.position
	elif event is InputEventScreenTouch and not event.pressed and drag_from != Vector2i(-1, -1):
		_drop(event.position)
		drag_from = Vector2i(-1, -1)
	queue_redraw()


func _spawn() -> void:
	if energy <= 0:
		return
	for attempt in 40:
		var c := Vector2i(randi() % COLS, randi() % ROWS)
		if g[c.x][c.y] == 0:
			g[c.x][c.y] = 1
			energy -= 1
			Juice.sfx("tick")
			return


func _drop(pos: Vector2) -> void:
	var tier: int = g[drag_from.x][drag_from.y]
	if ORDER_R.has_point(pos):
		if tier == order_tier:
			g[drag_from.x][drag_from.y] = 0
			order_done += 1
			Juice.sfx("coin")
			if order_done >= order_need:
				add_points(1)
				chapter += 1
				energy = max_energy
				Juice.sfx("chime")
				Juice.flash(Color(0.9, 0.8, 0.4), 0.25)
				_new_order()
		return
	var c := _cell(pos)
	if c == Vector2i(-1, -1) or c == drag_from:
		return
	if g[c.x][c.y] == 0:
		g[c.x][c.y] = tier
		g[drag_from.x][drag_from.y] = 0
	elif g[c.x][c.y] == tier and tier < TCOL.size() - 1:
		g[c.x][c.y] = tier + 1
		g[drag_from.x][drag_from.y] = 0
		Juice.sfx("chime")


func _process(delta: float) -> void:
	if not running:
		return
	regen += delta
	if regen >= 2.0:
		regen = 0.0
		energy = mini(energy + 1, max_energy)
		queue_redraw()


func _item(center: Vector2, tier: int) -> void:
	draw_circle(center, 44.0, TCOL[tier])
	draw_string(f(), Vector2(center.x - 40, center.y + 12), str(tier), HORIZONTAL_ALIGNMENT_CENTER, 80, 34, Color(0, 0, 0, 0.7))


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.1, 0.09))
	draw_string(f(), Vector2(0, 130), "CHAPTER %d" % chapter, HORIZONTAL_ALIGNMENT_CENTER, W, 40, Color(1, 0.9, 0.5))
	draw_rect(GEN_R, Color(0.25, 0.4, 0.3) if energy > 0 else Color(0.2, 0.2, 0.2))
	draw_string(f(), Vector2(GEN_R.position.x, GEN_R.position.y + 55), "SPAWN", HORIZONTAL_ALIGNMENT_CENTER, GEN_R.size.x, 28, Color.WHITE)
	draw_string(f(), Vector2(GEN_R.position.x, GEN_R.position.y + 100), "energy %d/%d" % [energy, max_energy], HORIZONTAL_ALIGNMENT_CENTER, GEN_R.size.x, 22, Color(0.8, 1, 0.8))
	draw_rect(ORDER_R, Color(0.4, 0.32, 0.2))
	draw_string(f(), Vector2(ORDER_R.position.x, ORDER_R.position.y + 52), "ORDER: deliver tier %d" % order_tier, HORIZONTAL_ALIGNMENT_CENTER, ORDER_R.size.x, 26, Color(1, 0.9, 0.5))
	draw_string(f(), Vector2(ORDER_R.position.x, ORDER_R.position.y + 98), "%d / %d  (drag here)" % [order_done, order_need], HORIZONTAL_ALIGNMENT_CENTER, ORDER_R.size.x, 24, Color.WHITE)
	for x in COLS:
		for y in ROWS:
			var rr := Rect2(OX + x * CS + 4, OY + y * CS + 4, CS - 8, CS - 8)
			draw_rect(rr, Color(1, 1, 1, 0.05))
			if g[x][y] > 0 and Vector2i(x, y) != drag_from:
				_item(rr.get_center(), g[x][y])
	if drag_from != Vector2i(-1, -1):
		_item(drag_pos, g[drag_from.x][drag_from.y])
	draw_string(f(), Vector2(20, H - 16), "spawn · merge matching tiers · deliver the order", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
