extends MechDemo3D
## DEMOLITION DERBY (BeamNG-lite): ram rivals in a walled arena. Damage scales with the
## CLOSING SPEED and hit angle — your reinforced nose into their side wrecks them cheap,
## and cars visibly deform (squash, lower, darken, tilt, wheel splay) until they smoke
## out at 0 HP. Last car running wins the round; tougher rivals every round.
## Touch: left stick throttle(up)/reverse + steer, BOOST button. Desktop: WASD, SPACE boost.

const ARENA := 22.0
const CAR_R := 1.5
const BASE_Y := 0.55
const ACCEL := 11.0
const DRAG := 1.1
const TURN := 2.4
const MAX_FWD := 15.0
const MAX_REV := 6.0
const BOOST_MULT := 1.8
const LUNGE := 4.0
const DMG_K := 0.9
const MIN_CLOSE := 2.0
const CAM_DIST := 9.0
const CAM_H := 6.5
const WRECK_PTS := 40
const KILL_BONUS := 60
const ROUND_BONUS := 150
const HEAL := 45.0

var tc: TouchControls
var cars: Array = []
var smoke: Array = []
var round_no := 1
var kills := 0
var _shake := 0.0
var dying := 0.0

var hud_fill: ColorRect
var hud_info: Label


func start() -> void:
	super.start()
	setup_world(Color(0.10, 0.11, 0.14), 0.85, Vector3(-60, -35, 0))
	make_camera(Vector3(0, CAM_H, CAM_DIST), Vector3.ZERO, 68.0)
	_build_arena()
	_build_hud()
	tc = add_touch_controls([
		{"id": "boost", "label": "BOOST", "col": Color(0.95, 0.75, 0.2)},
	], false, true)
	tc.action.connect(func(_id): _lunge())
	_spawn_player()
	_new_round()


func _build_arena() -> void:
	mesh_box(Vector3(ARENA * 2.0 + 4.0, 0.5, ARENA * 2.0 + 4.0), Vector3(0, -0.25, 0), Color(0.16, 0.17, 0.2))
	var wc := Color(0.28, 0.29, 0.34)
	var h := 2.5
	mesh_box(Vector3(ARENA * 2.0 + 2.0, h, 1.0), Vector3(0, h * 0.5, ARENA), wc)
	mesh_box(Vector3(ARENA * 2.0 + 2.0, h, 1.0), Vector3(0, h * 0.5, -ARENA), wc)
	mesh_box(Vector3(1.0, h, ARENA * 2.0 + 2.0), Vector3(ARENA, h * 0.5, 0), wc)
	mesh_box(Vector3(1.0, h, ARENA * 2.0 + 2.0), Vector3(-ARENA, h * 0.5, 0), wc)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	var hp_lbl := Label.new()
	hp_lbl.text = "CONDITION"
	hp_lbl.add_theme_font_size_override("font_size", 20)
	hp_lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	hp_lbl.position = Vector2(W * 0.5 - 150.0, 108.0)
	layer.add_child(hp_lbl)
	var frame := ColorRect.new()
	frame.color = Color(0, 0, 0, 0.5)
	frame.position = Vector2(W * 0.5 - 154.0, 132.0)
	frame.size = Vector2(308, 28)
	layer.add_child(frame)
	hud_fill = ColorRect.new()
	hud_fill.color = Color(0.35, 0.9, 0.45)
	hud_fill.position = Vector2(W * 0.5 - 150.0, 136.0)
	hud_fill.size = Vector2(300, 20)
	layer.add_child(hud_fill)
	hud_info = Label.new()
	hud_info.add_theme_font_size_override("font_size", 26)
	hud_info.add_theme_color_override("font_color", Color.WHITE)
	hud_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud_info.position = Vector2(W * 0.5 - 200.0, 168.0)
	hud_info.size = Vector2(400, 30)
	layer.add_child(hud_info)


