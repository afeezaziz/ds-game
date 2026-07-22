extends MechDemo3D
## HERO SHOOTER (Overwatch): third-person arena built on OBJECTIVE CONTROL + an
## ability/ULT economy. Stand on the CAPTURE POINT alone to fill it; an enemy on it
## freezes it (CONTESTED) and enemies alone push it back. FIRE auto-aims the nearest
## bot in a cone; DASH repositions with i-frames; ULT charges from damage + holding
## the point, then unleashes a damage NOVA + rapid-fire OVERDRIVE. Fill = round win.
## Touch: stick move, FIRE/DASH/ULT buttons.  Desktop: WASD, J fire, K dash, L ult.

const ARENA := 20.0
const PSPEED := 9.0
const ESPEED := 4.2
const FIRE_CD := 0.22
const OD_FIRE_CD := 0.08
const PBULLET := 42.0
const EBULLET := 22.0
const PT_RADIUS := 4.2
const CAP_TIME := 9.0
const DASH_CD := 3.2
const DASH_DIST := 6.5
const DASH_IFRAME := 0.45
const AIM_DOT := 0.25
const AIM_RANGE := 24.0
const ULT_PER_DMG := 0.05
const ULT_PER_SEC := 0.06
const NOVA_RADIUS := 9.0
const NOVA_DMG := 8.0
const OVERDRIVE_TIME := 3.0
const REGEN_DELAY := 3.0
const REGEN_RATE := 16.0

var tc: TouchControls
var player: Node3D
var _shield: MeshInstance3D
var _point_disk: MeshInstance3D
var _root: Node3D

var _pyaw := PI
var _hp := 100.0
var _max_hp := 100.0
var _lives := 3
var _round := 1
var _fire_cd := 0.0
var _dash_cd := 0.0
var _iframe := 0.0
var _overdrive := 0.0
var _combat := 9.0
var _shake := 0.0
var _ult := 0.0
var _ult_ready := false
var _capture := 0.0
var _contested := false
var _pending := ""

var _enemies: Array = []    # {node,hp,max,fcd,bar}
var _bullets: Array = []    # {node,vel,life,hostile}
var _fx: Array = []         # {node,t,dur,r0,r1}

var _point_pos := Vector3.ZERO

var _hud: Control
var _hp_fill: ColorRect
var _cap_fill: ColorRect
var _dash_fill: ColorRect
var _ult_fill: ColorRect
var _lbl_score: Label
var _lbl_round: Label
var _lbl_cap: Label
var _lbl_dash: Label
var _lbl_ult: Label
var _lbl_msg: Label


func start() -> void:
	super.start()
	setup_world(Color(0.08, 0.10, 0.15), 0.8, Vector3(-58, -40, 0))
	make_camera(Vector3(0, 15, 12), Vector3.ZERO, 60.0)
	mesh_box(Vector3(ARENA * 2.0, 0.4, ARENA * 2.0), Vector3(0, -0.2, 0), Color(0.14, 0.16, 0.21))
	for i in 4:
		var a := float(i) * TAU / 4.0 + 0.6
		mesh_box(Vector3(2.2, 1.8, 2.2), Vector3(cos(a) * 11.0, 0.9, sin(a) * 11.0), Color(0.22, 0.25, 0.32))
	_point_disk = mesh_cyl(PT_RADIUS, 0.12, _point_pos + Vector3(0, 0.07, 0), Color(0.5, 0.7, 1.0))
	label3d("CAPTURE", _point_pos + Vector3(0, 0.4, 0), 32, Color(0.75, 0.85, 1.0))
	player = Node3D.new()
	add_child(player)
	mesh_cyl(0.7, 1.6, Vector3(0, 0.8, 0), Color(0.3, 0.7, 1.0), player)
	mesh_sphere(0.36, Vector3(0, 1.78, 0), Color(0.7, 0.9, 1.0), player)
	mesh_box(Vector3(0.34, 0.3, 1.1), Vector3(0, 1.05, 0.6), Color(0.85, 0.95, 1.0), player)
	_shield = mesh_sphere(1.15, Vector3(0, 1.0, 0), Color(0.4, 0.8, 1.0, 0.35), player)
	var sm := _shield.material_override as StandardMaterial3D
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shield.visible = false
	_build_hud()
	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.4, 0.35)},
		{"id": "dash", "label": "DASH", "col": Color(0.4, 0.8, 1.0)},
		{"id": "ult", "label": "ULT", "col": Color(0.4, 0.4, 0.45)},
	], false, true)
	tc.action.connect(func(id):
		if id == "dash": _try_dash()
		elif id == "ult": _try_ult())
	_new_round(true)


