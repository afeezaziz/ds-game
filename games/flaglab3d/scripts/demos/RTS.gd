extends MechDemo3D
## RTS: run an economy and raze the enemy BASE. RES ticks up (a harvester shuttles
## the CRYSTAL for lumps); TRAIN spends RES to build a SOLDIER at your base. Tap YOUR
## soldier to SELECT, tap empty ground to MOVE, tap an ENEMY to ATTACK-move; RALLY
## selects all. Enemy waves escalate; lose your base = over, raze theirs = tougher one.
## Touch: TRAIN / RALLY buttons + world taps. Desktop: T train, A rally, tap to command.

const ALLY := 0
const ENEMY := 1
const FZ := 22.0                 # base z-line (+ you, - enemy)
const TRAIN_COST := 40
const BUILD_TIME := 1.6
const HARVEST := 25.0
const AGGRO := 9.0
const TAP_R := 3.2
const SELECT_R := 4.5
const POP := Vector2(360, 560)

var tc: TouchControls
var units: Array = []
var hud: Label3D
var res := 60.0
var queued := 0
var build_t := BUILD_TIME
var enemy_t := 5.0
var elapsed := 0.0
var tier := 1
var node_pos := Vector3(-9, 0, FZ - 4)
var c_ally := Color(0.42, 0.62, 0.95)
var c_enemy := Color(0.95, 0.46, 0.4)


func start() -> void:
	super.start()
	setup_world(Color(0.12, 0.14, 0.1), 0.9)
	make_camera(Vector3(0, 34, 28), Vector3(0, 0, -2), 60.0)
	tc = add_touch_controls([
		{"id": "produce", "label": "TRAIN", "col": Color(0.5, 0.75, 0.95)},
		{"id": "allmove", "label": "RALLY", "col": Color(0.6, 0.85, 0.55)},
	], false, false)
	tc.action.connect(func(id):
		if id == "produce": _produce()
		elif id == "allmove": _select_all())
	mesh_box(Vector3(30, 0.2, FZ * 2 + 10), Vector3(0, -0.35, 0), Color(0.16, 0.2, 0.13))
	mesh_sphere(1.3, node_pos + Vector3(0, 0.7, 0), Color(0.45, 0.9, 0.6))
	label3d("CRYSTAL", node_pos + Vector3(0, 2.6, 0), 22, Color(0.6, 1, 0.7))
	hud = label3d("", Vector3(-4.4, 5.2, -9), 20, Color(0.95, 0.98, 1), cam)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_base(ALLY); _base(ENEMY)
	_spawn(ALLY, "harvester")


func _process(delta: float) -> void:
	if not running: return
	elapsed += delta
	res += 4.0 * delta
	if queued > 0:
		build_t -= delta
		if build_t <= 0.0:
			build_t = BUILD_TIME; queued -= 1
			_spawn(ALLY, "soldier"); Juice.sfx("coin", 1.1)
	enemy_t -= delta
	if enemy_t <= 0.0:
		enemy_t = maxf(2.2, 6.0 - tier * 0.4)
		var n := mini(6, 1 + tier + int(elapsed / 30.0))
		for _i in n: _spawn(ENEMY, "soldier")
		if n >= 2:
			Juice.sfx("tick", 0.8)
			Juice.popup("WAVE x%d" % n, Vector2(360, 220), c_enemy, 34)
	_ai(delta); _hud()


func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventScreenTouch and event.pressed:
		var from := cam.project_ray_origin(event.position)
		var dir := cam.project_ray_normal(event.position)
		var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
		if hit != null: _tap(hit)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T: _produce()
		elif event.keycode == KEY_A: _select_all()


func _ai(delta: float) -> void:
	for u in units.duplicate():
		if not u.alive: continue
		if u.kind == "harvester":
			_harvest(u, delta); continue
		if u.target != null and not u.target.alive: u.target = null
		if u.target == null:
			u.target = _nearest_enemy(u, u.range if (u.kind == "base" or u.hold) else AGGRO)
		if u.target != null:
			if u.pos.distance_to(u.target.pos) <= u.range + 0.4:
				u.cd -= delta
				if u.cd <= 0.0:
					u.cd = u.atk; _damage(u.target, u.dmg); Juice.sfx("thud", 0.9)
			elif u.kind != "base":
				_step(u, u.target.pos, delta)
		elif u.kind == "soldier" and u.pos.distance_to(u.goal) > 0.6:
			_step(u, u.goal, delta)


