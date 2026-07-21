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
var tc: TouchControls
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
	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.45, 0.35)},
		{"id": "reload", "label": "RELOAD", "col": Color(0.55, 0.65, 0.85)},
	], true)
	tc.action.connect(func(id):
		if id == "fire": _fire()
		elif id == "reload": _reload())
	tc.look.connect(_on_look)


func _on_look(rel: Vector2) -> void:
	yaw -= rel.x * 0.006
	pitch = clampf(pitch - rel.y * 0.005, -1.2, 1.2)


func _reload() -> void:
	if reload_t <= 0.0 and ammo < mag:
		reload_t = 1.1
		Juice.sfx("tick")


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
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_fire()
		elif event.keycode == KEY_R:
			_reload()


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
	var inx := tc.move.x + key_axis_x()
	var inz := -tc.move.y + key_axis_y()
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
