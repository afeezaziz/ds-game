extends MechDemo3D
## EXTRACTION SHOOTER (Tarkov / Hunt): insert empty, scavenge LOOT crates for
## value, but a raid's haul only BANKS if you reach the EXTRACT ring and hold it —
## die first and you lose everything carried. Rival AI scavengers race you for loot
## and shoot. Stick = move, FIRE / SPACE auto-aims the nearest rival in a forward
## cone, EXTRACT auto-fills while you stand in the ring. Score = total banked value.

const ARENA := 22.0
const PSPEED := 9.5
const FIRE_CD := 0.2
const PBULLET := 36.0
const RBULLET := 20.0
const EX_RADIUS := 3.2
const EX_TIME := 2.6
const AIM_DOT := 0.3

var tc: TouchControls
var player: Node3D
var _root: Node3D

var _pyaw := 0.0
var _hp := 100.0
var _max_hp := 100.0
var _carried := 0
var _raid := 1
var _runs := 3
var _fire_cd := 0.0
var _shake := 0.0
var _pending := ""

var _loot: Array = []       # {node,value,col}
var _rivals: Array = []     # {node,hp,max,fcd,bar}
var _bullets: Array = []    # {node,vel,life,hostile}

var _extract_pos := Vector3.ZERO
var _extract_fill := 0.0
var _extracting := false

var _hud: Control
var _hp_fill: ColorRect
var _lbl_carry: Label
var _lbl_bank: Label
var _lbl_raid: Label
var _lbl_dist: Label
var _lbl_msg: Label
var _ex_bg: ColorRect
var _ex_fill: ColorRect
var _ex_lbl: Label


func start() -> void:
	super.start()
	setup_world(Color(0.09, 0.10, 0.14), 0.75, Vector3(-58, -42, 0))
	make_camera(Vector3(0, 16, 11), Vector3.ZERO, 60.0)
	mesh_box(Vector3(ARENA * 2.0, 0.4, ARENA * 2.0), Vector3(0, -0.2, 0), Color(0.15, 0.17, 0.21))
	for i in 6:
		var a := float(i) * TAU / 6.0
		mesh_box(Vector3(2.4, 1.6, 2.4), Vector3(cos(a) * 9.0, 0.8, sin(a) * 9.0), Color(0.22, 0.24, 0.3))
	player = Node3D.new()
	add_child(player)
	mesh_cyl(0.7, 1.6, Vector3(0, 0.8, 0), Color(0.3, 0.8, 0.95), player)
	mesh_box(Vector3(0.35, 0.3, 1.1), Vector3(0, 1.0, 0.6), Color(0.9, 0.97, 1.0), player)
	_build_hud()
	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.4, 0.35)},
	], false, true)
	_new_raid()


# ---------- raid lifecycle ----------

func _new_raid() -> void:
	if _root:
		_root.queue_free()
	_root = Node3D.new()
	add_child(_root)
	_loot.clear()
	_rivals.clear()
	_bullets.clear()
	_carried = 0
	_hp = _max_hp
	_extract_fill = 0.0
	player.position = Vector3(0, 0, ARENA - 3.0)
	_pyaw = PI
	_extract_pos = Vector3(0, 0, -(ARENA - 4.0))
	mesh_cyl(EX_RADIUS, 0.15, _extract_pos + Vector3(0, 0.06, 0), Color(0.3, 0.9, 0.5), _root)
	mesh_box(Vector3(0.3, 4.0, 0.3), _extract_pos + Vector3(0, 2.0, 0), Color(0.4, 1.0, 0.6), _root)
	label3d("EXTRACT", _extract_pos + Vector3(0, 2.6, 0), 40, Color(0.55, 1.0, 0.7), _root)
	for i in (6 + _raid):
		_spawn_loot()
	for i in clampi(3 + _raid, 4, 8):
		_spawn_rival()
	Juice.sfx("tick", 0.8)
	Juice.popup("RAID %d — INSERT" % _raid, Vector2(360, 360), Color(0.6, 0.9, 1.0), 46)


