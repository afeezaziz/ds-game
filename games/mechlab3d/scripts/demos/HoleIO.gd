extends MechDemo3D
## HOLE.IO — you are a black hole on a city plane. Drag to move; anything that
## fits falls in and you GROW. Big buildings need a bigger hole. 45 seconds,
## swallow as many as you can. (2018 .io smash.) Desktop: WASD move.

var hole: MeshInstance3D
var hole_mesh: CylinderMesh
var hole_pos := Vector2.ZERO
var radius := 1.2
var objs: Array = []   # {node, xz:Vector2, size, falling, dead}
var time_left := 45.0
var _drag := false
var _last := Vector2.ZERO


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.65, 0.8), 0.9, Vector3(-70, -20, 0))
	static_box(Vector3(60, 1, 60), Vector3(0, -0.5, 0), Color(0.35, 0.55, 0.35))
	hole = mesh_cyl(radius, 0.1, Vector3(0, 0.06, 0), Color(0.03, 0.03, 0.05))
	hole_mesh = hole.mesh as CylinderMesh
	hole_pos = Vector2.ZERO
	radius = 1.2
	time_left = 45.0
	objs.clear()
	for i in 90:
		var xz := Vector2(randf_range(-27, 27), randf_range(-27, 27))
		var sz := randf_range(0.6, 2.6)
		var h := sz * randf_range(1.0, 3.0)
		var node := mesh_box(Vector3(sz, h, sz), Vector3(xz.x, h * 0.5, xz.y),
			hue_col(i, 0.35, 0.85))
		objs.append({"node": node, "xz": xz, "size": sz, "falling": false, "dead": false})
	make_camera(Vector3(0, 34, 20), Vector3(0, 0, 0), 55.0)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		_drag = event.pressed
		_last = event.position
	elif event is InputEventScreenDrag:
		hole_pos += (event.position - _last) * 0.06
		_last = event.position


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	if time_left <= 0.0:
		end_demo()
		return
	var k := Vector2(key_axis_x(), -key_axis_y())
	hole_pos += k * 14.0 * delta
	hole_pos.x = clampf(hole_pos.x, -28, 28)
	hole_pos.y = clampf(hole_pos.y, -28, 28)
	hole.position = Vector3(hole_pos.x, 0.06, hole_pos.y)
	cam.position = Vector3(hole_pos.x, 34, hole_pos.y + 20)
	cam.look_at(Vector3(hole_pos.x, 0, hole_pos.y), Vector3.UP)

	for o in objs:
		if o.dead:
			continue
		if o.falling:
			o.node.position.y -= 14.0 * delta
			o.node.position.x = lerpf(o.node.position.x, hole_pos.x, 8.0 * delta)
			o.node.position.z = lerpf(o.node.position.z, hole_pos.y, 8.0 * delta)
			if o.node.position.y < -3.0:
				o.dead = true
				o.node.queue_free()
			continue
		if o.xz.distance_to(hole_pos) < radius * 0.9 and o.size < radius * 1.6:
			o.falling = true
			add_points(1)
			radius = minf(9.0, radius + o.size * 0.06)
			hole_mesh.top_radius = radius
			hole_mesh.bottom_radius = radius
			Juice.sfx("coin")