# ---------- round lifecycle ----------

func _new_round(first: bool) -> void:
	if _root:
		_root.queue_free()
	_root = Node3D.new()
	add_child(_root)
	_enemies.clear()
	_bullets.clear()
	_capture = 0.0
	_ult = 0.0
	_hp = _max_hp
	_iframe = 1.2
	player.position = Vector3(0, 0, ARENA - 3.0)
	_pyaw = PI
	for i in clampi(2 + _round, 3, 5):
		_spawn_enemy()
	Juice.sfx("tick", 0.9)
	var msg := "ROUND %d — HOLD THE POINT" % _round if not first else "CAPTURE THE POINT"
	Juice.popup(msg, Vector2(360, 380), Color(0.6, 0.9, 1.0), 44)


func _spawn_enemy() -> void:
	var a := randf() * TAU
	var pos := Vector3(cos(a) * 15.0, 0.0, sin(a) * 15.0)
	var node := Node3D.new()
	node.position = pos
	_root.add_child(node)
	mesh_cyl(0.7, 1.6, Vector3(0, 0.8, 0), Color(0.9, 0.35, 0.3), node)
	mesh_sphere(0.35, Vector3(0, 1.75, 0), Color(1.0, 0.6, 0.55), node)
	var bar := label3d("", Vector3(0, 2.4, 0), 24, Color(1.0, 0.55, 0.55), node)
	var hp := 3.0 + _round * 0.8
	_enemies.append({"node": node, "hp": hp, "max": hp, "fcd": randf() * 1.4, "bar": bar})


# ---------- per-frame ----------

func _process(delta: float) -> void:
	if not running:
		return
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_dash_cd = maxf(0.0, _dash_cd - delta)
	_iframe = maxf(0.0, _iframe - delta)
	_overdrive = maxf(0.0, _overdrive - delta)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_combat += delta
	if _combat > REGEN_DELAY and _hp < _max_hp:
		_hp = minf(_max_hp, _hp + REGEN_RATE * delta)
	_move_player(delta)
	var want_fire: bool = (tc and tc.held("fire")) or Input.is_key_pressed(KEY_J)
	if want_fire and _fire_cd <= 0.0:
		_fire()
	_update_enemies(delta)
	_update_bullets(delta)
	_update_capture(delta)
	_update_fx(delta)
	_shield.visible = _iframe > 0.0
	_update_cam()
	_update_hud()
	if _pending == "die":
		_do_die()
	elif _pending == "win":
		_do_win()
	_pending = ""


func _move_player(delta: float) -> void:
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	if mv.length() > 0.05:
		player.position += mv * PSPEED * delta
		_pyaw = atan2(mv.x, mv.z)
	player.position.x = clampf(player.position.x, -ARENA + 1.0, ARENA - 1.0)
	player.position.z = clampf(player.position.z, -ARENA + 1.0, ARENA - 1.0)
	player.rotation.y = _pyaw


func _forward() -> Vector3:
	return Vector3(sin(_pyaw), 0, cos(_pyaw))


func _fire() -> void:
	_fire_cd = OD_FIRE_CD if _overdrive > 0.0 else FIRE_CD
	var origin := player.position + Vector3(0, 1.0, 0)
	var fwd := _forward()
	var aim := fwd
	var best := -1
	var bestd := AIM_RANGE
	for i in _enemies.size():
		var node: Node3D = _enemies[i]["node"]
		var to := node.position - player.position
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or d > AIM_RANGE:
			continue
		if fwd.dot(to / d) < AIM_DOT:
			continue
		if d < bestd:
			bestd = d
			best = i
	if best >= 0:
		var rn: Node3D = _enemies[best]["node"]
		aim = ((rn.position + Vector3(0, 1.0, 0)) - origin).normalized()
		_pyaw = atan2(aim.x, aim.z)
	_spawn_bullet(origin, aim * PBULLET, false)
	Juice.sfx("tick", 1.4 if _overdrive > 0.0 else 1.2)
	Juice.haptic(10)


