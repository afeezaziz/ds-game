extends MechDemo
## HILL CLIMB — drive over the hills, don't run out of fuel (Hill Climb
## Racing). Hold right half = gas, left half = brake/reverse. Grab fuel cans.
## Score = distance. Desktop: D gas, A brake.

var car_x := 120.0
var speed := 0.0
var fuel := 100.0
var throttle := 0.0
var next_can := 500.0
var can_x := 500.0


func start() -> void:
	super.start()
	car_x = 120.0
	speed = 0.0
	fuel = 100.0
	throttle = 0.0
	next_can = 500.0
	can_x = 500.0
	queue_redraw()


func _gy(x: float) -> float:
	return 840.0 + sin(x * 0.004) * 150.0 + sin(x * 0.013) * 60.0


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		throttle = (1.0 if event.position.x > W * 0.5 else -1.0) if event.pressed else 0.0
	elif event is InputEventScreenDrag:
		throttle = 1.0 if event.position.x > W * 0.5 else -1.0


func _process(delta: float) -> void:
	if not running:
		return
	var t := throttle
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		t = 1.0
	elif Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		t = -1.0
	speed += t * 200.0 * delta
	speed *= 0.99
	speed = clampf(speed, -120.0, 430.0)
	car_x += speed * delta
	car_x = maxf(120.0, car_x)
	fuel -= delta * (0.5 + absf(t) * 1.8)
	set_score(int((car_x - 120.0) / 10.0))

	if car_x > can_x - 30.0 and car_x < can_x + 30.0:
		fuel = minf(100.0, fuel + 35.0)
		Juice.sfx("coin")
		next_can += randf_range(500.0, 900.0)
		can_x = next_can
	elif car_x > can_x + 60.0:
		next_can = car_x + randf_range(500.0, 900.0)
		can_x = next_can

	if fuel <= 0.0:
		Juice.sfx("boom")
		end_demo()
		return
	queue_redraw()


func _sx(worldx: float) -> float:
	return worldx - car_x + 200.0


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.45, 0.62, 0.82))
	var poly := PackedVector2Array()
	poly.append(Vector2(0, H))
	var wx := car_x - 200.0
	while wx < car_x + 600.0:
		poly.append(Vector2(_sx(wx), _gy(wx)))
		wx += 12.0
	poly.append(Vector2(W, H))
	draw_colored_polygon(poly, Color(0.4, 0.55, 0.32))
	# fuel can
	if _sx(can_x) > -40 and _sx(can_x) < W + 40:
		draw_rect(Rect2(_sx(can_x) - 14, _gy(can_x) - 44, 28, 40), Color(0.9, 0.3, 0.3))
	# car
	var cy := _gy(car_x)
	var ang := atan2(_gy(car_x + 12.0) - _gy(car_x - 12.0), 24.0)
	draw_set_transform(Vector2(200, cy - 22), ang, Vector2.ONE)
	draw_rect(Rect2(-40, -22, 80, 34), Color(0.9, 0.75, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_circle(Vector2(200 - 26, cy), 16.0, Color(0.1, 0.1, 0.1))
	draw_circle(Vector2(200 + 26, cy), 16.0, Color(0.1, 0.1, 0.1))
	# fuel gauge
	draw_rect(Rect2(24, 60, 300, 34), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(24, 60, 3.0 * fuel, 34), Color(0.3, 0.85, 0.4) if fuel > 25 else Color(0.9, 0.4, 0.3))
	draw_string(f(), Vector2(24, 130), "FUEL", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_string(f(), Vector2(24, H - 16), "right = gas · left = brake · grab fuel cans",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))
