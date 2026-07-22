extends MechDemo3D
## FPS x TOWER DEFENSE (Orcs Must Die): defend the RIFT at the end of a winding
## lane. BUILD phase — spend RESOURCES to PLACE traps (SPIKE floor / ARROW wall /
## TAR pit) where your crosshair meets the ground. WAVE phase — traps auto-attack
## AND you shoot the orcs yourself; kills refund resource. Leaks drain the rift.
## Stick = move, drag = look, FIRE (J), PLACE (B), CYCLE trap (Q/Tab), WAVE (Space).

const ARENA_X := 18.0
const ARENA_Z := 22.0
const EYE := 1.7
const MOVE_SPD := 7.0
const LOOK_SENS := 0.005
const FIRE_CD := 0.16
const GUN_DMG := 4.0
const GUN_RANGE := 40.0
const AIM_DOT := 0.965
const ENEMY_SPD := 2.4
const BUILD_TIME := 16.0
const RIFT_MAX := 12
const SPAWN_INT := 0.9
const PLACE_RANGE := 26.0
const NEAR_PATH := 6.0
const TRAP_GAP := 1.7
const REFUND_GUN := 6
const REFUND_TRAP := 3
const SPIKE_DPS := 7.0
const SPIKE_R := 2.0
const TAR_R := 2.4
const TAR_SLOW := 0.4
const ARROW_R := 9.0
const ARROW_DMG := 6.0
const ARROW_CD := 1.1

var tc: TouchControls

var _ppos := Vector3(7, 0, 17)
var _yaw := PI
var _pitch := -0.25
var _fire_cd := 0.0
var _shake := 0.0

var _path: Array = []           # Array[Vector3] waypoints, spawn..rift
var _enemies: Array = []        # {node,hp,max,wp,bar}
var _traps: Array = []          # {node,type,pos,cd}
var _fx: Array = []             # {node,vel,life}
var _defs: Array = []           # trap definitions

var _phase := "build"
var _wave_num := 1
var _waves_cleared := 0
var _res := 140
var _rift := RIFT_MAX
var _build_time := BUILD_TIME
var _spawn_left := 0
var _spawn_timer := 0.0
var _trap_sel := 0

var _aim_ground := Vector3.ZERO
var _aim_hit := false
var _ghost: MeshInstance3D
var _rift_beam: MeshInstance3D

var _hud: Control
var _cross: Label
var _rift_fill: ColorRect
var _lbl_res: Label
var _lbl_trap: Label
var _lbl_wave: Label
var _lbl_phase: Label


func start() -> void:
	super.start()
	setup_world(Color(0.07, 0.08, 0.12), 0.7, Vector3(-60, -35, 0))
	make_camera(_ppos + Vector3(0, EYE, 0), _ppos + Vector3(0, EYE, -1), 72.0)
	_defs = [
		{"name": "SPIKE", "cost": 20, "col": Color(0.85, 0.75, 0.3)},
		{"name": "ARROW", "cost": 35, "col": Color(0.6, 0.8, 1.0)},
		{"name": "TAR", "cost": 15, "col": Color(0.35, 0.25, 0.45)},
	]
	_build_arena()
	_build_ghost()
	_build_hud()
	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.4, 0.35)},
		{"id": "place", "label": "PLACE", "col": Color(0.4, 0.8, 0.5)},
		{"id": "cycle", "label": "TYPE", "col": Color(0.5, 0.7, 0.95)},
		{"id": "wave", "label": "WAVE", "col": Color(0.9, 0.75, 0.35)},
	], true, true)
	tc.action.connect(func(id):
		if id == "place": _try_place()
		elif id == "cycle": _cycle_trap()
		elif id == "wave": _start_wave(true))
	tc.look.connect(_on_look)
	Juice.popup("BUILD — DEFEND THE RIFT", Vector2(360, 360), Color(0.6, 0.9, 1.0), 44)


