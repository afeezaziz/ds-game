extends MechDemo
## SLINGSHOT — drag-aim ballistic launch at stacked targets. 12 shots.

const ANCHOR := Vector2(150.0, 1000.0)
const GROUND := 1080.0

var ball := ANCHOR
var vel := Vector2.ZERO
var flying := false
var aiming := false
var shots := 12
var targets: Array = []


func start() -> void:
	super.start()
	ball = ANCHOR
	flying = false
	aiming = false
	shots = 12
	_spawn_targets()
	queue_redraw()


func _spawn_targets() -> void:
	targets.clear()
	var bx := randf_range(420.0, 600.0)
	targets.append(Rect2(bx - 76.0, GROUND - 70.0, 70.0, 70.0))
	targets.append(Rect2(bx + 6.0, GROUND - 70.0, 70.0, 70.0))
	targets.append(Rect2(bx - 35.0, GROUND - 142.0, 70.0, 70.0))


func _unhandled_input(event: InputEvent) -> void:
	if not running or flying:
		return
	if event is InputEventScreenTouch:
		if event.pressed and event.position.distance_to(ball) < 130.0:
			aiming = true
		elif not event.pressed and aiming:
			aiming = false
			vel = (ANCHOR - ball) * 6.5
			vel = vel.limit_length(1500.0)
			flying = true
			shots -= 1
	elif event is InputEventScreenDrag and aiming:
		ball = ANCHOR + (event.position - ANCHOR).limit_length(240.0)
	queue_redraw()


func _process(delta: float) -> void:
	if not running or not flying:
		return
	vel.y += 1000.0 * delta
	ball += vel * delta
	for t in targets.duplicate():
		if (t as Rect2).grow(14.0).has_point(ball):
			targets.erase(t)
			add_points(25)
			if targets.is_empty():
				add_points(50)
				_spawn_targets()
	if ball.y > GROUND and vel.length() < 220.0:
		_reset_shot()
	elif ball.y > H + 60.0 or ball.x > W + 60.0 or ball.x < -60.0:
		_reset_shot()
	elif ball.y > GROUND:
		ball.y = GROUND
		vel.y = -vel.y * 0.5
		vel.x *= 0.8
	queue_redraw()


func _reset_shot() -> void:
	flying = false
	ball = ANCHOR
	vel = Vector2.ZERO
	if shots <= 0:
		end_demo()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.45, 0.7, 0.9))
	draw_rect(Rect2(0, GROUND, W, H - GROUND), Color(0.4, 0.6, 0.3))
	draw_rect(Rect2(ANCHOR.x - 8.0, GROUND - 90.0, 16.0, 90.0), Color(0.4, 0.25, 0.15))
	if aiming or not flying:
		draw_line(Vector2(ANCHOR.x - 8.0, ANCHOR.y - 80.0), ball, Color(0.3, 0.2, 0.15), 6.0)
		draw_line(Vector2(ANCHOR.x + 8.0, ANCHOR.y - 80.0), ball, Color(0.3, 0.2, 0.15), 6.0)
	for t in targets:
		draw_rect(t, Color(0.75, 0.55, 0.3))
		draw_rect((t as Rect2).grow(-10.0), Color(0.6, 0.42, 0.22))
	draw_circle(ball, 22.0, Color(0.85, 0.2, 0.2))
	draw_string(f(), Vector2(20, 150), "SHOTS %d" % shots,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.9))
	draw_string(f(), Vector2(20, H - 16), "drag the ball back, release to launch",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0, 0, 0, 0.4))
