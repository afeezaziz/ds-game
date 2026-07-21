extends MechDemo
## ASTEROIDS — rotate & shoot with drift. Touch anywhere: the ship turns
## toward your finger and auto-fires. Rocks split when shot.

var ship := Vector2(360, 780)
var angle := -PI / 2
var target_angle := -PI / 2
var rocks: Array = []
var bullets: Array = []
var fire_t := 0.0
var spawn_t := 0.0


func start() -> void:
	super.start()
	rocks.clear()
	bullets.clear()
	angle = -PI / 2
	target_angle = angle
	fire_t = 0.0
	spawn_t = 0.6
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch and event.pressed:
		target_angle = (event.position - ship).angle()
	elif event is InputEventScreenDrag:
		target_angle = (event.position - ship).angle()


func _process(delta: float) -> void:
	if not running:
		return
	angle = lerp_angle(angle, target_angle, 7.0 * delta)

	fire_t -= delta
	if fire_t <= 0.0:
		fire_t = 0.22
		var dir := Vector2.from_angle(angle)
		bullets.append({"p": ship + dir * 34.0, "v": dir * 760.0})

	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(0.55, 1.4 - score * 0.004)
		var edge := randi() % 4
		var p := Vector2(randf() * W, -60.0)
		if edge == 1: p = Vector2(randf() * W, H + 60.0)
		elif edge == 2: p = Vector2(-60.0, randf() * H)
		elif edge == 3: p = Vector2(W + 60.0, randf() * H)
		var aim := Vector2(randf_range(160, 560), randf_range(400, 1000))
		rocks.append({"p": p, "v": (aim - p).normalized() * randf_range(60.0, 130.0),
			"r": randf_range(36.0, 58.0)})

	for b in bullets:
		b.p += b.v * delta
	bullets = bullets.filter(func(b): return b.p.x > -20 and b.p.x < W + 20 and b.p.y > -20 and b.p.y < H + 20)

	for r in rocks:
		r.p += r.v * delta
		r.p.x = wrapf(r.p.x, -80.0, W + 80.0)
		r.p.y = wrapf(r.p.y, -80.0, H + 80.0)

	for r in rocks.duplicate():
		if r.p.distance_to(ship) < r.r + 20.0:
			end_demo()
			return
		for b in bullets.duplicate():
			if b.p.distance_to(r.p) < r.r:
				bullets.erase(b)
				rocks.erase(r)
				if r.r > 30.0:
					add_points(5)
					for i in 2:
						rocks.append({"p": r.p, "v": Vector2.from_angle(randf() * TAU) * randf_range(90.0, 170.0),
							"r": r.r * 0.6})
				else:
					add_points(10)
				break

	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.05, 0.05, 0.1))
	for r in rocks:
		draw_circle(r.p, r.r, Color(0.55, 0.5, 0.45))
		draw_circle(r.p, r.r - 6.0, Color(0.35, 0.32, 0.3))
	for b in bullets:
		draw_circle(b.p, 5.0, Color(1, 0.9, 0.4))
	var d := Vector2.from_angle(angle)
	var n := Vector2(-d.y, d.x)
	draw_colored_polygon(PackedVector2Array([
		ship + d * 30.0, ship - d * 18.0 + n * 15.0, ship - d * 18.0 - n * 15.0,
	]), Color(0.85, 0.95, 1.0))
	draw_string(f(), Vector2(20, H - 16), "touch = aim · auto-fire",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
