extends MechDemo3D
## CO-OP HORDE SURVIVAL (Left 4 Dead / Killing Floor), first-person. Endless
## escalating WAVES swarm from all sides with a countdown LULL between them;
## SPECIALS (charger rush / spitter acid pools / tank soak) break the rhythm, and a
## MAG+RESERVE ammo economy with manual RELOAD + walk-over ammo/health drops is the
## squeeze — run dry mid-wave and you die. Touch: stick move, drag-right look, FIRE
## (hold), RELOAD. Desktop: WASD move, drag look region, J fire, R reload.

const ARENA := 19.0
const EYE := 1.6
const MOVE_SPEED := 6.5
const LOOK_SENS := 0.006
const FIRE_CD := 0.12
const WEAPON_DMG := 3.5
const MAG_SIZE := 30
const RELOAD_TIME := 1.7
const MAX_HP := 120.0
const REGEN := 12.0
const LULL_TIME := 6.0
const POOL_R := 2.2

var tc: TouchControls
var player: Node3D
var _root: Node3D
var _gun: Node3D

var _pyaw := 0.0
var _ppitch := -0.05
var _hp := 120.0
var _shake := 0.0
var _recoil := 0.0

var _mag := 30
var _reserve := 120
var _reloading := false
var _reload_t := 0.0
var _fire_cd := 0.0
var _empty_cd := 0.0

var _wave := 0
var _kills := 0
var _state := "lull"
var _lull_t := 3.0
var _spawn_cd := 0.0
var _pool_snd := 0.0
var _pending := ""

var _queue: Array = []
var _enemies: Array = []
var _spits: Array = []
var _pools: Array = []
var _drops: Array = []

var _hud: Control
var _hp_fill: ColorRect
var _lbl_ammo: Label
var _lbl_wave: Label
var _lbl_kills: Label
var _lbl_center: Label
var _rl_bg: ColorRect
var _rl_fill: ColorRect


func start() -> void:
	super.start()
	setup_world(Color(0.07, 0.08, 0.11), 0.7, Vector3(-60, -35, 0))
	make_camera(Vector3(0, EYE, 0), Vector3(0, EYE, 1), 72.0)
	mesh_box(Vector3(ARENA * 2.4, 0.4, ARENA * 2.4), Vector3(0, -0.2, 0), Color(0.13, 0.14, 0.17))
	for i in 22:
		var a := float(i) * TAU / 22.0
		mesh_box(Vector3(1.4, 2.6, 1.4), Vector3(cos(a) * (ARENA + 0.6), 1.3, sin(a) * (ARENA + 0.6)), Color(0.2, 0.21, 0.26))
	for i in 5:
		var a2 := float(i) * TAU / 5.0 + 0.3
		mesh_box(Vector3(2.0, 1.6, 2.0), Vector3(cos(a2) * 7.5, 0.8, sin(a2) * 7.5), Color(0.24, 0.25, 0.3))
	player = Node3D.new()
	add_child(player)
	_gun = Node3D.new()
	cam.add_child(_gun)
	mesh_box(Vector3(0.18, 0.18, 0.9), Vector3(0, 0, -0.1), Color(0.15, 0.16, 0.2), _gun)
	mesh_box(Vector3(0.12, 0.3, 0.14), Vector3(0, -0.2, 0.25), Color(0.2, 0.22, 0.28), _gun)
	_gun.position = Vector3(0.42, -0.36, -1.0)
	_root = Node3D.new()
	add_child(_root)
	_build_hud()
	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.4, 0.35)},
		{"id": "reload", "label": "RELOAD", "col": Color(0.4, 0.6, 0.9)},
	], true, true)
	tc.look.connect(_on_look)
	tc.action.connect(func(id):
		if id == "reload":
			_reload())
	_begin_lull(3.0)


func _on_look(rel: Vector2) -> void:
	_pyaw -= rel.x * LOOK_SENS
	_ppitch = clampf(_ppitch - rel.y * LOOK_SENS, -1.25, 1.25)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_R:
			_reload()


# ---------- per-frame ----------

