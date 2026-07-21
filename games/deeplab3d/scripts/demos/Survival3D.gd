extends MechDemo3D
## SURVIVAL 3D — a Valheim / Rust-lite loop. GATHER wood from trees and stone from
## rocks by walking into them and holding attack. By day you build; at NIGHT
## raiders spawn at the edges and march on your CAMPFIRE. Spend resources to build
## WALLS (block them) and a stronger fire. Eat berries or hunger drains health.
## Survive nights. Score = nights survived. Touch: left pad move, GATHER / BUILD /
## EAT buttons. Desktop: WASD move, J gather, B build wall, E eat.

var player: Node3D
var ppos := Vector3(0, 0, 6)
var pyaw := 0.0
var hp := 100.0
var hunger := 100.0

var wood := 0
var stone := 0
var berries := 3

var nodes3d: Array = []      # {kind,pos,amt,node}
var walls: Array = []        # {pos,hp,node}
var raiders: Array = []      # {pos,hp,node}
var fire: Node3D
var fire_hp := 100.0

var daytime := 0.0           # 0..1 within a day
var day := 1
var is_night := false
var to_spawn := 0
var spawn_t := 0.0

var tc: TouchControls
var gathering := false
var hud: Label3D
var env: Environment
const DAY_LEN := 34.0
const WALL_COST := 4          # wood
const FIRE_COST := 6          # wood, heals fire


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.7, 0.9), 0.9)
	static_box(Vector3(90, 1, 90), Vector3(0, -0.5, 0), Color(0.35, 0.55, 0.35))
	for c in get_children():
		if c is WorldEnvironment:
			env = (c as WorldEnvironment).environment
			break
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(0.9, 1.7, 0.9), Vector3(0, 0.85, 0), Color(0.9, 0.8, 0.5), player)
	# central campfire
	fire = Node3D.new()
	add_child(fire)
	mesh_cyl(1.2, 0.4, Vector3(0, 0.2, 0), Color(0.4, 0.3, 0.25), fire)
	mesh_sphere(0.7, Vector3(0, 0.9, 0), Color(1.0, 0.6, 0.2), fire)
	_scatter_resources()
	ppos = Vector3(0, 0, 6)
	hp = 100.0
	hunger = 100.0
	wood = 0
	stone = 0
	berries = 3
	fire_hp = 100.0
	day = 1
	daytime = 0.1
	is_night = false
	make_camera(Vector3(0, 18, 18), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 12, 0), 34, Color.WHITE)
	tc = add_touch_controls([
		{"id": "gather", "label": "GATHER", "col": Color(0.6, 0.75, 0.4)},
		{"id": "build", "label": "BUILD", "col": Color(0.6, 0.5, 0.4)},
		{"id": "eat", "label": "EAT", "col": Color(0.8, 0.35, 0.55)},
	])
	tc.action.connect(func(id):
		if id == "gather": _gather()
		elif id == "build": _build_wall()
		elif id == "eat": _eat())


func _scatter_resources() -> void:
	for i in 18:
		var a := randf() * TAU
		var r := randf_range(10, 40)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var is_tree := randf() < 0.6
		var n: MeshInstance3D
		if is_tree:
			mesh_cyl(0.4, 3.0, p + Vector3(0, 1.5, 0), Color(0.5, 0.35, 0.2))
			n = mesh_sphere(1.5, p + Vector3(0, 3.6, 0), Color(0.25, 0.55, 0.28))
		else:
			n = mesh_box(Vector3(1.8, 1.5, 1.8), p + Vector3(0, 0.75, 0), Color(0.55, 0.55, 0.6))
		nodes3d.append({"kind": "wood" if is_tree else "stone", "pos": p, "amt": 5, "node": n})
	# a few berry bushes
	for i in 4:
		var a := randf() * TAU
		var r := randf_range(8, 30)
		var p := Vector3(cos(a) * r, 0, sin(a) * r)
		var n := mesh_sphere(0.9, p + Vector3(0, 0.7, 0), Color(0.5, 0.2, 0.5))
		nodes3d.append({"kind": "berry", "pos": p, "amt": 3, "node": n})


func _nearest(kind_any: bool) -> Dictionary:
	var best := {}
	var bd := 3.2
	for n in nodes3d:
		var d: float = ppos.distance_to(n.pos)
		if d < bd:
			bd = d
			best = n
	return best


func _gather() -> void:
	var n := _nearest(true)
	if n.is_empty():
		return
	n.amt -= 1
	if n.kind == "wood":
		wood += 2
	elif n.kind == "stone":
		stone += 2
	else:
		berries += 1
	Juice.sfx("thud")
	Juice.haptic(10)
	if n.amt <= 0:
		n.node.queue_free()
		nodes3d.erase(n)