func _harvest(u: Dictionary, delta: float) -> void:
	var base = _find_base(ALLY)
	if base == null: return
	var dst: Vector3 = node_pos if u.state == 0 else base.pos
	_step(u, dst, delta)
	if u.pos.distance_to(dst) < 2.2:
		if u.state == 1:
			res += HARVEST; Juice.sfx("tick", 1.3)
		u.state = 1 - u.state


func _step(u: Dictionary, dst: Vector3, delta: float) -> void:
	var to := dst - u.pos; to.y = 0.0
	if to.length() < 0.05: return
	u.pos += to.normalized() * u.spd * delta
	u.pos.x = clampf(u.pos.x, -13.5, 13.5)
	u.pos.z = clampf(u.pos.z, -FZ - 3, FZ + 3)
	u.node.position = u.pos


func _tap(world: Vector3) -> void:
	if _near(world, ENEMY, TAP_R, false) != null:
		_order(world, false); return
	if _near(world, ALLY, SELECT_R, true) != null:
		_clear_sel()
		for u in units:
			if u.alive and u.selectable and u.pos.distance_to(world) < SELECT_R:
				_set_sel(u, true)
		Juice.sfx("tick", 1.1); Juice.haptic(8); return
	_order(world, true)


func _order(world: Vector3, hold: bool) -> void:
	var sel := _selected()
	if sel.is_empty():
		for u in units:
			if u.alive and u.selectable: sel.append(u)
	if sel.is_empty(): return
	for u in sel:
		u.goal = world; u.hold = hold; u.target = null
	Juice.sfx("thud" if not hold else "tick", 1.0); Juice.haptic(10)
	Juice.popup("ATTACK" if not hold else "MOVE", POP, c_enemy if not hold else c_ally)


func _produce() -> void:
	if not running: return
	if res < float(TRAIN_COST):
		Juice.sfx("tick", 0.6); return
	res -= float(TRAIN_COST); queued += 1
	Juice.sfx("tick"); Juice.haptic(10)


func _select_all() -> void:
	if not running: return
	var n := 0
	for u in units:
		if u.alive and u.selectable:
			_set_sel(u, true); n += 1
	Juice.sfx("chime"); Juice.haptic(12)
	Juice.popup("RALLY x%d" % n, POP, c_ally)


func _set_sel(u: Dictionary, on: bool) -> void:
	u.selected = on
	if u.ring != null: u.ring.visible = on


func _clear_sel() -> void:
	for u in units:
		if u.selectable: _set_sel(u, false)


func _selected() -> Array:
	var a: Array = []
	for u in units:
		if u.alive and u.selectable and u.selected: a.append(u)
	return a


func _spawn(team: int, kind: String) -> void:
	var base = _find_base(team)
	if base == null: return
	var fwd := -1.0 if team == ALLY else 1.0
	var col := c_ally if team == ALLY else c_enemy
	var u := {"kind": kind, "team": team, "alive": true, "selected": false, "ring": null,
		"selectable": team == ALLY and kind == "soldier", "target": null, "cd": 0.0,
		"state": 0, "hold": kind == "soldier",
		"pos": base.pos + Vector3(randf_range(-3, 3), 0, fwd * randf_range(3, 5))}
	if kind == "harvester":
		u.hp = 70.0; u.maxhp = 70.0; u.dmg = 0.0; u.range = 0.0; u.atk = 1.0; u.spd = 6.0
		u.goal = node_pos
		u.node = mesh_box(Vector3(1.4, 1.0, 1.9), u.pos, Color(0.9, 0.85, 0.5))
	else:
		if team == ALLY:
			u.hp = 64.0; u.dmg = 11.0; u.spd = 4.7; u.goal = base.pos + Vector3(0, 0, -7)
		else:
			u.hp = 44.0 + tier * 10.0; u.dmg = 8.0 + tier * 2.0; u.spd = 4.1
			u.goal = _find_base(ALLY).pos
		u.maxhp = u.hp; u.range = 2.3; u.atk = 0.6
		u.node = mesh_box(Vector3(1, 1.6, 1), u.pos, col)
		if u.selectable:
			var ring := mesh_cyl(0.9, 0.08, Vector3(0, -0.86, 0), Color(1, 0.95, 0.5), u.node)
			ring.visible = false; u.ring = ring
	u.node.position = u.pos
	units.append(u)


