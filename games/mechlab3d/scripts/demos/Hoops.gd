extends MechDemo3D
## HOOP SHOT — flick the ball to shoot arcs into the hoop. It drifts side to
## side as you score. Miss three and you're out. Score = baskets. Desktop:
## click-drag-release to flick.

var ball: MeshInstance3D
var ball_v := Vector3.ZERO
var flying := false
var hoop: Node3D
var hoop_x := 0.0
var hoop_dir := 1.0
var hoop_speed := 0.0
var misses := 0
var scored_this := false
var _press := Vector2.ZERO
var _press_t := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.2, 0.24, 0.32), 0.95)
	static_box(Vector3(20, 1, 24), Vector3(0, -0.5, 6), Color(0.4, 0.3, 0.22))
	hoop = Node3D.new()
	add_child(hoop)
	_hoop_visual()
	ball = mesh_sphere(0.4, Vector3(0, 1.0, -3), Color(0.9, 0.5, 0.2))
	_reset_ball()
	hoop_x = 0.0
	hoop_dir = 1.0
	hoop_speed = 0.0
	misses = 0
	make_camera(Vector3(0, 3.5, -8.5), Vector3(0, 3, 6))


func _hoop_visual() -> void:
	mesh_box(Vector3(2.4, 1.8, 0.3), Vector3(0, 4.6, 10.4), Color(0.9, 0.9, 0.95), hoop)
	var rim := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.55
	tm.outer_radius = 0.72
	rim.mesh = tm
	rim.material_override = _mat(Color(0.95, 0.4, 0.15))
	rim.position = Vector3(0, 3.6, 9.6)
	rim.rotation.x = PI / 2.0
	hoop.add_child(rim)


func _reset_ball() -> void:
	flying = false
	ball_v = Vector3.ZERO
	scored_this = false
	ball.position = Vector3(0, 1.0, -3)


func _unhandled_input(event: InputEvent) -> void:
	if not running or flying:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press = event.position
			_press_t = Time.get_ticks_msec() / 1000.0
		else:
			var d: Vector2 = event.position - _press
			var dt: float = maxf(0.05, Time.get_ticks_msec() / 1000.0 - _press_t)
			if d.length() < 20.0:
				return
			var power: float = clampf(d.length() / dt * 0.02, 6.0, 16.0)
			ball_v = Vector3(d.x * 0.02, power * 0.7, power)
			flying = true
			Juice.sfx("tick")


func _process(delta: float) -> void:
	if not running:
		return
	hoop_speed = minf(4.0, float(score) * 0.15)
	hoop_x += hoop_dir * hoop_speed * delta
	if absf(hoop_x) > 4.0:
		hoop_dir *= -1.0
	hoop.position.x = hoop_x

	if flying:
		ball_v.y -= 14.0 * delta
		ball.position += ball_v * delta
		var rim_pos := Vector3(hoop_x, 3.6, 9.6)
		if not scored_this and ball.position.distance_to(rim_pos) < 0.6 and ball_v.y < 0.0:
			scored_this = true
			add_points(2)
			Juice.sfx("chime")
			Juice.flash(Color(1, 0.9, 0.5), 0.15)
		if ball.position.y < -1.0 or ball.position.z > 14.0:
			if not scored_this:
				misses += 1
				Juice.haptic(30)
				if misses >= 3:
					end_demo()
					return
			_reset_ball()
