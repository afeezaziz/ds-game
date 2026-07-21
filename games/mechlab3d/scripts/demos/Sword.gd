extends MechDemo3D
## SWORD DASH — dash down a corridor of foes; TAP to slash the one in range.
## Let an enemy reach you unslain and it's over. Score = kills (combo builds).
## Desktop: Space / click to slash.

const STRIKE := 3.0

var player: MeshInstance3D
var pz := 0.0
var speed := 7.0
var combo := 0
var enemies: Array = []   # {z, node, dead}
var next_z := 8.0


func start() -> void:
	super.start()
	setup_world(Color(0.14, 0.12, 0.18), 0.9)
	static_box(Vector3(5, 1, 600), Vector3(0, -0.5, 300), Color(0.28, 0.26, 0.32))
	player = mesh_box(Vector3(0.9, 1.5, 0.9), Vector3(0, 0.75, 0), Color(0.5, 0.9, 1.0))
	mesh_box(Vector3(0.15, 0.15, 1.4), Vector3(0.6, 1.0, 0.6), Color(0.95, 0.95, 1.0), player)
	pz = 0.0
	speed = 7.0
	combo = 0
	enemies.clear()
	next_z = 8.0
	for i in 6:
		_spawn()
	make_camera(Vector3(0, 4, -7), Vector3(0, 1, 6))


func _spawn() -> void:
	var node := mesh_box(Vector3(0.9, 1.4, 0.9), Vector3(randf_range(-1.2, 1.2), 0.7, next_z), Color(0.8, 0.3, 0.3))
	enemies.append({"z": next_z, "node": node, "dead": false})
	next_z += randf_range(4.0, 7.0)


func _slash() -> void:
	var tgt = _nearest_ahead()
	if tgt and tgt.z - pz < STRIKE and tgt.z - pz > -0.5:
		tgt.dead = true
		tgt.node.queue_free()
		combo += 1
		add_points(1)
		Juice.sfx("chime", 1.0 + minf(combo, 8) * 0.05)
		Juice.haptic(15)
	else:
		combo = 0


func _nearest_ahead():
	var best = null
	var bd := 9999.0
	for e in enemies:
		if e.dead:
			continue
		var d: float = e.z - pz
		if d > -0.5 and d < bd:
			bd = d
			best = e
	return best


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if (event is InputEventScreenTouch and event.pressed) \
			or (event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE):
		_slash()


func _process(delta: float) -> void:
	if not running:
		return
	speed = minf(13.0, speed + delta * 0.2)
	pz += speed * delta
	player.position.z = pz

	while next_z < pz + 50.0:
		_spawn()

	for e in enemies.duplicate():
		if e.dead:
			enemies.erase(e)
			continue
		e.node.position.x = lerpf(e.node.position.x, 0.0, delta)  # drift into lane
		if e.z <= pz - 0.3:
			Juice.haptic(50)
			end_demo()
			return

	cam.position = Vector3(0, 4, pz - 7)
	cam.look_at(Vector3(0, 1, pz + 6), Vector3.UP)
