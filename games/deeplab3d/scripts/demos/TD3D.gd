extends MechDemo3D
## TOWER DEFENSE 3D — build towers on a 3D field; creeps follow a set path;
## towers auto-shoot. Tap the ground to build. Score = waves survived.
## (Ground-plane raycast via camera unproject — no physics.)

const PATH := [Vector3(-24, 0, -8), Vector3(8, 0, -8), Vector3(8, 0, 8),
	Vector3(-8, 0, 8), Vector3(-8, 0, -20), Vector3(24, 0, -20)]
const COST := 20
const RANGE := 9.0

var towers: Array = []      # {pos, cd, node}
var creeps: Array = []      # {seg, d, hp, maxhp, node}
var beams: Array = []
var gold := 70
var lives := 10
var wave := 0
var to_spawn := 0
var spawn_t := 0.0
var wave_t := 3.0
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.4, 0.55, 0.7), 0.9, Vector3(-65, -30, 0))
	static_box(Vector3(64, 1, 64), Vector3(0, -0.5, 0), Color(0.3, 0.45, 0.3))
	# draw path as slabs
	for i in range(PATH.size() - 1):
		var a: Vector3 = PATH[i]
		var b: Vector3 = PATH[i + 1]
		var mid := (a + b) * 0.5
		var len := a.distance_to(b)
		var horiz := absf(b.x - a.x) > absf(b.z - a.z)
		mesh_box(Vector3(len if horiz else 3.0, 0.2, 3.0 if horiz else len), mid + Vector3(0, 0.1, 0), Color(0.5, 0.4, 0.3))
	gold = 70
	lives = 10
	wave = 0
	to_spawn = 0
	wave_t = 3.0
	towers = []
	creeps = []
	beams = []
	make_camera(Vector3(0, 34, 30), Vector3(0, 0, 0), 50.0)
	hud = label3d("", Vector3(0, 14, 22), 40, Color.WHITE)


func _ground_point(sp: Vector2) -> Vector3:
	var from := cam.project_ray_origin(sp)
	var dir := cam.project_ray_normal(sp)
	var plane := Plane(Vector3.UP, 0.0)
	var hit = plane.intersects_ray(from, dir)
	return hit if hit != null else Vector3.ZERO


func _near_path(p: Vector3) -> bool:
	for i in range(PATH.size() - 1):
		var q := Geometry3D.get_closest_point_to_segment(p, PATH[i], PATH[i + 1])
		if p.distance_to(q) < 3.5:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	if gold < COST:
		return
	var p := _ground_point(event.position)
	if absf(p.x) > 30 or absf(p.z) > 30 or _near_path(p):
		return
	for t in towers:
		if t.pos.distance_to(p) < 3.0:
			return
	var node := Node3D.new()
	node.position = p
	add_child(node)
	mesh_box(Vector3(1.6, 3.0, 1.6), Vector3(0, 1.5, 0), Color(0.4, 0.55, 0.9), node)
	mesh_sphere(0.7, Vector3(0, 3.2, 0), Color(0.7, 0.85, 1.0), node)
	towers.append({"pos": p, "cd": 0.0, "node": node})
	gold -= COST
	Juice.sfx("coin")


func _process(delta: float) -> void:
	if not running:
		return
	if to_spawn > 0:
		spawn_t -= delta
		if spawn_t <= 0.0:
			spawn_t = 0.8
			to_spawn -= 1
			var hp := 4 + wave * 2
			var node := mesh_box(Vector3(1.2, 1.2, 1.2), PATH[0] + Vector3(0, 0.6, 0), Color(0.85, 0.35, 0.35))
			creeps.append({"seg": 0, "d": 0.0, "hp": hp, "maxhp": hp, "node": node})
	elif creeps.is_empty():
		wave_t -= delta
		if wave_t <= 0.0:
			wave += 1
			to_spawn = 4 + wave
			wave_t = 3.0
			gold += 15 + wave * 3
			set_score(wave)

	var speed := 4.0 + wave * 0.2
	for c in creeps.duplicate():
		c.d += speed * delta
		var seg_len: float = PATH[c.seg].distance_to(PATH[c.seg + 1])
		while c.d >= seg_len:
			c.d -= seg_len
			c.seg += 1
			if c.seg >= PATH.size() - 1:
				break
			seg_len = PATH[c.seg].distance_to(PATH[c.seg + 1])
		if c.seg >= PATH.size() - 1:
			c.node.queue_free()
			creeps.erase(c)
			lives -= 1
			Juice.sfx("boom")
			if lives <= 0:
				end_demo()
				return
			continue
		c.node.position = PATH[c.seg].lerp(PATH[c.seg + 1], c.d / seg_len) + Vector3(0, 0.6, 0)

	for t in towers:
		t.cd -= delta
		if t.cd > 0.0:
			continue
		var best = null
		var bd := RANGE
		for c in creeps:
			var d: float = t.pos.distance_to(c.node.position)
			if d < bd:
				bd = d
				best = c
		if best != null:
			t.cd = 0.5
			best.hp -= 2
			beams.append({"a": t.pos + Vector3(0, 3.2, 0), "b": best.node.position, "node": null, "t": 0.1})
			if best.hp <= 0:
				best.node.queue_free()
				creeps.erase(best)
				gold += 4

	for b in beams.duplicate():
		b.t -= delta
		if b.t <= 0.0:
			beams.erase(b)

	hud.text = "GOLD %d   LIVES %d   WAVE %d   (tap to build)" % [gold, lives, wave]