func _process(delta: float) -> void:
	if not running:
		return
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_empty_cd = maxf(0.0, _empty_cd - delta)
	if _reloading:
		_reload_t -= delta
		if _reload_t <= 0.0:
			var take := mini(MAG_SIZE - _mag, _reserve)
			_mag += take
			_reserve -= take
			_reloading = false
			Juice.sfx("chime", 1.1)
	_move_player(delta)
	_update_cam(delta)
	if (tc and tc.held("fire")) or Input.is_key_pressed(KEY_J):
		_fire()
	_update_waves(delta)
	_update_enemies(delta)
	_update_spits(delta)
	_update_pools(delta)
	_update_drops(delta)
	_update_hud()
	if _pending == "die":
		_pending = ""
		_do_die()


func _move_player(delta: float) -> void:
	var fwd := Vector3(sin(_pyaw), 0, cos(_pyaw))
	var right := Vector3(cos(_pyaw), 0, -sin(_pyaw))
	var f := -tc.move.y + key_axis_y()
	var s := tc.move.x + key_axis_x()
	var mv := fwd * f + right * s
	if mv.length() > 1.0:
		mv = mv.normalized()
	player.position += mv * MOVE_SPEED * delta
	var rr := Vector2(player.position.x, player.position.z).length()
	if rr > ARENA - 0.8:
		player.position.x *= (ARENA - 0.8) / rr
		player.position.z *= (ARENA - 0.8) / rr


func _update_cam(delta: float) -> void:
	_recoil = maxf(0.0, _recoil - delta * 2.5)
	_shake = maxf(0.0, _shake - delta * 3.0)
	var eye := player.position + Vector3(0, EYE, 0)
	var fwd := Vector3(sin(_pyaw) * cos(_ppitch), sin(_ppitch), cos(_pyaw) * cos(_ppitch))
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.12
	cam.position = eye + sh
	cam.look_at(eye + fwd, Vector3.UP)
	if _gun:
		_gun.position = Vector3(0.42, -0.36, -1.0 + _recoil)
		_gun.rotation = Vector3(_recoil * 0.6, 0, 0)


# ---------- shooting / ammo ----------

func _fire() -> void:
	if _reloading or _fire_cd > 0.0:
		return
	if _mag <= 0:
		if _empty_cd <= 0.0:
			_empty_cd = 0.4
			Juice.sfx("tick", 0.35)
		return
	_fire_cd = FIRE_CD
	_mag -= 1
	_recoil = 0.25
	_shake = maxf(_shake, 0.12)
	Juice.sfx("tick", 1.5)
	Juice.flash(Color(1, 0.85, 0.4), 0.06)
	Juice.haptic(10)
	var eye := cam.global_position
	var aim := (-cam.global_transform.basis.z).normalized()
	var best: Variant = null
	var bestd := 999.0
	for e in _enemies:
		var n: Node3D = e["node"]
		var c := n.position + Vector3(0, e["ch"], 0)
		var to := c - eye
		var along := to.dot(aim)
		if along <= 0.6 or along > 60.0:
			continue
		var perp := (eye + aim * along).distance_to(c)
		if perp <= e["r"] and along < bestd:
			bestd = along
			best = e
	if best != null:
		_hit_enemy(best, WEAPON_DMG)


func _reload() -> void:
	if _reloading or _mag >= MAG_SIZE or _reserve <= 0:
		return
	_reloading = true
	_reload_t = RELOAD_TIME
	Juice.sfx("tick", 0.6)
	Juice.haptic(15)


func _hit_enemy(e: Dictionary, dmg: float) -> void:
	e["hp"] -= dmg
	Juice.sfx("thud", 1.3)
	Juice.haptic(6)
	if e["hp"] <= 0.0:
		_kill_enemy(e)
	else:
		var frac := clampf(e["hp"] / e["max"], 0.0, 1.0)
		(e["bar"] as Label3D).text = "=".repeat(int(ceil(frac * 5.0)))


