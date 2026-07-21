extends MechDemo3D
## PARKOUR — auto-run across floating platforms; TAP to jump the gaps. Miss
## and you fall. Score = distance. Desktop: Space to jump.

var player: MeshInstance3D
var pz := 0.0
var py := 0.0
var vy := 0.0
var speed := 9.0
var falling := false
var plats: Array = []   # {z0, z1}
var next_z := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.4, 0.55, 0.8))
	player = mesh_box(Vector3(0.9, 1.2, 0.9), Vector3(0, 0.6, 0), Color(0.95, 0.85, 0.4))
	pz = 0.0
	py = 0.0
	vy = 0.0
	speed = 9.0
	falling = false
	plats.clear()
	next_z = -4.0
	for i in 12:
		_extend()
	make_camera(Vector3(0, 5, -8), Vector3(0, 0, 6))


func _extend() -> void:
	var length := randf_range(4.0, 8.0)
	var z0 := next_z
	var z1 := z0 + length
	mesh_box(Vector3(3.0, 0.6, length), Vector3(0, -0.3, (z0 + z1) * 0.5), hue_col(z0 * 0.03, 0.45, 0.8))
	plats.append({"z0": z0, "z1": z1})
	next_z = z1 + randf_range(2.5, 5.0)


func _under(z: float) -> bool:
	for p in plats:
		if z >= p.z0 and z <= p.z1:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	var jump := (event is InputEventScreenTouch and event.pressed) \
		or (event is InputEventKey and event.pressed and not event.echo \
			and (event.keycode == KEY_SPACE or event.keycode == KEY_W))
	if jump and py <= 0.01 and _under(pz):
		vy = 8.5
		Juice.sfx("tick")


func _process(delta: float) -> void:
	if falling:
		vy -= 24.0 * delta
		py += vy * delta
		player.position = Vector3(0, 0.6 + py, pz)
		if py < -6.0:
			end_demo()
		return
	if not running:
		return
	speed = minf(16.0, speed + delta * 0.25)
	pz += speed * delta
	set_score(int(pz))

	vy -= 24.0 * delta
	py = maxf(0.0, py + vy * delta)
	if py <= 0.0:
		vy = 0.0
		if not _under(pz):
			falling = true
			vy = 0.0
			Juice.haptic(40)
			return

	while next_z < pz + 40.0:
		_extend()

	player.position = Vector3(0, 0.6 + py, pz)
	cam.position = Vector3(0, 5, pz - 8)
	cam.look_at(Vector3(0, 0, pz + 6), Vector3.UP)
