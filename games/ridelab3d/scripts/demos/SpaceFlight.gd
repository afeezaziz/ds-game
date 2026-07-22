extends MechDemo3D
## SPACE 6DOF NEWTONIAN FLIGHT (Elite/Everspace). The deep system is MOMENTUM:
## THRUST adds velocity along your nose and it PERSISTS — you drift. To slow you
## must flip and counter-thrust or hold BRAKE. Orientation (pitch/yaw/roll) is
## independent of travel, so you face one way while sliding another — lead shots.
## Touch: drag=look pitch/yaw, THRUST / BRAKE / FIRE buttons, stick.y also throttles.
## Desktop: W/S pitch, A/D yaw, Q/E roll, SHIFT thrust, CTRL brake, SPACE fire.

const THRUST_ACCEL := 20.0
const BRAKE_DECEL := 16.0
const MAX_SPEED := 60.0
const LOOK_SENS := 0.0035
const KEY_ROT := 1.4
const ROLL_RATE := 2.0
const BULLET_SPEED := 130.0
const FIRE_CD := 0.15
const ESHOT_SPEED := 70.0
const ENEMY_ACCEL := 11.0
const ENEMY_MAX := 34.0
const HIT_R := 2.6
const STAR_R := 190.0

var ship: Node3D
var engine_glow: MeshInstance3D
var ppos := Vector3.ZERO
var vel := Vector3.ZERO
var hull := 100.0
var fire_cd := 0.0
var hurt_cd := 0.0
var spawn_t := 1.0
var t := 0.0
var kills := 0
var look_accum := Vector2.ZERO
var cam_pos := Vector3.ZERO
var _shake := 0.0

var pbul: Array = []
var ebul: Array = []
var foes: Array = []
var stars: Array = []
var rocks: Array = []
var prograde: MeshInstance3D
var tc: TouchControls
var hud: Label


func start() -> void:
	super.start()
	setup_world(Color(0.02, 0.02, 0.05), 0.9, Vector3(-40, -30, 0))
	ppos = Vector3.ZERO
	vel = Vector3.ZERO
	hull = 100.0
	fire_cd = 0.0
	hurt_cd = 0.0
	spawn_t = 1.0
	t = 0.0
	kills = 0
	look_accum = Vector2.ZERO
	pbul = []
	ebul = []
	foes = []
	stars = []
	rocks = []

	ship = _make_ship(Color(0.72, 0.82, 0.95), Color(0.35, 0.6, 0.95))
	ship.position = ppos
	engine_glow = mesh_box(Vector3(0.7, 0.7, 0.7), Vector3(0, 0, 1.5), Color(0.5, 0.8, 1.0), ship)
	engine_glow.visible = false

	# infinite tiled star-field (wrapped around the ship each frame)
	for i in 150:
		var base := Vector3(randf_range(-STAR_R, STAR_R), randf_range(-STAR_R, STAR_R), randf_range(-STAR_R, STAR_R))
		var s := randf_range(0.5, 1.4)
		var node := mesh_box(Vector3(s, s, s), base, Color(0.9, 0.9, 1.0))
		stars.append({"node": node, "base": base})

	# a couple of asteroids near the start (drift hazards)
	for i in 3:
		var rp := Vector3(randf_range(-45, 45), randf_range(-30, 30), randf_range(30, 80))
		var rr := randf_range(6.0, 11.0)
		var rn := mesh_sphere(rr, rp, Color(0.4, 0.36, 0.33))
		rocks.append({"node": rn, "pos": rp, "r": rr})

	# prograde (velocity-vector) marker — the drift is legible
	prograde = mesh_box(Vector3(1.1, 1.1, 1.1), Vector3.ZERO, Color(0.3, 1.0, 0.5))
	prograde.visible = false

	cam_pos = ppos + Vector3(0, 3.5, 11)
	make_camera(cam_pos, ppos, 68.0)
	label3d("+", Vector3(0, 0, -3), 64, Color(0.9, 1, 0.9), cam)

	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(24, 90)
	hud.add_theme_font_size_override("font_size", 34)
	hud.add_theme_color_override("font_color", Color(0.85, 0.95, 1.0))
	layer.add_child(hud)
	demo_over.connect(func(_s): layer.visible = false)

	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.4, 0.35)},
		{"id": "thrust", "label": "THRUST", "col": Color(0.4, 0.7, 0.95)},
		{"id": "brake", "label": "BRAKE", "col": Color(0.85, 0.75, 0.35)},
	], true, true)
	tc.look.connect(func(rel): look_accum += rel)


