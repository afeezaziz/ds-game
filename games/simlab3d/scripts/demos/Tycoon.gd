extends MechDemo3D
## PARK TYCOON — build, attract, profit (Two Point / Planet Coaster). Pick a build
## type and tap a grid cell to place it: RIDES pull guests and earn, FOOD stalls take
## their money, DECOR lifts happiness (which grows the crowd). Guests wander, spend
## and leave if it's grim. Drag to orbit. Endless; score = peak guests. Desktop: drag orbit.

const N := 10
const CELL := 3.2
const TYPES := ["RIDE", "FOOD", "DECOR"]
const TCOST := [60, 35, 20]
const TCOL := [Color(0.9, 0.4, 0.5), Color(0.95, 0.8, 0.3), Color(0.5, 0.85, 0.6)]

var grid := {}                # Vector2i -> type index
var sel := 0
var coins := 120
var happiness := 0.5
var guests: Array = []        # {node,pos,target,cd}
var ride_cells: Array = []
var food_cells: Array = []
var peak := 0
var cam_yaw := 0.6
var _press := Vector2.ZERO
var _dragged := 0.0
var hud: Label3D
var tc: TouchControls
var spawn_t := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.7, 0.85), 0.95, Vector3(-60, -30, 0))
	static_box(Vector3(N * CELL + 4, 1, N * CELL + 4), Vector3(0, -0.5, 0), Color(0.35, 0.55, 0.4))
	for x in N:
		for z in N:
			mesh_box(Vector3(CELL - 0.2, 0.08, CELL - 0.2), _w(Vector2i(x, z)) + Vector3(0, 0.05, 0), Color(1, 1, 1, 0.05))
	grid = {}
	coins = 120
	happiness = 0.5
	guests = []
	peak = 0
	make_camera(Vector3(0, 26, 26), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 13, 0), 34, Color.WHITE)
	tc = add_touch_controls([
		{"id": "RIDE", "label": "RIDE $60", "col": TCOL[0]},
		{"id": "FOOD", "label": "FOOD $35", "col": TCOL[1]},
		{"id": "DECOR", "label": "DECOR $20", "col": TCOL[2]},
	], false, false)
	tc.action.connect(func(id): sel = TYPES.find(id))


func _w(c: Vector2i) -> Vector3:
	return Vector3((c.x - N * 0.5 + 0.5) * CELL, 0, (c.y - N * 0.5 + 0.5) * CELL)


func _ground_cell(sp: Vector2) -> Vector2i:
	var from := cam.project_ray_origin(sp)
	var dir := cam.project_ray_normal(sp)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	if hit == null:
		return Vector2i(-1, -1)
	var cx := int(round(hit.x / CELL + N * 0.5 - 0.5))
	var cz := int(round(hit.z / CELL + N * 0.5 - 0.5))
	if cx < 0 or cx >= N or cz < 0 or cz >= N:
		return Vector2i(-1, -1)
	return Vector2i(cx, cz)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press = event.position
			_dragged = 0.0
		elif _dragged < 16.0:
			var c := _ground_cell(event.position)
			if c != Vector2i(-1, -1) and not grid.has(c) and coins >= TCOST[sel]:
				coins -= TCOST[sel]
				grid[c] = sel
				var h := [4.0, 2.0, 1.2][sel]
				mesh_box(Vector3(CELL - 0.5, h, CELL - 0.5), _w(c) + Vector3(0, h * 0.5, 0), TCOL[sel])
				if sel == 0: ride_cells.append(c)
				elif sel == 1: food_cells.append(c)
				Juice.sfx("coin")
	elif event is InputEventScreenDrag:
		_dragged += event.relative.length()
		cam_yaw += event.relative.x * 0.005


func _process(delta: float) -> void:
	if not running:
		return
	# happiness from decor share; guests want rides+food
	var decor := 0
	for v in grid.values():
		if v == 2: decor += 1
	var attractions: int = ride_cells.size() + food_cells.size()
	happiness = clampf(0.3 + decor * 0.06 - guests.size() * 0.008, 0.0, 1.0)

	# spawn guests based on rides + happiness
	spawn_t -= delta
	if spawn_t <= 0.0 and not ride_cells.is_empty() and guests.size() < 60:
		spawn_t = maxf(0.4, 2.5 - ride_cells.size() * 0.15)
		if randf() < happiness + 0.2:
			var node := mesh_box(Vector3(0.7, 1.2, 0.7), Vector3.ZERO, hue_col(guests.size() * 0.1, 0.5, 0.9))
			var p := Vector3(randf_range(-1, 1), 0.6, N * CELL * 0.5 + 2)
			node.position = p
			guests.append({"node": node, "pos": p, "target": _pick_target(), "cd": 0.0})

	for g in guests.duplicate():
		var to: Vector3 = g.target - g.pos
		if to.length() < 1.2:
			g.cd -= delta
			if g.cd <= 0.0:
				# earn at the destination, then re-target or leave
				coins += 5 if randf() < 0.5 else 3
				g.cd = randf_range(1.0, 2.5)
				if randf() < 0.2 or happiness < 0.3:
					g.node.queue_free()
					guests.erase(g)
					continue
				g.target = _pick_target()
		else:
			g.pos += to.normalized() * 4.0 * delta
			g.node.position = g.pos

	peak = maxi(peak, guests.size())
	set_score(peak)

	var r := 36.0
	cam.position = Vector3(sin(cam_yaw) * r, 26, cos(cam_yaw) * r)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	hud.text = "GUESTS %d (peak %d)   COINS %d   HAPPY %d%%   [%s]" % [
		guests.size(), peak, coins, int(happiness * 100), TYPES[sel]]
	hud.position = Vector3(0, 13, 0)


func _pick_target() -> Vector3:
	var pool: Array = ride_cells + food_cells
	if pool.is_empty():
		return Vector3(0, 0.6, 0)
	return _w(pool[randi() % pool.size()]) + Vector3(0, 0.6, 0)