func _spawn_loot() -> void:
	var roll := randf()
	var val := 40
	var col := Color(0.78, 0.78, 0.74)
	if roll > 0.85:
		val = 240
		col = Color(0.72, 0.42, 0.95)
	elif roll > 0.55:
		val = 110
		col = Color(0.35, 0.6, 1.0)
	val += _raid * 10
	var lim := ARENA - 6.0
	var pos := Vector3(randf_range(-lim, lim), 0.5, randf_range(-lim, lim))
	var node := mesh_box(Vector3(1.0, 1.0, 1.0), pos, col, _root)
	label3d("$%d" % val, Vector3(0, 1.3, 0), 26, col, node)
	_loot.append({"node": node, "value": val, "col": col})


func _spawn_rival() -> void:
	var pos := Vector3(randf_range(-16.0, 16.0), 0.0, randf_range(-16.0, 10.0))
	var node := Node3D.new()
	node.position = pos
	_root.add_child(node)
	mesh_cyl(0.7, 1.6, Vector3(0, 0.8, 0), Color(0.9, 0.35, 0.3), node)
	mesh_sphere(0.35, Vector3(0, 1.75, 0), Color(1.0, 0.6, 0.5), node)
	var bar := label3d("", Vector3(0, 2.4, 0), 24, Color(1.0, 0.5, 0.5), node)
	var hp := 2.0 + _raid * 0.5
	_rivals.append({"node": node, "hp": hp, "max": hp, "fcd": randf() * 1.5, "bar": bar})


# ---------- per-frame ----------

func _process(delta: float) -> void:
	if not running:
		return
	_fire_cd = maxf(0.0, _fire_cd - delta)
	_shake = maxf(0.0, _shake - delta * 3.0)
	_move_player(delta)
	if _fire_cd <= 0.0 and ((tc and tc.held("fire")) or Input.is_key_pressed(KEY_SPACE)):
		_fire()
	_update_rivals(delta)
	_update_bullets(delta)
	_update_loot()
	_update_extract(delta)
	_update_cam()
	_update_hud()
	if _pending == "die":
		_do_die()
	elif _pending == "bank":
		_do_bank()
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
	_fire_cd = FIRE_CD
	var origin := player.position + Vector3(0, 1.0, 0)
	var fwd := _forward()
	var aim := fwd
	var best := -1
	var bestd := 26.0
	for i in _rivals.size():
		var node: Node3D = _rivals[i]["node"]
		var to := node.position - player.position
		to.y = 0.0
		var d := to.length()
		if d < 0.01 or d > 26.0:
			continue
		if fwd.dot(to / d) < AIM_DOT:
			continue
		if d < bestd:
			bestd = d
			best = i
	if best >= 0:
		var rn: Node3D = _rivals[best]["node"]
		aim = ((rn.position + Vector3(0, 1.0, 0)) - origin).normalized()
	_spawn_bullet(origin, aim * PBULLET, false)
	Juice.sfx("tick", 1.4)
	Juice.haptic(12)


func _spawn_bullet(pos: Vector3, vel: Vector3, hostile: bool) -> void:
	var col := Color(1.0, 0.4, 0.4) if hostile else Color(1.0, 0.85, 0.4)
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
			if p.distance_to(player.position + Vector3(0, 1.0, 0)) < 1.0:
				_hurt_player(9.0)
				dead = true
		elif not dead:
			for r in _rivals.duplicate():
				var rn: Node3D = r["node"]
				if p.distance_to(rn.position + Vector3(0, 1.0, 0)) < 1.1:
					_hit_rival(r, 1.0)
					dead = true
					break
		if dead:
			node.queue_free()
			_bullets.erase(b)