func _make_ship(body: Color, fin: Color) -> Node3D:
	var n := Node3D.new()
	add_child(n)
	mesh_box(Vector3(1.4, 0.5, 3.0), Vector3.ZERO, body, n)
	mesh_box(Vector3(2.6, 0.2, 0.9), Vector3(0, 0, 0.6), fin, n)
	mesh_box(Vector3(0.4, 0.6, 1.0), Vector3(0, 0.35, 0.5), fin, n)
	return n


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_fire()


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	fire_cd -= delta
	hurt_cd -= delta

	# --- orientation: rotate in local space for true 6DOF (no gimbal snap) ---
	var roll_in := 0.0
	if Input.is_key_pressed(KEY_Q):
		roll_in -= 1.0
	if Input.is_key_pressed(KEY_E):
		roll_in += 1.0
	var ang_yaw := -look_accum.x * LOOK_SENS - key_axis_x() * KEY_ROT * delta
	var ang_pitch := -look_accum.y * LOOK_SENS + key_axis_y() * KEY_ROT * delta
	ship.rotate_object_local(Vector3.UP, ang_yaw)
	ship.rotate_object_local(Vector3.RIGHT, ang_pitch)
	ship.rotate_object_local(Vector3.FORWARD, roll_in * ROLL_RATE * delta)
	look_accum = Vector2.ZERO

	var fwd := -ship.global_transform.basis.z

	# --- throttle: buttons, stick.y, or SHIFT/CTRL. Velocity PERSISTS. ---
	var thr := 0.0
	var brk := 0.0
	if tc:
		if tc.held("thrust"):
			thr = 1.0
		if tc.held("brake"):
			brk = 1.0
		if tc.move.y < -0.15:
			thr = maxf(thr, -tc.move.y)
		if tc.move.y > 0.15:
			brk = maxf(brk, tc.move.y)
	if Input.is_key_pressed(KEY_SHIFT):
		thr = 1.0
	if Input.is_key_pressed(KEY_CTRL):
		brk = 1.0

	if thr > 0.0:
		vel += fwd * THRUST_ACCEL * thr * delta
	if brk > 0.0:
		vel = vel.move_toward(Vector3.ZERO, BRAKE_DECEL * brk * delta)
	vel = vel.limit_length(MAX_SPEED)
	ppos += vel * delta
	ship.position = ppos
	engine_glow.visible = thr > 0.0

	# continuous fire while held
	if (tc and tc.held("fire")):
		_fire()

	_wrap_stars()
	_update_bullets(delta)
	_update_foes(delta, fwd)
	_check_rocks()
	_update_marker()
	_update_camera(delta)

	var spd := vel.length()
	var drift := "prograde" if fwd.dot(vel.normalized()) > 0.6 or spd < 1.0 else "DRIFTING"
	hud.text = "HULL %d    SPEED %d m/s    KILLS %d\n%s" % [int(maxf(0.0, hull)), int(spd), kills, drift]


func _fire() -> void:
	if fire_cd > 0.0:
		return
	fire_cd = FIRE_CD
	var fwd := -ship.global_transform.basis.z
	# Newtonian: shots inherit the ship's momentum, so your drift carries them
	pbul.append({"pos": ppos + fwd * 2.5, "vel": fwd * BULLET_SPEED + vel, "life": 2.5,
		"node": mesh_box(Vector3(0.3, 0.3, 1.2), ppos, Color(0.5, 1.0, 0.7))})
	Juice.sfx("tick", 1.25)


func _update_bullets(delta: float) -> void:
	for b in pbul.duplicate():
		b.pos += b.vel * delta
		b.life -= delta
		b.node.position = b.pos
		if b.life <= 0.0:
			b.node.queue_free()
			pbul.erase(b)
			continue
		for e in foes.duplicate():
			if b.pos.distance_to(e.pos) < 3.0:
				b.node.queue_free()
				pbul.erase(b)
				e.hp -= 1
				if e.hp <= 0:
					e.node.queue_free()
					foes.erase(e)
					kills += 1
					add_points(1)
					Juice.sfx("boom")
					Juice.flash(Color(0.6, 0.9, 1.0), 0.18)
					Juice.popup("KILL", Vector2(360, 470), Color(0.5, 1, 0.7), 46)
				else:
					Juice.sfx("thud")
				break

	for b in ebul.duplicate():
		b.pos += b.vel * delta
		b.life -= delta
		b.node.position = b.pos
		if b.life <= 0.0:
			b.node.queue_free()
			ebul.erase(b)
			continue
		if b.pos.distance_to(ppos) < HIT_R:
			b.node.queue_free()
			ebul.erase(b)
			_take_damage(11.0)


