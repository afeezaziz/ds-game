extends MechDemo
## SURVIVE EVO (deep) — real Vampire-Survivors build-craft. FIVE weapons and SIX
## passives that modify them; max a weapon and pair it with the right passive to
## EVOLVE it into a stronger form. Enemy archetypes (swarm/runner/tank/exploder)
## and timed BOSS waves that drop chests. Drag to move; everything auto-fires.
## Score = kills.

# weapon lvl (0 = unowned), evolved flag. Passives lvl 0-5.
var wlv := {"bolt": 1, "orbit": 0, "whip": 0, "aura": 0, "boom": 0}
var wevo := {"bolt": false, "orbit": false, "whip": false, "aura": false, "boom": false}
var pas := {"might": 0, "haste": 0, "area": 0, "magnet": 0, "armor": 0, "growth": 0}
const EVO_PAIR := {"bolt": "might", "orbit": "area", "whip": "haste", "aura": "armor", "boom": "growth"}
const EVO_NAME := {"bolt": "RAILGUN", "orbit": "SATURN", "whip": "CYCLONE", "aura": "SANCTUARY", "boom": "COMET"}

var pp := Vector2(360, 700)
var hp := 100.0
var maxhp := 100.0
var inv := 0.0
var regen_t := 0.0
var move := Vector2.ZERO
var stick := false
var origin := Vector2.ZERO

var enemies: Array = []
var bolts: Array = []
var booms: Array = []
var gems: Array = []
var chests: Array = []
var spawn_t := 0.0
var boss_t := 45.0
var orbit_ang := 0.0
var whip_t := 0.0
var boom_t := 0.0
var bolt_t := 0.0
var t := 0.0

var xp := 0
var need := 5
var level := 1
var choosing := false
var choices: Array = []


func start() -> void:
	super.start()
	wlv = {"bolt": 1, "orbit": 0, "whip": 0, "aura": 0, "boom": 0}
	wevo = {"bolt": false, "orbit": false, "whip": false, "aura": false, "boom": false}
	pas = {"might": 0, "haste": 0, "area": 0, "magnet": 0, "armor": 0, "growth": 0}
	pp = Vector2(360, 700)
	hp = 100.0
	maxhp = 100.0
	inv = 0.0
	enemies = []
	bolts = []
	booms = []
	gems = []
	chests = []
	spawn_t = 0.4
	boss_t = 45.0
	whip_t = 0.0
	boom_t = 0.0
	t = 0.0
	xp = 0
	need = 5
	level = 1
	choosing = false


func _might() -> float: return 1.0 + pas.might * 0.16
func _haste() -> float: return maxf(0.4, 1.0 - pas.haste * 0.08)
func _area() -> float: return 1.0 + pas.area * 0.16
func _magnet() -> float: return 90.0 + pas.magnet * 45.0


func _opt_rect(i: int) -> Rect2:
	return Rect2(70, 440 + i * 160, 580, 140)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if choosing:
		if event is InputEventScreenTouch and event.pressed:
			for i in choices.size():
				if _opt_rect(i).has_point(event.position):
					_apply(choices[i])
					choosing = false
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			stick = true
			origin = event.position
			move = Vector2.ZERO
		else:
			stick = false
			move = Vector2.ZERO
	elif event is InputEventScreenDrag and stick:
		move = ((event.position - origin) / 70.0).limit_length(1.0)


func _offer() -> void:
	var pool := []
	# evolutions first (the payoff)
	for w in wlv:
		if wlv[w] >= 8 and not wevo[w] and pas[EVO_PAIR[w]] >= 3:
			pool.append({"kind": "evo", "w": w})
	var owned_w := 0
	for w in wlv:
		if wlv[w] > 0:
			owned_w += 1
	for w in wlv:
		if wlv[w] > 0 and wlv[w] < 8 and not wevo[w]:
			pool.append({"kind": "wlv", "w": w})
		elif wlv[w] == 0 and owned_w < 5:
			pool.append({"kind": "wnew", "w": w})
	for p in pas:
		if pas[p] < 5:
			pool.append({"kind": "pas", "p": p})
	pool.shuffle()
	# ensure evolutions kept at front
	var evos := pool.filter(func(o): return o.kind == "evo")
	var rest := pool.filter(func(o): return o.kind != "evo")
	choices = (evos + rest).slice(0, 3)
	while choices.size() < 3 and not rest.is_empty():
		choices.append(rest.pop_back())
	choosing = true


