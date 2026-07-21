extends MechDemo
## MERGE BOARD — the Merge Mansion / Merge Dragons loop (2017-2020): tap the
## generator to spawn items, drag two of the same tier together to merge up,
## deliver ordered tiers for big rewards. Endless; score = merge value.

const COLS := 5
const ROWS := 6
const CS := 124.0
const OX := 50.0
const OY := 330.0
const GEN_R := Rect2(50, 170, 220, 120)
const ORDER_R := Rect2(450, 170, 220, 120)
const TIER_COLORS := [Color(0.6, 0.6, 0.6), Color(0.45, 0.75, 0.5), Color(0.35, 0.65, 0.95),
	Color(0.8, 0.55, 0.9), Color(0.95, 0.75, 0.3), Color(0.95, 0.4, 0.35), Color(1.0, 0.9, 0.5)]

var g: Array = []
var energy := 20
var regen := 0.0
var order_tier := 3
var orders_done := 0
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
	energy = 20
	regen = 0.0
	order_tier = 3
	orders_done = 0
	drag_from = Vector2i(-1, -1)
	queue_redraw()


func _cell_at(p: Vector2) -> Vector2i:
	var cx := int((p.x - OX) / CS)
	var cy := int((p.y - OY) / CS)
	if cx < 0 or cx >= COLS or cy < 0 or cy >= ROWS or p.x < OX or p.y < OY:
		return Vector2i(-1, -1)
	return Vector2i(cx, cy)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch and event.pressed:
		if GEN_R.has_point(event.position):
			_spawn_item()
			return
		var c := _cell_at(event.position)
		if c != Vector2i(-1, -1) and g[c.x][c.y] > 0:
			drag_from = c
			drag_pos = event.position
	elif event is InputEventScreenDrag and drag_from != Vector2i(-1, -1):
		drag_pos = event.position
	elif event is InputEventScreenTouch and not event.pressed and drag_from != Vector2i(-1, -1):
		_drop(event.position)
		drag_from = Vector2i(-1, -1)
	queue_redraw()


func _spawn_item() -> void:
	if energy <= 0:
		return
	for attempt in 40:
		var c := Vector2i(randi() % COLS, randi() % ROWS)
		if g[c.x][c.y] == 0:
			g[c.x][c.y] = 1
			energy -= 1
			return


func _drop(p: Vector2) -> void:
	var tier: int = g[drag_from.x][drag_from.y]
	if ORDER_R.has_point(p):
		if tier == order_tier:
			g[drag_from.x][drag_from.y] = 0
			add_points(100 * order_tier)
			orders_done += 1
			energy = mini(energy + 12, 40)
			order_tier = randi_range(2, mini(3 + orders_done / 2, 6))
		return
	var c := _cell_at(p)
	if c == Vector2i(-1, -1) or c == drag_from:
		return
	if g[c.x][c.y] == 0:
		g[c.x][c.y] = tier
		g[drag_from.x][drag_from.y] = 0
	elif g[c.x][c.y] == tier and tier < TIER_COLORS.size() - 1:
		g[c.x][c.y] = tier + 1
		g[drag_from.x][drag_from.y] = 0
		add_points(10 * int(pow(2, tier)))


func _process(delta: float) -> void:
	if not running:
		return
	regen += delta
	if regen >= 2.0:
		regen = 0.0
		energy = mini(energy + 1, 40)
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.1, 0.09))
	draw_rect(GEN_R, Color(0.25, 0.4, 0.3) if energy > 0 else Color(0.2, 0.2, 0.2))
	draw_string(f(), Vector2(GEN_R.position.x, GEN_R.position.y + 52), "TAP: SPAWN",
		HORIZONTAL_ALIGNMENT_CENTER, GEN_R.size.x, 26, Color.WHITE)
	draw_string(f(), Vector2(GEN_R.position.x, GEN_R.position.y + 94), "energy %d" % energy,
		HORIZONTAL_ALIGNMENT_CENTER, GEN_R.size.x, 24, Color(0.8, 1, 0.8))
	draw_rect(ORDER_R, Color(0.4, 0.32, 0.2))
	draw_string(f(), Vector2(ORDER_R.position.x, ORDER_R.position.y + 52), "ORDER: T%d" % order_tier,
		HORIZONTAL_ALIGNMENT_CENTER, ORDER_R.size.x, 28, Color(1, 0.9, 0.5))
	draw_string(f(), Vector2(ORDER_R.position.x, ORDER_R.position.y + 94), "drop here → +%d" % (100 * order_tier),
		HORIZONTAL_ALIGNMENT_CENTER, ORDER_R.size.x, 22, Color(1, 1, 1, 0.6))
	for x in COLS:
		for y in ROWS:
			var r := Rect2(OX + x * CS + 4, OY + y * CS + 4, CS - 8, CS - 8)
			draw_rect(r, Color(1, 1, 1, 0.05))
			var tier: int = g[x][y]
			if tier > 0 and Vector2i(x, y) != drag_from:
				_item(r.get_center(), tier)
	if drag_from != Vector2i(-1, -1):
		_item(drag_pos, g[drag_from.x][drag_from.y])
	draw_string(f(), Vector2(20, H - 16), "drag same tiers together · fill orders · endless",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))


func _item(center: Vector2, tier: int) -> void:
	draw_circle(center, 44.0, TIER_COLORS[tier])
	draw_string(f(), Vector2(center.x - 40, center.y + 12), str(tier),
		HORIZONTAL_ALIGNMENT_CENTER, 80, 34, Color(0, 0, 0, 0.7))
