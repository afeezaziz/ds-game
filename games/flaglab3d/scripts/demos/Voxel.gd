extends MechDemo3D
## VOXEL BUILDER — first-person on a block grid. Look to aim; MINE the block
## under the crosshair (J), PLACE one on the air cell before it (F), JUMP (Space).
## Walk with WASD / stick. Survive the ~40s day/night cycle: at NIGHT mobs swarm
## from the edges and drain HP — wall yourself in. Score = blocks mined + nights.

const GRAV := 24.0
const SPEED := 4.4
const EYE_H := 1.55
const CYCLE := 40.0
const JUMP_V := 8.5
const REACH := 6.0
const WORLD := 16
const MAX_HP := 100.0
const MOB_SPEED := 1.7
const DRAIN := 22.0
const BTYPES := [
	Color(0.42, 0.7, 0.36),   # 0 grass
	Color(0.55, 0.4, 0.28),   # 1 dirt
	Color(0.56, 0.56, 0.62),  # 2 stone
	Color(0.5, 0.35, 0.2),    # 3 wood
]

var tc: TouchControls
var yaw := 0.0
var pitch := 0.0
var ppos := Vector3(8, EYE_H + 1.0, 8)
var vy := 0.0
var grounded := false
var blocks := {}          # Vector3i -> {"type": int, "node": MeshInstance3D}
var inv := {}             # type:int -> count:int
var sel_type := 0
var mobs: Array = []
var mined := 0
var nights := 0
var hp := MAX_HP
var day_t := 8.0
var is_night := false
var dmg_cd := 0.0
var env: Environment
var hud: Label3D
var cross: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.7, 0.95), 0.85, Vector3(-58, -35, 0))
	for c in get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
	_gen_world()
	make_camera(ppos, ppos + Vector3.FORWARD, 72.0)
	cross = label3d("+", Vector3(0, 0, -1.2), 70, Color(1, 1, 1, 0.85), cam)
	hud = label3d("", Vector3(-0.62, -0.42, -1.1), 34, Color.WHITE, cam)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	tc = add_touch_controls([
		{"id": "mine", "label": "MINE", "col": Color(0.8, 0.6, 0.4)},
		{"id": "place", "label": "PLACE", "col": Color(0.5, 0.7, 0.9)},
		{"id": "jump", "label": "JUMP", "col": Color(0.6, 0.85, 0.55)},
	], true)
	tc.action.connect(func(id):
		if id == "mine":
			_mine()
		elif id == "place":
			_place()
		elif id == "jump":
			_jump())
	tc.look.connect(_on_look)


func _on_look(rel: Vector2) -> void:
	yaw -= rel.x * 0.005
	pitch = clampf(pitch - rel.y * 0.004, -1.4, 1.4)


func _gen_world() -> void:
	for x in WORLD:
		for z in WORLD:
			var t := 1 if (x + z) % 5 == 0 else 0
			_add_block(Vector3i(x, 0, z), t)
	for i in 9:
		var px := randi_range(2, WORLD - 3)
		var pz := randi_range(2, WORLD - 3)
		var h := randi_range(1, 3)
		for y in h:
			_add_block(Vector3i(px, 1 + y, pz), 2)
	inv[0] = 6
	inv[2] = 4


func _add_block(cell: Vector3i, t: int) -> void:
	var m := mesh_box(Vector3.ONE * 0.98, Vector3(cell) + Vector3(0.5, 0.5, 0.5), BTYPES[t])
	blocks[cell] = {"type": t, "node": m}


func _solid(x: int, y: int, z: int) -> bool:
	return blocks.has(Vector3i(x, y, z))


func _surface(x: int, z: int) -> int:
	for y in range(6, -2, -1):
		if _solid(x, y, z):
			return y + 1
	return 0


func _ray() -> Dictionary:
	var origin := ppos
	var aim := -cam.global_transform.basis.z
	var prev := Vector3i(floori(origin.x), floori(origin.y), floori(origin.z))
	var d := 0.0
	while d < REACH:
		var p := origin + aim * d
		var c := Vector3i(floori(p.x), floori(p.y), floori(p.z))
		if blocks.has(c):
			return {"hit": true, "cell": c, "prev": prev}
		prev = c
		d += 0.12
	return {"hit": false}


func _mine() -> void:
	var r := _ray()
	if not r.get("hit", false):
		return
	var c: Vector3i = r["cell"]
	var bt: int = blocks[c]["type"]
	blocks[c]["node"].queue_free()
	blocks.erase(c)
	inv[bt] = int(inv.get(bt, 0)) + 1
	sel_type = bt
	mined += 1
	add_points(1)
	Juice.sfx("thud", 1.1)
	Juice.haptic(18)
	Juice.flash(Color(0.85, 0.6, 0.35), 0.12)


func _place() -> void:
	var r := _ray()
	if not r.get("hit", false):
		return
	var c: Vector3i = r["prev"]
	if blocks.has(c) or c.y < 0:
		return
	var feet := ppos.y - EYE_H
	if c.x == floori(ppos.x) and c.z == floori(ppos.z) and c.y >= floori(feet) and c.y <= floori(ppos.y):
		return
	var t := _pick_type()
	if t < 0:
		return
	inv[t] = int(inv[t]) - 1
	_add_block(c, t)
	Juice.sfx("thud")
	Juice.haptic(18)
	Juice.flash(Color(0.5, 0.7, 0.9), 0.1)


