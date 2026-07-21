extends MechDemo
## FLAPPY — one-tap gravity flight through gaps. The 2013 mobile icon.

var bird_y := 600.0
var vy := 0.0
var pipes: Array = []
var spawn_t := 0.0


func start() -> void:
	super.start()
	bird_y = 600.0
	vy = 0.0
	pipes.clear()
	spawn_t = 0.9
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if running and event is InputEventScreenTouch and event.pressed:
		vy = -520.0


func _process(delta: float) -> void:
	if not running:
		return
	vy += 1400.0 * delta
	bird_y += vy * delta

	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = 1.55
		pipes.append({"x": W + 70.0, "gap": randf_range(300.0, H - 380.0), "passed": false})

	for p in pipes:
		p.x -= 250.0 * delta
		if not p.passed and p.x < 160.0:
			p.passed = true
			add_points(1)
		if absf(p.x - 160.0) < 62.0 and (bird_y < p.gap - 150.0 or bird_y > p.gap + 150.0):
			end_demo()
			return
	pipes = pipes.filter(func(p): return p.x > -80.0)

	if bird_y > H - 30.0 or bird_y < -40.0:
		end_demo()
		return
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.35, 0.65, 0.85))
	for p in pipes:
		draw_rect(Rect2(p.x - 52.0, 0, 104.0, p.gap - 150.0), Color(0.3, 0.75, 0.35))
		draw_rect(Rect2(p.x - 52.0, p.gap + 150.0, 104.0, H - p.gap - 150.0), Color(0.3, 0.75, 0.35))
	draw_rect(Rect2(0, H - 26.0, W, 26.0), Color(0.75, 0.65, 0.4))
	draw_circle(Vector2(160.0, bird_y), 26.0, Color(1, 0.85, 0.25))
	draw_circle(Vector2(172.0, bird_y - 6.0), 5.0, Color(0.1, 0.1, 0.1))
	draw_string(f(), Vector2(20, H - 42), "tap to flap",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0, 0, 0, 0.4))
