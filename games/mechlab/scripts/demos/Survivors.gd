extends MechDemo
## SURVIVORS — the Vampire Survivors loop (2022): you only move; weapons
## auto-fire; swarms grow; XP gems level you up and you pick 1 of 3 upgrades.
## The hottest single-player mechanic of the 2020s.

var ppos := Vector2(360, 700)
var php := 5.0
var maxhp := 5.0
var inv := 0.0
var t := 0.0

var stick_on := false
var stick_origin := Vector2.ZERO
var move := Vector2.ZERO

var enemies: Array = []
var bullets: Array = []
var gems: Array = []
var spawn_t := 0.0
var fire_t := 0.0

var dmg := 1.0
var fire_cd := 0.55
var speed := 250.0
var pickup := 95.0

var xp := 0
var level := 1
var next_xp := 5
var choosing := false
var choices: Array = []

const UPGRADES := [
	["+70% DAMAGE", "dmg"], ["FASTER FIRE", "rate"], ["+MOVE SPEED", "spd"],
	["+1 MAX HP, FULL HEAL", "hp"], ["BIGGER MAGNET", "mag"],
]


func start() -> void:
	super.start()
	ppos = Vector2(360, 700)
	maxhp = 5.0
	php = maxhp
	inv = 0.0
	t = 0.0
	move = Vector2.ZERO
	stick_on = false
	enemies.clear()
	bullets.clear()
	gems.clear()
	spawn_t = 0.5
	fire_t = 0.0
	dmg = 1.0
	fire_cd = 0.55
	speed = 250.0
	pickup = 95.0
	xp = 0
	level = 1
	next_xp = 5
	choosing = false
	queue_redraw()


func _choice_rect(i: int) -> Rect2:
	return Rect2(90, 420 + i * 160, 540, 130)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if choosing:
		if event is InputEventScreenTouch and event.pressed:
			for i in choices.size():
				if _choice_rect(i).has_point(event.position):
					_apply(choices[i][1])
					choosing = false
					return
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			stick_on = true
			stick_origin = event.position
			move = Vector2.ZERO
		else:
			stick_on = false
			move = Vector2.ZERO
	elif event is InputEventScreenDrag and stick_on:
		move = ((event.position - stick_origin) / 70.0).limit_length(1.0)


func _apply(code: String) -> void:
	match code:
		"dmg": dmg *= 1.7
		"rate": fire_cd *= 0.8
		"spd": speed += 40.0
		"hp":
			maxhp += 1.0
			php = maxhp
		"mag": pickup += 55.0


func _process(delta: float) -> void:
	if not running or choosing:
		return
	t += delta
	inv -= delta
	fire_t -= delta
	spawn_t -= delta

	ppos += move * speed * delta
	ppos.x = clampf(ppos.x, 30.0, W - 30.0)
	ppos.y = clampf(ppos.y, 150.0, H - 30.0)

	if spawn_t <= 0.0:
		spawn_t = maxf(0.22, 0.95 - t * 0.012)
		var edge := randi() % 4
		var p := Vector2(randf() * W, 120.0)
		if edge == 1: p = Vector2(randf() * W, H + 30.0)
		elif edge == 2: p = Vector2(-30.0, randf_range(120.0, H))
		elif edge == 3: p = Vector2(W + 30.0, randf_range(120.0, H))
		enemies.append({"p": p, "hp": 1.0 + t * 0.055, "spd": randf_range(55.0, 75.0) + t * 1.1})

	for e in enemies:
		e.p += (ppos - e.p).normalized() * e.spd * delta
		if inv <= 0.0 and e.p.distance_to(ppos) < 34.0:
			php -= 1.0
			inv = 0.8
			if php <= 0.0:
				end_demo()
				return

	if fire_t <= 0.0 and not enemies.is_empty():
		fire_t = fire_cd
		var best = null
		var bd := 999999.0
		for e in enemies:
			var d2: float = e.p.distance_to(ppos)
			if d2 < bd:
				bd = d2
				best = e
		bullets.append({"p": ppos, "v": (best.p - ppos).normalized() * 540.0})

	for b in bullets.duplicate():
		b.p += b.v * delta
		if b.p.x < -20 or b.p.x > W + 20 or b.p.y < 100 or b.p.y > H + 20:
			bullets.erase(b)
			continue
		for e in enemies.duplicate():
			if b.p.distance_to(e.p) < 22.0:
				bullets.erase(b)
				e.hp -= dmg
				if e.hp <= 0.0:
					enemies.erase(e)
					add_points(1)
					gems.append({"p": e.p})
				break

	for g in gems.duplicate():
		var d3: float = g.p.distance_to(ppos)
		if d3 < pickup:
			g.p += (ppos - g.p).normalized() * 430.0 * delta
		if d3 < 26.0:
			gems.erase(g)
			xp += 1
			if xp >= next_xp:
				level += 1
				xp = 0
				next_xp = 4 + level * 3
				choices = []
				var pool := UPGRADES.duplicate()
				pool.shuffle()
				choices = pool.slice(0, 3)
				choosing = true
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.08, 0.07, 0.1))
	for g in gems:
		draw_circle(g.p, 8.0, Color(0.4, 0.9, 1.0))
	for e in enemies:
		draw_circle(e.p, 20.0, Color(0.8, 0.25, 0.3))
		draw_circle(e.p, 11.0, Color(0.5, 0.12, 0.18))
	for b in bullets:
		draw_circle(b.p, 6.0, Color(1, 0.95, 0.6))
	var pc := Color(1, 1, 1) if inv <= 0.0 else Color(1, 1, 1, 0.45)
	draw_circle(ppos, 18.0, pc)
	for i in int(maxhp):
		draw_rect(Rect2(24 + i * 30, 132, 24, 12),
			Color(0.9, 0.3, 0.3) if i < int(php) else Color(1, 1, 1, 0.15))
	draw_string(f(), Vector2(W - 240, 150), "LV %d  %d:%02d" % [level, int(t) / 60, int(t) % 60],
		HORIZONTAL_ALIGNMENT_RIGHT, 220, 26, Color(1, 1, 1, 0.7))
	draw_rect(Rect2(0, 118, W * (float(xp) / float(next_xp)), 6.0), Color(0.4, 0.9, 1.0))
	if choosing:
		draw_rect(Rect2(0, 0, W, H), Color(0, 0, 0, 0.6))
		draw_string(f(), Vector2(0, 380), "LEVEL UP — CHOOSE",
			HORIZONTAL_ALIGNMENT_CENTER, W, 40, Color.WHITE)
		for i in choices.size():
			var r := _choice_rect(i)
			draw_rect(r, Color(0.2, 0.3, 0.45))
			draw_string(f(), Vector2(r.position.x, r.position.y + 78), choices[i][0],
				HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Color.WHITE)
	else:
		draw_string(f(), Vector2(20, H - 16), "drag = move · everything else is automatic",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
