extends MechDemo3D
## MUSOU HORDE: one warrior versus a field of DOZENS of grunts. ATTACK sweeps a
## wide arc that mows down EVERY enemy in front of you at once, chaining a COMBO;
## each kill fills a MUSOU gauge you unleash for a screen-clearing spin. Tougher
## OFFICERS roam the swarm for big score + territory. Contact chips HP; 0 = defeat.
## Touch: stick move, ATTACK arc, MUSOU screen-clear. Desktop: WASD, J attack, K musou.

const POP := Vector2(360, 560)
const BOUND := 30.0
const ARC := 1.15          # half-angle of the swing (radians)
const REACH := 7.5         # swing radius
const SWING := 0.26        # swing anim duration

var tc: TouchControls
var warrior: Dictionary
var blade: MeshInstance3D
var foes: Array = []
var hud: Label3D
var cam_face := Vector3(0, 0, -1)
var kills := 0
var officers_down := 0
var combo := 0
var combo_t := 0.0
var musou := 0.0           # gauge 0..100
var musou_t := 0.0         # active spin seconds left
var musou_tick := 0.0
var swing_t := 0.0
var spawn_t := 1.0
var officer_t := 9.0
var elapsed := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.09, 0.11, 0.16), 0.85)
	make_camera(Vector3(0, 6.5, 9), Vector3.ZERO, 62.0)
	tc = add_touch_controls([
		{"id": "attack", "label": "ATTACK", "col": Color(0.9, 0.5, 0.4)},
		{"id": "musou", "label": "MUSOU", "col": Color(1.0, 0.75, 0.25)}])
	tc.action.connect(func(id):
		if id == "attack": _attack()
		elif id == "musou": _musou())
	mesh_box(Vector3(BOUND * 2, 0.3, BOUND * 2), Vector3(0, -0.2, 0), Color(0.14, 0.17, 0.13))
	for i in 4:
		var a := i * TAU / 4.0
		mesh_box(Vector3(0.6, 6, 0.6), Vector3(cos(a) * BOUND, 3, sin(a) * BOUND), Color(0.3, 0.25, 0.2))
	hud = label3d("", Vector3(-3.0, 4.3, -9), 20, Color(0.96, 0.98, 1), cam)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	warrior = {"pos": Vector3.ZERO, "facing": Vector3(0, 0, -1), "hp": 100.0, "maxhp": 100.0}
	warrior.node = mesh_box(Vector3(1.1, 2.2, 1.1), Vector3(0, 1.1, 0), Color(0.35, 0.75, 0.95))
	blade = mesh_box(Vector3(0.25, 0.25, 4.2), Vector3(0, 0.4, -1.6), Color(0.95, 0.95, 1.0), warrior.node)
	for i in 26:
		_spawn_grunt()


func _process(delta: float) -> void:
	if not running: return
	elapsed += delta
	combo_t = maxf(0.0, combo_t - delta)
	if combo_t <= 0.0: combo = 0
	swing_t = maxf(0.0, swing_t - delta)
	_move(delta)
	_swarm(delta)
	_spawn_logic(delta)
	_musou_update(delta)
	_anim_blade()
	_camera(delta)
	_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: _attack()
		elif event.keycode == KEY_K: _musou()


func _move(delta: float) -> void:
	var dir := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if dir.length() > 0.15:
		dir = dir.normalized()
		warrior.facing = dir
		var p: Vector3 = warrior.pos + dir * 9.0 * delta
		p.x = clampf(p.x, -BOUND + 1, BOUND - 1)
		p.z = clampf(p.z, -BOUND + 1, BOUND - 1)
		warrior.pos = p
	warrior.node.position = warrior.pos + Vector3(0, 1.1, 0)
	if musou_t <= 0.0:
		warrior.node.rotation.y = atan2(-warrior.facing.x, -warrior.facing.z)