func _try_dash() -> void:
	if _dash_cd > 0.0:
		return
	_dash_cd = DASH_CD
	_iframe = DASH_IFRAME
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	var dir := mv.normalized() if mv.length() > 0.1 else _forward()
	for k in 5:
		var t := float(k) / 4.0
		_spawn_fx(player.position + dir * DASH_DIST * t + Vector3(0, 0.9, 0), Color(0.4, 0.8, 1.0), 0.5, 0.05, 0.35)
	player.position += dir * DASH_DIST
	player.position.x = clampf(player.position.x, -ARENA + 1.0, ARENA - 1.0)
	player.position.z = clampf(player.position.z, -ARENA + 1.0, ARENA - 1.0)
	Juice.sfx("chime", 1.6)
	Juice.flash(Color(0.4, 0.8, 1.0), 0.12)
	Juice.haptic(18)


func _try_ult() -> void:
	if not _ult_ready:
		Juice.sfx("tick", 0.5)
		return
	_ult = 0.0
	_ult_ready = false
	_overdrive = OVERDRIVE_TIME
	_spawn_fx(player.position + Vector3(0, 1.0, 0), Color(1.0, 0.8, 0.3), 1.0, NOVA_RADIUS, 0.5)
	for e in _enemies.duplicate():
		var node: Node3D = e["node"]
		if node.position.distance_to(player.position) < NOVA_RADIUS:
			var away := (node.position - player.position)
			away.y = 0.0
			node.position += away.normalized() * 3.0
			_hit_enemy(e, NOVA_DMG)
	_shake = 0.6
	Juice.sfx("boom")
	Juice.sfx("coin", 1.3)
	Juice.flash(Color(1.0, 0.85, 0.4), 0.3)
	Juice.hitstop(80)
	Juice.popup("NOVA — OVERDRIVE!", Vector2(360, 430), Color(1.0, 0.85, 0.3), 50)


func _spawn_bullet(pos: Vector3, vel: Vector3, hostile: bool) -> void:
	var col := Color(1.0, 0.4, 0.4) if hostile else Color(1.0, 0.9, 0.4)
	var node := mesh_sphere(0.16, pos, col, _root)
	_bullets.append({"node": node, "vel": vel, "life": 1.6, "hostile": hostile})


func _update_bullets(delta: float) -> void:
	for b in _bullets.duplicate():
		b["life"] -= delta
		var node: MeshInstance3D = b["node"]
		node.position += b["vel"] * delta
		var p := node.position
		var dead: bool = b["life"] <= 0.0 or absf(p.x) > ARENA or absf(p.z) > ARENA
		if not dead and b["hostile"]:
			if _iframe <= 0.0 and p.distance_to(player.position + Vector3(0, 1.0, 0)) < 1.0:
				_hurt_player(9.0)
				dead = true
		elif not dead:
			for e in _enemies.duplicate():
				var en: Node3D = e["node"]
				if p.distance_to(en.position + Vector3(0, 1.0, 0)) < 1.1:
					_hit_enemy(e, 1.0)
					dead = true
					break
		if dead:
			node.queue_free()
			_bullets.erase(b)


func _update_enemies(delta: float) -> void:
	for e in _enemies.duplicate():
		var node: Node3D = e["node"]
		var to_pt := _point_pos - node.position
		to_pt.y = 0.0
		var dpt := to_pt.length()
		if dpt > PT_RADIUS * 0.55:
			node.position += (to_pt / dpt) * ESPEED * delta
			node.rotation.y = atan2(to_pt.x, to_pt.z)
		var dpl := node.position.distance_to(player.position)
		e["fcd"] -= delta
		if dpl < AIM_RANGE and e["fcd"] <= 0.0:
			e["fcd"] = randf_range(1.0, 1.8)
			var origin := node.position + Vector3(0, 1.0, 0)
			var aim := ((player.position + Vector3(0, 1.0, 0)) - origin).normalized()
			_spawn_bullet(origin, aim * EBULLET, true)
		var bar: Label3D = e["bar"]
		var frac := clampf(e["hp"] / e["max"], 0.0, 1.0)
		bar.text = "=".repeat(int(ceil(frac * 4.0))) if frac < 1.0 else ""


func _hit_enemy(e: Dictionary, dmg: float) -> void:
	e["hp"] -= dmg
	_ult = minf(1.0, _ult + ULT_PER_DMG * dmg)
	_shake = maxf(_shake, 0.1)
	Juice.sfx("thud", 1.3)
	if e["hp"] <= 0.0:
		var node: Node3D = e["node"]
		var bounty := 50 + _round * 15
		add_points(bounty)
		_ult = minf(1.0, _ult + 0.06)
		Juice.sfx("chime", 1.3)
		Juice.popup("+%d KILL" % bounty, _to_screen(node.position + Vector3(0, 1.9, 0)), Color(1.0, 0.7, 0.5), 34)
		node.queue_free()
		_enemies.erase(e)
		_spawn_enemy()


