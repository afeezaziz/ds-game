extends MechDemo
## BREAKOUT — paddle deflection physics. Drag anywhere to move the paddle.

var px := 360.0
var ball := Vector2(360, 900)
var vel := Vector2(240, -430)
var bricks: Array = []
var speed_mult := 1.0


func start() -> void:
	super.start()
	px = 360.0
	ball = Vector2(360, 900)
	vel = Vector2(240, -430)
	speed_mult = 1.0
	_fill_bricks()
	queue_redraw()


func _fill_bricks() -> void:
	bricks.clear()
	for j in 6:
		for i in 8:
			bricks.append(Rect2(10 + i * 88, 150 + j * 42, 80, 34))


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenDrag or (event is InputEventScreenTouch and event.pressed):
		px = clampf(event.position.x, 85.0, W - 85.0)


func _process(delta: float) -> void:
	if not running:
		return
	ball += vel * speed_mult * delta
	if ball.x < 12.0:
		ball.x = 12.0
		vel.x = absf(vel.x)
	elif ball.x > W - 12.0:
		ball.x = W - 12.0
		vel.x = -absf(vel.x)
	if ball.y < 140.0:
		ball.y = 140.0
		vel.y = absf(vel.y)
	# paddle
	if vel.y > 0.0 and ball.y > 1128.0 and ball.y < 1175.0 and absf(ball.x - px) < 95.0:
		vel.y = -absf(vel.y)
		vel.x = clampf(vel.x + (ball.x - px) * 3.2, -520.0, 520.0)
	# bricks
	for r in bricks:
		if (r as Rect2).grow(11.0).has_point(ball):
			bricks.erase(r)
			add_points(10)
			vel.y = -vel.y
			break
	if bricks.is_empty():
		_fill_bricks()
		speed_mult *= 1.12
		add_points(50)
	if ball.y > H + 20.0:
		end_demo()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 130, W, H - 130), Color(0.08, 0.08, 0.13))
	for r in bricks:
		var rr := r as Rect2
		var row := int((rr.position.y - 150.0) / 42.0)
		draw_rect(rr, Color.from_hsv(fmod(0.0 + row * 0.12, 1.0), 0.6, 0.9))
	draw_rect(Rect2(px - 80, 1140, 160, 22), Color(0.9, 0.9, 1.0))
	draw_circle(ball, 11.0, Color(1, 0.9, 0.4))
	draw_string(f(), Vector2(20, H - 16), "drag to move the paddle",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