func _make_car(col: Color, hp: float, is_player: bool) -> Car:
	var c := Car.new()
	c.root = Node3D.new()
	add_child(c.root)
	c.body = Node3D.new()
	c.body.position = Vector3(0, BASE_Y, 0)
	c.root.add_child(c.body)
	c.hull = mesh_box(Vector3(1.8, 0.7, 3.0), Vector3.ZERO, col, c.body)
	c.cabin = mesh_box(Vector3(1.5, 0.6, 1.4), Vector3(0, 0.6, -0.2), col.darkened(0.2), c.body)
	var nose_col := Color(0.92, 0.92, 0.96) if is_player else col.lightened(0.25)
	c.nose = mesh_box(Vector3(1.9, 0.5, 0.5), Vector3(0, -0.05, 1.6), nose_col, c.body)
	c.wheels = []
	for wx in [-0.95, 0.95]:
		for wz in [-1.1, 1.1]:
			var w := mesh_cyl(0.45, 0.35, Vector3(wx, 0.4, wz), Color(0.08, 0.08, 0.09), c.root)
			w.rotation.z = PI * 0.5
			c.wheels.append(w)
	c.hp = hp
	c.max_hp = hp
	c.base_col = col
	c.is_player = is_player
	return c


func _spawn_player() -> void:
	var p := _make_car(Color(0.25, 0.55, 0.95), 120.0, true)
	p.spd_cap = MAX_FWD
	p.ai = false
	cars.append(p)


func _new_round() -> void:
	for c in cars.duplicate():
		if not c.is_player:
			c.root.queue_free()
			cars.erase(c)
	var p: Car = cars[0]
	p.pos = Vector2.ZERO
	p.yaw = 0.0
	p.speed = 0.0
	p.wrecked = false
	p.dent = 0.0
	p.hp = minf(p.max_hp, p.hp + HEAL) if round_no > 1 else p.max_hp
	var n := clampi(3 + round_no, 4, 6)
	for k in n:
		var ang := TAU * float(k) / float(n)
		var rc := hue_col(float(k) * 3.0 + float(round_no), 0.6, 0.85)
		var hp := 70.0 + float(round_no - 1) * 12.0
		var r := _make_car(rc, hp, false)
		r.pos = Vector2(sin(ang), cos(ang)) * (ARENA * 0.62)
		r.yaw = ang + PI
		r.ai = true
		r.spd_cap = 11.0 + float(round_no - 1) * 0.9
		r.aggr = 0.5 + float(round_no) * 0.12
		r.retarget = randf()
		cars.append(r)
	_update_deform_all()


func _lunge() -> void:
	if cars.is_empty() or dying > 0.0:
		return
	var p: Car = cars[0]
	if p.wrecked:
		return
	p.speed += LUNGE
	Juice.sfx("tick", 1.5)
	Juice.haptic(12)


func _process(delta: float) -> void:
	if not running:
		return
	delta = minf(delta, 0.05)
	if cars.is_empty():
		return
	if dying > 0.0:
		dying -= delta
		_update_deform_all()
		_update_smoke(delta)
		_update_cam(delta)
		if dying <= 0.0:
			end_demo()
		return
	_drive_player(delta)
	for c in cars:
		if c.ai and not c.wrecked:
			_drive_ai(c, delta)
	for c in cars:
		_integrate(c, delta)
	_collisions()
	_update_deform_all()
	_update_smoke(delta)
	_update_cam(delta)
	_update_hud()
	_check_round()


func _drive_player(delta: float) -> void:
	var p: Car = cars[0]
	if p.wrecked:
		return
	var throttle := clampf(key_axis_y() - tc.move.y, -1.0, 1.0)
	var steer := clampf(tc.move.x + key_axis_x(), -1.0, 1.0)
	var boosting := (tc.held("boost") or Input.is_key_pressed(KEY_SPACE)) and throttle > 0.0
	var cap := p.spd_cap * (BOOST_MULT if boosting else 1.0)
	var acc := throttle * ACCEL * (BOOST_MULT if boosting else 1.0)
	p.speed += acc * delta
	p.speed -= p.speed * DRAG * delta
	p.speed = clampf(p.speed, -MAX_REV, cap)
	p.steer_in = steer


