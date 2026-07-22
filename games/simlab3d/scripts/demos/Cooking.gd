extends MechDemo3D
## COOKING RUSH — kitchen time-management (Overcooked). Orders queue with timers. Run
## to the PANTRY to grab an ingredient, the STOVE to cook it, then the PASS to serve —
## before the ticket expires. Juggle the routing. Miss three orders and service ends.
## Desktop: WASD move, J interact with the station you're on.

var chef: Node3D
var ppos := Vector3(0, 0, 6)
var holding := 0              # 0 none, 1 raw, 2 cooked
var cook_t := 0.0
var cooking := false
var stations := {}           # name -> Vector3
var orders: Array = []       # {t}  seconds left
var order_t := 0.0
var served := 0
var lives := 3
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.6, 0.68, 0.8), 0.95)
	static_box(Vector3(30, 1, 24), Vector3(0, -0.5, 0), Color(0.5, 0.5, 0.55))
	chef = Node3D.new()
	add_child(chef)
	mesh_box(Vector3(1.0, 1.9, 1.0), Vector3(0, 0.95, 0), Color(0.95, 0.95, 1.0), chef)
	stations = {
		"PANTRY": Vector3(-10, 0, -6),
		"STOVE": Vector3(0, 0, -8),
		"PASS": Vector3(10, 0, -6),
	}
	_station("PANTRY", Color(0.4, 0.7, 0.4))
	_station("STOVE", Color(0.8, 0.4, 0.3))
	_station("PASS", Color(0.85, 0.8, 0.4))
	ppos = Vector3(0, 0, 6)
	holding = 0
	served = 0
	lives = 3
	orders = []
	order_t = 2.0
	make_camera(Vector3(0, 16, 16), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 9, 0), 30, Color.WHITE)
	tc = add_touch_controls([{"id": "act", "label": "ACT", "col": Color(0.9, 0.7, 0.4)}])
	tc.action.connect(func(_id): _act())


func _station(name: String, col: Color) -> void:
	var p: Vector3 = stations[name]
	mesh_box(Vector3(4, 2, 3), p + Vector3(0, 1, 0), col)
	label3d(name, p + Vector3(0, 3, 0), 30, Color.WHITE)


func _near(name: String) -> bool:
	return ppos.distance_to(stations[name]) < 3.6


func _act() -> void:
	if _near("PANTRY") and holding == 0:
		holding = 1
		Juice.sfx("tick")
	elif _near("STOVE") and holding == 1 and not cooking:
		cooking = true
		cook_t = 2.2
		Juice.sfx("thud")
	elif _near("PASS") and holding == 2:
		if orders.is_empty():
			return
		orders.pop_front()
		holding = 0
		served += 1
		add_points(1)
		Juice.sfx("coin")
		Juice.flash(Color(0.5, 1, 0.6), 0.2)
		Juice.popup("SERVED! +1", Vector2(W * 0.5, H * 0.38), Color(1, 0.9, 0.4))
	else:
		Juice.sfx("tick")


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_J:
		_act()


func _process(delta: float) -> void:
	if not running:
		return
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * 8.5 * delta
	ppos.x = clampf(ppos.x, -14, 14)
	ppos.z = clampf(ppos.z, -10, 11)
	chef.position = ppos
	chef.rotation.y = atan2(mv.x, mv.z) if mv.length() > 0.1 else chef.rotation.y
	# a plate floats above the chef showing what they carry
	chef.get_child(0).scale = Vector3.ONE if holding == 0 else Vector3(1, 1 + holding * 0.2, 1)

	if cooking:
		cook_t -= delta
		if cook_t <= 0.0:
			cooking = false
			holding = 2
			Juice.sfx("chime")

	# spawn orders; each ticks down
	order_t -= delta
	if order_t <= 0.0 and orders.size() < 5:
		order_t = maxf(2.5, 6.0 - served * 0.1)
		orders.append({"t": 16.0})
	for o in orders.duplicate():
		o.t -= delta
		if o.t <= 0.0:
			orders.erase(o)
			lives -= 1
			Juice.sfx("boom")
			Juice.flash(Color(1, 0.3, 0.3), 0.25)
			Juice.popup("ORDER LOST", Vector2(W * 0.5, H * 0.4), Color(1, 0.5, 0.4))
			if lives <= 0:
				end_demo()
				return

	cam.position = ppos * 0.3 + Vector3(0, 16, 16)
	cam.look_at(Vector3(0, 0, -2), Vector3.UP)
	var carry := ["empty-handed", "raw", "COOKED"][holding]
	var tickets := ""
	for o in orders:
		tickets += "%ds " % int(o.t)
	hud.text = "SERVED %d   lives %d   holding: %s%s\norders: %s" % [
		served, lives, carry, "  (cooking...)" if cooking else "", tickets if tickets != "" else "-"]
	hud.position = Vector3(0, 9, 0)