func _build_arena() -> void:
	mesh_box(Vector3(ARENA_X * 2.0, 0.2, ARENA_Z * 2.0), Vector3(0, -0.1, 0), Color(0.13, 0.15, 0.19))
	_path = [
		Vector3(-12, 0, -18), Vector3(-12, 0, -2), Vector3(2, 0, -2),
		Vector3(2, 0, 10), Vector3(12, 0, 10),
	]
	for i in _path.size() - 1:
		var a: Vector3 = _path[i]
		var b: Vector3 = _path[i + 1]
		var mid := (a + b) * 0.5
		var sx := absf(b.x - a.x) + 3.0
		var sz := absf(b.z - a.z) + 3.0
		mesh_box(Vector3(sx, 0.06, sz), mid + Vector3(0, 0.03, 0), Color(0.28, 0.3, 0.36))
	# spawn portal
	mesh_box(Vector3(3.4, 0.2, 3.4), _path[0] + Vector3(0, 0.05, 0), Color(0.5, 0.2, 0.25))
	label3d("SPAWN", _path[0] + Vector3(0, 2.4, 0), 36, Color(1.0, 0.5, 0.5))
	# rift
	var r: Vector3 = _path[_path.size() - 1]
	mesh_cyl(1.8, 0.25, r + Vector3(0, 0.12, 0), Color(0.35, 0.7, 1.0))
	_rift_beam = mesh_box(Vector3(0.9, 5.5, 0.9), r + Vector3(0, 2.75, 0), Color(0.4, 0.85, 1.0))
	label3d("RIFT", r + Vector3(0, 6.0, 0), 44, Color(0.6, 0.9, 1.0))


func _build_ghost() -> void:
	_ghost = mesh_box(Vector3(2.0, 0.1, 2.0), Vector3.ZERO, Color(0.3, 1.0, 0.4, 0.4))
	var gm := _ghost.material_override as StandardMaterial3D
	gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost.visible = false
	mesh_box(Vector3(0.12, 1.4, 0.12), Vector3(0, 0.75, 0), Color(1, 1, 1, 0.5), _ghost)


func _on_look(rel: Vector2) -> void:
	_yaw += rel.x * LOOK_SENS
	_pitch = clampf(_pitch - rel.y * LOOK_SENS, -1.2, 0.35)


# ---------- per frame ----------

func _process(delta: float) -> void:
	if not running:
		return
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_move_player(delta)
	_update_cam()
	_update_aim()
	if _fire_cd <= 0.0 and ((tc and tc.held("fire")) or Input.is_key_pressed(KEY_J)):
		_fire()
	if _phase == "build":
		_build_time -= delta
		if _build_time <= 0.0:
			_start_wave(false)
	elif _spawn_left > 0:
		_spawn_timer -= delta
		if _spawn_timer <= 0.0:
			_spawn_enemy()
			_spawn_left -= 1
			_spawn_timer = SPAWN_INT
	_update_enemies(delta)
	_update_traps(delta)
	_update_fx(delta)
	if _phase == "wave" and _spawn_left <= 0 and _enemies.is_empty():
		_end_wave()
	_update_hud()


func _move_player(delta: float) -> void:
	var fwd := -tc.move.y + key_axis_y()
	var strafe := tc.move.x + key_axis_x()
	var mv := _flat_fwd() * fwd + _flat_right() * strafe
	mv.y = 0.0
	if mv.length() > 1.0:
		mv = mv.normalized()
	_ppos += mv * MOVE_SPD * delta
	_ppos.x = clampf(_ppos.x, -ARENA_X + 1.0, ARENA_X - 1.0)
	_ppos.z = clampf(_ppos.z, -ARENA_Z + 1.0, ARENA_Z - 1.0)


func _flat_fwd() -> Vector3:
	return Vector3(sin(_yaw), 0, cos(_yaw))


func _flat_right() -> Vector3:
	return Vector3(cos(_yaw), 0, -sin(_yaw))


func _look_dir() -> Vector3:
	return Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch))


func _update_cam() -> void:
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.3
	cam.position = _ppos + Vector3(0, EYE, 0) + sh
	cam.look_at(cam.position + _look_dir(), Vector3.UP)


func _update_aim() -> void:
	_aim_hit = false
	var dir := _look_dir()
	if dir.y < -0.02:
		var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(cam.position, dir)
		if hit != null:
			_aim_ground = hit
			_aim_hit = true
	if _aim_hit:
		_ghost.visible = true
		_ghost.position = _aim_ground + Vector3(0, 0.06, 0)
		var ok := _placeable(_aim_ground) and _res >= int(_defs[_trap_sel]["cost"])
		(_ghost.material_override as StandardMaterial3D).albedo_color = \
			Color(0.3, 1.0, 0.4, 0.45) if ok else Color(1.0, 0.35, 0.3, 0.45)
	else:
		_ghost.visible = false


# ---------- shooting ----------

