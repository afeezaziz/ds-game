extends MechDemo
## SURVIVE EVO — the Vampire Survivors depth layer: auto-fighting swarm, but
## weapons LEVEL UP and EVOLVE at max into stronger forms. Drag to move; pick an
## upgrade each level. Three hits and you're out. Score = kills.

var pp := Vector2(360, 700)
var hp := 3
var inv := 0.0
var move := Vector2.ZERO
var stick := false
var origin := Vector2.ZERO
var enemies: Array = []
var bolts: Array = []
var gems: Array = []
var spawn_t := 0.0
var xp := 0
var level := 1
var next_xp := 5
var choosing := false
var choices: Array = []

# weapons: bolt (projectile), orb (orbiting). level 0 = not owned.
var bolt_lv := 1
var orb_lv := 0
var bolt_evo := false
var orb_evo := false
var bolt_t := 0.0
var orb_ang := 0.0
var t := 0.0


func start() -> void:
	super.start()
	pp = Vector2(360, 700)
	hp = 3
	inv = 0.0
	enemies = []
	bolts = []
	gems = []
	spawn_t = 0.5
	xp = 0
	level = 1
	next_xp = 5
	choosing = false
	bolt_lv = 1
	orb_lv = 0
	bolt_evo = false
	orb_evo = false
	t = 0.0
	queue_redraw()


func _opt_rect(i: int) -> Rect2:
	return Rect2(90, 500 + i * 150, 540, 130)


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


func _apply(code: String) -> void:
	match code:
		"bolt":
			bolt_lv += 1
			if bolt_lv >= 5 and not bolt_evo:
				bolt_evo = true
		"orb":
			orb_lv += 1
			if orb_lv >= 5 and not orb_evo:
				orb_evo = true
		"hp":
			hp += 1
	Juice.sfx("chime")


func _offer() -> void:
	var pool := ["bolt", "hp"]
	if orb_lv == 0:
		pool.append("orb")
	else:
		pool.append("orb")
		pool.append("orb")
	pool.shuffle()
	choices = []
	for c in pool:
		if not choices.has(c) or c == "orb":
			choices.append(c)
		if choices.size() >= 3:
			break
	while choices.size() < 3:
		choices.append("hp")
	choosing = true


func _process(delta: float) -> void:
	if not running or choosing:
		return
	t += delta
	inv -= delta
	var mv := move
	pp += mv * 240.0 * delta
	pp.x = clampf(pp.x, 20, W - 20)
	pp.y = clampf(pp.y, 150, H - 20)

	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(0.25, 0.9 - t * 0.01)
		var edge := randi() % 4
		var p := Vector2(randf() * W, 120.0)
		if edge == 1: p = Vector2(randf() * W, H)
		elif edge == 2: p = Vector2(0, randf() * H)
		elif edge == 3: p = Vector2(W, randf() * H)
		enemies.append({"pos": p, "hp": 1.0 + t * 0.05})

	# bolt weapon
	bolt_t -= delta
	if bolt_t <= 0.0 and not enemies.is_empty():
		bolt_t = 0.5 if not bolt_evo else 0.22
		var tgt = _nearest()
		if tgt:
			bolts.append({"pos": pp, "vel": (tgt.pos - pp).normalized() * 560.0, "pierce": bolt_evo, "dmg": bolt_lv * (2.0 if bolt_evo else 1.0)})

	# orb weapon
	orb_ang += delta * (2.5 if not orb_evo else 3.5)

	for e in enemies:
		e.pos = e.pos.move_toward(pp, (55.0 + t) * delta)
		if inv <= 0.0 and e.pos.distance_to(pp) < 30.0:
			hp -= 1
			inv = 0.9
			Juice.flash(Color(1, 0.3, 0.3), 0.25)
			Juice.haptic(30)
			if hp <= 0:
				end_demo()
				return
		# orb damage
		if orb_lv > 0:
			for k in (2 if orb_evo else 1):
				var oa := orb_ang + k * PI
				var op := pp + Vector2(cos(oa), sin(oa)) * 90.0
				if e.pos.distance_to(op) < (34.0 if orb_evo else 26.0):
					e.hp -= orb_lv * 3.0 * delta

	for b in bolts.duplicate():
		b.pos += b.vel * delta
		if b.pos.x < -20 or b.pos.x > W + 20 or b.pos.y < 100 or b.pos.y > H + 20:
			bolts.erase(b)
			continue
		for e in enemies.duplicate():
			if b.pos.distance_to(e.pos) < 22.0:
				e.hp -= b.dmg
				if not b.pierce:
					bolts.erase(b)
				if e.hp <= 0:
					enemies.erase(e)
					gems.append({"pos": e.pos})
					add_points(1)
				break

	for e in enemies.duplicate():
		if e.hp <= 0:
			enemies.erase(e)
			gems.append({"pos": e.pos})
			add_points(1)

	for g in gems.duplicate():
		if g.pos.distance_to(pp) < 90.0:
			g.pos = g.pos.move_toward(pp, 420.0 * delta)
		if g.pos.distance_to(pp) < 24.0:
			gems.erase(g)
			xp += 1
			if xp >= next_xp:
				level += 1
				xp = 0
				next_xp = 4 + level * 3
				_offer()
	queue_redraw()


func _nearest():
	var best = null
	var bd := 99999.0
	for e in enemies:
		var d: float = e.pos.distance_to(pp)
		if d < bd:
			bd = d
			best = e
	return best


func _label(code: String) -> String:
	match code:
		"bolt":
			return "RAILGUN (evolve!)" if bolt_lv == 4 else "BOLT +1 (lv %d)" % (bolt_lv + 1)
		"orb":
			if orb_lv == 0:
				return "NEW: ORBIT"
			return "SATURN (evolve!)" if orb_lv == 4 else "ORBIT +1 (lv %d)" % (orb_lv + 1)
		_:
			return "+1 MAX HP"


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.08, 0.07, 0.1))
	for g in gems:
		draw_circle(g.pos, 7.0, Color(0.4, 0.9, 1.0))
	for e in enemies:
		draw_circle(e.pos, 18.0, Color(0.8, 0.3, 0.35))
	for b in bolts:
		draw_circle(b.pos, 6.0, Color(1, 0.95, 0.6) if not b.pierce else Color(0.6, 0.9, 1.0))
	if orb_lv > 0:
		for k in (2 if orb_evo else 1):
			var oa := orb_ang + k * PI
			draw_circle(pp + Vector2(cos(oa), sin(oa)) * 90.0, 34.0 if orb_evo else 24.0, Color(0.6, 0.8, 1.0, 0.6))
	draw_circle(pp, 16.0, Color.WHITE if inv <= 0.0 else Color(1, 1, 1, 0.4))
	draw_string(f(), Vector2(20, 130), "HP %d   LV %d   time %d:%02d" % [hp, level, int(t) / 60, int(t) % 60], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_rect(Rect2(0, 118, W * float(xp) / float(next_xp), 6), Color(0.4, 0.9, 1.0))
	if choosing:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
		draw_string(f(), Vector2(0, 440), "LEVEL UP — CHOOSE", HORIZONTAL_ALIGNMENT_CENTER, W, 40, Color.WHITE)
		for i in choices.size():
			var rr := _opt_rect(i)
			draw_rect(rr, Color(0.25, 0.35, 0.5))
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y + 12), _label(choices[i]), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 28, Color.WHITE)
	else:
		draw_string(f(), Vector2(20, H - 16), "drag to move · weapons are automatic", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
