extends MechDemo3D
## RAIL SHOOTER — on-rails light-gun (Star Fox / House of the Dead). The ship flies
## itself forward; you AIM a reticle (stick / mouse) and FIRE at incoming drones,
## and DODGE-roll to sidestep their return fire. Score = kills; accuracy builds a
## combo. HP 0 = over. Desktop: WASD aim, SPACE fire, Shift dodge.

var reticle: Node3D
var aim := Vector2.ZERO
var railz := 0.0
var hp := 100.0
var fire_cd := 0.0
var dodge_t := 0.0
var dodge_dir := 0.0
var combo := 0
var foes: Array = []          # {node,pos,hp,fire}
var ebul: Array = []          # {pos,vel,life,node}
var spawn_t := 0.0
var t := 0.0
var tc: TouchControls
var hud: Label3D
const REACH := 26.0


func start() -> void:
	super.start()
	setup_world(Color(0.05, 0.06, 0.12), 0.7, Vector3(-50, 20, 0))
	# a receding tunnel of pillars to sell forward motion
	for i in 20:
		var z := -i * 14.0
		mesh_box(Vector3(2, 18, 2), Vector3(-16, 0, z), hue_col(i * 0.1, 0.4, 0.5))
		mesh_box(Vector3(2, 18, 2), Vector3(16, 0, z), hue_col(i * 0.1, 0.4, 0.5))
	railz = 0.0
	hp = 100.0
	combo = 0
	foes = []
	ebul = []
	spawn_t = 0.6
	t = 0.0
	make_camera(Vector3(0, 2, 8), Vector3(0, 2, -1), 70.0)
	reticle = Node3D.new()
	add_child(reticle)
	mesh_box(Vector3(1.6, 0.2, 0.2), Vector3.ZERO, Color(0.4, 1, 0.5), reticle)
	mesh_box(Vector3(0.2, 1.6, 0.2), Vector3.ZERO, Color(0.4, 1, 0.5), reticle)
	hud = Label3D.new()
	hud.font_size = 38
	hud.position = Vector3(-0.6, -0.42, -1.3)
	hud.modulate = Color(0.8, 1, 0.9)
	cam.add_child(hud)
	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.45, 0.35)},
		{"id": "dodge", "label": "DODGE", "col": Color(0.5, 0.8, 0.95)},
	])
	tc.action.connect(func(id):
		if id == "fire": _fire()
		elif id == "dodge": _dodge())


func _aim_point() -> Vector3:
	# reticle plane 24 units ahead of the ship
	return Vector3(aim.x * 13.0, 2.0 + -aim.y * 9.0, railz - 24.0)


func _fire() -> void:
	if fire_cd > 0.0:
		return
	fire_cd = 0.16
	Juice.sfx("tick")
	var ap := _aim_point()
	var hit := false
	for f in foes.duplicate():
		if f.pos.distance_to(ap) < 3.2:
			f.hp -= 1
			hit = true
			if f.hp <= 0:
				f.node.queue_free()
				foes.erase(f)
				combo += 1
				add_points(1 + combo / 5)
				Juice.sfx("boom")
				Juice.popup("x%d" % combo, Vector2(W * 0.5, H * 0.4), Color(1, 0.9, 0.4))
			break
	if not hit:
		combo = 0


func _dodge() -> void:
	if dodge_t > 0.0:
		return
	dodge_t = 0.5
	dodge_dir = -1.0 if aim.x > 0.0 else 1.0
	Juice.sfx("thud")
	Juice.haptic(15)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_fire()
		elif event.keycode == KEY_SHIFT:
			_dodge()


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	fire_cd -= delta
	dodge_t = maxf(0.0, dodge_t - delta)
	railz -= (18.0 + t * 0.2) * delta          # auto-advance forward

	aim = (aim + Vector2(tc.move.x + key_axis_x(), tc.move.y - key_axis_y()) * delta * 2.5)
	aim.x = clampf(aim.x, -1.0, 1.0)
	aim.y = clampf(aim.y, -1.0, 1.0)
	var ap := _aim_point()
	reticle.position = ap
	reticle.look_at(cam.global_position, Vector3.UP)

	# camera strafes during a dodge (i-frames)
	var sx := dodge_dir * sin((0.5 - dodge_t) / 0.5 * PI) * 6.0 if dodge_t > 0.0 else 0.0
	cam.position = Vector3(sx, 2, railz + 8.0)
	cam.look_at(Vector3(0, 2, railz - 20.0), Vector3.UP)

	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(0.45, 1.4 - t * 0.02)
		var p := Vector3(randf_range(-12, 12), randf_range(-1, 6), railz - 70.0)
		var node := mesh_box(Vector3(2, 2, 2), p, Color(0.9, 0.4, 0.4))
		foes.append({"node": node, "pos": p, "hp": 2, "fire": randf_range(1.0, 2.4)})

	for f in foes.duplicate():
		f.pos.z += (16.0 + t * 0.3) * delta       # approach the ship
		f.node.position = f.pos
		f.node.rotation.y += delta
		f.fire -= delta
		if f.fire <= 0.0 and f.pos.z < railz - 6.0:
			f.fire = randf_range(1.4, 2.6)
			var dir := (Vector3(0, 2, railz) - f.pos).normalized()
			ebul.append({"pos": f.pos, "vel": dir * 40.0, "life": 4.0,
				"node": mesh_sphere(0.4, f.pos, Color(1, 0.7, 0.2))})
		if f.pos.z > railz + 4.0:                  # flew past
			f.node.queue_free()
			foes.erase(f)
			combo = 0

	for b in ebul.duplicate():
		b.pos += b.vel * delta
		b.life -= delta
		b.node.position = b.pos
		if b.life <= 0.0:
			b.node.queue_free()
			ebul.erase(b)
			continue
		if dodge_t <= 0.0 and b.pos.distance_to(Vector3(cam.position.x, 2, railz)) < 2.2:
			b.node.queue_free()
			ebul.erase(b)
			hp -= 12.0
			Juice.flash(Color(1, 0.3, 0.3), 0.25)
			Juice.haptic(30)
			if hp <= 0.0:
				end_demo()
				return

	hud.text = "HP %d   KILLS %d   COMBO x%d%s" % [int(max(0, hp)), score, combo,
		"   DODGE!" if dodge_t > 0.0 else ""]