func _drive_ai(c: Car, delta: float) -> void:
	c.retarget -= delta
	if c.retarget <= 0.0 or _is_dead_idx(c.target):
		c.target = _pick_target(c)
		c.retarget = randf_range(1.2, 2.5)
	var steer := 0.0
	var throttle := 1.0
	if c.target >= 0:
		var t: Car = cars[c.target]
		var to := t.pos - c.pos
		var diff := wrapf(atan2(to.x, to.y) - c.yaw, -PI, PI)
		steer = clampf(diff * 2.2, -1.0, 1.0)
	if c.pos.length() > ARENA - 5.0:
		var cd := wrapf(atan2(-c.pos.x, -c.pos.y) - c.yaw, -PI, PI)
		steer = clampf(steer + cd * 1.5, -1.0, 1.0)
	if absf(c.speed) < 0.6:
		c.stuck += delta
	else:
		c.stuck = maxf(0.0, c.stuck - delta)
	if c.stuck > 1.0:
		throttle = -1.0
		if c.stuck > 2.0:
			c.stuck = 0.0
	var near := c.target >= 0 and (cars[c.target].pos - c.pos).length() < 8.0
	var cap := c.spd_cap * (1.5 if c.aggr > 0.8 and near else 1.0)
	var acc := throttle * ACCEL * (0.6 + c.aggr * 0.5)
	c.speed += acc * delta
	c.speed -= c.speed * DRAG * delta
	c.speed = clampf(c.speed, -MAX_REV, cap)
	c.steer_in = steer


func _integrate(c: Car, delta: float) -> void:
	c.yaw += c.steer_in * TURN * delta * clampf(c.speed / 4.0, -1.0, 1.0)
	var fwd := Vector2(sin(c.yaw), cos(c.yaw))
	c.vel = fwd * c.speed
	c.pos += c.vel * delta
	var lim := ARENA - CAR_R
	if absf(c.pos.x) > lim:
		c.pos.x = clampf(c.pos.x, -lim, lim)
		c.speed *= 0.4
		if c.is_player:
			_shake = maxf(_shake, 0.25)
	if absf(c.pos.y) > lim:
		c.pos.y = clampf(c.pos.y, -lim, lim)
		c.speed *= 0.4
		if c.is_player:
			_shake = maxf(_shake, 0.25)
	c.root.position = Vector3(c.pos.x, 0.0, c.pos.y)
	c.root.rotation.y = c.yaw
	c.bump_cd = maxf(0.0, c.bump_cd - delta)


func _collisions() -> void:
	for i in cars.size():
		for j in range(i + 1, cars.size()):
			var a: Car = cars[i]
			var b: Car = cars[j]
			var d := b.pos - a.pos
			var dist := d.length()
			var mind := CAR_R * 2.0
			if dist >= mind or dist < 0.001:
				continue
			var n := d / dist
			var overlap := mind - dist
			var a_dead := a.wrecked
			var b_dead := b.wrecked
			if a_dead and not b_dead:
				b.pos += n * overlap
			elif b_dead and not a_dead:
				a.pos -= n * overlap
			elif not a_dead and not b_dead:
				a.pos -= n * (overlap * 0.5)
				b.pos += n * (overlap * 0.5)
			if a_dead or b_dead:
				if not a_dead:
					a.speed *= 0.6
				if not b_dead:
					b.speed *= 0.6
				continue
			var closing := (a.vel - b.vel).dot(n)
			if closing <= MIN_CLOSE or a.bump_cd > 0.0 or b.bump_cd > 0.0:
				a.speed *= 0.7
				b.speed *= 0.7
				continue
			_ram(i, j, n, closing)


