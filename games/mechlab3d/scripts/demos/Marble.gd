extends MechDemo3D
## MARBLE ROLL — a marble rolls forward along a winding narrowing track.
## Steer L/R to stay on it; roll off the edge and you fall. Score = distance.
## (Going Balls / Marble It Up.) Desktop: A/D or drag to steer.

var marble: MeshInstance3D
var mx := 0.0
var mz := 0.0
var py := 0.6
var vy := 0.0
var speed := 11.0
var falling := false
var tiles: Array = []
var next_z := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.15, 0.18, 0.3), 0.9)
	marble = mesh_sphere(0.6, Vector3(0, 0.6, 0), Color(0.95, 0.8, 0.35))
	mx = 0.0
	mz = 0.0
	py = 0.6
	vy = 0.0
	speed = 11.0
	falling = false
	next_z = 0.0
	for i in 30:
		_extend()
	make_camera(Vector3(0, 5, -8), Vector3(0, 0, 6))


func _center(z: float) -> float:
	return sin(z * 0.028) * 5.0


func _halfw(z: float) -> float:
	return maxf(1.4, 3.2 - z * 0.004)


func _extend() -> void:
	var z := next_z
	var c := _center(z)
	var w := _halfw(z)
	mesh_box(Vector3(w * 2.0, 0.4, 2.1), Vector3(c, -0.2, z), hue_col(z * 0.05, 0.45, 0.8))
	tiles.append(z)
	next_z += 2.0


func _unhandled_input(event: InputEvent) -> void:
	if running and event is InputEventScreenDrag:
		mx += event.relative.x * 0.03


func _process(delta: float) -> void:
	if falling:
		vy -= 20.0 * delta
		py += vy * delta
		marble.position.y = py
		if py < -6.0:
			end_demo()
		return
	if not running:
		return
	speed = minf(20.0, speed + delta * 0.3)
	mz += speed * delta
	mx += key_axis_x() * 8.0 * delta
	set_score(int(mz))

	while next_z < mz + 70.0:
		_extend()

	if absf(mx - _center(mz)) > _halfw(mz) + 0.3:
		falling = true
		vy = 0.0
		Juice.haptic(40)
		return

	marble.position = Vector3(mx, py, mz)
	marble.rotate_x(speed * delta * 0.6)
	cam.position = Vector3(_center(mz) * 0.5, 5, mz - 8)
	cam.look_at(Vector3(_center(mz + 6) * 0.6, 0, mz + 6), Vector3.UP)