func _fire() -> void:
	_fire_cd = FIRE_CD
	var origin := cam.position
	var fwd := _look_dir()
	var best: Variant = null
	var best_dot := AIM_DOT
	var hit_pos := origin + fwd * 6.0
	for e in _enemies:
		var c: Vector3 = (e["node"] as Node3D).position + Vector3(0, 1.0, 0)
		var to := c - origin
		var d := to.length()
		if d > GUN_RANGE or d < 0.1:
			continue
		var dot := fwd.dot(to / d)
		if dot > best_dot:
			best_dot = dot
			best = e
			hit_pos = c
	Juice.sfx("tick", 1.5)
	Juice.haptic(10)
	_spark(origin + fwd * 1.4, Color(1.0, 0.9, 0.4), 0.6)
	if best != null:
		best["hp"] -= GUN_DMG
		_spark(hit_pos, Color(1.0, 0.6, 0.3), 1.0)
		_shake = maxf(_shake, 0.08)
		if best["hp"] <= 0.0:
			_kill_enemy(best, true)


# ---------- traps ----------

func _cycle_trap() -> void:
	_trap_sel = (_trap_sel + 1) % _defs.size()
	Juice.sfx("tick", 1.0)
	Juice.haptic(8)


func _try_place() -> void:
	if not _aim_hit:
		Juice.sfx("tick", 0.6)
		return
	var d: Dictionary = _defs[_trap_sel]
	if _res < int(d["cost"]):
		Juice.sfx("thud", 0.7)
		Juice.popup("NEED $%d" % int(d["cost"]), Vector2(360, 720), Color(1.0, 0.5, 0.4), 34)
		return
	if not _placeable(_aim_ground):
		Juice.sfx("thud", 0.6)
		Juice.popup("BAD SPOT", Vector2(360, 720), Color(1.0, 0.5, 0.4), 34)
		return
	_res -= int(d["cost"])
	_spawn_trap(_trap_sel, _aim_ground)
	Juice.sfx("chime", 0.9)
	Juice.flash(d["col"], 0.1)
	Juice.haptic(16)
	Juice.popup("-$%d %s" % [int(d["cost"]), d["name"]], _to_screen(_aim_ground + Vector3(0, 1.4, 0)), d["col"], 32)


func _placeable(g: Vector3) -> bool:
	if absf(g.x) > ARENA_X - 0.5 or absf(g.z) > ARENA_Z - 0.5:
		return false
	if _dist_to_path(g) > NEAR_PATH:
		return false
	if Vector2(g.x - _ppos.x, g.z - _ppos.z).length() > PLACE_RANGE:
		return false
	if g.distance_to(_path[_path.size() - 1]) < 2.2:
		return false
	for tr in _traps:
		var tp: Vector3 = tr["pos"]
		if Vector2(g.x - tp.x, g.z - tp.z).length() < TRAP_GAP:
			return false
	return true


func _spawn_trap(type: int, pos: Vector3) -> void:
	var d: Dictionary = _defs[type]
	var node := Node3D.new()
	node.position = pos
	add_child(node)
	if type == 0:      # SPIKE floor
		mesh_box(Vector3(2.0, 0.1, 2.0), Vector3(0, 0.05, 0), Color(0.35, 0.3, 0.2), node)
		for sx in [-0.5, 0.5]:
			for sz in [-0.5, 0.5]:
				mesh_box(Vector3(0.16, 0.7, 0.16), Vector3(sx, 0.35, sz), d["col"], node)
	elif type == 1:    # ARROW wall
		mesh_box(Vector3(1.8, 1.5, 0.5), Vector3(0, 0.75, 0), Color(0.3, 0.35, 0.42), node)
		mesh_box(Vector3(1.4, 0.35, 0.7), Vector3(0, 0.9, 0), d["col"], node)
	else:              # TAR pit
		mesh_cyl(TAR_R, 0.08, Vector3(0, 0.05, 0), Color(0.12, 0.09, 0.16), node)
	_traps.append({"node": node, "type": type, "pos": pos, "cd": randf() * ARROW_CD})


func _update_traps(delta: float) -> void:
	for tr in _traps:
		if int(tr["type"]) != 1:
			continue
		tr["cd"] -= delta
		if tr["cd"] > 0.0:
			continue
		var tp: Vector3 = tr["pos"]
		var target: Variant = null
		var bd := ARROW_R
		for e in _enemies:
			var d := (e["node"] as Node3D).position.distance_to(tp)
			if d < bd:
				bd = d
				target = e
		if target != null:
			tr["cd"] = ARROW_CD
			var ep: Vector3 = (target["node"] as Node3D).position + Vector3(0, 1.0, 0)
			_spark(tp + Vector3(0, 1.0, 0), Color(0.7, 0.9, 1.0), 0.5)
			_shoot_fx(tp + Vector3(0, 1.0, 0), ep)
			target["hp"] -= ARROW_DMG
			Juice.sfx("tick", 0.9)
			if target["hp"] <= 0.0:
				_kill_enemy(target, false)