func _ram(ia: int, ib: int, n: Vector2, closing: float) -> void:
	var a: Car = cars[ia]
	var b: Car = cars[ib]
	var fa := Vector2(sin(a.yaw), cos(a.yaw))
	var fb := Vector2(sin(b.yaw), cos(b.yaw))
	var align_a := clampf(fa.dot(n), 0.0, 1.0)
	var align_b := clampf(fb.dot(-n), 0.0, 1.0)
	var dmg_b := closing * DMG_K * (0.5 + align_a) * (1.4 - 0.9 * align_b)
	var dmg_a := closing * DMG_K * (0.5 + align_b) * (1.4 - 0.9 * align_a)
	b.hp -= dmg_b
	a.hp -= dmg_a
	b.last_by = ia
	a.last_by = ib
	var sev := clampf(closing / 13.0, 0.0, 1.0)
	a.dent += randf_range(-0.04, 0.04) + sev * 0.05
	b.dent += randf_range(-0.04, 0.04) + sev * 0.05
	a.speed *= 0.35
	b.speed *= 0.35
	a.pos -= n * 0.3
	b.pos += n * 0.3
	a.bump_cd = 0.35
	b.bump_cd = 0.35
	var mid := Vector3((a.pos.x + b.pos.x) * 0.5, 1.0, (a.pos.y + b.pos.y) * 0.5)
	if a.is_player or b.is_player:
		_shake = maxf(_shake, 0.25 + sev * 0.9)
		Juice.haptic(int(15 + sev * 35))
		Juice.hitstop(int(sev * 90))
		Juice.flash(Color(1, 0.85, 0.7), 0.12 + sev * 0.2)
		Juice.sfx("boom" if sev > 0.6 else "thud", 1.0 + sev * 0.3)
		var pc := Color(1, 0.6, 0.4) if a.is_player and dmg_a > dmg_b else Color(1, 0.9, 0.5)
		_popup3(mid, "%d" % int(dmg_a + dmg_b), pc)
	elif sev > 0.5:
		Juice.sfx("thud", 0.8)
	_check_wreck(ia)
	_check_wreck(ib)


func _check_wreck(i: int) -> void:
	var c: Car = cars[i]
	if c.wrecked or c.hp > 0.0:
		return
	c.wrecked = true
	c.hp = 0.0
	c.speed = 0.0
	c.dent += randf_range(0.2, 0.4)
	if c.is_player:
		Juice.sfx("boom", 0.8)
		Juice.flash(Color(1, 0.3, 0.25), 0.4)
		_shake = maxf(_shake, 1.4)
		dying = 1.3
		return
	add_points(WRECK_PTS)
	Juice.sfx("boom", 1.1)
	var mid := Vector3(c.pos.x, 1.5, c.pos.y)
	if c.last_by == 0:
		kills += 1
		add_points(KILL_BONUS)
		_shake = maxf(_shake, 0.6)
		Juice.hitstop(70)
		Juice.haptic(40)
		Juice.sfx("coin")
		_popup3(mid, "WRECKED!", Color(1, 0.85, 0.3))
	else:
		_popup3(mid, "OUT", Color(1, 1, 1, 0.85))


func _check_round() -> void:
	if cars[0].wrecked:
		return
	var alive_rivals := 0
	for c in cars:
		if c.ai and not c.wrecked:
			alive_rivals += 1
	if alive_rivals == 0:
		round_no += 1
		add_points(ROUND_BONUS)
		Juice.sfx("coin")
		Juice.flash(Color(1, 0.9, 0.5), 0.25)
		_popup3(Vector3(cars[0].pos.x, 2.0, cars[0].pos.y), "ROUND CLEARED", Color(0.6, 1, 0.7))
		_new_round()


func _pick_target(c: Car) -> int:
	var best := -1
	var bd := 1.0e9
	for i in cars.size():
		var o: Car = cars[i]
		if o == c or o.wrecked:
			continue
		var d := (o.pos - c.pos).length()
		if o.is_player:
			d *= 0.7
		if d < bd:
			bd = d
			best = i
	return best


func _is_dead_idx(i: int) -> bool:
	return i < 0 or i >= cars.size() or cars[i].wrecked


func _update_deform_all() -> void:
	for c in cars:
		_apply_deform(c)


