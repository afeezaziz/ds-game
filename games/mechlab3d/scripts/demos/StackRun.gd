extends MechDemo3D
## TALL RUN — auto-run; grab blocks to grow your stack taller, duck under
## ceilings that shave blocks off. Reach a WALL shorter than its required
## height and you're stopped. Score = distance. Desktop: A/D or drag to steer.

var runner: Node3D
var blocks: Array = []   # visual block meshes
var height := 1
var px := 0.0
var pz := 0.0
var speed := 8.0
var items: Array = []    # {z, x, node, kind, val}  kind: pickup|ceil|wall
var next_z := 0.0
var req_label: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.62, 0.8))
	runner = Node3D.new()
	add_child(runner)
	height = 1
	_rebuild_stack()
	px = 0.0
	pz = 0.0
	speed = 8.0
	items.clear()
	next_z = 10.0
	req_label = label3d("", Vector3(0, 4, 0), 40, Color.WHITE)
	make_camera(Vector3(0, 5, -9), Vector3(0, 1, 6))


func _rebuild_stack() -> void:
	for c in runner.get_children():
		c.queue_free()
	for i in height:
		mesh_box(Vector3(0.9, 0.5, 0.9), Vector3(0, 0.25 + i * 0.5, 0), hue_col(i, 0.5, 0.9), runner)


func _add(d: int) -> void:
	height = clampi(height + d, 0, 20)
	_rebuild_stack()
	if height <= 0:
		end_demo()


func _unhandled_input(event: InputEvent) -> void:
	if running and event is InputEventScreenDrag:
		px = clampf(px + event.relative.x * 0.03, -2.6, 2.6)


func _process(delta: float) -> void:
	if not running:
		return
	speed = minf(14.0, speed + delta * 0.2)
	pz += speed * delta
	px = clampf(px + key_axis_x() * 6.0 * delta, -2.6, 2.6)
	set_score(int(pz))

	while next_z < pz + 60.0:
		_spawn(next_z)
		next_z += randf_range(6.0, 10.0)

	for it in items.duplicate():
		if it.z < pz - 4.0:
			if is_instance_valid(it.node):
				it.node.queue_free()
			items.erase(it)
			continue
		if absf(it.z - pz) < 0.8:
			match it.kind:
				"pickup":
					if absf(it.x - px) < 1.0 and not it.get("dead", false):
						it.dead = true
						it.node.queue_free()
						_add(1)
						Juice.sfx("coin")
				"ceil":
					if height > it.val and not it.get("hit", false):
						it.hit = true
						_add(it.val - height)
						Juice.sfx("thud")
				"wall":
					if not it.get("hit", false):
						it.hit = true
						if height < it.val:
							Juice.haptic(50)
							end_demo()
							return
						add_points(20)
						Juice.sfx("chime")

	runner.position = Vector3(px, 0, pz)
	req_label.position = Vector3(px, height * 0.5 + 1.2, pz)
	req_label.text = str(height)
	cam.position = Vector3(px * 0.4, 5, pz - 9)
	cam.look_at(Vector3(0, 1, pz + 6), Vector3.UP)


func _spawn(z: float) -> void:
	var r := randf()
	if r < 0.55:
		var xp := randf_range(-2.2, 2.2)
		var node := mesh_box(Vector3(0.8, 0.5, 0.8), Vector3(xp, 0.4, z), Color(0.9, 0.8, 0.3))
		items.append({"z": z, "x": xp, "node": node, "kind": "pickup", "val": 0})
	elif r < 0.8:
		var lvl := 1 + randi() % 4
		var node2 := mesh_box(Vector3(5, 0.4, 0.6), Vector3(0, lvl * 0.5 + 0.5, z), Color(0.75, 0.35, 0.35))
		items.append({"z": z, "x": 0, "node": node2, "kind": "ceil", "val": lvl})
	else:
		var req := 2 + randi() % 6
		var node3 := mesh_box(Vector3(5, req * 0.5, 0.5), Vector3(0, req * 0.25, z), Color(0.4, 0.4, 0.5))
		items.append({"z": z, "x": 0, "node": node3, "kind": "wall", "val": req})
		label3d(str(req), Vector3(0, req * 0.5 + 0.6, z), 36, Color(1, 0.9, 0.5))