# ---------- enemies ----------

func _spawn_enemy() -> void:
	var node := Node3D.new()
	node.position = _path[0]
	add_child(node)
	var tint := Color(0.4, 0.7, 0.35).lerp(Color(0.85, 0.3, 0.3), minf(1.0, _wave_num / 12.0))
	mesh_cyl(0.45, 1.3, Vector3(0, 0.65, 0), tint, node)
	mesh_sphere(0.3, Vector3(0, 1.5, 0), tint.darkened(0.25), node)
	var bar := label3d("", Vector3(0, 2.1, 0), 22, Color(1.0, 0.5, 0.5), node)
	var hp := 6.0 + _wave_num * 3.0
	_enemies.append({"node": node, "hp": hp, "max": hp, "wp": 1, "bar": bar})


func _update_enemies(delta: float) -> void:
	for e in _enemies.duplicate():
		var node: Node3D = e["node"]
		var slow := 1.0
		for tr in _traps:
			var tp: Vector3 = tr["pos"]
			var fd := Vector2(node.position.x - tp.x, node.position.z - tp.z).length()
			var ty := int(tr["type"])
			if ty == 2 and fd < TAR_R:
				slow = minf(slow, TAR_SLOW)
			elif ty == 0 and fd < SPIKE_R:
				e["hp"] -= SPIKE_DPS * delta
		if e["hp"] <= 0.0:
			_kill_enemy(e, false)
			continue
		var tgt: Vector3 = _path[e["wp"]]
		var to := tgt - node.position
		to.y = 0.0
		var d := to.length()
		if d < 0.35:
			e["wp"] = int(e["wp"]) + 1
			if int(e["wp"]) >= _path.size():
				_leak(e)
				continue
		else:
			node.position += (to / d) * ENEMY_SPD * slow * delta
			node.rotation.y = atan2(to.x, to.z)
		var frac := clampf(e["hp"] / e["max"], 0.0, 1.0)
		(e["bar"] as Label3D).text = "=".repeat(int(ceil(frac * 5.0))) if frac < 1.0 else "====="


func _kill_enemy(e: Dictionary, by_gun: bool) -> void:
	if not _enemies.has(e):
		return
	var refund := REFUND_GUN if by_gun else REFUND_TRAP
	_res += refund
	var node: Node3D = e["node"]
	Juice.sfx("chime", 1.2)
	Juice.popup("+$%d" % refund, _to_screen(node.position + Vector3(0, 1.8, 0)), Color(0.6, 1.0, 0.6), 30)
	_spark(node.position + Vector3(0, 1.0, 0), Color(0.5, 1.0, 0.5), 1.2)
	node.queue_free()
	_enemies.erase(e)


func _leak(e: Dictionary) -> void:
	_rift -= 1
	_shake = 0.5
	Juice.sfx("boom", 1.1)
	Juice.flash(Color(1.0, 0.3, 0.35), 0.2)
	Juice.haptic(24)
	(e["node"] as Node3D).queue_free()
	_enemies.erase(e)
	if _rift <= 0:
		_game_over()


func _game_over() -> void:
	Juice.sfx("boom")
	Juice.flash(Color(1.0, 0.3, 0.3), 0.4)
	Juice.hitstop(90)
	Juice.popup("RIFT DESTROYED", Vector2(360, 520), Color(1.0, 0.4, 0.4), 54)
	end_demo()


# ---------- waves ----------

func _start_wave(_manual: bool) -> void:
	if _phase != "build":
		return
	_phase = "wave"
	_spawn_left = 4 + _wave_num * 2
	_spawn_timer = 0.0
	Juice.sfx("boom", 0.7)
	Juice.popup("WAVE %d INCOMING" % _wave_num, Vector2(360, 400), Color(1.0, 0.6, 0.4), 46)


func _end_wave() -> void:
	_waves_cleared += 1
	add_points(1)
	var income := 50 + _wave_num * 6
	_res += income
	_wave_num += 1
	_phase = "build"
	_build_time = BUILD_TIME
	Juice.sfx("coin")
	Juice.sfx("chime", 1.4)
	Juice.flash(Color(0.4, 0.9, 1.0), 0.2)
	Juice.hitstop(60)
	Juice.popup("WAVE CLEARED  +$%d" % income, Vector2(360, 420), Color(0.5, 1.0, 0.7), 46)


