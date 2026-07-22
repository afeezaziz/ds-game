extends MechDemo3D
## BATTLE ROYALE — high-angle drop into a shrinking storm. Loot crates upgrade
## your gun (pistol->SMG->rifle) + armor/heals; 16 AI hunt each other and you,
## and the closing zone herds everyone together. Move: stick / WASD. FIRE (hold
## to auto-fire the nearest enemy in range), HEAL spends a charge. Last one wins.

const ARENA := 30.0
const PLR_SPD := 11.0
const BOT_SPD := 7.0
const T_NAME := ["PISTOL", "SMG", "RIFLE"]
const T_DMG := [14.0, 10.0, 26.0]
const T_RANGE := [10.0, 12.0, 18.0]
const T_CD := [0.55, 0.18, 0.5]

class Bot:
	var n: MeshInstance3D
	var pos := Vector3.ZERO
	var hp := 60.0
	var tier := 0
	var cd := 0.0
	var aim := Vector3.ZERO
	var alive := true

var tc: TouchControls
var hud: Label
var mech: MeshInstance3D
var zone_mesh: MeshInstance3D
var p_pos := Vector3.ZERO
var p_hp := 100.0
var p_arm := 0.0
var p_tier := 0
var p_cd := 0.0
var p_heals := 2
var kills := 0
var match_num := 1
var bots: Array = []
var loot: Array = []
var _fx: Array = []
var _shake := 0.0
var _stt := 0.0
var zone_c := Vector3.ZERO
var zc_t := Vector3.ZERO
var zone_r := 28.0
var zr_t := 28.0
var ph_time := 12.0
var storm_dps := 4.5

func start() -> void:
	super.start()
	setup_world(Color(0.14, 0.10, 0.20), 0.85)
	mesh_box(Vector3(ARENA * 2.0 + 8.0, 0.5, ARENA * 2.0 + 8.0), Vector3(0, -0.25, 0), Color(0.20, 0.14, 0.28))
	make_camera(Vector3(0, 26, 14), Vector3.ZERO, 55.0)
	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.45, 0.35)},
		{"id": "heal", "label": "HEAL", "col": Color(0.4, 0.8, 0.5)},
	])
	tc.action.connect(func(id):
		if id == "fire": _fire()
		elif id == "heal": _heal())
	mech = mesh_box(Vector3(1.2, 1.6, 1.2), Vector3(0, 0.8, 0), Color(0.35, 0.8, 1.0))
	mesh_box(Vector3(0.35, 0.35, 1.4), Vector3(0, 1.0, 0.9), Color(0.2, 0.5, 0.7), mech)
	zone_mesh = mesh_cyl(1.0, 0.1, Vector3(0, 0.05, 0), Color(0.4, 0.95, 0.75))
	var zm := zone_mesh.material_override as StandardMaterial3D
	zm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	zm.albedo_color = Color(0.4, 0.95, 0.75, 0.16)
	var cl := CanvasLayer.new()
	cl.layer = 2
	add_child(cl)
	hud = Label.new()
	hud.position = Vector2(26, 158)
	hud.add_theme_font_size_override("font_size", 30)
	hud.add_theme_color_override("font_color", Color(0.95, 0.97, 1.0))
	cl.add_child(hud)
	demo_over.connect(func(_s): cl.visible = false)
	_new_match()

func _new_match() -> void:
	for b in bots:
		if is_instance_valid(b.n): b.n.queue_free()
	for c in loot:
		if is_instance_valid(c["n"]): c["n"].queue_free()
	bots.clear()
	loot.clear()
	p_pos = Vector3.ZERO
	p_hp = 100.0
	p_arm = 0.0
	p_tier = 0
	p_heals = 2
	zone_c = Vector3.ZERO
	zc_t = Vector3.ZERO
	zone_r = ARENA * 0.95
	zr_t = zone_r
	ph_time = maxf(6.0, 12.0 - match_num * 0.8)
	storm_dps = 3.0 + match_num * 1.5
	for i in 16:
		var b := Bot.new()
		b.pos = _rand_point()
		b.aim = _rand_point()
		b.tier = 0 if randf() < 0.6 else (1 if randf() < 0.7 else 2)
		b.hp = 60.0 + b.tier * 20.0
		b.n = mesh_box(Vector3(1.1, 1.5, 1.1), b.pos + Vector3(0, 0.8, 0), Color(0.9, 0.35 + b.tier * 0.1, 0.3))
		bots.append(b)
	for i in 10:
		var pos := _rand_point()
		var n := mesh_box(Vector3(0.7, 0.7, 0.7), pos + Vector3(0, 0.4, 0), Color(1.0, 0.85, 0.2))
		loot.append({"n": n, "pos": pos, "taken": false})
	popup("MATCH %d — 17 ALIVE" % match_num, Color(0.8, 0.9, 1.0))

