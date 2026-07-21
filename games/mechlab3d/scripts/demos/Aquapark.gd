extends MechDemo3D
## WATER SLIDE — slide down a winding tube; LEAN to build sideways momentum
## and hug the curve. Slip over the lip and you fly off. Boost pads speed you
## up. Score = distance. (Aquapark.io.) Desktop: A/D or drag to lean.

const TW := 3.4

var rider: MeshInstance3D
var x := 0.0
var vx := 0.0
var dist := 0.0
var speed := 14.0
var falling := false
var fall_v := Vector3.ZERO
var tiles: Array = []
var next_d := 0.0
var lean := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.4, 0.7, 0.9), 0.95, Vector3(-45, -25, 0))
	rider = mesh_sphere(0.5, Vector3.ZERO, Color(0.95, 0.85, 0.3))
	x = 0.0
	vx = 0.0
	dist = 0.0
	speed = 14.0
	falling = false
	next_d = 0.0
	lean = 0.0
	for i in 30:
		_extend()
	make_camera(Vector3(0, 5, -8), Vector3(0, -1, 8))


func _center(d: float) -> float:
	return sin(d * 0.03) * 6.0


func _pos(d: float, xx: float) -> Vector3:
	return Vector3(xx, -d * 0.14 + 0.5, d * 0.99)


func _extend() -> void:
	var d := next_d
	var c := _center(d)
	mesh_box(Vector3(TW * 2.0, 0.3, 2.05), _pos(d, c) + Vector3(0, -0.5, 0), Color(0.3, 0.6, 0.85))
	# lips
	mesh_box(Vector3(0.3, 1.0, 2.05), _pos(d, c - TW), Color(0.6, 0.8, 0.95))
	mesh_box(Vector3(0.3, 1.0, 2.05), _pos(d, c + TW), Color(0.6, 0.8, 0.95))
	tiles.append(d)
	next_d += 2.0


func _unhandled_input(event: InputEvent) -> void:
	if running and event is InputEventScreenDrag:
		lean = clampf(event.relative.x * 0.08, -1.0, 1.0)


func _process(delta: float) -> void:
	if falling:
		fall_v.y -= 20.0 * delta
		rider.position += fall_v * delta
		if rider.position.y < -8.0:
			end_demo()
		return
	if not running:
		return
	speed = minf(26.0, speed + delta * 0.4)
	dist += speed * delta
	set_score(int(dist))

	var steer := lean + key_axis_x()
	lean *= 0.85
	vx += steer * 22.0 * delta
	vx *= 0.96
	x += vx * delta

	var c := _center(dist)
	if absf(x - c) > TW - 0.3:
		falling = true
		fall_v = Vector3(vx, 2.0, speed * 0.5)
		Juice.haptic(40)
		return

	while next_d < dist + 70.0:
		_extend()

	rider.position = _pos(dist, x)
	cam.position = _pos(dist - 7.0, c * 0.4) + Vector3(0, 4, 0)
	cam.look_at(_pos(dist + 6.0, c), Vector3.UP)