func _pick_type() -> int:
	if int(inv.get(sel_type, 0)) > 0:
		return sel_type
	for t in inv:
		if int(inv[t]) > 0:
			return int(t)
	return -1


func _jump() -> void:
	if grounded:
		vy = JUMP_V
		grounded = false
		Juice.sfx("tick")
		Juice.haptic(12)


func _spawn_night() -> void:
	var n := clampi(2 + nights, 2, 7)
	for i in n:
		var e := randi_range(0, 3)
		var mx := randf_range(0.6, WORLD - 0.6)
		var mz := randf_range(0.6, WORLD - 0.6)
		if e == 0:
			mx = 0.6
		elif e == 1:
			mx = WORLD - 0.6
		elif e == 2:
			mz = 0.6
		else:
			mz = WORLD - 0.6
		var sy := _surface(floori(mx), floori(mz))
		var node := mesh_box(Vector3(0.7, 1.0, 0.7), Vector3(mx, sy + 0.5, mz), Color(0.75, 0.25, 0.3))
		mobs.append({"node": node})


func _end_night() -> void:
	for m in mobs:
		m["node"].queue_free()
	mobs.clear()
	nights += 1
	add_points(20)
	Juice.sfx("chime")
	Juice.flash(Color(0.6, 0.9, 0.6), 0.22)
	Juice.haptic(35)


func _update_cycle(delta: float) -> void:
	day_t += delta
	var phase := fmod(day_t, CYCLE) / CYCLE
	var was := is_night
	is_night = phase >= 0.5
	if is_night and not was:
		_spawn_night()
	elif was and not is_night:
		_end_night()
	if env:
		var nf := 0.0 if phase < 0.5 else (phase - 0.5) * 2.0
		env.ambient_light_energy = lerpf(0.85, 0.2, nf)
		env.background_color = Color(0.5, 0.7, 0.95).lerp(Color(0.03, 0.04, 0.1), nf)


func _move(delta: float) -> void:
	var fwd := -cam.global_transform.basis.z
	var right := cam.global_transform.basis.x
	fwd.y = 0.0
	right.y = 0.0
	fwd = fwd.normalized()
	right = right.normalized()
	var ix := key_axis_x() + tc.move.x
	var iy := key_axis_y() - tc.move.y
	var want := (right * ix + fwd * iy).limit_length(1.0) * SPEED * delta
	var feet := ppos.y - EYE_H
	var cy := floori(feet + 0.5)
	var nx := ppos.x + want.x
	var nz := ppos.z + want.z
	if not _solid(floori(nx), cy, floori(ppos.z)):
		ppos.x = clampf(nx, 0.6, WORLD - 0.6)
	if not _solid(floori(ppos.x), cy, floori(nz)):
		ppos.z = clampf(nz, 0.6, WORLD - 0.6)
	vy -= GRAV * delta
	ppos.y += vy * delta
	feet = ppos.y - EYE_H
	var gy := floori(feet - 0.02)
	grounded = false
	if _solid(floori(ppos.x), gy, floori(ppos.z)) and vy <= 0.0 and feet <= gy + 1.05:
		ppos.y = gy + 1.0 + EYE_H
		vy = 0.0
		grounded = true
	if ppos.y < -4.0:
		ppos = Vector3(8, EYE_H + 4.0, 8)
		vy = 0.0
		hp -= 15.0


func _mobs_step(delta: float) -> void:
	dmg_cd = maxf(0.0, dmg_cd - delta)
	for m in mobs:
		var mp: Vector3 = m["node"].position
		var to := Vector3(ppos.x - mp.x, 0.0, ppos.z - mp.z)
		if to.length() < 1.15:
			hp -= DRAIN * delta
			if dmg_cd <= 0.0:
				dmg_cd = 0.4
				Juice.sfx("thud", 0.7)
				Juice.flash(Color(0.9, 0.2, 0.2), 0.18)
				Juice.haptic(30)
		else:
			var s := to.normalized() * MOB_SPEED * delta
			var cy := floori(mp.y)
			if not _solid(floori(mp.x + s.x), cy, floori(mp.z)):
				mp.x += s.x
			if not _solid(floori(mp.x), cy, floori(mp.z + s.z)):
				mp.z += s.z
		mp.y = _surface(floori(mp.x), floori(mp.z)) + 0.5
		m["node"].position = mp


func _inv_total() -> int:
	var n := 0
	for t in inv:
		n += int(inv[t])
	return n


func _process(delta: float) -> void:
	if not running:
		return
	cam.position = ppos
	cam.basis = Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, pitch)
	_update_cycle(delta)
	_move(delta)
	if is_night:
		_mobs_step(delta)
	cross.modulate = Color(1, 0.9, 0.3, 0.9) if _ray().get("hit", false) else Color(1, 1, 1, 0.7)
	hud.text = "HP %d\n%s\nMINED %d\nBLOCKS %d" % [
		int(maxf(hp, 0.0)), ("NIGHT" if is_night else "DAY"), mined, _inv_total()]
	if hp <= 0.0:
		Juice.sfx("boom")
		Juice.flash(Color(1, 0.3, 0.3), 0.4)
		Juice.haptic(60)
		end_demo()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			_mine()
		elif event.keycode == KEY_F:
			_place()
		elif event.keycode == KEY_SPACE:
			_jump()