func _hurt_player(dmg: float) -> void:
	if _pending != "":
		return
	_hp -= dmg
	_combat = 0.0
	_shake = 0.4
	Juice.sfx("thud", 0.9)
	Juice.flash(Color(1.0, 0.3, 0.3), 0.12)
	Juice.haptic(20)
	if _hp <= 0.0:
		_hp = 0.0
		_pending = "die"


# ---------- objective ----------

func _update_capture(delta: float) -> void:
	var pl_on := Vector2(player.position.x - _point_pos.x, player.position.z - _point_pos.z).length() < PT_RADIUS
	var en_on := 0
	for e in _enemies:
		var en: Node3D = e["node"]
		if Vector2(en.position.x - _point_pos.x, en.position.z - _point_pos.z).length() < PT_RADIUS:
			en_on += 1
	_contested = pl_on and en_on > 0
	if pl_on and en_on == 0:
		_capture = minf(1.0, _capture + delta / CAP_TIME)
		_ult = minf(1.0, _ult + ULT_PER_SEC * delta)
	elif en_on > 0 and not pl_on:
		_capture = maxf(0.0, _capture - delta / (CAP_TIME * 1.6))
	var col := Color(0.5, 0.7, 1.0)
	if _contested:
		col = Color(1.0, 0.8, 0.3)
	elif pl_on:
		col = Color(0.4, 1.0, 0.6)
	elif en_on > 0:
		col = Color(1.0, 0.4, 0.4)
	(_point_disk.material_override as StandardMaterial3D).albedo_color = col.lerp(Color.WHITE, _capture * 0.4)
	if _ult >= 1.0 and not _ult_ready:
		_ult_ready = true
		Juice.sfx("coin", 1.1)
		Juice.popup("ULT READY", Vector2(360, 500), Color(1.0, 0.85, 0.3), 40)
	if _capture >= 1.0 and _pending == "":
		_pending = "win"


func _do_win() -> void:
	var bonus := 300 + _round * 120
	add_points(bonus)
	Juice.sfx("coin")
	Juice.sfx("chime", 1.6)
	Juice.flash(Color(0.4, 1.0, 0.6), 0.3)
	Juice.hitstop(80)
	Juice.popup("POINT CAPTURED +%d" % bonus, Vector2(360, 420), Color(0.5, 1.0, 0.7), 50)
	_round += 1
	_new_round(false)


func _do_die() -> void:
	_lives -= 1
	Juice.sfx("boom")
	Juice.flash(Color(1.0, 0.35, 0.3), 0.35)
	Juice.hitstop(90)
	_shake = 0.7
	if _lives <= 0:
		Juice.popup("ELIMINATED", Vector2(360, 520), Color(1.0, 0.4, 0.4), 54)
		end_demo()
		return
	Juice.popup("DOWN — %d LEFT" % _lives, Vector2(360, 520), Color(1.0, 0.5, 0.4), 48)
	_capture = maxf(0.0, _capture - 0.4)
	_hp = _max_hp
	_iframe = 1.6
	player.position = Vector3(0, 0, ARENA - 3.0)
	_pyaw = PI


# ---------- fx / camera ----------

func _spawn_fx(pos: Vector3, col: Color, r0: float, r1: float, dur: float) -> void:
	var node := mesh_sphere(1.0, pos, Color(col.r, col.g, col.b, 0.4), _root)
	var m := node.material_override as StandardMaterial3D
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	node.scale = Vector3.ONE * r0
	_fx.append({"node": node, "t": 0.0, "dur": dur, "r0": r0, "r1": r1})


func _update_fx(delta: float) -> void:
	for f in _fx.duplicate():
		f["t"] += delta
		var frac := clampf(f["t"] / f["dur"], 0.0, 1.0)
		var node: MeshInstance3D = f["node"]
		node.scale = Vector3.ONE * lerpf(f["r0"], f["r1"], frac)
		var m := node.material_override as StandardMaterial3D
		var c := m.albedo_color
		c.a = 0.4 * (1.0 - frac)
		m.albedo_color = c
		if frac >= 1.0:
			node.queue_free()
			_fx.erase(f)


func _update_cam() -> void:
	var sh := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)) * _shake * 0.6
	cam.position = player.position + Vector3(0, 15, 12) + sh
	cam.look_at(player.position + Vector3(0, 1.0, 0), Vector3.UP)


