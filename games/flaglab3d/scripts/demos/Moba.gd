extends MechDemo3D
## MOBA lane push: shove minion waves + your hero down ONE lane to smash the enemy CORE.
## Waves spawn every ~10s and clash at a moving mid-lane equilibrium; towers auto-shoot
## minions first but PUNISH a lone tower-diver. Last-hits give gold, kills give XP ->
## levels -> more damage. Kill the core to escalate (endless); your core/hero falling loses.
## Touch: stick move, ATTACK last-hit, Q skillshot, W AoE. Desktop: WASD, J basic, K=Q, L=W.

const LANE := 40.0
const ALLY := 0
const ENEMY := 1
const POP := Vector2(360, 520)

var tc: TouchControls
var hero: Dictionary
var units: Array = []
var shots: Array = []
var hud: Label3D
var wave_t := 3.0
var q_cd := 0.0
var w_cd := 0.0
var tier := 1
var respawns := 3
var c_ally := Color(0.4, 0.6, 0.95)
var c_enemy := Color(0.95, 0.45, 0.4)


func start() -> void:
	super.start()
	setup_world(Color(0.10, 0.16, 0.12), 0.9)
	make_camera(Vector3(0, 22, 14), Vector3.ZERO, 60.0)
	tc = add_touch_controls([
		{"id": "attack", "label": "ATTACK", "col": Color(0.9, 0.5, 0.4)},
		{"id": "q", "label": "Q", "col": Color(0.5, 0.7, 0.95)},
		{"id": "w", "label": "W", "col": Color(0.7, 0.5, 0.9)}])
	tc.action.connect(func(id):
		if id == "attack": _basic()
		elif id == "q": _cast_q()
		elif id == "w": _cast_w())
	mesh_box(Vector3(40, 0.2, LANE * 2 + 12), Vector3(0, -0.35, 0), Color(0.12, 0.2, 0.13))
	mesh_box(Vector3(12, 0.4, LANE * 2 + 10), Vector3(0, -0.2, 0), Color(0.18, 0.22, 0.18))
	hud = label3d("", Vector3(-2.9, 4.2, -9), 20, Color(0.95, 0.98, 1), cam)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	hero = {"kind": "hero", "team": ALLY, "alive": true, "pos": Vector3(0, 0, LANE - 6),
		"facing": Vector3(0, 0, -1), "hp": 240.0, "maxhp": 240.0, "dmg": 22.0,
		"level": 1, "xp": 0.0, "gold": 0}
	hero.node = mesh_box(Vector3(1.4, 2.2, 1.4), hero.pos, Color(0.3, 0.9, 0.7))
	units.append(hero)
	_base(ALLY, 1)
	_base(ENEMY, tier)


func _process(delta: float) -> void:
	if not running: return
	q_cd = maxf(0.0, q_cd - delta); w_cd = maxf(0.0, w_cd - delta)
	_move(delta)
	wave_t -= delta
	if wave_t <= 0.0:
		wave_t = 10.0
		_wave()
	_ai(delta); _shots(delta)
	cam.position = hero.pos + Vector3(0, 22, 14)
	cam.look_at(hero.pos, Vector3.UP)
	_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: _basic()
		elif event.keycode == KEY_K: _cast_q()
		elif event.keycode == KEY_L: _cast_w()


func _move(delta: float) -> void:
	var dir := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if dir.length() > 0.15:
		dir = dir.normalized(); hero.facing = dir
		var p: Vector3 = hero.pos + dir * 10.0 * delta
		p.x = clampf(p.x, -5.5, 5.5); p.z = clampf(p.z, -LANE - 3, LANE + 3)
		hero.pos = p; hero.node.position = p


func _ai(delta: float) -> void:
	for u in units.duplicate():
		if not u.alive or u.kind == "hero" or u.kind == "core": continue
		u.cd -= delta
		var tgt = _acquire(u)
		if tgt != null:
			if u.pos.distance_to(tgt.pos) <= u.rng:
				if u.cd <= 0.0:
					u.cd = u.atk
					if u.kind == "tower":
						_shot(u.pos + Vector3(0, 3, 0), tgt, u.dmg, c_enemy if u.team == ENEMY else c_ally)
					else:
						_damage(tgt, u.dmg)
			elif u.kind == "minion":
				u.pos = u.pos + (tgt.pos - u.pos).normalized() * 5.0 * delta; u.node.position = u.pos
		elif u.kind == "minion":
			var goal := Vector3(u.lane, 0, (-LANE if u.team == ALLY else LANE))
			u.pos = u.pos + (goal - u.pos).normalized() * 5.0 * delta; u.node.position = u.pos


