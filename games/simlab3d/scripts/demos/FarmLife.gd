extends MechDemo3D
## FARM & LIFE SIM — plant, grow, harvest, reinvest (Stardew). Walk the field and
## ACT on the tile underfoot: till soil, plant a seed, then harvest once it ripens
## over the days. Crops grow while you work other plots; sell for coins to plant
## more. Greet the townsfolk for a daily gift. Endless. Desktop: WASD move, J act, K talk.

const N := 8
const CELL := 3.0
var grid := {}                # Vector2i -> state 0 empty/1 tilled/2 planted/3 ripe
var growth := {}              # Vector2i -> 0..1
var crop_nodes := {}          # Vector2i -> MeshInstance3D
var player: Node3D
var ppos := Vector3.ZERO
var coins := 20
var harvested := 0
var day := 1
var day_t := 0.0
var townsfolk: Array = []     # {node,pos,cd}
var friends := 0
var tc: TouchControls
var hud: Label3D
const SEED_COST := 3
const SELL := 10


func start() -> void:
	super.start()
	setup_world(Color(0.55, 0.75, 0.9), 0.95)
	static_box(Vector3(N * CELL + 4, 1, N * CELL + 4), Vector3(0, -0.5, 0), Color(0.35, 0.55, 0.32))
	for x in N:
		for z in N:
			mesh_box(Vector3(CELL - 0.2, 0.1, CELL - 0.2), _w(Vector2i(x, z)) + Vector3(0, 0.05, 0), Color(0.45, 0.35, 0.25, 0.5))
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(1.0, 1.8, 1.0), Vector3(0, 0.9, 0), Color(0.9, 0.8, 0.4), player)
	ppos = _w(Vector2i(4, 4))
	coins = 20
	harvested = 0
	day = 1
	for i in 2:
		var node := Node3D.new()
		add_child(node)
		mesh_box(Vector3(1.0, 1.8, 1.0), Vector3(0, 0.9, 0), Color(0.6, 0.5, 0.9), node)
		var p := _w(Vector2i(i * (N - 1), 0)) + Vector3(0, 0, -4)
		node.position = p
		townsfolk.append({"node": node, "pos": p, "cd": 0.0})
	make_camera(Vector3(0, 22, 20), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 10, 0), 32, Color.WHITE)
	tc = add_touch_controls([
		{"id": "act", "label": "ACT", "col": Color(0.6, 0.8, 0.4)},
		{"id": "talk", "label": "TALK", "col": Color(0.6, 0.6, 0.95)},
	])
	tc.action.connect(func(id):
		if id == "act": _act()
		elif id == "talk": _talk())


func _w(c: Vector2i) -> Vector3:
	return Vector3((c.x - N * 0.5 + 0.5) * CELL, 0, (c.y - N * 0.5 + 0.5) * CELL)


func _cell() -> Vector2i:
	return Vector2i(int(round(ppos.x / CELL + N * 0.5 - 0.5)), int(round(ppos.z / CELL + N * 0.5 - 0.5)))


func _act() -> void:
	var c := _cell()
	if c.x < 0 or c.x >= N or c.y < 0 or c.y >= N:
		return
	var st: int = grid.get(c, 0)
	if st == 0:
		grid[c] = 1
		Juice.sfx("thud")
	elif st == 1:
		if coins < SEED_COST:
			return
		coins -= SEED_COST
		grid[c] = 2
		growth[c] = 0.0
		var node := mesh_sphere(0.3, _w(c) + Vector3(0, 0.4, 0), Color(0.4, 0.8, 0.3))
		crop_nodes[c] = node
		Juice.sfx("tick")
	elif st == 3:
		grid[c] = 0
		coins += SELL
		harvested += 1
		add_points(1)
		set_score(harvested)
		if crop_nodes.has(c):
			crop_nodes[c].queue_free()
			crop_nodes.erase(c)
		Juice.sfx("coin")
		Juice.popup("+%d" % SELL, Vector2(W * 0.5, H * 0.4), Color(1, 0.9, 0.4))


func _talk() -> void:
	for tf in townsfolk:
		if ppos.distance_to(tf.pos) < 3.0 and tf.cd <= 0.0:
			tf.cd = 10.0
			friends += 1
			coins += 6
			Juice.sfx("chime")
			Juice.popup("♥ +6", Vector2(W * 0.5, H * 0.38), Color(1, 0.7, 0.8))
			return


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: _act()
		elif event.keycode == KEY_K: _talk()


func _process(delta: float) -> void:
	if not running:
		return
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * 8.0 * delta
	ppos.x = clampf(ppos.x, -N * CELL * 0.5, N * CELL * 0.5)
	ppos.z = clampf(ppos.z, -N * CELL * 0.5 - 5, N * CELL * 0.5)
	player.position = ppos
	if mv.length() > 0.1:
		player.rotation.y = atan2(mv.x, mv.z)

	# crops grow over time; a day passes every ~14s
	day_t += delta
	if day_t >= 14.0:
		day_t = 0.0
		day += 1
	for c in grid.keys():
		if grid[c] == 2:
			growth[c] = min(1.0, growth[c] + delta / 20.0)
			if crop_nodes.has(c):
				var g: float = growth[c]
				crop_nodes[c].position = _w(c) + Vector3(0, 0.4 + g * 0.8, 0)
				crop_nodes[c].scale = Vector3.ONE * (0.6 + g)
				(crop_nodes[c].material_override as StandardMaterial3D).albedo_color = Color(0.4, 0.8, 0.3).lerp(Color(0.95, 0.8, 0.2), g)
			if growth[c] >= 1.0:
				grid[c] = 3
	for tf in townsfolk:
		tf.cd = maxf(0.0, tf.cd - delta)

	cam.position = ppos + Vector3(0, 22, 20)
	cam.look_at(ppos, Vector3.UP)
	var st: int = grid.get(_cell(), 0)
	var hint := ["till", "plant ($%d)" % SEED_COST, "growing...", "HARVEST"][st]
	hud.text = "DAY %d   COINS %d   harvested %d   ♥%d   [tile: %s]" % [day, coins, harvested, friends, hint]
	hud.position = ppos + Vector3(0, 9, 0)
