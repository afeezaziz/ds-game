extends MechDemo3D
## PORTAL — place two linked portals and route yourself across the void (Portal).
## Drop the BLUE portal at your feet; FIRE the ORANGE one forward — it lands on the
## farthest platform you're aiming at. Step into either and you pop out the other.
## Reach the exit; each chamber widens the gap. Desktop: WASD move, J blue, K orange.

var hero: Node3D
var hpos := Vector3(0, 0.5, 8)
var facing := Vector3(0, 0, -1)
var plats: Array = []         # {pos, size}  AABB on XZ (y=0 top)
var blue = null               # Vector3 or null
var orange = null
var blue_node: Node3D
var orange_node: Node3D
var exit_pos := Vector3.ZERO
var flag: Node3D
var tele_cd := 0.0
var chamber := 1
var tc: TouchControls
var hud: Label3D
const RANGE := 44.0


func start() -> void:
	super.start()
	setup_world(Color(0.08, 0.09, 0.14), 0.8, Vector3(-55, -20, 0))
	hero = Node3D.new()
	add_child(hero)
	mesh_box(Vector3(1.0, 1.6, 1.0), Vector3(0, 0.8, 0), Color(0.5, 0.85, 0.9), hero)
	blue_node = mesh_cyl(1.0, 0.3, Vector3(0, -5, 0), Color(0.3, 0.6, 1.0))
	orange_node = mesh_cyl(1.0, 0.3, Vector3(0, -5, 0), Color(1.0, 0.6, 0.2))
	flag = Node3D.new()
	add_child(flag)
	mesh_cyl(0.15, 3.0, Vector3(0, 1.5, 0), Color(0.4, 1, 0.5), flag)
	make_camera(Vector3(0, 16, 16), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 9, 0), 30, Color.WHITE)
	tc = add_touch_controls([
		{"id": "blue", "label": "BLUE", "col": Color(0.4, 0.6, 1.0)},
		{"id": "orange", "label": "ORANGE", "col": Color(1.0, 0.6, 0.3)},
	])
	tc.action.connect(func(id):
		if id == "blue": _blue()
		elif id == "orange": _orange())
	_build()


func _build() -> void:
	for p in plats:
		p.node.queue_free()
	plats = []
	blue = null
	orange = null
	blue_node.position = Vector3(0, -5, 0)
	orange_node.position = Vector3(0, -5, 0)
	_plat(Vector3(0, 0, 8), Vector3(10, 1, 10))                       # start
	var gap := 10.0 + chamber * 4.0
	_plat(Vector3(0, 0, 8 - gap - 10), Vector3(10, 1, 10))            # far platform across the gap
	# a couple of side islands to bounce portals off
	_plat(Vector3(-16, 0, -6), Vector3(6, 1, 6))
	exit_pos = Vector3(0, 0.5, 8 - gap - 10)
	flag.position = exit_pos + Vector3(0, 0, 0)
	hpos = Vector3(0, 0.5, 8)


func _plat(pos: Vector3, size: Vector3) -> void:
	var node := mesh_box(size, pos + Vector3(0, -size.y * 0.5, 0) + Vector3(0, 0.5, 0), hue_col(pos.z * 0.03, 0.3, 0.55))
	plats.append({"pos": pos, "size": size, "node": node})


func _on_plat(p: Vector3) -> bool:
	for pl in plats:
		if absf(p.x - pl.pos.x) < pl.size.x * 0.5 and absf(p.z - pl.pos.z) < pl.size.z * 0.5:
			return true
	return false


func _blue() -> void:
	if _on_plat(hpos):
		blue = Vector3(hpos.x, 0.6, hpos.z)
		blue_node.position = blue
		Juice.sfx("tick")


func _orange() -> void:
	# march forward; keep the farthest point that is on a platform
	var landed = null
	var t := 1.0
	while t < RANGE:
		var s := hpos + facing * t
		if _on_plat(s):
			landed = Vector3(s.x, 0.6, s.z)
		t += 1.0
	if landed != null:
		orange = landed
		orange_node.position = orange
		Juice.sfx("tick")
		Juice.flash(Color(1, 0.7, 0.3), 0.1)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: _blue()
		elif event.keycode == KEY_K: _orange()


func _process(delta: float) -> void:
	if not running:
		return
	tele_cd = maxf(0.0, tele_cd - delta)
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	var np := hpos + mv * 7.0 * delta
	if _on_plat(np):
		hpos = np
	if mv.length() > 0.1:
		facing = mv.normalized()
		hero.rotation.y = atan2(mv.x, mv.z)
	hero.position = hpos

	# teleport between linked portals
	if blue != null and orange != null and tele_cd <= 0.0:
		if hpos.distance_to(blue) < 1.4:
			hpos = orange + facing * 1.4
			tele_cd = 0.6
			Juice.sfx("chime"); Juice.haptic(15)
		elif hpos.distance_to(orange) < 1.4:
			hpos = blue + facing * 1.4
			tele_cd = 0.6
			Juice.sfx("chime"); Juice.haptic(15)

	flag.rotation.y += delta * 2.0
	if hpos.distance_to(exit_pos) < 2.0:
		chamber += 1
		add_points(3)
		Juice.sfx("coin"); Juice.flash(Color(0.5, 1, 0.6), 0.3)
		Juice.popup("CHAMBER %d SOLVED" % (chamber - 1), Vector2(W * 0.5, H * 0.32), Color(1, 0.9, 0.4))
		_build()

	cam.position = hpos + Vector3(0, 16, 16)
	cam.look_at(hpos + Vector3(0, 0, -4), Vector3.UP)
	hud.text = "CHAMBER %d   blue %s  orange %s   → aim & FIRE across the gap" % [
		chamber, "set" if blue != null else "-", "set" if orange != null else "-"]
	hud.position = hpos + Vector3(0, 9, 0)