func _swarm(delta: float) -> void:
	for e in foes:
		if not e.alive: continue
		e.hit_cd = maxf(0.0, e.hit_cd - delta)
		var ring: Vector3 = warrior.pos + Vector3(cos(e.ang), 0, sin(e.ang)) * e.gap
		var to := ring - e.pos
		if to.length() > 0.05:
			e.pos += to.normalized() * e.spd * delta
		e.node.position = e.pos + Vector3(0, e.h * 0.5, 0)
		if warrior.pos.distance_to(e.pos) < 1.7 and e.hit_cd <= 0.0:
			e.hit_cd = 1.0
			_damage_player(e.dmg)


func _attack() -> void:
	if not running or swing_t > 0.0: return
	swing_t = SWING
	Juice.sfx("tick", 1.2); Juice.haptic(10)
	var slain := 0
	var f: Vector3 = warrior.facing
	for e in foes.duplicate():
		if not e.alive: continue
		var to: Vector3 = e.pos - warrior.pos
		var d := to.length()
		if d > 0.1 and d <= REACH and f.angle_to(to) <= ARC:
			if _hurt(e, 34.0): slain += 1
	if slain > 0:
		combo += slain
		combo_t = 2.2
		_fill_musou(slain * 6.0)
		Juice.sfx("thud"); Juice.hitstop(mini(70, 24 + slain * 8))
		Juice.flash(Color(1, 0.8, 0.4), 0.12); Juice.haptic(16)
		Juice.popup("x%d  COMBO %d" % [slain, combo], POP, Color(1, 0.85, 0.4), 46)
	else:
		_fill_musou(1.0)


func _musou() -> void:
	if not running or musou < 100.0 or musou_t > 0.0: return
	musou = 0.0
	musou_t = 2.0
	musou_tick = 0.0
	Juice.sfx("boom"); Juice.flash(Color(1, 0.85, 0.3), 0.5); Juice.hitstop(80); Juice.haptic(40)
	Juice.popup("MUSOU RAMPAGE!", Vector2(360, 430), Color(1, 0.8, 0.2), 58)


func _musou_update(delta: float) -> void:
	if musou_t <= 0.0: return
	musou_t -= delta
	warrior.node.rotation.y += delta * 22.0
	musou_tick -= delta
	if musou_tick <= 0.0:
		musou_tick = 0.12
		var slain := 0
		for e in foes.duplicate():
			if e.alive and warrior.pos.distance_to(e.pos) < 14.0:
				if _hurt(e, 26.0): slain += 1
		if slain > 0:
			Juice.sfx("thud"); Juice.sfx("coin")
			Juice.popup("x%d" % slain, POP, Color(1, 0.7, 0.2), 40)
	if musou_t <= 0.0:
		Juice.sfx("chime")


func _hurt(e: Dictionary, dmg: float) -> bool:
	e.hp -= dmg
	if e.kind == "officer" and is_instance_valid(e.bar):
		e.bar.scale.x = clampf(e.hp / e.maxhp, 0.02, 1.0)
	if e.hp <= 0.0:
		_kill(e)
		return true
	return false


func _kill(e: Dictionary) -> void:
	e.alive = false
	if is_instance_valid(e.node): e.node.queue_free()
	kills += 1
	if e.kind == "officer":
		officers_down += 1
		add_points(25)
		_fill_musou(30.0)
		Juice.sfx("coin"); Juice.flash(Color(1, 0.9, 0.4), 0.4); Juice.hitstop(90); Juice.haptic(30)
		Juice.popup("OFFICER SLAIN!  TERRITORY %d" % officers_down, Vector2(360, 460), Color(1, 0.9, 0.4), 46)
	else:
		add_points(1)
	foes.erase(e)


func _damage_player(dmg: float) -> void:
	warrior.hp -= dmg
	Juice.sfx("thud", 0.8); Juice.flash(Color(0.8, 0.2, 0.2), 0.18); Juice.haptic(14)
	if warrior.hp <= 0.0:
		warrior.hp = 0.0
		Juice.sfx("boom"); Juice.flash(Color(0.9, 0.15, 0.15), 0.6); Juice.hitstop(120); Juice.haptic(60)
		Juice.popup("OVERWHELMED", POP, Color(1, 0.4, 0.4), 54)
		end_demo()


