extends MechDemo
## BOSS BULLET-HELL — dodge the boss's telegraphed patterns while your ship
## auto-fires up. Deplete its HP to face a harder boss with a new pattern.
## Three hits and you're out. Score = bosses downed. Drag to move.

var pp := Vector2(360, 1050)
var lives := 3
var inv := 0.0
var pb: Array = []       # player bullets {pos}
var eb: Array = []       # enemy bullets {pos, vel}
var fire_t := 0.0
var boss := Vector2(360, 260)
var bhp := 100
var bmax := 100
var pattern := 0
var bosses := 0
var spawn_t := 0.0
var spiral := 0.0
var bdir := 1.0


func start() -> void:
	super.start()
	pp = Vector2(360, 1050)
	lives = 3
	inv = 0.0
	pb = []
	eb = []
	boss = Vector2(360, 260)
	bhp = 100
	bmax = 100
	pattern = 0
	bosses = 0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenDrag:
		pp += event.relative
	elif event is InputEventScreenTouch and event.pressed:
		pp = event.position
	pp.x = clampf(pp.x, 20, W - 20)
	pp.y = clampf(pp.y, 700, H - 20)


func _process(delta: float) -> void:
	if not running:
		return
	inv -= delta
	# player auto-fire
	fire_t -= delta
	if fire_t <= 0.0:
		fire_t = 0.12
		pb.append({"pos": pp + Vector2(0, -30)})
	for b in pb.duplicate():
		b.pos.y -= 900.0 * delta
		if b.pos.y < 0:
			pb.erase(b)
			continue
		if b.pos.distance_to(boss) < 46.0:
			pb.erase(b)
			bhp -= 2
			if bhp <= 0:
				_next_boss()
				return

	# boss movement
	boss.x += bdir * 90.0 * delta
	if boss.x < 120 or boss.x > W - 120:
		bdir *= -1.0

	# boss patterns
	spawn_t -= delta
	if pattern == 0:
		if spawn_t <= 0.0:
			spawn_t = 0.9
			for i in range(-3, 4):
				eb.append({"pos": boss, "vel": Vector2(i * 70.0, 260.0)})
	elif pattern == 1:
		if spawn_t <= 0.0:
			spawn_t = 0.5
			var d := (pp - boss).normalized()
			for k in [-0.2, 0.0, 0.2]:
				eb.append({"pos": boss, "vel": d.rotated(k) * 320.0})
	else:
		if spawn_t <= 0.0:
			spawn_t = 0.06
			spiral += 0.4
			eb.append({"pos": boss, "vel": Vector2.from_angle(spiral) * 240.0})

	for b in eb.duplicate():
		b.pos += b.vel * delta
		if b.pos.x < -20 or b.pos.x > W + 20 or b.pos.y < -20 or b.pos.y > H + 20:
			eb.erase(b)
			continue
		if inv <= 0.0 and b.pos.distance_to(pp) < 22.0:
			eb.erase(b)
			lives -= 1
			inv = 1.2
			Juice.flash(Color(1, 0.3, 0.3), 0.3)
			Juice.haptic(40)
			if lives <= 0:
				end_demo()
				return
	queue_redraw()


func _next_boss() -> void:
	add_points(1)
	bosses += 1
	pattern = bosses % 3
	bmax = 100 + bosses * 40
	bhp = bmax
	eb = []
	Juice.sfx("chime")
	Juice.flash(Color(0.9, 0.7, 0.4), 0.3)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.06, 0.1))
	# boss
	draw_circle(boss, 46.0, Color(0.8, 0.3, 0.4))
	draw_rect(Rect2(160, 150, 400, 20), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(160, 150, 400 * clampf(float(bhp) / float(bmax), 0, 1), 20), Color(0.9, 0.35, 0.4))
	draw_string(f(), Vector2(160, 140), "BOSS %d   pattern: %s" % [bosses + 1, ["spread", "aimed", "spiral"][pattern]], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	for b in eb:
		draw_circle(b.pos, 8.0, Color(1, 0.6, 0.3))
	for b in pb:
		draw_circle(b.pos, 5.0, Color(0.6, 0.9, 1.0))
	var pc := Color(0.5, 0.9, 1.0) if inv <= 0.0 else Color(1, 1, 1, 0.4)
	draw_colored_polygon(PackedVector2Array([pp + Vector2(0, -20), pp + Vector2(-16, 16), pp + Vector2(16, 16)]), pc)
	draw_string(f(), Vector2(20, 70), "LIVES " + "* ".repeat(lives), HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 0.5, 0.5))
	draw_string(f(), Vector2(20, H - 16), "drag to move · you auto-fire",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