func _base(team: int) -> void:
	var z := FZ if team == ALLY else -FZ
	var col := c_ally if team == ALLY else c_enemy
	var hp := 600.0 if team == ALLY else 480.0 + tier * 220.0
	var b := {"kind": "base", "team": team, "alive": true, "selected": false, "ring": null,
		"selectable": false, "pos": Vector3(0, 0, z), "hp": hp, "maxhp": hp, "dmg": 16.0,
		"range": 8.0, "atk": 0.5, "cd": 0.0, "spd": 0.0, "hold": true,
		"goal": Vector3(0, 0, z), "target": null}
	b.node = mesh_box(Vector3(5, 4, 5), b.pos + Vector3(0, 2, 0), col)
	label3d("BASE", Vector3(0, 4, 0), 30, col, b.node)
	units.append(b)


func _damage(u: Dictionary, dmg: float) -> void:
	if not u.alive: return
	u.hp -= dmg
	if u.hp <= 0.0: _die(u)


func _die(u: Dictionary) -> void:
	if not u.alive: return
	u.alive = false
	if u.kind == "base":
		if u.team == ENEMY: _win(u)
		else: _lose(u)
		return
	if is_instance_valid(u.node): u.node.queue_free()
	units.erase(u)
	if u.team == ENEMY:
		add_points(1); Juice.sfx("coin"); Juice.haptic(8)


func _win(base: Dictionary) -> void:
	add_points(5); tier += 1
	Juice.sfx("boom"); Juice.sfx("coin"); Juice.flash(Color(1, 0.9, 0.4), 0.5)
	Juice.hitstop(90); Juice.haptic(30)
	Juice.popup("ENEMY BASE RAZED! +5", POP, Color(1, 0.9, 0.4))
	if is_instance_valid(base.node): base.node.queue_free()
	units.erase(base)
	for e in units.duplicate():
		if e.team == ENEMY and e.alive:
			e.alive = false
			if is_instance_valid(e.node): e.node.queue_free()
			units.erase(e)
	_base(ENEMY)


func _lose(base: Dictionary) -> void:
	Juice.sfx("boom"); Juice.flash(Color(0.9, 0.2, 0.2), 0.6)
	Juice.hitstop(120); Juice.haptic(40)
	Juice.popup("YOUR BASE DESTROYED", POP, Color(1, 0.4, 0.4))
	if is_instance_valid(base.node): base.node.queue_free()
	end_demo()


func _nearest_enemy(u: Dictionary, r: float):
	var best = null
	var bd := r
	for e in units:
		if not e.alive or e.team == u.team: continue
		var d: float = u.pos.distance_to(e.pos)
		if d < bd:
			bd = d; best = e
	return best


func _near(pos: Vector3, team: int, r: float, sel_only: bool):
	var best = null
	var bd := r
	for u in units:
		if not u.alive or u.team != team: continue
		if sel_only and not u.selectable: continue
		var d: float = pos.distance_to(u.pos)
		if d < bd:
			bd = d; best = u
	return best


func _find_base(team: int):
	for u in units:
		if u.alive and u.kind == "base" and u.team == team: return u
	return null


func _hud() -> void:
	var eb = _find_base(ENEMY)
	var yb = _find_base(ALLY)
	var army := 0
	for u in units:
		if u.alive and u.team == ALLY and u.kind == "soldier": army += 1
	hud.text = "RES %d    ARMY %d    TRAIN:%d\nENEMY BASE  %s\nYOUR BASE   %s    tier %d" % [
		int(res), army, TRAIN_COST,
		("%d/%d" % [int(eb.hp), int(eb.maxhp)]) if eb != null else "--",
		("%d/%d" % [int(yb.hp), int(yb.maxhp)]) if yb != null else "--", tier]