func _fill_musou(amt: float) -> void:
	var was := musou
	musou = clampf(musou + amt, 0.0, 100.0)
	if was < 100.0 and musou >= 100.0:
		Juice.sfx("chime"); Juice.flash(Color(1, 0.8, 0.3), 0.25)
		Juice.popup("MUSOU READY!", Vector2(360, 500), Color(1, 0.8, 0.3), 44)


func _spawn_logic(delta: float) -> void:
	var target := mini(26 + int(elapsed / 6.0) * 4, 58)
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(0.35, 1.4 - elapsed * 0.02)
		var live := foes.size()
		if live < target:
			for i in mini(4, target - live):
				_spawn_grunt()
	officer_t -= delta
	if officer_t <= 0.0:
		officer_t = maxf(5.0, 11.0 - elapsed * 0.03)
		_spawn_officer()


func _spawn_grunt() -> void:
	var a := randf() * TAU
	var r := BOUND - 2.0
	var e := {"kind": "grunt", "alive": true, "h": 1.6, "gap": 1.4 + randf(),
		"ang": randf() * TAU, "spd": 3.2 + randf() * 0.8, "hp": 30.0, "maxhp": 30.0,
		"dmg": 5.0, "hit_cd": randf()}
	e.pos = Vector3(cos(a) * r, 0, sin(a) * r)
	e.node = mesh_box(Vector3(0.9, 1.6, 0.9), e.pos + Vector3(0, 0.8, 0), hue_col(randf() * 5.0, 0.4, 0.7))
	foes.append(e)


func _spawn_officer() -> void:
	var a := randf() * TAU
	var r := BOUND - 3.0
	var e := {"kind": "officer", "alive": true, "h": 3.0, "gap": 2.4,
		"ang": randf() * TAU, "spd": 2.4, "hp": 220.0, "maxhp": 220.0,
		"dmg": 16.0, "hit_cd": 0.5}
	e.pos = Vector3(cos(a) * r, 0, sin(a) * r)
	e.node = mesh_box(Vector3(1.8, 3.0, 1.8), e.pos + Vector3(0, 1.5, 0), Color(0.85, 0.3, 0.35))
	label3d("OFFICER", Vector3(0, 2.3, 0), 26, Color(1, 0.8, 0.5), e.node)
	e.bar = mesh_box(Vector3(2.2, 0.25, 0.25), Vector3(0, 2.0, 0), Color(0.4, 0.95, 0.4), e.node)
	foes.append(e)


func _anim_blade() -> void:
	if swing_t > 0.0:
		blade.rotation.y = lerpf(ARC, -ARC, 1.0 - swing_t / SWING)
	else:
		blade.rotation.y = -ARC * 0.6


func _camera(delta: float) -> void:
	cam_face = cam_face.lerp(warrior.facing, clampf(delta * 4.0, 0.0, 1.0)).normalized()
	var shake := Vector3.ZERO
	if musou_t > 0.0:
		shake = Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2), randf_range(-0.3, 0.3))
	cam.position = warrior.pos - cam_face * 9.0 + Vector3(0, 6.5, 0) + shake
	cam.look_at(warrior.pos + Vector3(0, 1.4, 0) + cam_face * 3.0, Vector3.UP)


func _hud() -> void:
	var mtxt: String
	if musou_t > 0.0:
		mtxt = "SPIN %.1f" % musou_t
	elif musou >= 100.0:
		mtxt = "READY"
	else:
		mtxt = "%d%%" % int(musou)
	hud.text = "HP %d/%d\nCOMBO %d\nMUSOU %s\nKILLS %d\nOFFICERS %d" % [
		int(warrior.hp), int(warrior.maxhp), combo, mtxt, kills, officers_down]
