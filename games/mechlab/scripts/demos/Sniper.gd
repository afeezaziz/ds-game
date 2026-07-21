extends MechDemo
## SNIPER — the mission-shooter loop (Sniper 3D era): drag for fine aim,
## lift your finger without moving to FIRE. Headshots pay double. 8 bullets.

var scope := Vector2(360, 620)
var bullets := 8
var targets: Array = []
var respawn_t := 0.0
var speed_mult := 1.0
var _press_pos := Vector2.ZERO
var _dragged := 0.0
var flash_t := 0.0


func start() -> void:
	super.start()
	scope = Vector2(360, 620)
	bullets = 8
	speed_mult = 1.0
	targets.clear()
	for i in 3:
		_spawn_target(i)
	queue_redraw()


func _spawn_target(lane: int) -> void:
	var y := [430.0, 650.0, 870.0][lane % 3]
	targets.append({"p": Vector2(randf_range(60, 660), y),
		"v": (1.0 if randf() < 0.5 else -1.0) * randf_range(70.0, 130.0),
		"lane": lane % 3})


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press_pos = event.position
			_dragged = 0.0
		else:
			if _dragged < 14.0:
				_fire()
	elif event is InputEventScreenDrag:
		_dragged += event.relative.length()
		scope += event.relative * 0.55
		scope.x = clampf(scope.x, 30.0, W - 30.0)
		scope.y = clampf(scope.y, 300.0, 1000.0)


func _fire() -> void:
	bullets -= 1
	flash_t = 0.1
	var hit := false
	for t in targets.duplicate():
		if scope.distance_to(t.p) < 36.0:
			hit = true
			var headshot: bool = scope.y < t.p.y - 10.0
			add_points(50 if headshot else 25)
			targets.erase(t)
			speed_mult *= 1.12
			respawn_t = 1.2
	if not hit:
		# scatter: everyone runs faster for a moment
		for t in targets:
			t.v *= 1.4
	if bullets <= 0:
		end_demo()


func _process(delta: float) -> void:
	if not running:
		return
	flash_t = maxf(0.0, flash_t - delta)
	for t in targets:
		t.p.x += t.v * speed_mult * delta
		if t.p.x < 50.0:
			t.p.x = 50.0
			t.v = absf(t.v)
		elif t.p.x > W - 50.0:
			t.p.x = W - 50.0
			t.v = -absf(t.v)
	respawn_t -= delta
	if targets.size() < 3 and respawn_t <= 0.0:
		_spawn_target(randi() % 3)
		respawn_t = 1.2
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.07, 0.12))
	# city silhouettes + rooftop lanes
	for i in 3:
		var y := [470.0, 690.0, 910.0][i]
		draw_rect(Rect2(0, y, W, 14), Color(0.15, 0.17, 0.24))
	for t in targets:
		draw_rect(Rect2(t.p.x - 14, t.p.y - 26, 28, 52), Color(0.85, 0.4, 0.35))
		draw_circle(Vector2(t.p.x, t.p.y - 34), 11.0, Color(0.95, 0.75, 0.6))
	# scope
	var c := Color(0.4, 1.0, 0.5) if flash_t <= 0.0 else Color(1, 1, 1)
	draw_arc(scope, 60.0, 0, TAU, 48, c, 3.0)
	draw_arc(scope, 36.0, 0, TAU, 40, Color(c.r, c.g, c.b, 0.5), 2.0)
	draw_line(scope + Vector2(-78, 0), scope + Vector2(78, 0), c, 2.0)
	draw_line(scope + Vector2(0, -78), scope + Vector2(0, 78), c, 2.0)
	draw_string(f(), Vector2(20, 160), "BULLETS %d" % bullets,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.8))
	draw_string(f(), Vector2(20, H - 40), "drag = aim precisely · tap (no drag) = FIRE",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
	draw_string(f(), Vector2(20, H - 12), "above the neck pays double",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
