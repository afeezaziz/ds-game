extends MechDemo
## ARTILLERY — angle-and-power lobbing across terrain, with wind (Worms /
## Scorched Earth). Drag from the cannon to aim, release to fire. Hit the
## flag to score; miss three and you're out.

const STEP := 12
var ground: Array = []   # y for each sample column
var cannon := Vector2(90, 0)
var target_x := 560.0
var wind := 0.0
var proj := Vector2.ZERO
var pvel := Vector2.ZERO
var flying := false
var misses := 0
var aim := Vector2(120, -120)


func start() -> void:
	super.start()
	_terrain()
	cannon = Vector2(90, _ground_y(90) - 20)
	_new_target()
	misses = 0
	flying = false
	queue_redraw()


func _terrain() -> void:
	ground = []
	var base := 1000.0
	var x := 0.0
	while x <= W:
		var y := base + sin(x * 0.006) * 90.0 + sin(x * 0.021) * 40.0
		ground.append(y)
		x += STEP


func _ground_y(px: float) -> float:
	var i := clampi(int(px / STEP), 0, ground.size() - 1)
	return ground[i]


func _new_target() -> void:
	target_x = randf_range(360, 660)
	wind = randf_range(-120.0, 120.0)


func _unhandled_input(event: InputEvent) -> void:
	if not running or flying:
		return
	if event is InputEventScreenDrag or (event is InputEventScreenTouch and event.pressed):
		aim = (event.position - cannon).limit_length(220.0)
	if event is InputEventScreenTouch and not event.pressed:
		flying = true
		proj = cannon
		pvel = aim * 5.5
		Juice.sfx("thud")
	queue_redraw()


func _process(delta: float) -> void:
	if not running or not flying:
		return
	pvel.y += 500.0 * delta
	pvel.x += wind * delta
	proj += pvel * delta
	if proj.x < 0 or proj.x > W or proj.y > H:
		_miss()
	elif proj.y >= _ground_y(proj.x):
		if absf(proj.x - target_x) < 42.0:
			add_points(1)
			Juice.sfx("chime")
			Juice.flash(Color(1, 0.9, 0.5), 0.2)
			flying = false
			_new_target()
		else:
			_miss()
	queue_redraw()


func _miss() -> void:
	flying = false
	misses += 1
	Juice.sfx("boom")
	if misses >= 3:
		end_demo()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.4, 0.6, 0.8))
	var poly := PackedVector2Array()
	poly.append(Vector2(0, H))
	for i in ground.size():
		poly.append(Vector2(i * STEP, ground[i]))
	poly.append(Vector2(W, H))
	draw_colored_polygon(poly, Color(0.35, 0.5, 0.3))
	draw_rect(Rect2(cannon.x - 18, cannon.y - 12, 36, 30), Color(0.3, 0.3, 0.35))
	var ty := _ground_y(target_x)
	draw_line(Vector2(target_x, ty), Vector2(target_x, ty - 60), Color(0.9, 0.9, 0.9), 4.0)
	draw_colored_polygon(PackedVector2Array([Vector2(target_x, ty - 60),
		Vector2(target_x + 40, ty - 48), Vector2(target_x, ty - 36)]), Color(0.9, 0.3, 0.3))
	if not flying:
		draw_line(cannon, cannon + aim, Color(1, 1, 1, 0.6), 3.0)
	if flying:
		draw_circle(proj, 10.0, Color(0.1, 0.1, 0.1))
	var wtxt := "WIND %s%d" % [">" if wind > 0 else "<", int(absf(wind))]
	draw_string(f(), Vector2(20, 60), wtxt, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(1, 1, 1, 0.9))
	draw_string(f(), Vector2(20, 100), "MISSES %d/3" % misses, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.6, 0.6))
	draw_string(f(), Vector2(20, H - 16), "drag from the cannon, release to fire",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))