func _acquire(u):
	var best = null
	var bm = null
	var bd: float = u.detect
	var bmd: float = u.detect
	for e in units:
		if not e.alive or e.team == u.team: continue
		var d: float = u.pos.distance_to(e.pos)
		if d < bd:
			bd = d; best = e
		if e.kind == "minion" and d < bmd:
			bmd = d; bm = e
	return bm if (u.prefer and bm != null) else best


func _shots(delta: float) -> void:
	for s in shots.duplicate():
		if s.homing:
			if s.target == null or not s.target.alive:
				_kill(s); continue
			var to: Vector3 = s.target.pos + Vector3(0, 1, 0) - s.pos
			if to.length() < 1.2:
				_damage(s.target, s.dmg); _kill(s); continue
			s.pos = s.pos + to.normalized() * 24.0 * delta
		else:
			s.pos = s.pos + s.dir * 28.0 * delta
			var hit = null
			for e in units:
				if e.alive and e.team == ENEMY and e.kind != "hero" and e.pos.distance_to(s.pos) < 1.8:
					hit = e; break
			if hit != null:
				_damage(hit, s.dmg); _kill(s); continue
		s.life -= delta
		if s.life <= 0.0:
			_kill(s); continue
		s.node.position = s.pos


func _kill(s) -> void:
	if is_instance_valid(s.node): s.node.queue_free()
	shots.erase(s)


func _basic() -> void:
	if not running: return
	var t = _nearest(hero.pos, 6.0)
	if t == null: return
	var lethal: bool = t.hp <= hero.dmg and t.kind == "minion"
	_damage(t, hero.dmg); Juice.sfx("thud"); Juice.haptic(10)
	if lethal:
		hero.gold += 30; Juice.sfx("coin")
		Juice.popup("LAST HIT +30g", POP, Color(1, 0.85, 0.3))


func _cast_q() -> void:
	if not running or q_cd > 0.0: return
	q_cd = 4.0
	var s := {"homing": false, "dir": hero.facing, "dmg": 30.0 + hero.level * 6.0,
		"pos": hero.pos + Vector3(0, 1, 0), "life": 1.4}
	s.node = mesh_sphere(0.45, s.pos, Color(0.55, 0.8, 1))
	shots.append(s); Juice.sfx("tick"); Juice.haptic(12)


func _cast_w() -> void:
	if not running or w_cd > 0.0: return
	w_cd = 8.0
	var dmg := 22.0 + hero.level * 5.0
	for e in units.duplicate():
		if e.alive and e.team == ENEMY and e.pos.distance_to(hero.pos) < 6.5:
			_damage(e, dmg)
	var ring := mesh_sphere(6.0, hero.pos + Vector3(0, 0.5, 0), Color(0.8, 0.5, 1))
	get_tree().create_timer(0.22).timeout.connect(ring.queue_free)
	Juice.sfx("boom"); Juice.flash(Color(0.7, 0.4, 1), 0.3); Juice.hitstop(40); Juice.haptic(25)


func _damage(u, dmg: float) -> void:
	if not u.alive: return
	u.hp -= dmg
	if u.hp <= 0.0: _die(u)


func _die(u) -> void:
	if u.kind == "hero":
		_hero_death(); return
	u.alive = false
	if is_instance_valid(u.node): u.node.queue_free()
	units.erase(u)
	if u.team == ENEMY:
		var near: bool = u.pos.distance_to(hero.pos) < 18.0
		if near: _xp(u.xp)
		if u.kind == "minion":
			if near: hero.gold += 10
			Juice.sfx("thud")
		elif u.kind == "tower":
			add_points(1); hero.gold += 120
			Juice.sfx("boom"); Juice.flash(c_ally, 0.35)
			Juice.popup("TOWER DOWN +1", POP, c_ally)
		elif u.kind == "core":
			_win()
	elif u.team == ALLY and u.kind == "core":
		_lose()


func _xp(x: float) -> void:
	hero.xp += x
	if hero.xp >= hero.level * 100:
		hero.xp -= hero.level * 100
		hero.level += 1; hero.dmg += 6.0; hero.maxhp += 30.0; hero.hp = hero.maxhp
		Juice.sfx("chime"); Juice.flash(Color(1, 0.9, 0.4), 0.3)
		Juice.popup("LEVEL %d!" % hero.level, POP, Color(1, 0.9, 0.4))