func _apply_deform(c: Car) -> void:
	var ratio := clampf(c.hp / c.max_hp, 0.0, 1.0)
	var dmg := 1.0 - ratio
	c.body.scale = Vector3(1.0 - 0.12 * dmg, 1.0 - 0.4 * dmg, 1.0 - 0.2 * dmg)
	c.body.position.y = (BASE_Y - 0.3) if c.wrecked else (BASE_Y - 0.28 * dmg)
	c.body.rotation = Vector3(c.dent * 0.35, 0.0, c.dent)
	var col := c.base_col.lerp(Color(0.13, 0.1, 0.08), clampf(dmg * 1.1, 0.0, 0.88))
	(c.hull.material_override as StandardMaterial3D).albedo_color = col
	(c.cabin.material_override as StandardMaterial3D).albedo_color = col.darkened(0.2)
	if dmg > 0.4 and not c.wheels.is_empty():
		c.wheels[0].rotation.x = dmg * 0.6


func _update_cam(delta: float) -> void:
	var p: Car = cars[0]
	var fwd := Vector2(sin(p.yaw), cos(p.yaw))
	var target := Vector3(p.pos.x, 0.6, p.pos.y)
	var want := target + Vector3(-fwd.x, 0.0, -fwd.y) * CAM_DIST + Vector3(0.0, CAM_H, 0.0)
	cam.position = cam.position.lerp(want, clampf(delta * 4.0, 0.0, 1.0))
	if _shake > 0.001:
		cam.position += Vector3(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake
	cam.look_at(target, Vector3.UP)
	_shake = maxf(0.0, _shake - delta * 3.5)


func _update_hud() -> void:
	var p: Car = cars[0]
	var ratio := clampf(p.hp / p.max_hp, 0.0, 1.0)
	hud_fill.size.x = 300.0 * ratio
	hud_fill.color = Color(0.9, 0.25, 0.2).lerp(Color(0.35, 0.9, 0.45), ratio)
	var alive := 0
	for c in cars:
		if not c.wrecked:
			alive += 1
	hud_info.text = "ROUND %d    CARS %d    KILLS %d" % [round_no, alive, kills]


func _update_smoke(delta: float) -> void:
	for c in cars:
		if not (c.wrecked or c.hp / c.max_hp < 0.33):
			continue
		c.smoke_t -= delta
		if c.smoke_t <= 0.0 and smoke.size() < 40:
			c.smoke_t = 0.16 if c.wrecked else 0.4
			_spawn_smoke(Vector3(c.pos.x + randf_range(-0.4, 0.4), 1.2, c.pos.y + randf_range(-0.4, 0.4)), c.wrecked)
	for s in smoke.duplicate():
		s.life -= delta
		s.node.position.y += delta * 1.6
		s.node.scale += Vector3.ONE * delta * 0.7
		(s.node.material_override as StandardMaterial3D).albedo_color.a = clampf(s.life / s.max_life, 0.0, 1.0) * 0.6
		if s.life <= 0.0:
			s.node.queue_free()
			smoke.erase(s)


func _spawn_smoke(pos: Vector3, dark: bool) -> void:
	var col := Color(0.2, 0.2, 0.22) if dark else Color(0.55, 0.55, 0.58)
	var mi := mesh_sphere(randf_range(0.3, 0.5), pos, col)
	var m := mi.material_override as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color.a = 0.55
	var pf := Puff.new()
	pf.node = mi
	pf.life = randf_range(0.8, 1.4)
	pf.max_life = pf.life
	smoke.append(pf)


func _popup3(world: Vector3, text: String, col: Color) -> void:
	if cam == null or cam.is_position_behind(world):
		return
	Juice.popup(text, cam.unproject_position(world), col, 40)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_lunge()


class Car:
	var root: Node3D
	var body: Node3D
	var hull: MeshInstance3D
	var cabin: MeshInstance3D
	var nose: MeshInstance3D
	var wheels: Array = []
	var pos := Vector2.ZERO
	var yaw := 0.0
	var speed := 0.0
	var vel := Vector2.ZERO
	var steer_in := 0.0
	var hp := 100.0
	var max_hp := 100.0
	var base_col := Color.WHITE
	var is_player := false
	var ai := false
	var wrecked := false
	var bump_cd := 0.0
	var dent := 0.0
	var last_by := -1
	var target := -1
	var retarget := 0.0
	var stuck := 0.0
	var spd_cap := 12.0
	var aggr := 0.6
	var smoke_t := 0.0


class Puff:
	var node: MeshInstance3D
	var life := 0.0
	var max_life := 1.0
