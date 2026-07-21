extends MechDemo
## DASH RUN — the Geometry Dash loop: an auto-running cube, one tap to jump,
## spikes that end everything. Precision + rhythm + rage-retry.

const GROUND := 1040.0
const PX := 180.0

var py := GROUND
var vy := 0.0
var rot := 0.0
var x_off := 0.0
var speed := 380.0
var spikes: Array = []
var next_x := 900.0


func start() -> void:
	super.start()
	py = GROUND
	vy = 0.0
	rot = 0.0
	x_off = 0.0
	speed = 380.0
	spikes.clear()
	next_x = 900.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch and event.pressed and py >= GROUND - 1.0:
		vy = -820.0


func _process(delta: float) -> void:
	if not running:
		return
	x_off += speed * delta
	speed = minf(560.0, speed + delta * 3.0)
	set_score(int(x_off / 100.0))

	vy += 2500.0 * delta
	py += vy * delta
	if py >= GROUND:
		py = GROUND
		vy = 0.0
		rot = 0.0
	else:
		rot += 7.0 * delta

	while next_x < x_off + W + 200.0:
		var cluster := 1 + randi() % 3
		for i in cluster:
			spikes.append(next_x + i * 46.0)
		next_x += cluster * 46.0 + randf_range(320.0, 560.0) + speed * 0.25

	spikes = spikes.filter(func(sx): return sx > x_off - 100.0)
	for sx in spikes:
		var screen_x: float = sx - x_off + PX
		if absf(screen_x - PX) < 34.0 and py > GROUND - 44.0:
			end_demo()
			return
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.08, 0.16))
	# parallax stripes
	for i in 6:
		var lx := fmod(-x_off * 0.3 + i * 160.0, W + 160.0)
		draw_rect(Rect2(lx, 200, 3, GROUND - 200), Color(1, 1, 1, 0.04))
	draw_rect(Rect2(0, GROUND + 22, W, H - GROUND), Color(0.16, 0.13, 0.26))
	draw_line(Vector2(0, GROUND + 22), Vector2(W, GROUND + 22), Color(0.5, 0.4, 0.9), 3.0)
	for sx in spikes:
		var screen_x: float = sx - x_off + PX
		if screen_x > -60.0 and screen_x < W + 60.0:
			draw_colored_polygon(PackedVector2Array([
				Vector2(screen_x - 22, GROUND + 22), Vector2(screen_x + 22, GROUND + 22),
				Vector2(screen_x, GROUND - 24)]), Color(0.9, 0.35, 0.45))
	# the cube
	draw_set_transform(Vector2(PX, py - 1.0), rot, Vector2.ONE)
	draw_rect(Rect2(-22, -44, 44, 44), Color(0.4, 0.9, 1.0))
	draw_rect(Rect2(-12, -34, 10, 10), Color(0.1, 0.2, 0.3))
	draw_rect(Rect2(4, -34, 10, 10), Color(0.1, 0.2, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(f(), Vector2(20, H - 16), "tap to jump · score = distance",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
