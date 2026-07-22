extends MechDemo3D
## PHYSICS PUZZLE — carry cubes onto pressure plates (Portal / sokoban). Every plate
## needs weight — a CUBE or you standing on it. Satisfy them all to drop the exit gate,
## then reach the EXIT. Each room adds a plate, so soon you can't hold them all down
## alone. Endless. Desktop: WASD move, J grab/drop.

var player: Node3D
var ppos := Vector3(0, 0, 8)
var carrying = null           # cube dict or null
var cubes: Array = []         # {node,pos}
var plates: Array = []        # {node,pos,lit}
var door: Node3D
var exit_pos := Vector3(0, 0, -14)
var room := 1
var solved := false
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.55, 0.62), 0.9, Vector3(-55, -25, 0))
	static_box(Vector3(30, 1, 40), Vector3(0, -0.5, -4), Color(0.3, 0.32, 0.38))
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(1.2, 2.0, 1.2), Vector3(0, 1.0, 0), Color(0.4, 0.8, 0.9), player)
	door = mesh_box(Vector3(8, 4, 1), Vector3(0, 2, -10), Color(0.6, 0.4, 0.3))
	make_camera(Vector3(0, 16, 16), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 10, 0), 30, Color.WHITE)
	tc = add_touch_controls([{"id": "grab", "label": "GRAB", "col": Color(0.9, 0.75, 0.4)}])
	tc.action.connect(func(_id): _grab())
	_build_room()


func _build_room() -> void:
	for c in cubes: c.node.queue_free()
	for p in plates: p.node.queue_free()
	cubes = []
	plates = []
	carrying = null
	solved = false
	ppos = Vector3(0, 0, 8)
	var n := 1 + room
	for i in n:
		var pp := Vector3(randf_range(-11, 11), 0, randf_range(-6, 2))
		var node := mesh_box(Vector3(2.4, 0.2, 2.4), pp + Vector3(0, 0.1, 0), Color(0.8, 0.5, 0.3))
		plates.append({"node": node, "pos": pp, "lit": false})
		# one cube per plate, minus one so at least one plate needs YOU (or forces stacking of choices)
		if i < n - 1 + (1 if room == 1 else 0):
			var cp := Vector3(randf_range(-11, 11), 0.6, randf_range(4, 9))
			var cn := mesh_box(Vector3(1.6, 1.2, 1.6), cp, Color(0.85, 0.8, 0.4))
			cubes.append({"node": cn, "pos": cp})
	door.visible = true
	exit_pos = Vector3(0, 0, -16)


func _grab() -> void:
	if carrying != null:
		carrying.pos = ppos + Vector3(0, 0.6, 0)
		carrying.node.position = carrying.pos
		carrying = null
		Juice.sfx("thud")
		return
	for c in cubes:
		if ppos.distance_to(c.pos) < 2.2:
			carrying = c
			Juice.sfx("tick")
			return


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		_grab()


func _process(delta: float) -> void:
	if not running:
		return
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * 7.5 * delta
	ppos.x = clampf(ppos.x, -13, 13)
	# the closed door blocks passage northward until solved
	if not solved and ppos.z < -8.5:
		ppos.z = -8.5
	ppos.z = clampf(ppos.z, -18, 13)
	player.position = ppos
	if mv.length() > 0.1:
		player.rotation.y = atan2(mv.x, mv.z)
	if carrying != null:
		carrying.pos = ppos + Vector3(0, 2.4, 0)
		carrying.node.position = carrying.pos

	# evaluate plates
	var all_lit := true
	for p in plates:
		var weighted := (carrying == null and ppos.distance_to(p.pos) < 1.6)
		if not weighted:
			for c in cubes:
				if c != carrying and Vector3(c.pos.x, 0, c.pos.z).distance_to(p.pos) < 1.6:
					weighted = true
					break
		p.lit = weighted
		(p.node.material_override as StandardMaterial3D).albedo_color = Color(0.4, 0.9, 0.5) if weighted else Color(0.8, 0.5, 0.3)
		if not weighted:
			all_lit = false

	if all_lit and not solved:
		solved = true
		door.visible = false
		Juice.sfx("chime")
		Juice.flash(Color(0.7, 1.0, 0.8), 0.25)
		Juice.popup("GATE OPEN", Vector2(W * 0.5, H * 0.34), Color(0.7, 1, 0.8))
	if solved and ppos.distance_to(exit_pos) < 2.5:
		room += 1
		add_points(3)
		Juice.sfx("coin")
		Juice.flash(Color(1, 0.95, 0.6), 0.3)
		Juice.popup("ROOM %d SOLVED" % (room - 1), Vector2(W * 0.5, H * 0.3), Color(1, 0.9, 0.4))
		_build_room()

	cam.position = ppos * 0.4 + Vector3(0, 16, 16)
	cam.look_at(Vector3(0, 0, -4), Vector3.UP)
	var lit := plates.filter(func(p): return p.lit).size()
	hud.text = "ROOM %d   plates %d/%d   %s%s" % [
		room, lit, plates.size(), "carrying cube" if carrying != null else "hands free",
		"   → EXIT" if solved else ""]
	hud.position = ppos + Vector3(0, 10, 0)