func _process(delta: float) -> void:
	if not running: return
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 0.05:
		p_pos = _clamp_arena(p_pos + mv.normalized() * PLR_SPD * delta)
	mech.position = p_pos + Vector3(0, 0.8, 0)
	p_cd = maxf(0.0, p_cd - delta)
	if tc.held("fire"): _fire()
	if _outside(p_pos):
		_hurt_player(storm_dps * delta)
		_stt += delta
		if _stt > 0.5:
			_stt = 0.0
			sfx("tick")
			flash(Color(0.7, 0.25, 0.55), 0.06)
	_update_bots(delta)
	_update_loot()
	_update_zone(delta)
	for i in range(_fx.size() - 1, -1, -1):
		_fx[i][1] -= delta
		if _fx[i][1] <= 0.0:
			_fx[i][0].queue_free()
			_fx.remove_at(i)
	cam.position = Vector3(p_pos.x, 26.0, p_pos.z + 14.0)
	cam.look_at(Vector3(p_pos.x, 0.0, p_pos.z), Vector3.UP)
	if _shake > 0.01:
		cam.position += Vector3(randf_range(-_shake, _shake), 0, randf_range(-_shake, _shake))
		_shake = maxf(0.0, _shake - delta * 22.0)
	var zs := "shrinks %ds" % int(ceil(ph_time)) if zr_t > 4.0 else "FINAL RING"
	hud.text = "HP %d   ARM %d\nWPN %s   HEAL %d\nALIVE %d   KILLS %d\nZONE %s" % [
		int(p_hp), int(p_arm), T_NAME[p_tier], p_heals, _alive_bots() + 1, kills, zs]
	if _alive_bots() == 0: _win()

func _update_bots(delta: float) -> void:
	for b in bots:
		if not b.alive: continue
		b.cd = maxf(0.0, b.cd - delta)
		if _outside(b.pos):
			_hurt_bot(b, storm_dps * 1.2 * delta, false)
			if not b.alive: continue
		var best := b.pos.distance_to(p_pos)
		var t_pos := p_pos
		var t_bot: Bot = null
		for o in bots:
			if o == b or not o.alive: continue
			var d := b.pos.distance_to(o.pos)
			if d < best:
				best = d
				t_pos = o.pos
				t_bot = o
		var goal := zone_c if _outside(b.pos) else (t_pos if best < 18.0 else b.aim)
		var dir := goal - b.pos
		dir.y = 0.0
		if dir.length() > 0.1: b.pos += dir.normalized() * BOT_SPD * delta
		b.pos = _clamp_arena(b.pos)
		if b.pos.distance_to(b.aim) < 1.5: b.aim = _rand_point()
		b.n.position = b.pos + Vector3(0, 0.8, 0)
		if best < T_RANGE[b.tier] and b.cd <= 0.0:
			b.cd = T_CD[b.tier] * 1.3
			_tracer(b.pos + Vector3(0, 0.9, 0), t_pos + Vector3(0, 0.9, 0), Color(1.0, 0.5, 0.3))
			if t_bot == null: _hurt_player(T_DMG[b.tier] * 0.6)
			else: _hurt_bot(t_bot, T_DMG[b.tier] * 0.6, false)

func _fire() -> void:
	if not running or p_cd > 0.0: return
	var best := T_RANGE[p_tier] + 0.01
	var tgt: Bot = null
	for b in bots:
		if not b.alive: continue
		var d := p_pos.distance_to(b.pos)
		if d < best:
			best = d
			tgt = b
	if tgt == null: return
	p_cd = T_CD[p_tier]
	_tracer(p_pos + Vector3(0, 0.9, 0), tgt.pos + Vector3(0, 0.9, 0), Color(0.4, 0.9, 1.0))
	sfx("thud")
	haptic(8)
	_hurt_bot(tgt, T_DMG[p_tier], true)

func _heal() -> void:
	if not running or p_heals <= 0 or p_hp >= 100.0: return
	p_heals -= 1
	p_hp = minf(100.0, p_hp + 35.0)
	sfx("chime")
	flash(Color(0.4, 0.9, 0.5), 0.2)
	popup("+35", Color(0.5, 1.0, 0.6))
	haptic(20)

