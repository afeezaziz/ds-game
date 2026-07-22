extends MechDemo3D
## PERSPECTIVE — rotate to align the path (Monument Valley). A pivoting bridge only
## becomes walkable when its far end lines up with the goal platform; ROTATE it until
## it connects, then walk across. Misaligned, the bridge is just empty air. Each level
## moves the goal. Desktop: A/D rotate, WASD move.

var hero: Node3D
var hpos := Vector3(0, 0.6, 0)
var pivot := Vector3(0, 0, -6)
var bridge: Node3D
var angle := 0.0
var blen := 12.0
var start_c := Vector3(0, 0, 4)
var goal_c := Vector3(0, 0, -18)
var goal_node: Node3D
var connected := false
var level := 1
var tc: TouchControls
var hud: Label3D
const PLAT_R := 4.0


func start() -> void:
	super.start()
	setup_world(Color(0.12, 0.1, 0.18), 0.85, Vector3(-50, -25, 0))
	# start + goal platforms
	mesh_box(Vector3(8, 1, 8), start_c + Vector3(0, 0, 0), Color(0.5, 0.6, 0.75))
	goal_node = mesh_box(Vector3(8, 1, 8), Vector3(0, 0, -18), Color(0.5, 0.75, 0.55))
	bridge = Node3D.new()
	add_child(bridge)
	mesh_box(Vector3(2.0, 0.4, blen), Vector3(0, 0.4, -blen * 0.5), Color(0.85, 0.75, 0.4), bridge)
	bridge.position = pivot
	hero = Node3D.new()
	add_child(hero)
	mesh_box(Vector3(1.0, 1.6, 1.0), Vector3(0, 0.8, 0), Color(0.95, 0.85, 0.4), hero)
	hpos = start_c + Vector3(0, 0.6, 0)
	level = 1
	make_camera(Vector3(10, 14, 14), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 9, 0), 30, Color.WHITE)
	tc = add_touch_controls([
		{"id": "rl", "label": "◄ ROT", "col": Color(0.6, 0.7, 0.95)},
		{"id": "rr", "label": "ROT ►", "col": Color(0.6, 0.7, 0.95)},
	])
	tc.action.connect(func(id):
		if id == "rl": angle -= 0.26
		elif id == "rr": angle += 0.26)
	_place_goal()


func _place_goal() -> void:
	var a := randf_range(-1.0, 1.0)
	goal_c = pivot + Vector3(sin(a), 0, -cos(a)) * blen
	goal_c.y = 0
	goal_node.position = goal_c
	hpos = start_c + Vector3(0, 0.6, 0)


func _bridge_end() -> Vector3:
	return pivot + Vector3(sin(angle), 0, -cos(angle)) * blen


func _on_start(p: Vector3) -> bool:
	return absf(p.x - start_c.x) < PLAT_R and absf(p.z - start_c.z) < PLAT_R


func _on_goal(p: Vector3) -> bool:
	return absf(p.x - goal_c.x) < PLAT_R and absf(p.z - goal_c.z) < PLAT_R


func _on_bridge(p: Vector3) -> bool:
	# distance from the pivot→end segment
	var seg := _bridge_end() - pivot
	var t := clampf((p - pivot).dot(seg) / seg.length_squared(), 0.0, 1.0)
	var closest := pivot + seg * t
	return Vector2(p.x - closest.x, p.z - closest.z).length() < 1.6


func _walkable(p: Vector3) -> bool:
	if _on_start(p) or _on_goal(p):
		return true
	return connected and _on_bridge(p)


func _process(delta: float) -> void:
	if not running:
		return
	angle += (key_axis_x()) * 1.2 * delta
	bridge.rotation.y = angle
	connected = _bridge_end().distance_to(goal_c) < 2.6
	# recolor the bridge to signal connection
	var bm := bridge.get_child(0) as MeshInstance3D
	(bm.material_override as StandardMaterial3D).albedo_color = Color(0.4, 0.9, 0.5) if connected else Color(0.85, 0.75, 0.4)

	var mv := Vector3(tc.move.x, 0, tc.move.y)
	# WASD contributes to move too (rotate uses A/D via key_axis, so use W/S + stick for walking)
	mv.z += -key_axis_y()
	if mv.length() > 1.0:
		mv = mv.normalized()
	var np := hpos + mv * 6.0 * delta
	if _walkable(np):
		hpos = np
	hpos.y = 0.6
	hero.position = hpos
	if mv.length() > 0.1:
		hero.rotation.y = atan2(mv.x, mv.z)

	goal_node.rotation.y += delta
	if _on_goal(hpos):
		level += 1
		add_points(3)
		Juice.sfx("chime"); Juice.flash(Color(0.6, 1, 0.7), 0.3)
		Juice.popup("ALIGNED! level %d" % level, Vector2(W * 0.5, H * 0.32), Color(1, 0.9, 0.4))
		_place_goal()

	cam.position = Vector3(10, 15, 15)
	cam.look_at(pivot, Vector3.UP)
	hud.text = "LEVEL %d   %s   (rotate the bridge to connect, then cross)" % [
		level, "CONNECTED — walk across" if connected else "not aligned"]
	hud.position = hpos + Vector3(0, 8, 0)
