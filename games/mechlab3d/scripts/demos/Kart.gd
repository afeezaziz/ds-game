extends MechDemo3D
## KART DRIFT — arcade kart, auto-accelerating down an endless road. Steer
## L/R; HOLD to drift (sharper turn, builds boost); release to BOOST. Dodge
## the cones. Hit one = over. Score = distance. Desktop: A/D steer, Space drift.

var kart: Node3D
var kx := 0.0
var kz := 0.0
var speed := 16.0
var boost := 0.0
var boost_t := 0.0
var drifting := false
var cones: Array = []
var next_z := 30.0
const ROAD_W := 7.0


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.68, 0.85))
	static_box(Vector3(ROAD_W * 2 + 2, 1, 600), Vector3(0, -0.5, 280), Color(0.22, 0.22, 0.26))
	mesh_box(Vector3(0.3, 0.4, 600), Vector3(-ROAD_W, 0.2, 280), Color(0.9, 0.8, 0.2))
	mesh_box(Vector3(0.3, 0.4, 600), Vector3(ROAD_W, 0.2, 280), Color(0.9, 0.8, 0.2))
	kart = Node3D.new()
	add_child(kart)
	mesh_box(Vector3(1.4, 0.6, 2.2), Vector3(0, 0.5, 0), Color(0.9, 0.25, 0.25), kart)
	mesh_box(Vector3(1.0, 0.4, 0.8), Vector3(0, 0.95, -0.3), Color(0.2, 0.2, 0.3), kart)
	kx = 0.0
	kz = 0.0
	speed = 16.0
	boost = 0.0
	boost_t = 0.0
	next_z = 30.0
	make_camera(Vector3(0, 4, -8), Vector3(0, 1, 8))


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch or event is InputEventKey:
		var pressed: bool = event.pressed
		var is_drift := (event is InputEventKey and (event as InputEventKey).keycode == KEY_SPACE) \
			or event is InputEventScreenTouch
		if is_drift:
			if pressed and not drifting:
				drifting = true
				boost = 0.0
			elif not pressed and drifting:
				drifting = false
				boost_t = boost
				boost = 0.0
				Juice.sfx("coin")


func _process(delta: float) -> void:
	if not running:
		return
	var cur_speed := speed
	if boost_t > 0.0:
		boost_t -= delta
		cur_speed *= 1.6
	speed = minf(30.0, speed + delta * 0.5)
	kz += cur_speed * delta
	set_score(int(kz / 2.0))

	var steer := key_axis_x()
	# touch steer: tilt by horizontal finger position handled via drag below
	var turn := 2.6 * (1.6 if drifting else 1.0)
	kx = clampf(kx + steer * turn * delta * 3.0, -ROAD_W + 1.0, ROAD_W - 1.0)
	if drifting:
		boost = minf(1.5, boost + delta)

	kart.position = Vector3(kx, 0, kz)
	kart.rotation.y = lerp_angle(kart.rotation.y, -steer * (0.5 if drifting else 0.3), 8.0 * delta)
	cam.position = Vector3(kx * 0.5, 4, kz - 8)
	cam.look_at(Vector3(kx * 0.5, 1, kz + 8), Vector3.UP)

	while next_z < kz + 90.0:
		var cx := randf_range(-ROAD_W + 1.5, ROAD_W - 1.5)
		var node := mesh_box(Vector3(1.0, 1.2, 1.0), Vector3(cx, 0.6, next_z), Color(0.95, 0.55, 0.15))
		cones.append({"z": next_z, "x": cx, "node": node})
		next_z += randf_range(7.0, 13.0)

	for c in cones.duplicate():
		if c.z < kz - 6.0:
			c.node.queue_free()
			cones.erase(c)
			continue
		if absf(c.z - kz) < 1.2 and absf(c.x - kx) < 1.3:
			Juice.haptic(50)
			end_demo()
			return


func _input(event: InputEvent) -> void:
	# touch drag steering (in addition to keys)
	if running and event is InputEventScreenDrag:
		kx = clampf(kx + event.relative.x * 0.03, -ROAD_W + 1.0, ROAD_W - 1.0)
