extends MechDemo3D
## PHOTO SAFARI — framing and timing (Pokémon Snap). Drag to aim your lens; creatures
## roam and now and then strike a rare POSE. SNAP to shoot — the score rewards a subject
## that's centred, close, and mid-pose. You get a limited roll of film; spend it on your
## best shots. Desktop: WASD reposition, drag look, SPACE snap.

var rig: Node3D
var ppos := Vector3(0, 2, 16)
var yaw := 0.0
var pitch := -0.1
var creatures: Array = []     # {node, pos, vel, pose_t, posing, kind}
var film := 12
var last_score := 0
var best := 0
var reticle: Node3D
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.55, 0.78, 0.92), 1.0, Vector3(-45, -30, 0))
	static_box(Vector3(80, 1, 80), Vector3(0, -0.5, -10), Color(0.35, 0.6, 0.35))
	for i in 8:
		mesh_cyl(0.4, 4.0, Vector3(randf_range(-30, 30), 2, randf_range(-40, 4)), Color(0.4, 0.3, 0.2))
		mesh_sphere(2.0, Vector3(randf_range(-30, 30), 4.5, randf_range(-40, 4)), Color(0.25, 0.5, 0.28))
	rig = Node3D.new()
	add_child(rig)
	ppos = Vector3(0, 2, 16)
	film = 12
	creatures = []
	for i in 6:
		_spawn(i)
	make_camera(Vector3(0, 2, 16), Vector3(0, 2, 0), 60.0)
	reticle = Node3D.new()
	mesh_box(Vector3(1.2, 0.06, 0.06), Vector3.ZERO, Color(1, 1, 1, 0.7), reticle)
	mesh_box(Vector3(0.06, 1.2, 0.06), Vector3.ZERO, Color(1, 1, 1, 0.7), reticle)
	reticle.position = Vector3(0, 0, -6)
	cam.add_child(reticle)
	hud = Label3D.new()
	hud.font_size = 34
	hud.position = Vector3(-0.6, -0.42, -1.3)
	hud.modulate = Color(0.9, 1, 0.9)
	cam.add_child(hud)
	tc = add_touch_controls([{"id": "snap", "label": "SNAP", "col": Color(0.95, 0.85, 0.35)}], true)
	tc.action.connect(func(_id): _snap())
	tc.look.connect(func(rel):
		yaw -= rel.x * 0.004
		pitch = clampf(pitch - rel.y * 0.003, -0.8, 0.6))


func _spawn(i: int) -> void:
	var node := Node3D.new()
	add_child(node)
	var kind := i % 3
	var col := [Color(0.9, 0.6, 0.3), Color(0.4, 0.7, 0.95), Color(0.6, 0.85, 0.4)][kind]
	mesh_box(Vector3(1.6, 1.2, 2.2), Vector3(0, 0.9, 0), col, node)
	mesh_sphere(0.7, Vector3(0, 1.6, 1.0), col, node)
	var p := Vector3(randf_range(-26, 26), 0, randf_range(-36, 2))
	node.position = p
	creatures.append({"node": node, "pos": p, "vel": Vector3.ZERO, "pose_t": randf_range(2, 6), "posing": false, "kind": kind})


func _snap() -> void:
	if film <= 0:
		return
	film -= 1
	var fwd := -cam.global_transform.basis.z
	var origin := cam.global_position
	var best_shot := 0
	for c in creatures:
		var to: Vector3 = (c.pos + Vector3(0, 1.2, 0)) - origin
		var dist := to.length()
		var center := fwd.dot(to.normalized())          # 1.0 = dead centre
		if center < 0.9 or dist > 45.0:
			continue
		var centering := pow(clampf((center - 0.9) / 0.1, 0.0, 1.0), 1.5)
		var nearness := clampf(1.0 - dist / 40.0, 0.05, 1.0)
		var pose_bonus := 2.2 if c.posing else 1.0
		var s := int(120.0 * centering * nearness * pose_bonus)
		best_shot = maxi(best_shot, s)
	last_score = best_shot
	best = maxi(best, best_shot)
	add_points(best_shot)
	if best_shot > 0:
		Juice.sfx("coin" if best_shot > 120 else "tick")
		Juice.flash(Color(1, 1, 1), 0.15)
		Juice.popup("+%d" % best_shot, Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))
	else:
		Juice.sfx("thud")
	if film <= 0:
		Juice.popup("FILM OUT — total %d" % score, Vector2(W * 0.5, H * 0.3), Color(1, 0.9, 0.4))
		end_demo()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_snap()


func _process(delta: float) -> void:
	if not running:
		return
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	# reposition on the ground plane relative to facing
	var flat := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	ppos += (flat * (-mv.z) + right * mv.x) * 7.0 * delta
	ppos.x = clampf(ppos.x, -34, 34)
	ppos.z = clampf(ppos.z, -20, 22)
	cam.position = ppos
	cam.rotation = Vector3(pitch, yaw, 0)

	for c in creatures:
		c.pose_t -= delta
		if c.pose_t <= 0.0:
			c.posing = not c.posing
			c.pose_t = randf_range(1.5, 5.0) if not c.posing else randf_range(1.2, 2.2)
			if c.posing:
				c.vel = Vector3.ZERO
			else:
				c.vel = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized() * randf_range(1.5, 3.5)
		if not c.posing:
			c.pos += c.vel * delta
			c.pos.x = clampf(c.pos.x, -30, 30)
			c.pos.z = clampf(c.pos.z, -40, 2)
		c.node.position = c.pos
		# pose = jump/scale flourish so it reads through the lens
		c.node.scale = Vector3.ONE * (1.0 + (0.3 if c.posing else 0.0))
		c.node.position.y = (0.6 if c.posing else 0.0)
		c.node.rotation.y += delta * (2.0 if c.posing else 0.4)

	hud.text = "FILM %d   last %d   best %d   total %d\naim & SNAP posing subjects, centred & close" % [
		film, last_score, best, score]