# ---------- fx ----------

func _spark(pos: Vector3, col: Color, scale: float) -> void:
	var node := mesh_sphere(0.18 * scale, pos, col)
	_fx.append({"node": node, "vel": Vector3.ZERO, "life": 0.28})


func _shoot_fx(a: Vector3, b: Vector3) -> void:
	var node := mesh_sphere(0.12, a, Color(0.8, 0.95, 1.0))
	_fx.append({"node": node, "vel": (b - a) / 0.12, "life": 0.12})


func _update_fx(delta: float) -> void:
	for f in _fx.duplicate():
		f["life"] -= delta
		var node: MeshInstance3D = f["node"]
		node.position += f["vel"] * delta
		node.scale *= (1.0 - delta * 3.0)
		if f["life"] <= 0.0:
			node.queue_free()
			_fx.erase(f)


# ---------- geometry ----------

func _pt_seg(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ap := Vector2(p.x - a.x, p.z - a.z)
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var t := 0.0
	var denom := ab.dot(ab)
	if denom > 0.0001:
		t = clampf(ap.dot(ab) / denom, 0.0, 1.0)
	var proj := Vector2(a.x, a.z) + ab * t
	return Vector2(p.x, p.z).distance_to(proj)


func _dist_to_path(p: Vector3) -> float:
	var m := 9999.0
	for i in _path.size() - 1:
		m = minf(m, _pt_seg(p, _path[i], _path[i + 1]))
	return m


func _to_screen(w: Vector3) -> Vector2:
	if cam and not cam.is_position_behind(w):
		return cam.unproject_position(w)
	return Vector2(360, 640)


# ---------- HUD ----------

func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	_hud = Control.new()
	_hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_hud)
	_cross = _mk_lbl(Vector2(340, 616), 46, Color(1, 1, 1, 0.75))
	_cross.text = "+"
	_cross.size = Vector2(40, 40)
	_cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_wave = _mk_lbl(Vector2(30, 116), 30, Color(1, 1, 1, 0.85))
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.5)
	bg.position = Vector2(30, 156)
	bg.size = Vector2(300, 26)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(bg)
	_rift_fill = ColorRect.new()
	_rift_fill.color = Color(0.4, 0.85, 1.0)
	_rift_fill.position = Vector2(33, 159)
	_rift_fill.size = Vector2(294, 20)
	_rift_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_rift_fill)
	_lbl_res = _mk_lbl(Vector2(30, 190), 40, Color(1.0, 0.85, 0.4))
	_lbl_trap = _mk_lbl(Vector2(30, 240), 28, Color(0.7, 0.9, 1.0))
	_lbl_phase = _mk_lbl(Vector2(0, 300), 40, Color(1.0, 0.7, 0.4))
	_lbl_phase.size = Vector2(720, 52)
	_lbl_phase.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _mk_lbl(pos: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(l)
	return l


func _update_hud() -> void:
	_rift_fill.size.x = 294.0 * clampf(float(_rift) / float(RIFT_MAX), 0.0, 1.0)
	_rift_fill.color = Color(0.9, 0.4, 0.35) if _rift <= 4 else Color(0.4, 0.85, 1.0)
	if _rift_beam:
		(_rift_beam.material_override as StandardMaterial3D).albedo_color = _rift_fill.color
	_lbl_wave.text = "RIFT %d/%d      WAVE %d" % [_rift, RIFT_MAX, _wave_num]
	_lbl_res.text = "$%d" % _res
	var d: Dictionary = _defs[_trap_sel]
	_lbl_trap.text = "TRAP: %s ($%d)   cleared %d" % [d["name"], int(d["cost"]), _waves_cleared]
	if _phase == "build":
		_lbl_phase.add_theme_color_override("font_color", Color(0.5, 0.9, 1.0))
		_lbl_phase.text = "BUILD — %ds  (WAVE to start)" % int(ceil(_build_time))
	else:
		_lbl_phase.add_theme_color_override("font_color", Color(1.0, 0.6, 0.4))
		_lbl_phase.text = "WAVE %d — %d left" % [_wave_num, _spawn_left + _enemies.size()]


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_B:
				_try_place()
			KEY_Q, KEY_TAB:
				_cycle_trap()
			KEY_SPACE, KEY_ENTER:
				_start_wave(true)
