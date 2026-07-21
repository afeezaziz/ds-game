extends MechDemo3D
## SKY RINGS — fly a plane forward through rings for points; dodge the red
## pillars. Drag to steer up/down/left/right. Crash = over. Score =
## distance + rings. Desktop: WASD steer.

var plane: Node3D
var pos := Vector3(0, 6, 0)
var speed := 18.0
var things: Array = []   # {z, node, ring, cx, cy, passed}
var next_z := 40.0
var _drag := Vector2.ZERO


func start() -> void:
	super.start()
	setup_world(Color(0.45, 0.62, 0.85), 0.95)
	plane = Node3D.new()
	add_child(plane)
	mesh_box(Vector3(2.4, 0.3, 1.4), Vector3(0, 0, 0), Color(0.9, 0.9, 0.95), plane)
	mesh_box(Vector3(0.4, 0.8, 1.0), Vector3(0, 0.4, -0.4), Color(0.8, 0.3, 0.3), plane)
	pos = Vector3(0, 6, 0)
	speed = 18.0
	next_z = 40.0
	things.clear()
	make_camera(Vector3(0, 7, -9), Vector3(0, 6, 10))


func _unhandled_input(event: InputEvent) -> void:
	if running and event is InputEventScreenDrag:
		_drag = event.relative


func _process(delta: float) -> void:
	if not running:
		return
	speed = minf(30.0, speed + delta * 0.4)
	pos.z += speed * delta
	set_score(int(pos.z / 2.0))

	var steer := Vector2(key_axis_x(), key_axis_y()) * 9.0 * delta
	steer += Vector2(_drag.x, -_drag.y) * 0.03
	_drag = Vector2.ZERO
	pos.x = clampf(pos.x + steer.x, -9, 9)
	pos.y = clampf(pos.y + steer.y, 1.5, 12)

	plane.position = pos
	plane.rotation.z = lerpf(plane.rotation.z, -steer.x * 0.15, 6.0 * delta)
	cam.position = Vector3(pos.x * 0.5, pos.y + 1.5, pos.z - 9)
	cam.look_at(Vector3(pos.x * 0.5, pos.y, pos.z + 10), Vector3.UP)

	while next_z < pos.z + 100.0:
		if randf() < 0.6:
			var cx := randf_range(-7, 7)
			var cy := randf_range(2.5, 10)
			var node := _ring(Vector3(cx, cy, next_z))
			things.append({"z": next_z, "node": node, "ring": true, "cx": cx, "cy": cy, "passed": false})
		else:
			var px := randf_range(-8, 8)
			var node2 := mesh_box(Vector3(1.2, 14, 1.2), Vector3(px, 6, next_z), Color(0.8, 0.25, 0.25))
			things.append({"z": next_z, "node": node2, "ring": false, "cx": px, "cy": 6, "passed": false})
		next_z += randf_range(12.0, 20.0)

	for t in things.duplicate():
		if t.z < pos.z - 8.0:
			t.node.queue_free()
			things.erase(t)
			continue
		if not t.passed and absf(t.z - pos.z) < 1.2:
			t.passed = true
			var d := Vector2(pos.x - t.cx, pos.y - t.cy).length()
			if t.ring:
				if d < 2.2:
					add_points(5)
					Juice.sfx("coin")
			else:
				if d < 1.4:
					Juice.haptic(50)
					end_demo()
					return


func _ring(p: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.8
	tm.outer_radius = 2.2
	mi.mesh = tm
	mi.material_override = _mat(Color(1, 0.85, 0.3))
	mi.position = p
	mi.rotation.x = PI / 2.0
	add_child(mi)
	return mi