func _kill_enemy(e: Dictionary) -> void:
	var t: String = e["type"]
	var pts := 10
	if t == "spitter":
		pts = 25
	elif t == "charger":
		pts = 30
	elif t == "tank":
		pts = 120
	add_points(pts)
	_kills += 1
	var n: Node3D = e["node"]
	var sp := _to_screen(n.position + Vector3(0, e["ch"] + 0.6, 0))
	Juice.sfx("chime", 1.2 if t == "walker" else 1.5)
	Juice.popup("+%d" % pts, sp, Color(1, 0.85, 0.4), 30 if t == "walker" else 42)
	if t == "tank":
		Juice.sfx("coin")
		Juice.hitstop(60)
		Juice.flash(Color(1, 0.6, 0.3), 0.2)
		_spawn_drop("ammo", n.position)
		_spawn_drop("med", n.position + Vector3(1.4, 0, 0))
	elif t == "charger" or t == "spitter":
		if randf() < 0.55:
			_spawn_drop("ammo" if randf() < 0.6 else "med", n.position)
	n.queue_free()
	_enemies.erase(e)


# ---------- wave lifecycle ----------

func _update_waves(delta: float) -> void:
	if _state == "lull":
		_lull_t -= delta
		if _hp < MAX_HP:
			_hp = minf(MAX_HP, _hp + REGEN * delta)
		if _lull_t <= 0.0:
			_begin_wave()
	else:
		_spawn_cd -= delta
		if _queue.size() > 0 and _spawn_cd <= 0.0 and _enemies.size() < 26:
			_spawn_cd = maxf(0.22, 0.75 - _wave * 0.03)
			_spawn_enemy(str(_queue.pop_back()))
		if _queue.is_empty() and _enemies.is_empty():
			_clear_wave()


func _begin_lull(t: float) -> void:
	_state = "lull"
	_lull_t = t
	_spawn_drop("ammo", _rand_ground())
	if _hp < MAX_HP * 0.6:
		_spawn_drop("med", _rand_ground())


func _begin_wave() -> void:
	_wave += 1
	_state = "wave"
	_build_queue()
	_spawn_cd = 0.4
	Juice.sfx("boom", 1.4)
	Juice.flash(Color(0.8, 0.2, 0.2), 0.15)
	Juice.hitstop(50)
	Juice.popup("WAVE %d" % _wave, Vector2(360, 430), Color(1, 0.5, 0.4), 60)


func _clear_wave() -> void:
	var bonus := 40 + _wave * 20
	add_points(bonus)
	Juice.sfx("coin")
	Juice.sfx("chime", 1.5)
	Juice.flash(Color(0.3, 0.9, 0.5), 0.2)
	Juice.popup("WAVE %d CLEARED  +%d" % [_wave, bonus], Vector2(360, 470), Color(0.5, 1, 0.7), 46)
	_begin_lull(LULL_TIME)


func _build_queue() -> void:
	_queue.clear()
	for i in (6 + _wave * 3):
		_queue.append("walker")
	if _wave >= 2:
		for i in (1 + int(_wave / 3)):
			_queue.append("charger")
	if _wave >= 3:
		for i in (1 + int((_wave - 3) / 3)):
			_queue.append("spitter")
	if _wave >= 4 and _wave % 2 == 0:
		_queue.append("tank")
	if _wave >= 6:
		_queue.append("tank")
	_queue.shuffle()


# ---------- enemies ----------

func _spawn_enemy(type: String) -> void:
	var ang := randf() * TAU
	var pos := Vector3(cos(ang) * (ARENA - 0.5), 0, sin(ang) * (ARENA - 0.5))
	var node := Node3D.new()
	node.position = pos
	_root.add_child(node)
	var e := {"node": node, "type": type, "atk": 0.0, "cs": "seek", "ct": 0.0, "cdir": Vector3.ZERO, "fcd": randf_range(1.0, 2.5)}
	if type == "walker":
		mesh_cyl(0.45, 1.5, Vector3(0, 0.75, 0), Color(0.35, 0.6, 0.3), node)
		mesh_sphere(0.32, Vector3(0, 1.7, 0), Color(0.7, 0.75, 0.55), node)
		e["hp"] = 3.0 + _wave * 0.8
		e["spd"] = 2.4 + _wave * 0.12
		e["dmg"] = 8.0
		e["r"] = 0.9
		e["ch"] = 1.0
	elif type == "charger":
		mesh_cyl(0.6, 1.7, Vector3(0, 0.85, 0), Color(0.9, 0.45, 0.2), node)
		mesh_box(Vector3(1.3, 0.7, 0.9), Vector3(0, 1.2, 0.4), Color(1.0, 0.6, 0.3), node)
		e["hp"] = 8.0 + _wave * 1.2
		e["spd"] = 2.6
		e["dmg"] = 26.0
		e["r"] = 1.0
		e["ch"] = 1.1
	elif type == "spitter":
		mesh_cyl(0.5, 1.3, Vector3(0, 0.65, 0), Color(0.55, 0.75, 0.2), node)
		mesh_sphere(0.5, Vector3(0, 1.4, 0), Color(0.85, 1.0, 0.3), node)
		e["hp"] = 5.0 + _wave * 0.7
		e["spd"] = 1.8
		e["dmg"] = 0.0
		e["r"] = 0.95
		e["ch"] = 1.0
	else:
		mesh_cyl(1.0, 2.6, Vector3(0, 1.3, 0), Color(0.5, 0.2, 0.22), node)
		mesh_sphere(0.7, Vector3(0, 2.7, 0), Color(0.7, 0.35, 0.35), node)
		e["hp"] = 45.0 + _wave * 7.0
		e["spd"] = 1.5
		e["dmg"] = 34.0
		e["r"] = 1.5
		e["ch"] = 1.6
	e["max"] = e["hp"]
	e["bar"] = label3d("", Vector3(0, e["ch"] + 1.5, 0), 22, Color(1, 0.5, 0.5), node)
	_enemies.append(e)
	if type != "walker":
		Juice.sfx("thud", 0.7)


