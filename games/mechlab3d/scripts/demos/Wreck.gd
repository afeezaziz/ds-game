extends MechDemo3D
## WRECKING BALL — real physics demolition. Drag back and release to hurl a
## ball at the tower; knock blocks off the platform. 5 throws. Score = blocks
## dropped. (Uses RigidBody3D — the one physics demo.) Desktop: click-drag-fire.

var blocks: Array = []
var throws := 5
var _press := Vector2.ZERO
var _aiming := false
var throws_label: Label3D
var settle_t := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.6, 0.75), 0.95)
	# platform blocks sit on
	static_box(Vector3(6, 1, 6), Vector3(0, 3.0, 12), Color(0.4, 0.42, 0.48))
	static_box(Vector3(60, 1, 60), Vector3(0, -0.5, 12), Color(0.3, 0.45, 0.3))
	throws = 5
	blocks.clear()
	for y in 5:
		for x in 3:
			_block(Vector3(-1.2 + x * 1.2, 4.0 + y * 1.05, 12))
	throws_label = label3d("THROWS 5", Vector3(0, 9, 12), 40, Color.WHITE)
	make_camera(Vector3(0, 5, -4), Vector3(0, 4, 12), 60.0)


func _block(pos: Vector3) -> void:
	var body := RigidBody3D.new()
	body.position = pos
	body.mass = 1.0
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.0, 1.0, 1.0)
	cs.shape = bs
	body.add_child(cs)
	body.add_child(mesh_box(Vector3(1.0, 1.0, 1.0), Vector3.ZERO, hue_col(pos.y, 0.5, 0.9)))
	add_child(body)
	blocks.append(body)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press = event.position
			_aiming = true
		elif _aiming:
			_aiming = false
			var d: Vector2 = event.position - _press
			if d.length() < 20.0:
				return
			_throw(d)


func _throw(d: Vector2) -> void:
	if throws <= 0:
		return
	throws -= 1
	throws_label.text = "THROWS %d" % throws
	var ball := RigidBody3D.new()
	ball.position = Vector3(0, 4.5, 0)
	ball.mass = 6.0
	var cs := CollisionShape3D.new()
	var sp := SphereShape3D.new()
	sp.radius = 0.7
	cs.shape = sp
	ball.add_child(cs)
	ball.add_child(mesh_sphere(0.7, Vector3.ZERO, Color(0.2, 0.2, 0.25)))
	add_child(ball)
	var power: float = clampf(d.length() * 0.06, 12.0, 30.0)
	ball.linear_velocity = Vector3(d.x * 0.05, maxf(2.0, -d.y * 0.05), power)
	Juice.sfx("boom")
	Juice.haptic(30)
	settle_t = 2.5


func _process(delta: float) -> void:
	if not running:
		return
	for b in blocks.duplicate():
		if is_instance_valid(b) and b.position.y < 1.0:
			add_points(1)
			Juice.sfx("thud")
			b.queue_free()
			blocks.erase(b)
	if throws <= 0:
		settle_t -= delta
		if settle_t <= 0.0:
			end_demo()
