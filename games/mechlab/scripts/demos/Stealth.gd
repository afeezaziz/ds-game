extends MechDemo
## STEALTH — reach the exit without entering a guard's vision cone (Metal Gear,
## 2D). Drag to steer; a cone or a guard's touch = caught. Each exit reached
## adds a faster guard. Score = exits reached.

var player := Vector2(360, 1180)
var goal := Vector2(360, 140)
var guards: Array = []
var level := 0
var target := Vector2(360, 1180)


func start() -> void:
	super.start()
	level = 0
	_setup()
	queue_redraw()


func _setup() -> void:
	player = Vector2(360, 1180)
	target = player
	guards = []
	for i in 2 + level:
		var y := 320.0 + i * 150.0
		guards.append({"pos": Vector2(randf_range(120, 600), y), "dir": 1.0,
			"y": y, "spd": 120.0 + level * 20.0, "facing": Vector2(1, 0)})


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if (event is InputEventScreenTouch and event.pressed) or event is InputEventScreenDrag:
		target = event.position


func _process(delta: float) -> void:
	if not running:
		return
	# keyboard nudge
	target += Vector2(key_x(), key_y()) * 260.0 * delta
	player = player.move_toward(target, 320.0 * delta)
	player.x = clampf(player.x, 20, W - 20)
	player.y = clampf(player.y, 20, H - 20)

	for g in guards:
		g.pos.x += g.dir * g.spd * delta
		if g.pos.x < 100 or g.pos.x > 620:
			g.dir *= -1.0
			g.pos.x = clampf(g.pos.x, 100, 620)
		g.facing = Vector2(g.dir, 0)
		if player.distance_to(g.pos) < 34.0:
			_caught()
			return
		var v := player - g.pos
		if v.length() < 320.0:
			var ang := rad_to_deg(absf(v.normalized().angle_to(g.facing)))
			if ang < 30.0:
				_caught()
				return

	if player.distance_to(goal) < 40.0:
		add_points(1)
		level += 1
		Juice.sfx("chime")
		_setup()
	queue_redraw()


func _caught() -> void:
	Juice.sfx("boom")
	Juice.haptic(50)
	end_demo()


func key_x() -> float:
	var v := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v += 1.0
	return v


func key_y() -> float:
	var v := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v += 1.0
	return v


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.11, 0.14))
	draw_circle(goal, 40.0, Color(0.3, 0.85, 0.4, 0.6))
	draw_string(f(), Vector2(goal.x - 40, goal.y + 8), "EXIT", HORIZONTAL_ALIGNMENT_CENTER, 80, 26, Color.WHITE)
	for g in guards:
		var left := g.facing.rotated(deg_to_rad(30)) * 320.0
		var right := g.facing.rotated(deg_to_rad(-30)) * 320.0
		draw_colored_polygon(PackedVector2Array([g.pos, g.pos + left, g.pos + right]),
			Color(1, 0.3, 0.3, 0.18))
		draw_circle(g.pos, 18.0, Color(0.3, 0.4, 0.95))
	draw_circle(player, 16.0, Color(0.95, 0.9, 0.5))
	draw_string(f(), Vector2(20, 60), "reach EXIT · avoid the red cones",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.6))