func _update_enemies(delta: float) -> void:
	for e in _enemies:
		var n: Node3D = e["node"]
		var t: String = e["type"]
		var to := player.position - n.position
		to.y = 0.0
		var d := to.length()
		var dir := to / d if d > 0.001 else Vector3.ZERO
		if t == "charger":
			_update_charger(e, n, dir, d, delta)
		elif t == "spitter":
			if d < 9.0:
				n.position -= dir * e["spd"] * delta
			elif d > 15.0:
				n.position += dir * e["spd"] * delta
			if d > 0.1:
				n.rotation.y = atan2(dir.x, dir.z)
			e["fcd"] -= delta
			if e["fcd"] <= 0.0 and d < 22.0:
				e["fcd"] = randf_range(2.2, 3.6)
				_spit(n.position + Vector3(0, 1.4, 0))
		else:
			if d > 0.4:
				n.position += dir * e["spd"] * delta
				n.rotation.y = atan2(dir.x, dir.z)
			_contact(e, d, delta)
		if t != "charger":
			var rr := Vector2(n.position.x, n.position.z).length()
			if rr > ARENA + 0.5:
				n.position.x *= (ARENA + 0.5) / rr
				n.position.z *= (ARENA + 0.5) / rr
		var frac := clampf(e["hp"] / e["max"], 0.0, 1.0)
		(e["bar"] as Label3D).text = "=".repeat(int(ceil(frac * 5.0))) if frac < 1.0 else ""


func _update_charger(e: Dictionary, n: Node3D, dir: Vector3, d: float, delta: float) -> void:
	match e["cs"]:
		"seek":
			if d < 13.0 and d > 0.3:
				e["cs"] = "wind"
				e["ct"] = 0.7
				e["cdir"] = dir
				n.rotation.y = atan2(dir.x, dir.z)
				Juice.sfx("tick", 1.7)
				Juice.popup("CHARGER!", _to_screen(n.position + Vector3(0, 2.4, 0)), Color(1, 0.6, 0.2), 30)
			else:
				n.position += dir * e["spd"] * delta
				if d > 0.1:
					n.rotation.y = atan2(dir.x, dir.z)
		"wind":
			e["ct"] -= delta
			n.position += Vector3(randf_range(-0.03, 0.03), 0, randf_range(-0.03, 0.03))
			if e["ct"] <= 0.0:
				e["cs"] = "dash"
				e["ct"] = 1.1
		"dash":
			e["ct"] -= delta
			var cd: Vector3 = e["cdir"]
			n.position += cd * 15.0 * delta
			var hd := Vector2(player.position.x - n.position.x, player.position.z - n.position.z).length()
			if hd < e["r"] + 0.6:
				_damage(e["dmg"], true)
				_shake = 0.7
				e["cs"] = "rest"
				e["ct"] = 1.2
			var rr := Vector2(n.position.x, n.position.z).length()
			if e["ct"] <= 0.0 or rr > ARENA + 1.0:
				e["cs"] = "rest"
				e["ct"] = 1.0
		"rest":
			e["ct"] -= delta
			if e["ct"] <= 0.0:
				e["cs"] = "seek"