func _update_rivals(delta: float) -> void:
	for r in _rivals.duplicate():
		var node: Node3D = r["node"]
		var tgt := player.position
		var seek_loot := false
		var ld := 9999.0
		var lc: Variant = null
		for c in _loot.duplicate():
			var cn: MeshInstance3D = c["node"]
			var d := node.position.distance_to(cn.position)
			if d < ld:
				ld = d
				lc = c
		var pd := node.position.distance_to(player.position)
		if lc != null and (ld < pd or pd > 15.0):
			tgt = (lc["node"] as MeshInstance3D).position
			seek_loot = true
		var dir := tgt - node.position
		dir.y = 0.0
		var dist := dir.length()
		if dist > 0.3:
			node.position += (dir / dist) * 5.5 * delta
			node.rotation.y = atan2(dir.x, dir.z)
		if seek_loot and lc != null and ld < 1.2:
			_rival_loot(lc)
		r["fcd"] -= delta
		if pd < 20.0 and r["fcd"] <= 0.0:
			r["fcd"] = randf_range(1.1, 2.0)
			var origin := node.position + Vector3(0, 1.0, 0)
			var aim := ((player.position + Vector3(0, 1.0, 0)) - origin).normalized()
			_spawn_bullet(origin, aim * RBULLET, true)
		var bar: Label3D = r["bar"]
		var frac := clampf(r["hp"] / r["max"], 0.0, 1.0)
		bar.text = "=".repeat(int(ceil(frac * 4.0))) if frac < 1.0 else ""


func _update_loot() -> void:
	for c in _loot.duplicate():
		var node: MeshInstance3D = c["node"]
		node.rotation.y += 0.03
		if player.position.distance_to(node.position) < 1.3:
			_carried += c["value"]
			Juice.sfx("coin" if c["value"] >= 150 else "chime", 1.1)
			Juice.flash(c["col"], 0.1)
			Juice.popup("+$%d" % c["value"], _to_screen(node.position + Vector3(0, 1.4, 0)), c["col"], 36)
			Juice.haptic(15)
			node.queue_free()
			_loot.erase(c)


func _rival_loot(c: Dictionary) -> void:
	var node: MeshInstance3D = c["node"]
	Juice.sfx("tick", 0.6)
	Juice.popup("RIVAL LOOTED", _to_screen(node.position + Vector3(0, 1.4, 0)), Color(1.0, 0.5, 0.5), 26)
	node.queue_free()
	_loot.erase(c)


func _hit_rival(r: Dictionary, dmg: float) -> void:
	r["hp"] -= dmg
	_shake = maxf(_shake, 0.12)
	Juice.sfx("thud", 1.3)
	if r["hp"] <= 0.0:
		var node: Node3D = r["node"]
		var bounty := 60 + _raid * 10
		_carried += bounty
		Juice.sfx("chime", 1.3)
		Juice.popup("+$%d KILL" % bounty, _to_screen(node.position + Vector3(0, 1.8, 0)), Color(1.0, 0.7, 0.5), 34)
		node.queue_free()
		_rivals.erase(r)


func _hurt_player(dmg: float) -> void:
	if _pending != "":
		return
	_hp -= dmg
	_shake = 0.4
	Juice.sfx("thud", 0.9)
	Juice.flash(Color(1.0, 0.3, 0.3), 0.12)
	Juice.haptic(20)
	if _hp <= 0.0:
		_hp = 0.0
		_pending = "die"


func _update_extract(delta: float) -> void:
	var pd := Vector2(player.position.x - _extract_pos.x, player.position.z - _extract_pos.z).length()
	_extracting = pd < EX_RADIUS
	if _extracting and _carried > 0:
		_extract_fill += delta / EX_TIME
		if _extract_fill >= 1.0 and _pending == "":
			_pending = "bank"
	elif not _extracting:
		_extract_fill = maxf(0.0, _extract_fill - delta * 0.5)