func _to_screen(w: Vector3) -> Vector2:
	if cam:
		return cam.unproject_position(w)
	return Vector2(360, 640)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			_try_dash()
		elif event.keycode == KEY_L:
			_try_ult()


# ---------- HUD ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	_bar(Vector2(30, 150), Vector2(300, 26), Color(0, 0, 0, 0.5))
	_hp_fill = _bar(Vector2(33, 153), Vector2(294, 20), Color(0.4, 0.9, 0.5))
	_lbl_score = _mk_lbl(Vector2(30, 186), 34, Color(1.0, 0.9, 0.5))
	_lbl_round = _mk_lbl(Vector2(30, 232), 24, Color(1, 1, 1, 0.7))
	_lbl_cap = _mk_lbl(Vector2(210, 150), 28, Color(0.7, 0.9, 1.0))
	_lbl_cap.size = Vector2(300, 34)
	_lbl_cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bar(Vector2(210, 186), Vector2(300, 26), Color(0, 0, 0, 0.5))
	_cap_fill = _bar(Vector2(213, 189), Vector2(0, 20), Color(0.4, 1.0, 0.6))
	_lbl_dash = _mk_lbl(Vector2(30, 300), 24, Color(0.5, 0.85, 1.0))
	_bar(Vector2(30, 332), Vector2(200, 16), Color(0, 0, 0, 0.5))
	_dash_fill = _bar(Vector2(32, 334), Vector2(196, 12), Color(0.4, 0.8, 1.0))
	_lbl_ult = _mk_lbl(Vector2(30, 366), 24, Color(1.0, 0.85, 0.4))
	_bar(Vector2(30, 398), Vector2(200, 16), Color(0, 0, 0, 0.5))
	_ult_fill = _bar(Vector2(32, 400), Vector2(0, 12), Color(1.0, 0.82, 0.3))
	_lbl_msg = _mk_lbl(Vector2(0, 600), 44, Color(1.0, 0.85, 0.3))
	_lbl_msg.size = Vector2(720, 60)
	_lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _bar(pos: Vector2, sz: Vector2, col: Color) -> ColorRect:
	var r := ColorRect.new()
	r.position = pos
	r.size = sz
	r.color = col
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(r)
	return r


func _mk_lbl(pos: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(l)
	return l


func _update_hud() -> void:
	_hp_fill.size.x = 294.0 * clampf(_hp / _max_hp, 0.0, 1.0)
	_hp_fill.color = Color(0.9, 0.4, 0.35) if _hp < _max_hp * 0.35 else Color(0.4, 0.9, 0.5)
	_lbl_score.text = "SCORE  %d" % score
	_lbl_round.text = "ROUND %d    LIVES %d" % [_round, _lives]
	_lbl_cap.text = "CONTESTED" if _contested else "CAPTURE  %d%%" % int(_capture * 100.0)
	_lbl_cap.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3) if _contested else Color(0.7, 0.9, 1.0))
	_cap_fill.size.x = 294.0 * clampf(_capture, 0.0, 1.0)
	_cap_fill.color = Color(1.0, 0.8, 0.3) if _contested else Color(0.4, 1.0, 0.6)
	var dready := _dash_cd <= 0.0
	_lbl_dash.text = "DASH  READY" if dready else "DASH  %.1fs" % _dash_cd
	_dash_fill.size.x = 196.0 * (1.0 - clampf(_dash_cd / DASH_CD, 0.0, 1.0))
	_lbl_ult.text = "ULT  READY" if _ult_ready else "ULT  %d%%" % int(_ult * 100.0)
	_ult_fill.size.x = 196.0 * clampf(_ult, 0.0, 1.0)
	_set_ult_btn(_ult_ready)
	if _overdrive > 0.0:
		_lbl_msg.text = "OVERDRIVE"
		_lbl_msg.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_lbl_msg.visible = true
	elif _contested:
		_lbl_msg.text = "CONTESTED — CLEAR THE POINT"
		_lbl_msg.add_theme_color_override("font_color", Color(1.0, 0.7, 0.3))
		_lbl_msg.visible = true
	else:
		_lbl_msg.visible = false


func _set_ult_btn(ready: bool) -> void:
	if not tc:
		return
	for d in tc._defs:
		if d["id"] == "ult":
			var want: Color = Color(1.0, 0.82, 0.25) if ready else Color(0.4, 0.4, 0.45)
			if d["col"] != want:
				d["col"] = want
				tc.queue_redraw()
			return