func _contact(e: Dictionary, d: float, delta: float) -> void:
	e["atk"] -= delta
	if d < e["r"] + 0.8 and e["atk"] <= 0.0:
		e["atk"] = 0.85
		_damage(e["dmg"], true)
		if e["type"] == "tank":
			_shake = 0.6


# ---------- spitter projectiles + acid pools ----------

func _spit(from: Vector3) -> void:
	var flat := Vector3(player.position.x - from.x, 0, player.position.z - from.z)
	var dist := flat.length()
	var t := clampf(dist / 12.0, 0.6, 1.6)
	var g := 14.0
	var vel := flat / t
	vel.y = 0.5 * g * t - from.y / t
	var node := mesh_sphere(0.28, from, Color(0.6, 0.9, 0.2), _root)
	_spits.append({"node": node, "vel": vel, "life": t + 0.3, "g": g})
	Juice.sfx("tick", 0.9)


func _update_spits(delta: float) -> void:
	for s in _spits.duplicate():
		var v: Vector3 = s["vel"]
		v.y -= s["g"] * delta
		s["vel"] = v
		var n: MeshInstance3D = s["node"]
		n.position += v * delta
		s["life"] -= delta
		if n.position.y <= 0.15 or s["life"] <= 0.0:
			_spawn_pool(Vector3(n.position.x, 0.07, n.position.z))
			n.queue_free()
			_spits.erase(s)


func _spawn_pool(pos: Vector3) -> void:
	var n := mesh_cyl(POOL_R, 0.12, pos, Color(0.5, 0.85, 0.15), _root)
	_pools.append({"node": n, "life": 5.0})
	Juice.sfx("thud", 0.6)


func _update_pools(delta: float) -> void:
	_pool_snd = maxf(0.0, _pool_snd - delta)
	for p in _pools.duplicate():
		p["life"] -= delta
		var n: MeshInstance3D = p["node"]
		var hd := Vector2(player.position.x - n.position.x, player.position.z - n.position.z).length()
		if hd < POOL_R:
			_damage(11.0 * delta, false)
			if _pool_snd <= 0.0:
				_pool_snd = 0.4
				Juice.sfx("tick", 0.5)
				Juice.flash(Color(0.6, 0.9, 0.2), 0.08)
				Juice.haptic(10)
		if p["life"] <= 0.0:
			n.queue_free()
			_pools.erase(p)


# ---------- drops ----------

func _spawn_drop(kind: String, pos: Vector3) -> void:
	var col := Color(0.8, 0.72, 0.25) if kind == "ammo" else Color(0.9, 0.3, 0.35)
	var n := mesh_box(Vector3(0.6, 0.6, 0.6), Vector3(pos.x, 0.5, pos.z), col, _root)
	label3d("AMMO" if kind == "ammo" else "+HP", Vector3(0, 0.9, 0), 22, col, n)
	_drops.append({"node": n, "kind": kind})


func _update_drops(_delta: float) -> void:
	var bob := sin(Time.get_ticks_msec() * 0.004) * 0.12
	for dr in _drops.duplicate():
		var n: MeshInstance3D = dr["node"]
		n.rotation.y += 0.03
		n.position.y = 0.5 + bob
		var hd := Vector2(player.position.x - n.position.x, player.position.z - n.position.z).length()
		if hd < 1.4:
			if dr["kind"] == "ammo":
				_reserve += 30
				Juice.sfx("coin", 1.1)
				Juice.popup("+30 AMMO", _to_screen(n.position + Vector3(0, 1, 0)), Color(1, 0.9, 0.4), 34)
			else:
				_hp = minf(MAX_HP, _hp + 45.0)
				Juice.sfx("chime", 1.4)
				Juice.popup("+45 HP", _to_screen(n.position + Vector3(0, 1, 0)), Color(0.5, 1, 0.6), 34)
			Juice.haptic(15)
			n.queue_free()
			_drops.erase(dr)


# ---------- damage / death ----------

