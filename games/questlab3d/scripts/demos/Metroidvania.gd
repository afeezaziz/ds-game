extends MechDemo3D
## METROIDVANIA 3D — ability-gated traversal. A single-jump can't clear the high wall
## until you grab DOUBLE-JUMP; the wide chasm stops you until you find DASH. Collect
## the power, reach the exit, and a deeper wing opens. Side-on 2.5D platforming.
## Desktop: A/D run, SPACE jump (double once earned), Shift dash.

var hero: Node3D
var pos := Vector3(-40, 2, 0)
var vx := 0.0
var vy := 0.0
var jumps := 0
var max_jumps := 1
var has_dash := false
var dash_t := 0.0
var dash_cd := 0.0
var plats: Array = []         # {pos,size}
var orbs: Array = []          # {node,pos,kind}
var goal := Vector3(44, 4, 0)
var flag: Node3D
var wing := 1
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.1, 0.08, 0.16), 0.85, Vector3(-50, -20, 0))
	hero = Node3D.new()
	add_child(hero)
	mesh_box(Vector3(1.2, 2.0, 1.2), Vector3(0, 1.0, 0), Color(0.5, 0.9, 0.8), hero)
	make_camera(Vector3(0, 6, 26), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 8, 0), 30, Color.WHITE)
	tc = add_touch_controls([
		{"id": "jump", "label": "JUMP", "col": Color(0.5, 0.85, 0.7)},
		{"id": "dash", "label": "DASH", "col": Color(0.9, 0.7, 0.4)},
	])
	tc.action.connect(func(id):
		if id == "jump": _jump()
		elif id == "dash": _dash())
	_build()


func _build() -> void:
	for p in plats:
		p.node.queue_free()
	for o in orbs:
		o.node.queue_free()
	plats = []
	orbs = []
	max_jumps = 1
	has_dash = false
	# ground segments with a high wall and a chasm
	_plat(Vector3(-40, 0, 0), Vector3(20, 2, 4))       # start ground
	_plat(Vector3(-24, 4, 0), Vector3(4, 1, 4))        # step
	_plat(Vector3(-14, 9, 0), Vector3(6, 1, 4))        # high ledge (needs double jump)
	_plat(Vector3(-2, 9, 0), Vector3(8, 1, 4))
	_plat(Vector3(20, 9, 0), Vector3(10, 1, 4))        # across the chasm (needs dash)
	_plat(Vector3(40, 9, 0), Vector3(12, 1, 4))        # goal platform
	_orb(Vector3(-30, 4, 0), "double")                 # reachable with single jump
	_orb(Vector3(-2, 11, 0), "dash")                   # up on the ledge chain
	goal = Vector3(44, 11, 0)
	if flag == null:
		flag = Node3D.new()
		add_child(flag)
		mesh_cyl(0.15, 4.0, Vector3(0, 2, 0), Color(1, 0.9, 0.3), flag)
	flag.position = goal
	pos = Vector3(-40, 3, 0)
	vx = 0.0
	vy = 0.0
	jumps = 0


func _plat(p: Vector3, s: Vector3) -> void:
	var node := mesh_box(s, p + Vector3(0, s.y * 0.5, 0), hue_col(p.x * 0.02, 0.3, 0.6))
	plats.append({"pos": p, "size": s, "node": node})


func _orb(p: Vector3, kind: String) -> void:
	var col := Color(0.5, 0.9, 1.0) if kind == "double" else Color(1, 0.7, 0.4)
	var node := mesh_sphere(0.6, p, col)
	orbs.append({"node": node, "pos": p, "kind": kind})


func _jump() -> void:
	if jumps < max_jumps:
		vy = 15.0
		jumps += 1
		Juice.sfx("tick")


func _dash() -> void:
	if has_dash and dash_cd <= 0.0:
		dash_t = 0.22
		dash_cd = 0.8
		Juice.sfx("thud")
		Juice.haptic(15)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _jump()
		elif event.keycode == KEY_SHIFT: _dash()


func _process(delta: float) -> void:
	if not running:
		return
	dash_t = maxf(0.0, dash_t - delta)
	dash_cd = maxf(0.0, dash_cd - delta)
	var ix := tc.move.x + key_axis_x()
	var facing := 1.0 if ix >= 0.0 else -1.0
	if dash_t > 0.0:
		vx = facing * 30.0
	else:
		vx = move_toward(vx, ix * 11.0, 60.0 * delta)
	pos.x += vx * delta
	vy -= 40.0 * delta
	pos.y += vy * delta

	# platform landing
	var grounded := false
	for p in plats:
		var top: float = p.pos.y + p.size.y
		if absf(pos.x - p.pos.x) < p.size.x * 0.5 + 0.6 and vy <= 0.0 and pos.y <= top + 0.5 and pos.y >= top - 1.0:
			pos.y = top
			vy = 0.0
			jumps = 0
			grounded = true
	if pos.y < -12.0:
		# fell — respawn at start of the wing
		pos = Vector3(-40, 3, 0)
		vy = 0.0
		Juice.sfx("boom")
		Juice.flash(Color(1, 0.3, 0.3), 0.2)
	pos.x = clampf(pos.x, -50, 52)
	hero.position = pos
	if ix != 0.0:
		hero.rotation.y = 0.0 if facing > 0 else PI

	for o in orbs.duplicate():
		if pos.distance_to(o.pos) < 1.6:
			o.node.queue_free()
			orbs.erase(o)
			if o.kind == "double":
				max_jumps = 2
				Juice.popup("DOUBLE JUMP", Vector2(W * 0.5, H * 0.34), Color(0.5, 0.9, 1))
			else:
				has_dash = true
				Juice.popup("DASH", Vector2(W * 0.5, H * 0.34), Color(1, 0.7, 0.4))
			Juice.sfx("coin")

	flag.rotation.y += delta * 2.0
	if pos.distance_to(goal) < 2.5:
		wing += 1
		add_points(5)
		Juice.sfx("chime")
		Juice.flash(Color(1, 0.95, 0.6), 0.35)
		Juice.popup("WING CLEARED", Vector2(W * 0.5, H * 0.34), Color(1, 0.9, 0.4))
		_build()

	cam.position = Vector3(pos.x, pos.y + 5.0, 26.0)
	cam.look_at(Vector3(pos.x, pos.y + 2.0, 0), Vector3.UP)
	hud.text = "WING %d   jumps %d   dash %s   reach the exit →" % [
		wing, max_jumps, "yes" if has_dash else "no"]
	hud.position = Vector3(pos.x, pos.y + 6.0, 0)