func _apply(o: Dictionary) -> void:
	match o.kind:
		"wlv", "wnew": wlv[o.w] += 1
		"pas": pas[o.p] += 1
		"evo":
			wevo[o.w] = true
			wlv[o.w] = 10
			Juice.flash(Color(0.9, 0.8, 0.4), 0.3)
	Juice.sfx("chime")


func _process(delta: float) -> void:
	if not running or choosing:
		return
	t += delta
	inv -= delta
	pp += move * 235.0 * delta
	pp.x = clampf(pp.x, 20, W - 20)
	pp.y = clampf(pp.y, 150, H - 20)

	# regen from armor passive
	if pas.armor > 0:
		regen_t += delta
		if regen_t >= 1.0:
			regen_t -= 1.0
			hp = minf(maxhp, hp + pas.armor * 0.5)

	_spawn(delta)
	_weapons(delta)
	_move_enemies(delta)
	_pickups(delta)
	queue_redraw()


func _spawn(delta: float) -> void:
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(0.2, 0.85 - t * 0.008)
		var r := randf()
		var typ := "swarm"
		if r < 0.2: typ = "runner"
		elif r < 0.32: typ = "tank"
		elif r < 0.4: typ = "exploder"
		_add_enemy(typ, 1.0)
	boss_t -= delta
	if boss_t <= 0.0:
		boss_t = 45.0
		_add_enemy("boss", 1.0)


func _add_enemy(typ: String, scale: float) -> void:
	var edge := randi() % 4
	var p := Vector2(randf() * W, 120.0)
	if edge == 1: p = Vector2(randf() * W, H)
	elif edge == 2: p = Vector2(0, randf() * H)
	elif edge == 3: p = Vector2(W, randf() * H)
	var base := 2.0 + t * 0.05
	match typ:
		"swarm": enemies.append({"pos": p, "hp": base, "spd": 52.0, "typ": typ, "r": 16.0})
		"runner": enemies.append({"pos": p, "hp": base * 0.7, "spd": 118.0, "typ": typ, "r": 14.0})
		"tank": enemies.append({"pos": p, "hp": base * 4.0, "spd": 34.0, "typ": typ, "r": 24.0})
		"exploder": enemies.append({"pos": p, "hp": base * 1.5, "spd": 70.0, "typ": typ, "r": 18.0})
		"boss": enemies.append({"pos": p, "hp": 60.0 + t * 1.5, "spd": 44.0, "typ": typ, "r": 40.0, "boss": true})