func _damage(amt: float, heavy: bool) -> void:
	if _pending != "":
		return
	_hp -= amt
	if heavy:
		_shake = maxf(_shake, 0.5)
		Juice.sfx("thud", 0.9)
		Juice.flash(Color(1, 0.3, 0.3), 0.14)
		Juice.haptic(20)
	if _hp <= 0.0:
		_hp = 0.0
		_pending = "die"


func _do_die() -> void:
	Juice.sfx("boom")
	Juice.flash(Color(1, 0.3, 0.3), 0.4)
	Juice.hitstop(90)
	Juice.popup("OVERRUN — WAVE %d, %d KILLS" % [_wave, _kills], Vector2(360, 540), Color(1, 0.4, 0.4), 42)
	end_demo()


func _rand_ground() -> Vector3:
	var a := randf() * TAU
	var rr := randf_range(3.0, ARENA - 3.0)
	return Vector3(cos(a) * rr, 0, sin(a) * rr)


func _to_screen(w: Vector3) -> Vector2:
	if cam:
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
	var hp_bg := ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0.5)
	hp_bg.position = Vector2(30, 150)
	hp_bg.size = Vector2(306, 30)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.4, 0.9, 0.5)
	_hp_fill.position = Vector2(33, 153)
	_hp_fill.size = Vector2(300, 24)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hp_fill)
	_lbl_wave = _mk_lbl(Vector2(30, 190), 32, Color(1, 0.55, 0.4))
	_lbl_kills = _mk_lbl(Vector2(30, 232), 24, Color(0.8, 0.85, 1.0))
	_lbl_ammo = _mk_lbl(Vector2(420, 1120), 54, Color.WHITE)
	_lbl_ammo.size = Vector2(280, 60)
	_lbl_ammo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_lbl_center = _mk_lbl(Vector2(0, 250), 40, Color(1, 0.85, 0.3))
	_lbl_center.size = Vector2(720, 60)
	_lbl_center.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# crosshair
	var ch_h := ColorRect.new()
	ch_h.color = Color(1, 1, 1, 0.7)
	ch_h.position = Vector2(348, 639)
	ch_h.size = Vector2(24, 2)
	ch_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(ch_h)
	var ch_v := ColorRect.new()
	ch_v.color = Color(1, 1, 1, 0.7)
	ch_v.position = Vector2(359, 628)
	ch_v.size = Vector2(2, 24)
	ch_v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(ch_v)
	# reload progress
	_rl_bg = ColorRect.new()
	_rl_bg.color = Color(0, 0, 0, 0.55)
	_rl_bg.position = Vector2(260, 720)
	_rl_bg.size = Vector2(200, 20)
	_rl_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_rl_bg)
	_rl_fill = ColorRect.new()
	_rl_fill.color = Color(0.4, 0.7, 1.0)
	_rl_fill.position = Vector2(260, 720)
	_rl_fill.size = Vector2(0, 20)
	_rl_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_rl_fill)


func _mk_lbl(pos: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(l)
	return l


func _update_hud() -> void:
	_hp_fill.size.x = 300.0 * clampf(_hp / MAX_HP, 0.0, 1.0)
	_hp_fill.color = Color(0.9, 0.35, 0.35) if _hp < MAX_HP * 0.35 else Color(0.4, 0.9, 0.5)
	_lbl_wave.text = "WAVE %d" % _wave if _wave > 0 else "PREP"
	_lbl_kills.text = "KILLS %d    SCORE %d" % [_kills, score]
	if _reloading:
		_lbl_ammo.text = "RELOADING"
		_lbl_ammo.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	elif _mag <= 0:
		_lbl_ammo.text = "RELOAD!" if _reserve > 0 else "NO AMMO"
		_lbl_ammo.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
	else:
		_lbl_ammo.text = "%d / %d" % [_mag, _reserve]
		_lbl_ammo.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if _mag <= 6 else Color.WHITE)
	if _state == "lull":
		_lbl_center.visible = true
		_lbl_center.text = "WAVE %d INCOMING in %d" % [_wave + 1, int(ceil(_lull_t))]
	else:
		_lbl_center.visible = false
	_rl_bg.visible = _reloading
	_rl_fill.visible = _reloading
	if _reloading:
		_rl_fill.size.x = 200.0 * clampf(1.0 - _reload_t / RELOAD_TIME, 0.0, 1.0)
