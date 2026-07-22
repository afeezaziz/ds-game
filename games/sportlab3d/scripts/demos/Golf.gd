extends MechDemo3D
## GOLF — aim, read the slope, sink it. Rotate the aim with the stick, HOLD SWING to
## fill the power meter and release to strike; the ball arcs, lands and ROLLS, and
## the green's slopes nudge it. Sink in par to bank strokes; run the stroke bank dry
## and it's over. Desktop: A/D aim, SPACE hold-to-swing.

var ball: Node3D
var bpos := Vector3(0, 0.3, 16)
var bvel := Vector3.ZERO
var rolling := false
var aim := 0.0
var power := 0.0
var charging := false
var hole := Vector3(0, 0, -18)
var flag: Node3D
var hills: Array = []          # {pos,radius,strength}
var strokes_left := 24
var hole_strokes := 0
var holes := 0
var aim_line: Node3D
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.72, 0.9), 0.95)
	static_box(Vector3(60, 1, 70), Vector3(0, -0.5, 0), Color(0.35, 0.62, 0.35))
	ball = mesh_sphere(0.4, Vector3.ZERO, Color.WHITE)
	flag = Node3D.new()
	add_child(flag)
	mesh_cyl(0.08, 3.0, Vector3(0, 1.5, 0), Color(0.9, 0.9, 0.9), flag)
	mesh_box(Vector3(1.2, 0.7, 0.05), Vector3(0.6, 2.6, 0), Color(1, 0.3, 0.3), flag)
	aim_line = mesh_box(Vector3(0.15, 0.05, 6.0), Vector3.ZERO, Color(1, 1, 0.4, 0.6))
	strokes_left = 24
	holes = 0
	hills = []
	make_camera(Vector3(0, 14, 26), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 9, 0), 34, Color.WHITE)
	tc = add_touch_controls([{"id": "swing", "label": "SWING", "col": Color(0.5, 0.85, 0.5)}])
	tc.action.connect(func(_id): charging = true)
	tc.released.connect(func(_id): _swing())
	_new_hole()


func _new_hole() -> void:
	bpos = Vector3(0, 0.3, 16)
	bvel = Vector3.ZERO
	rolling = false
	hole_strokes = 0
	hole = Vector3(randf_range(-16, 16), 0, randf_range(-24, -10))
	flag.position = hole
	# rebuild slope field
	for h in hills:
		h.node.queue_free()
	hills = []
	for i in 3:
		var p := Vector3(randf_range(-18, 18), 0, randf_range(-20, 12))
		var r := randf_range(5, 9)
		var s := randf_range(-1.0, 1.0)
		var node := mesh_cyl(r, 0.4, p + Vector3(0, 0.2, 0), Color(0.3, 0.55, 0.3) if s < 0 else Color(0.45, 0.68, 0.42))
		hills.append({"pos": p, "radius": r, "strength": s, "node": node})


func _swing() -> void:
	if not charging or rolling:
		charging = false
		return
	charging = false
	var dir := Vector3(sin(aim), 0, -cos(aim))
	bvel = dir * (power * 26.0) + Vector3(0, power * 10.0, 0)
	power = 0.0
	rolling = true
	strokes_left -= 1
	hole_strokes += 1
	Juice.sfx("thud")
	Juice.haptic(15)
	if strokes_left <= 0:
		# allow the shot to resolve; end checked in _process when it stops
		pass


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and not event.echo and event.keycode == KEY_SPACE:
		if event.pressed:
			charging = true
		else:
			_swing()


func _process(delta: float) -> void:
	if not running:
		return
	if charging:
		power = min(1.0, power + delta * 0.8)
	aim += (tc.move.x + key_axis_x()) * 1.4 * delta

	if rolling:
		bvel.y -= 26.0 * delta
		bpos += bvel * delta
		if bpos.y <= 0.3:
			bpos.y = 0.3
			bvel.y = -bvel.y * 0.35 if bvel.y < -3.0 else 0.0
			# ground friction + slope pushes
			bvel.x *= 0.94
			bvel.z *= 0.94
			for h in hills:
				var d := Vector2(bpos.x - h.pos.x, bpos.z - h.pos.z)
				if d.length() < h.radius:
					var push := d.normalized() * h.strength * 6.0 * delta
					bvel.x += push.x
					bvel.z += push.y
		if Vector2(bvel.x, bvel.z).length() < 0.6 and bpos.y <= 0.32:
			bvel = Vector3.ZERO
			rolling = false
			if strokes_left <= 0:
				end_demo()
				return
		if bpos.distance_to(hole + Vector3(0, 0.3, 0)) < 1.1 and bvel.length() < 12.0:
			holes += 1
			var par_bonus := maxi(0, 4 - hole_strokes)
			strokes_left += 4 + par_bonus
			add_points(1 + par_bonus)
			Juice.sfx("coin")
			Juice.flash(Color(1, 0.95, 0.5), 0.3)
			Juice.popup("SUNK! +%d" % (1 + par_bonus), Vector2(W * 0.5, H * 0.38), Color(1, 0.9, 0.4))
			_new_hole()
	ball.position = bpos

	aim_line.position = bpos + Vector3(sin(aim), -0.2, -cos(aim)) * 3.0
	aim_line.rotation.y = aim
	aim_line.visible = not rolling

	cam.position = bpos + Vector3(0, 14, 22)
	cam.look_at(bpos + Vector3(0, 0, -6), Vector3.UP)
	hud.text = "HOLE %d   strokes left %d   this hole %d   POWER %d%%" % [
		holes + 1, strokes_left, hole_strokes, int(power * 100)]
	hud.position = bpos + Vector3(0, 8, 0)