func _update_foes(delta: float, _fwd: Vector3) -> void:
	spawn_t -= delta
	if spawn_t <= 0.0 and foes.size() < 5:
		spawn_t = maxf(1.3, 3.2 - t * 0.02)
		var dir := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var p := ppos + dir * randf_range(70, 100)
		var node := _make_ship(Color(0.9, 0.42, 0.36), Color(0.6, 0.2, 0.2))
		foes.append({"node": node, "pos": p, "vel": vel * 0.5, "hp": 3, "fire": randf_range(1.0, 2.5)})

	for e in foes:
		var to: Vector3 = ppos - e.pos
		var dist := to.length()
		# seek-with-inertia: enemies accelerate toward you and drift too
		e.vel += to.normalized() * ENEMY_ACCEL * delta
		e.vel = (e.vel as Vector3).limit_length(ENEMY_MAX)
		e.pos += e.vel * delta
		e.node.position = e.pos
		_face(e.node, e.pos, ppos)
		e.fire -= delta
		if e.fire <= 0.0 and dist < 90.0:
			e.fire = randf_range(1.4, 2.8)
			var lead := ppos + vel * (dist / ESHOT_SPEED)
			var aim := (lead - e.pos).normalized()
			ebul.append({"pos": e.pos, "vel": aim * ESHOT_SPEED + e.vel, "life": 3.5,
				"node": mesh_box(Vector3(0.3, 0.3, 1.0), e.pos, Color(1.0, 0.5, 0.4))})
			Juice.sfx("tick", 0.7)


func _check_rocks() -> void:
	if hurt_cd > 0.0:
		return
	for r in rocks:
		if ppos.distance_to(r.pos) < r.r + 1.6:
			var n: Vector3 = (ppos - r.pos).normalized()
			vel = vel.bounce(n) * 0.6 if vel.length() > 0.1 else n * 8.0
			ppos = r.pos + n * (r.r + 1.8)
			ship.position = ppos
			_take_damage(16.0)
			hurt_cd = 0.6
			return


func _take_damage(amount: float) -> void:
	hull -= amount
	_shake += 0.35
	Juice.sfx("thud")
	Juice.flash(Color(1, 0.3, 0.3), 0.22)
	Juice.haptic(28)
	if hull <= 0.0:
		Juice.sfx("boom")
		Juice.flash(Color(1, 0.2, 0.2), 0.4)
		end_demo()


func _face(node: Node3D, from: Vector3, target: Vector3) -> void:
	var dir := target - from
	if dir.length() < 0.01:
		return
	var up := Vector3.UP
	if absf(dir.normalized().dot(up)) > 0.99:
		up = Vector3.FORWARD
	node.look_at(from + dir, up)


func _wrap_stars() -> void:
	for s in stars:
		var rel: Vector3 = s.base - ppos
		rel.x = wrapf(rel.x, -STAR_R, STAR_R)
		rel.y = wrapf(rel.y, -STAR_R, STAR_R)
		rel.z = wrapf(rel.z, -STAR_R, STAR_R)
		s.node.position = ppos + rel


func _update_marker() -> void:
	var spd := vel.length()
	if spd < 1.0:
		prograde.visible = false
		return
	prograde.visible = true
	prograde.position = ppos + vel.normalized() * 24.0


func _update_camera(delta: float) -> void:
	var basis := ship.global_transform.basis
	var desired := ppos + basis.z * 11.0 + basis.y * 3.5
	cam_pos = cam_pos.lerp(desired, clampf(7.0 * delta, 0.0, 1.0))
	_shake = maxf(0.0, _shake - delta * 1.5)
	var off := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake
	cam.position = cam_pos + off
	cam.look_at(ppos - basis.z * 6.0, basis.y)
