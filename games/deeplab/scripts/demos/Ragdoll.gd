extends MechDemo
## RAGDOLL FLING — the physics-toy loop (Kick the Buddy / Ragdoll games). Drag
## the ragdoll and release to fling it; bounce off pins for points and fly as
## far as you can. Endless; score = best distance. (Scripted physics — fully
## deterministic gray-box, no rigid-body tuning needed.)

const GY := 1050.0

var pos := Vector2(100, 900)
var vel := Vector2.ZERO
var ang := 0.0
var angvel := 0.0
var launched := false
var resting := false
var best_x := 0.0
var bumpers: Array = []
var press := Vector2.ZERO


func start() -> void:
	super.start()
	best_x = 0.0
	_reset_pos()


func _reset_pos() -> void:
	pos = Vector2(100, 900)
	vel = Vector2.ZERO
	ang = 0.0
	angvel = 0.0
	launched = false
	resting = false
	bumpers = []
	for i in 60:
		bumpers.append({"pos": Vector2(420 + i * 200 + randf_range(-60, 60), randf_range(480, 1000)), "cd": 0.0})
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch):
		return
	if event.pressed:
		if resting:
			_reset_pos()
		elif not launched:
			press = event.position
	elif not launched and not resting:
		var aim: Vector2 = (press - event.position)
		if aim.length() < 20.0:
			return
		vel = aim.limit_length(260.0) * 7.0
		angvel = randf_range(-6.0, 6.0)
		launched = true
		Juice.sfx("thud")


func _process(delta: float) -> void:
	if not running:
		return
	for b in bumpers:
		b.cd -= delta
	if launched:
		vel.y += 1600.0 * delta
		pos += vel * delta
		ang += angvel * delta
		if pos.y > GY:
			pos.y = GY
			vel.y = -vel.y * 0.45
			vel.x *= 0.82
			angvel *= 0.6
		for b in bumpers:
			if b.cd <= 0.0 and pos.distance_to(b.pos) < 58.0:
				var n: Vector2 = (pos - b.pos).normalized()
				vel = vel - 2.0 * vel.dot(n) * n
				vel *= 1.06
				angvel = randf_range(-9.0, 9.0)
				b.cd = 0.4
				add_points(3)
				Juice.sfx("coin")
		best_x = maxf(best_x, pos.x)
		set_score(int(best_x / 12.0))
		if vel.length() < 45.0 and pos.y >= GY - 2.0:
			launched = false
			resting = true
	queue_redraw()


func _sx(wx: float) -> float:
	return wx - maxf(0.0, pos.x - 220.0)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.5, 0.68, 0.85))
	var ox := maxf(0.0, pos.x - 220.0)
	draw_rect(Rect2(0, GY + 30, W, H - GY), Color(0.4, 0.55, 0.32))
	draw_line(Vector2(0, GY + 30), Vector2(W, GY + 30), Color(0.3, 0.4, 0.25), 4.0)
	for b in bumpers:
		var sx := b.pos.x - ox
		if sx > -60 and sx < W + 60:
			draw_circle(Vector2(sx, b.pos.y), 22.0, Color(0.95, 0.7, 0.25))
			draw_circle(Vector2(sx, b.pos.y), 14.0, Color(0.8, 0.5, 0.15))
	# ragdoll: body + head + limbs
	var p := Vector2(_sx(pos.x), pos.y)
	var d := Vector2.from_angle(ang)
	var n := Vector2(-d.y, d.x)
	draw_line(p - d * 22, p + d * 22, Color(0.3, 0.35, 0.55), 12.0)
	draw_line(p - d * 22, p - d * 22 + n * 26, Color(0.3, 0.35, 0.55), 8.0)
	draw_line(p - d * 22, p - d * 22 - n * 26, Color(0.3, 0.35, 0.55), 8.0)
	draw_line(p + d * 22, p + d * 22 + n * 22, Color(0.3, 0.35, 0.55), 8.0)
	draw_line(p + d * 22, p + d * 22 - n * 22, Color(0.3, 0.35, 0.55), 8.0)
	draw_circle(p + d * 34, 18.0, Color(1, 0.82, 0.62))
	if not launched and not resting:
		draw_line(p, Vector2(_sx(press.x) if false else p.x, p.y), Color(1, 1, 1, 0.0), 1.0)
		draw_string(f(), Vector2(20, H - 16), "drag the ragdoll and release to fling",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0, 0, 0, 0.5))
	elif resting:
		draw_string(f(), Vector2(0, 640), "TAP TO RELAUNCH", HORIZONTAL_ALIGNMENT_CENTER, W, 40, Color(1, 1, 0.7))