func _weapons(delta: float) -> void:
	# BOLT — projectile at nearest
	if wlv.bolt > 0:
		bolt_t -= delta
		if bolt_t <= 0.0 and not enemies.is_empty():
			bolt_t = (0.55 if not wevo.bolt else 0.28) * _haste()
			var tgt = _nearest()
			if tgt:
				var dmg := (4.0 + wlv.bolt * 2.0) * _might()
				bolts.append({"pos": pp, "vel": (tgt.pos - pp).normalized() * 560.0, "dmg": dmg, "pierce": wevo.bolt})
	# ORBIT — rotating orbs
	orbit_ang += delta * 2.6
	# AURA handled in enemy loop via distance
	# WHIP — periodic horizontal sweep
	if wlv.whip > 0:
		whip_t -= delta
		if whip_t <= 0.0:
			whip_t = (0.9 if not wevo.whip else 0.45) * _haste()
			var reach := (150.0 + wlv.whip * 20.0) * _area()
			var dmg := (6.0 + wlv.whip * 3.0) * _might()
			for en in enemies.duplicate():
				if absf(en.pos.y - pp.y) < 60.0 * _area() and absf(en.pos.x - pp.x) < reach:
					_damage(en, dmg)
	# BOOM — thrown, travels out and back
	if wlv.boom > 0:
		boom_t -= delta
		if boom_t <= 0.0:
			boom_t = (1.1 if not wevo.boom else 0.55) * _haste()
			var n := 1 + (2 if wevo.boom else 0)
			for k in n:
				var dir := Vector2.from_angle(randf() * TAU) if k > 0 else Vector2(0, -1)
				booms.append({"pos": pp, "vel": dir * 340.0, "age": 0.0, "dmg": (5.0 + wlv.boom * 2.0) * _might()})

	# bolts
	for b in bolts.duplicate():
		b.pos += b.vel * delta
		if b.pos.x < -20 or b.pos.x > W + 20 or b.pos.y < 100 or b.pos.y > H + 20:
			bolts.erase(b)
			continue
		for en in enemies.duplicate():
			if b.pos.distance_to(en.pos) < en.r + 4.0:
				_damage(en, b.dmg)
				if not b.pierce:
					bolts.erase(b)
				break
	# booms (return arc)
	for b in booms.duplicate():
		b.age += delta
		if b.age > 0.7:
			b.vel = (pp - b.pos).normalized() * 380.0
		b.pos += b.vel * delta
		if b.age > 1.6:
			booms.erase(b)
			continue
		for en in enemies:
			if b.pos.distance_to(en.pos) < en.r + 10.0:
				_damage(en, b.dmg * delta * 6.0)


func _damage(en: Dictionary, dmg: float) -> void:
	en.hp -= dmg
	if en.hp <= 0.0 and enemies.has(en):
		if en.get("typ") == "exploder" and pp.distance_to(en.pos) < 90.0 and inv <= 0.0:
			hp -= 8.0
			inv = 0.6
		if en.get("boss", false):
			chests.append({"pos": en.pos})
		enemies.erase(en)
		gems.append({"pos": en.pos, "xp": 3 if en.get("boss", false) else 1})
		add_points(1)


func _move_enemies(delta: float) -> void:
	for en in enemies:
		en.pos = en.pos.move_toward(pp, en.spd * delta)
		# aura dot
		if wlv.aura > 0:
			var rad := (70.0 + wlv.aura * 14.0) * _area()
			if pp.distance_to(en.pos) < rad:
				_damage(en, (4.0 + wlv.aura * 2.0) * _might() * delta)
				if wevo.aura and randf() < delta:
					hp = minf(maxhp, hp + 1.0)
		# orbit orbs
		if wlv.orbit > 0:
			var orbs := 1 + wlv.orbit / 2 + (2 if wevo.orbit else 0)
			for k in orbs:
				var oa := orbit_ang + k * TAU / orbs
				var op := pp + Vector2(cos(oa), sin(oa)) * (90.0 * _area())
				if en.pos.distance_to(op) < (30.0 if wevo.orbit else 22.0) * _area():
					_damage(en, (3.0 + wlv.orbit * 1.5) * _might() * delta * 3.0)
		# contact damage to player
		if inv <= 0.0 and en.pos.distance_to(pp) < en.r + 14.0:
			var dmg := 6.0 - pas.armor * 0.6
			if en.get("boss", false):
				dmg = 16.0 - pas.armor
			hp -= maxf(1.0, dmg)
			inv = 0.8
			Juice.flash(Color(1, 0.3, 0.3), 0.2)
			Juice.haptic(25)
			if hp <= 0.0:
				end_demo()
				return


func _pickups(delta: float) -> void:
	for g in gems.duplicate():
		if g.pos.distance_to(pp) < _magnet():
			g.pos = g.pos.move_toward(pp, 460.0 * delta)
		if g.pos.distance_to(pp) < 24.0:
			gems.erase(g)
			xp += maxi(1, int(g.xp * (1.0 + pas.growth * 0.2)))
			if xp >= need:
				level += 1
				xp = 0
				need = 4 + level * 3
				_offer()
	for c in chests.duplicate():
		if c.pos.distance_to(pp) < 30.0:
			chests.erase(c)
			# chest = free level-up
			_offer()


