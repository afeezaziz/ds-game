extends MechDemo3D
## TUMBLE FALL — a downhill slalom dive. You slide down the slope; steer L/R
## to weave between the blocks. Hit one = over. Score = distance. Desktop:
## A/D or drag to steer.

const SLOPE := 0.28

var ball: MeshInstance3D
var mx := 0.0
var dist := 0.0
var speed := 12.0
var blocks: Array = []
var next_d := 12.0


func start() -> void:
	super.start()
	setup_world(Color(0.55, 0.68, 0.85), 0.95, Vector3(-40, -30, 0))
	# long tilted ramp
	var ramp := mesh_box(Vector3(14, 0.5, 600), Vector3(0, 0, 300), Color(0.7, 0.72, 0.8))
	ramp.rotation.x = SLOPE
	ball = mesh_sphere(0.6, Vector3.ZERO, Color(0.9, 0.35, 0.4))
	mx = 0.0
	dist = 0.0
	speed = 12.0
	blocks.clear()
	next_d = 12.0
	make_camera(Vector3(0, 5, -8), Vector3(0, -2, 8))


func _pos_at(d: float, x: float) -> Vector3:
	return Vector3(x, -d * SLOPE + 0.6, d * cos(SLOPE))


func _unhandled_input(event: InputEvent) -> void:
	if running and event is InputEventScreenDrag:
		mx += event.relative.x * 0.03


func _process(delta: float) -> void:
	if not running:
		return
	speed = minf(24.0, speed + delta * 0.4)
	dist += speed * delta
	mx = clampf(mx + key_axis_x() * 9.0 * delta, -6.2, 6.2)
	set_score(int(dist))

	ball.position = _pos_at(dist, mx)
	ball.rotate_x(speed * delta * 0.5)
	var cam_p := _pos_at(dist - 7.0, mx * 0.4)
	cam.position = cam_p + Vector3(0, 4, 0)
	cam.look_at(_pos_at(dist + 6.0, 0), Vector3.UP)

	while next_d < dist + 80.0:
		var n := 1 + randi() % 2
		for i in n:
			var bx := randf_range(-6.0, 6.0)
			var node := mesh_box(Vector3(1.6, 1.4, 1.4), _pos_at(next_d, bx), Color(0.3, 0.3, 0.4))
			node.rotation.x = SLOPE
			blocks.append({"d": next_d, "x": bx, "node": node})
		next_d += randf_range(7.0, 12.0)

	for b in blocks.duplicate():
		if b.d < dist - 6.0:
			b.node.queue_free()
			blocks.erase(b)
			continue
		if absf(b.d - dist) < 1.2 and absf(b.x - mx) < 1.4:
			Juice.haptic(50)
			end_demo()
			return