func _hurt_bot(b: Bot, dmg: float, by_player: bool) -> void:
	if not b.alive: return
	b.hp -= dmg
	if b.hp > 0.0: return
	b.alive = false
	if is_instance_valid(b.n): b.n.queue_free()
	sfx("boom")
	if by_player:
		kills += 1
		add_points(1)
		popup("KILL", Color(1.0, 0.7, 0.4))
		_shake = maxf(_shake, 0.5)

func _hurt_player(dmg: float) -> void:
	var d := dmg
	if p_arm > 0.0:
		var a := minf(p_arm, d * 0.6)
		p_arm -= a
		d -= a
	p_hp -= d
	if dmg > 2.0:
		sfx("thud")
		shake2d(5.0)
		flash(Color(1.0, 0.3, 0.3), 0.12)
	if p_hp <= 0.0:
		p_hp = 0.0
		sfx("boom")
		flash(Color(1.0, 0.25, 0.25), 0.4)
		shake2d(14.0)
		popup("ELIMINATED", Color(1.0, 0.4, 0.4))
		end_demo()

func _update_loot() -> void:
	for c in loot:
		if c["taken"] or p_pos.distance_to(c["pos"]) >= 1.6: continue
		c["taken"] = true
		if is_instance_valid(c["n"]): c["n"].queue_free()
		sfx("coin")
		haptic(12)
		if p_tier < 2:
			p_tier += 1
			popup(T_NAME[p_tier] + "!", Color(1.0, 0.9, 0.4))
			flash(Color(1.0, 0.9, 0.4), 0.15)
		elif randf() < 0.5:
			p_arm = minf(60.0, p_arm + 20.0)
			popup("+ARMOR", Color(0.6, 0.8, 1.0))
		else:
			p_heals += 1
			popup("+HEAL", Color(0.5, 1.0, 0.6))

func _update_zone(delta: float) -> void:
	var k := minf(1.0, delta * 1.5)
	zone_r = lerpf(zone_r, zr_t, k)
	zone_c = zone_c.lerp(zc_t, k)
	zone_mesh.position = Vector3(zone_c.x, 0.05, zone_c.z)
	zone_mesh.scale = Vector3(zone_r, 1.0, zone_r)
	ph_time -= delta
	if ph_time <= 0.0 and zr_t > 4.0:
		zr_t = maxf(4.0, zr_t * 0.6)
		var sp := (zone_r - zr_t) * 0.6
		zc_t = zone_c + Vector3(randf_range(-sp, sp), 0, randf_range(-sp, sp))
		ph_time = maxf(6.0, 12.0 - match_num * 0.8)
		storm_dps *= 1.25
		sfx("tick")
		popup("ZONE CLOSING", Color(0.6, 0.9, 1.0))
		flash(Color(0.5, 0.6, 1.0), 0.15)

func _win() -> void:
	add_points(10 + match_num * 2)
	sfx("chime")
	sfx("coin")
	flash(Color(1.0, 0.95, 0.5), 0.3)
	popup("#1 VICTORY ROYALE", Color(1.0, 0.9, 0.4))
	haptic(40)
	match_num += 1
	_new_match()

func _tracer(a: Vector3, b: Vector3, col: Color) -> void:
	var dist := a.distance_to(b)
	if dist < 0.2: return
	var mi := mesh_box(Vector3(0.09, 0.09, 1.0), (a + b) * 0.5, col)
	mi.look_at(b, Vector3.UP)
	mi.scale = Vector3(1.0, 1.0, dist)
	_fx.append([mi, 0.06])

func _outside(pos: Vector3) -> bool:
	return Vector2(pos.x - zone_c.x, pos.z - zone_c.z).length() > zone_r

func _clamp_arena(pos: Vector3) -> Vector3:
	return Vector3(clampf(pos.x, -ARENA, ARENA), pos.y, clampf(pos.z, -ARENA, ARENA))

func _rand_point() -> Vector3:
	return Vector3(randf_range(-ARENA * 0.85, ARENA * 0.85), 0, randf_range(-ARENA * 0.85, ARENA * 0.85))

func _alive_bots() -> int:
	var c := 0
	for b in bots:
		if b.alive: c += 1
	return c

func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _fire()
		elif event.keycode == KEY_H: _heal()

# juice wrappers: adapt the task vocab to the shared Juice autoload
func sfx(n: String) -> void: Juice.sfx(n)
func flash(col: Color, dur := 0.2) -> void: Juice.flash(col, dur)
func popup(text: String, col := Color(1, 0.9, 0.4)) -> void: Juice.popup(text, Vector2(W * 0.5, H * 0.4), col)
func haptic(ms := 20) -> void: Juice.haptic(ms)
func shake2d(amt := 6.0) -> void: _shake = maxf(_shake, amt * 0.12)