func _nearest():
	var best = null
	var bd := 99999.0
	for en in enemies:
		var d: float = en.pos.distance_to(pp)
		if d < bd:
			bd = d
			best = en
	return best


func _label(o: Dictionary) -> String:
	match o.kind:
		"evo": return "EVOLVE → %s!" % EVO_NAME[o.w]
		"wlv": return "%s  Lv%d→%d" % [o.w.to_upper(), wlv[o.w], wlv[o.w] + 1]
		"wnew": return "NEW WEAPON: %s" % o.w.to_upper()
		"pas": return "%s  Lv%d→%d" % [o.p.capitalize(), pas[o.p], pas[o.p] + 1]
	return ""


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.08, 0.07, 0.1))
	for g in gems:
		draw_circle(g.pos, 7.0, Color(0.4, 0.9, 1.0) if g.xp == 1 else Color(0.9, 0.6, 1.0))
	for c in chests:
		draw_rect(Rect2(c.pos.x - 16, c.pos.y - 12, 32, 24), Color(0.95, 0.8, 0.3))
	for en in enemies:
		var col := Color(0.8, 0.35, 0.35)
		if en.typ == "runner": col = Color(0.9, 0.6, 0.3)
		elif en.typ == "tank": col = Color(0.55, 0.4, 0.5)
		elif en.typ == "exploder": col = Color(0.9, 0.4, 0.6)
		elif en.get("boss", false): col = Color(0.7, 0.2, 0.5)
		draw_circle(en.pos, en.r, col)
	# aura
	if wlv.aura > 0:
		var rad := (70.0 + wlv.aura * 14.0) * _area()
		draw_circle(pp, rad, Color(0.4, 0.8, 1.0, 0.08))
	# orbit
	if wlv.orbit > 0:
		var orbs := 1 + wlv.orbit / 2 + (2 if wevo.orbit else 0)
		for k in orbs:
			var oa := orbit_ang + k * TAU / orbs
			draw_circle(pp + Vector2(cos(oa), sin(oa)) * (90.0 * _area()), (30.0 if wevo.orbit else 22.0) * _area(), Color(0.6, 0.8, 1.0, 0.6))
	for b in bolts:
		draw_circle(b.pos, 6.0, Color(1, 0.95, 0.6) if not b.pierce else Color(0.6, 0.9, 1.0))
	for b in booms:
		draw_circle(b.pos, 12.0, Color(0.9, 0.7, 0.4))
	draw_circle(pp, 15.0, Color.WHITE if inv <= 0.0 else Color(1, 1, 1, 0.4))
	# HUD
	draw_string(f(), Vector2(20, 60), "HP %d   LV %d   %d:%02d" % [int(hp), level, int(t) / 60, int(t) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_rect(Rect2(0, 78, W * float(xp) / float(need), 6), Color(0.4, 0.9, 1.0))
	var wl := ""
	for w in wlv:
		if wlv[w] > 0:
			wl += (EVO_NAME[w] if wevo[w] else w.to_upper()) + " "
	draw_string(f(), Vector2(20, 110), wl, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.7, 0.85, 1.0))
	if choosing:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.65))
		draw_string(f(), Vector2(0, 380), "LEVEL UP", HORIZONTAL_ALIGNMENT_CENTER, W, 44, Color.WHITE)
		for i in choices.size():
			var rr := _opt_rect(i)
			var isevo: bool = choices[i].kind == "evo"
			draw_rect(rr, Color(0.5, 0.4, 0.2) if isevo else Color(0.25, 0.35, 0.5))
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y + 10), _label(choices[i]), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 30, Color.WHITE)
	else:
		draw_string(f(), Vector2(20, H - 16), "drag to move · max a weapon + its passive to EVOLVE", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.5))