func _build_wall() -> void:
	if wood < WALL_COST:
		return
	# place a wall segment just in front of the player
	var fwd := Vector3(sin(pyaw), 0, cos(pyaw))
	var wp := ppos + fwd * 2.0
	wood -= WALL_COST
	var node := mesh_box(Vector3(2.4, 2.2, 0.6), wp + Vector3(0, 1.1, 0), Color(0.6, 0.5, 0.4))
	node.rotation.y = pyaw
	walls.append({"pos": wp, "hp": 60.0, "node": node})
	Juice.sfx("chime")


func _eat() -> void:
	if berries <= 0:
		return
	berries -= 1
	hunger = minf(100.0, hunger + 35.0)
	hp = minf(100.0, hp + 8.0)
	Juice.sfx("coin")


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B:
			_build_wall()
		elif event.keycode == KEY_E:
			_eat()


func _wall_blocks(from: Vector3, to: Vector3) -> Dictionary:
	for w in walls:
		if to.distance_to(w.pos) < 1.6:
			return w
	return {}


func _process(delta: float) -> void:
	if not running:
		return
	# day/night clock
	daytime += delta / DAY_LEN
	if daytime >= 1.0:
		daytime -= 1.0
		day += 1
	var was_night := is_night
	is_night = daytime > 0.5
	if is_night and not was_night:
		# nightfall — raid wave scales with day
		to_spawn = 3 + day * 2
		spawn_t = 0.0
		Juice.sfx("boom")
	if not is_night and was_night:
		add_points(1)               # survived a night
		Juice.sfx("chime")
		fire_hp = minf(100.0, fire_hp + 20.0)
	# tint environment for time of day
	if env:
		var lg := 0.9 if not is_night else 0.35
		env.ambient_light_energy = lg
		env.background_color = Color(0.5, 0.7, 0.9) if not is_night else Color(0.08, 0.09, 0.16)

	# hunger & health
	hunger = maxf(0.0, hunger - 1.6 * delta)
	if hunger <= 0.0:
		hp -= 4.0 * delta
	if hp <= 0.0:
		end_demo()
		return

	# move
	gathering = tc.held("gather") or Input.is_key_pressed(KEY_J)
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 0.05:
		if mv.length() > 1.0:
			mv = mv.normalized()
		var np := ppos + mv * 8.0 * delta
		ppos = np
		pyaw = atan2(mv.x, mv.z)
	ppos.x = clampf(ppos.x, -44, 44)
	ppos.z = clampf(ppos.z, -44, 44)
	player.position = ppos
	player.rotation.y = pyaw
	if gathering:
		_gather_tick(delta)

	# fire flicker
	fire.get_child(1).scale = Vector3.ONE * (1.0 + sin(daytime * 120.0) * 0.12)

	# spawn + drive raiders at night
	if is_night:
		if to_spawn > 0:
			spawn_t -= delta
			if spawn_t <= 0.0:
				spawn_t = 1.4
				to_spawn -= 1
				var a := randf() * TAU
				var p := Vector3(cos(a) * 46, 0, sin(a) * 46)
				var node := mesh_box(Vector3(0.9, 1.6, 0.9), p + Vector3(0, 0.8, 0), Color(0.7, 0.25, 0.3))
				raiders.append({"pos": p, "hp": 6.0 + day, "node": node})

	for r in raiders.duplicate():
		# target: the campfire; walls in the way get attacked first
		var tgt := Vector3.ZERO
		var dir := (tgt - r.pos)
		var blocking := _wall_blocks(r.pos, r.pos + dir.normalized() * 1.6)
		if not blocking.is_empty() and r.pos.distance_to(blocking.pos) < 2.0:
			blocking.hp -= 12.0 * delta
			if blocking.hp <= 0.0:
				blocking.node.queue_free()
				walls.erase(blocking)
		else:
			r.pos += dir.normalized() * 3.4 * delta
		r.node.position = r.pos + Vector3(0, 0.8, 0)
		# reached fire?
		if r.pos.length() < 2.2:
			fire_hp -= 16.0 * delta
			if fire_hp <= 0.0:
				end_demo()
				return
		# player can melee raiders by walking into them + gather btn doubles as swing
		if ppos.distance_to(r.pos) < 2.0 and gathering:
			r.hp -= 30.0 * delta
			if r.hp <= 0.0:
				r.node.queue_free()
				raiders.erase(r)
				Juice.sfx("boom")

	cam.position = ppos + Vector3(0, 18, 18)
	cam.look_at(ppos, Vector3.UP)
	hud.text = "DAY %d %s  HP %d  FOOD %d  |  wood %d  stone %d  berry %d  |  fire %d%%" % [
		day, "NIGHT" if is_night else "day", int(hp), int(hunger), wood, stone, berries, int(max(0, fire_hp))]
	hud.position = ppos + Vector3(0, 4, 0)


var _gt := 0.0
func _gather_tick(delta: float) -> void:
	_gt += delta
	if _gt >= 0.4:
		_gt = 0.0
		if not _nearest(true).is_empty():
			_gather()
