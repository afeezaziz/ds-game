extends MechDemo3D
## FPS ARENA — first-person wave shooter with real movement. Left half drag =
## move, right half drag = look, FIRE button shoots. Reload when the mag empties.
## Enemies close in from all sides. Score = kills. Desktop: WASD + mouse-look +
## click.

var yaw := 0.0
var pitch := 0.0
var ppos := Vector3(0, 0, 0)
var hp := 100.0
var ammo := 12
var mag := 12
var reload_t := 0.0
var enemies: Array = []
var spawn_t := 0.0
var wave := 1
var t := 0.0
var inv := 0.0
var move_id := -1
var move_origin := Vector2.ZERO
var move_vec := Vector2.ZERO
var hud: Label3D
var muzzle := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.08, 0.09, 0.13), 0.7, Vector3(-55, 20, 0))
	static_box(Vector3(70, 1, 70), Vector3(0, -0.5, 0), Color(0.2, 0.22, 0.24))
	for i in 8:
		var a := i * TAU / 8.0
		static_box(Vector3(3, 5, 3), Vector3(cos(a) * 18, 2.5, sin(a) * 18), Color(0.3, 0.32, 0.36))
	yaw = 0.0
	pitch = 0.0
	ppos = Vector3.ZERO
	hp = 100.0
	ammo = 12
	enemies = []
	spawn_t = 0.5
	wave = 1
	t = 0.0
	make_camera(Vector3(0, 1.6, 0), Vector3(0, 1.6, -1))
	hud = Label3D.new()
	hud.font_size = 40
	hud.position = Vector3(-0.55, -0.42, -1.3)
	hud.modulate = Color(0.8, 1, 0.9)
	cam.add_child(hud)


func _fire() -> void:
	if reload_t > 0.0 or ammo <= 0:
		return
	ammo -= 1
	muzzle = 0.06
	Juice.sfx("thud")
	if ammo == 0:
		reload_t = 1.1
	var dir := -cam.global_transform.basis.z
	var best = null
	var bestdot := 0.992
	for e in enemies:
		var to: Vector3 = (e.node.position - cam.global_position).normalized()
		var d := dir.dot(to)
		if d > bestdot:
			bestdot = d
			best = e
	if best != null:
		best.hp -= 3
		if best.hp <= 0:
			best.node.queue_free()
			enemies.erase(best)
			add_points(1)
			Juice.haptic(12)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if Rect2(W - 200, H - 220, 180, 180).has_point(event.position):
				_fire()
			elif event.position.x < W * 0.5 and move_id == -1:
				move_id = event.index
				move_origin = event.position
				move_vec = Vector2.ZERO
		else:
			if event.index == move_id:
				move_id = -1
				move_vec = Vector2.ZERO
	elif event is InputEventScreenDrag:
		if event.index == move_id:
			move_vec = ((event.position - move_origin) / 80.0).limit_length(1.0)
		else:
			yaw -= event.relative.x * 0.006
			pitch = clampf(pitch - event.relative.y * 0.005, -1.2, 1.2)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fire()


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	inv -= delta
	muzzle = maxf(0.0, muzzle - delta)
	if reload_t > 0.0:
		reload_t -= delta
		if reload_t <= 0.0:
			ammo = mag

	cam.rotation = Vector3(pitch, yaw, 0)
	var f := -cam.global_transform.basis.z
	f.y = 0
	f = f.normalized()
	var r := cam.global_transform.basis.x
	var inx := move_vec.x + key_axis_x()
	var inz := -move_vec.y + key_axis_y()
	var mv := f * inz + r * inx
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * 7.0 * delta
	ppos.x = clampf(ppos.x, -32, 32)
	ppos.z = clampf(ppos.z, -32, 32)
	cam.position = ppos + Vector3(0, 1.6, 0)

	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(0.4, 1.5 - t * 0.015)
		wave = 1 + int(t / 25.0)
		var a := randf() * TAU
		var p := ppos + Vector3(cos(a), 0, sin(a)) * 30.0
		var node := mesh_box(Vector3(0.9, 1.7, 0.9), p + Vector3(0, 0.85, 0), Color(0.4, 0.65, 0.4))
		enemies.append({"node": node, "hp": 2 + wave})

	for e in enemies:
		var to: Vector3 = ppos - e.node.position
		to.y = 0
		e.node.position += to.normalized() * (2.6 + wave * 0.15) * delta
		if inv <= 0.0 and to.length() < 1.4:
			hp -= 10.0
			inv = 0.6
			Juice.flash(Color(1, 0.2, 0.2), 0.25)
			Juice.haptic(30)
			if hp <= 0.0:
				end_demo()
				return

	hud.text = "HP %d   AMMO %s   WAVE %d" % [int(max(0, hp)), ("RELOAD" if reload_t > 0 else str(ammo)), wave]
