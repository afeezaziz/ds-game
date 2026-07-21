extends MechDemo3D
## PLATFORMER 3D — a collectathon. Hop across floating platforms (some moving),
## grab every star, avoid the red hazards, don't fall. Double-jump enabled.
## Collect all stars to reach a higher level. Score = levels cleared. Desktop:
## WASD move, Space jump.

var player: Node3D
var ppos := Vector3(0, 1, 0)
var vy := 0.0
var jumps := 2
var plats: Array = []   # {pos, size, node, hazard, mv, amp, phase, axis}
var stars: Array = []
var lives := 3
var lev12 := 1
var spawn0 := Vector3(0, 1.2, 0)
var tc: TouchControls
var hud: Label3D
var t := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.45, 0.6, 0.85), 0.95)
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(0.8, 1.2, 0.8), Vector3(0, 0.6, 0), Color(0.95, 0.85, 0.4), player)
	lives = 3
	lev12 = 1
	hud = label3d("", Vector3(0, 4, 0), 40, Color.WHITE)
	_gen()
	make_camera(Vector3(0, 12, 12), Vector3.ZERO, 60.0)
	tc = add_touch_controls([{"id": "jump", "label": "JUMP", "col": Color(0.45, 0.75, 0.5)}])
	tc.action.connect(func(_id): _jump())


func _gen() -> void:
	for p in plats:
		p.node.queue_free()
	for s in stars:
		s.node.queue_free()
	plats = []
	stars = []
	var x := 0.0
	var z := 0.0
	var y := 0.0
	_plat(Vector3(0, 0, 0), Vector3(5, 0.5, 5), false, false)
	spawn0 = Vector3(0, 1.0, 0)
	for i in 9:
		x += randf_range(-5, 5)
		z += randf_range(4, 7)
		y += randf_range(-1.5, 2.0)
		var hazard := i > 1 and randf() < 0.2
		var mv := i > 2 and randf() < 0.35
		_plat(Vector3(x, y, z), Vector3(randf_range(3, 4.5), 0.5, randf_range(3, 4.5)), hazard, mv)
		if not hazard:
			var sn := mesh_sphere(0.35, Vector3(x, y + 1.4, z), Color(1, 0.85, 0.25))
			stars.append({"pos": Vector3(x, y + 1.4, z), "node": sn})
	# goal marker
	_plat(Vector3(x, y + 1, z + 6), Vector3(5, 0.5, 5), false, false)
	ppos = spawn0
	vy = 0.0
	jumps = 2


func _plat(pos: Vector3, size: Vector3, hazard: bool, mv: bool) -> void:
	var node := mesh_box(size, pos, Color(0.85, 0.3, 0.3) if hazard else hue_col(pos.z * 0.03, 0.4, 0.8))
	plats.append({"pos": pos, "size": size, "node": node, "hazard": hazard, "mv": mv,
		"base": pos, "amp": randf_range(2, 4), "phase": randf() * TAU, "axis": randi() % 2})


func _jump() -> void:
	if jumps > 0:
		vy = 9.0
		jumps -= 1
		Juice.sfx("tick")


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_jump()


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	for p in plats:
		if p.mv:
			var off := sin(t + p.phase) * p.amp
			p.pos = p.base + (Vector3(off, 0, 0) if p.axis == 0 else Vector3(0, 0, off))
			p.node.position = p.pos

	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * 7.0 * delta
	vy -= 24.0 * delta
	ppos.y += vy * delta

	# platform collision (landing)
	for p in plats:
		var top: float = p.pos.y + p.size.y * 0.5
		if absf(ppos.x - p.pos.x) < p.size.x * 0.5 and absf(ppos.z - p.pos.z) < p.size.z * 0.5:
			if vy <= 0.0 and ppos.y <= top + 0.6 and ppos.y >= top - 0.5:
				if p.hazard:
					_die()
					return
				ppos.y = top + 0.5
				vy = 0.0
				jumps = 2

	if ppos.y < -10.0:
		_die()
		return
	player.position = ppos

	for s in stars.duplicate():
		if ppos.distance_to(s.pos) < 1.2:
			s.node.queue_free()
			stars.erase(s)
			add_points(1)
			Juice.sfx("coin")
	if stars.is_empty():
		lev12 += 1
		add_points(5)
		Juice.sfx("chime")
		_gen()

	cam.position = ppos + Vector3(0, 8, 11)
	cam.look_at(ppos, Vector3.UP)
	hud.text = "LIVES %d   LEVEL %d   stars left %d" % [lives, lev12, stars.size()]
	hud.position = ppos + Vector3(0, 3, 0)


func _die() -> void:
	lives -= 1
	Juice.sfx("boom")
	Juice.haptic(30)
	if lives <= 0:
		end_demo()
		return
	ppos = spawn0
	vy = 0.0
	jumps = 2