func _do_die() -> void:
	var lost := _carried
	Juice.sfx("boom")
	Juice.flash(Color(1.0, 0.35, 0.3), 0.35)
	Juice.hitstop(90)
	Juice.popup("DIED — LOST $%d" % lost, Vector2(360, 520), Color(1.0, 0.4, 0.4), 52)
	_runs -= 1
	if _runs <= 0:
		end_demo()
		return
	_new_raid()


func _do_bank() -> void:
	var haul := _carried
	add_points(haul)
	Juice.sfx("coin")
	Juice.sfx("chime", 1.5)
	Juice.flash(Color(0.4, 1.0, 0.6), 0.25)
	Juice.hitstop(70)
	Juice.popup("EXTRACTED +$%d" % haul, Vector2(360, 420), Color(0.5, 1.0, 0.7), 52)
	_raid += 1
	_new_raid()


func _update_cam() -> void:
	var sh := Vector3(randf_range(-1.0, 1.0), 0, randf_range(-1.0, 1.0)) * _shake * 0.6
	cam.position = player.position + Vector3(0, 16, 11) + sh
	cam.look_at(player.position, Vector3.UP)


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
	hp_bg.size = Vector2(300, 26)
	hp_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(hp_bg)
	_hp_fill = ColorRect.new()
	_hp_fill.color = Color(0.4, 0.9, 0.5)
	_hp_fill.position = Vector2(33, 153)
	_hp_fill.size = Vector2(294, 20)
	_hp_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_hp_fill)
	_lbl_carry = _mk_lbl(Vector2(30, 186), 40, Color(1.0, 0.85, 0.4))
	_lbl_bank = _mk_lbl(Vector2(30, 236), 26, Color(0.7, 0.9, 1.0))
	_lbl_raid = _mk_lbl(Vector2(30, 272), 24, Color(1, 1, 1, 0.6))
	_lbl_dist = _mk_lbl(Vector2(30, 304), 24, Color(0.6, 1.0, 0.7))
	_lbl_msg = _mk_lbl(Vector2(0, 600), 44, Color(1.0, 0.85, 0.3))
	_lbl_msg.size = Vector2(720, 60)
	_lbl_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ex_bg = ColorRect.new()
	_ex_bg.color = Color(0, 0, 0, 0.55)
	_ex_bg.position = Vector2(160, 700)
	_ex_bg.size = Vector2(400, 34)
	_ex_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_ex_bg)
	_ex_fill = ColorRect.new()
	_ex_fill.color = Color(0.4, 1.0, 0.6)
	_ex_fill.position = Vector2(164, 704)
	_ex_fill.size = Vector2(0, 26)
	_ex_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hud.add_child(_ex_fill)
	_ex_lbl = _mk_lbl(Vector2(160, 662), 28, Color(0.6, 1.0, 0.7))
	_ex_lbl.text = "EXTRACTING…"


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
	_lbl_carry.text = "CARRYING  $%d" % _carried
	_lbl_bank.text = "BANKED  $%d" % score
	_lbl_raid.text = "RAID %d    RUNS LEFT %d" % [_raid, _runs]
	var pd := Vector2(player.position.x - _extract_pos.x, player.position.z - _extract_pos.z).length()
	_lbl_dist.text = "EXTRACT  %dm" % int(pd)
	if _extracting and _carried > 0:
		_lbl_msg.add_theme_color_override("font_color", Color(0.5, 1.0, 0.7))
		_lbl_msg.text = "BANKING — HOLD THE ZONE"
		_lbl_msg.visible = true
	elif _carried >= 200:
		_lbl_msg.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		_lbl_msg.text = "CARRYING $%d — EXTRACT!" % _carried
		_lbl_msg.visible = true
	else:
		_lbl_msg.visible = false
	var show := _extracting and _carried > 0
	_ex_bg.visible = show
	_ex_fill.visible = show
	_ex_lbl.visible = show
	_ex_fill.size.x = 392.0 * clampf(_extract_fill, 0.0, 1.0)