func _hero_death() -> void:
	Juice.sfx("boom"); Juice.flash(Color(0.9, 0.2, 0.2), 0.5); Juice.hitstop(80)
	respawns -= 1
	if respawns < 0:
		end_demo(); return
	hero.hp = hero.maxhp; hero.pos = Vector3(0, 0, LANE - 3); hero.node.position = hero.pos
	Juice.popup("RESPAWN - %d left" % respawns, POP, Color(0.8, 0.9, 1))


func _win() -> void:
	add_points(2); hero.gold += 250
	Juice.sfx("coin"); Juice.flash(Color(1, 0.9, 0.4), 0.5); Juice.hitstop(120)
	Juice.popup("ENEMY CORE DESTROYED!", POP, Color(1, 0.9, 0.4))
	tier += 1
	for e in units.duplicate():
		if e.team == ENEMY and e.alive:
			e.alive = false
			if is_instance_valid(e.node): e.node.queue_free()
			units.erase(e)
	_base(ENEMY, tier)


func _lose() -> void:
	Juice.sfx("boom"); Juice.flash(Color(0.9, 0.2, 0.2), 0.6)
	Juice.popup("YOUR CORE FELL", POP, Color(1, 0.4, 0.4))
	end_demo()


func _wave() -> void:
	for i in 4:
		_minion(ALLY, i); _minion(ENEMY, i)
	Juice.sfx("tick")


func _minion(team: int, idx: int) -> void:
	var sgn := 1.0 if team == ALLY else -1.0
	var m := {"kind": "minion", "team": team, "alive": true, "prefer": false,
		"lane": -2.0 + idx * 1.35, "rng": 2.6, "detect": 8.0, "atk": 0.8,
		"cd": randf() * 0.5, "xp": 25.0}
	m.pos = Vector3(m.lane, 0, sgn * 37.0)
	m.maxhp = 55.0 + (tier * 12.0 if team == ENEMY else hero.level * 8.0); m.hp = m.maxhp
	m.dmg = 8.0 + (tier * 2.0 if team == ENEMY else hero.level * 1.5)
	m.node = mesh_box(Vector3(1, 1.4, 1), m.pos, c_enemy if team == ENEMY else c_ally)
	units.append(m)


func _base(team: int, t: int) -> void:
	var sgn := -1.0 if team == ENEMY else 1.0
	var thp := 260.0 + t * 90.0
	_struct(team, "tower", Vector3(0, 0, sgn * 15), thp, t)
	_struct(team, "tower", Vector3(0, 0, sgn * 28), thp, t)
	_struct(team, "core", Vector3(0, 0, sgn * 40), thp * 1.7, t)


func _struct(team: int, kind: String, pos: Vector3, hp: float, t: int) -> void:
	var c := c_enemy if team == ENEMY else c_ally
	var sz := Vector3(2.4, 5, 2.4) if kind == "tower" else Vector3(4.4, 7, 4.4)
	var s := {"kind": kind, "team": team, "alive": true, "prefer": true, "pos": pos,
		"maxhp": hp, "hp": hp, "dmg": 32.0 + t * 8.0, "rng": 10.0, "detect": 10.0,
		"atk": 1.1, "cd": 0.0, "xp": (80.0 if kind == "tower" else 150.0)}
	s.node = mesh_box(sz, pos + Vector3(0, sz.y * 0.5, 0), c)
	label3d(kind.to_upper(), Vector3(0, sz.y * 0.5 + 1, 0), 26, c, s.node)
	units.append(s)


func _shot(pos: Vector3, target, dmg: float, col: Color) -> void:
	var s := {"homing": true, "target": target, "dmg": dmg, "pos": pos, "life": 3.0}
	s.node = mesh_sphere(0.35, pos, col)
	shots.append(s)


func _nearest(pos: Vector3, rng: float):
	var best = null
	var bd := rng
	for e in units:
		if not e.alive or e.team != ENEMY: continue
		var d: float = pos.distance_to(e.pos)
		if d < bd:
			bd = d; best = e
	return best


func _find(team: int, kind: String):
	for e in units:
		if e.alive and e.team == team and e.kind == kind: return e
	return null


func _hud() -> void:
	var core = _find(ENEMY, "core")
	var chp := ("%d/%d" % [int(core.hp), int(core.maxhp)]) if core != null else "--"
	hud.text = "HP %d/%d   LV %d   GOLD %d\nQ:%s   W:%s\nENEMY CORE %s   deaths:%d" % [
		int(hero.hp), int(hero.maxhp), hero.level, hero.gold,
		("%.1f" % q_cd) if q_cd > 0.0 else "RDY", ("%.1f" % w_cd) if w_cd > 0.0 else "RDY",
		chp, respawns]
