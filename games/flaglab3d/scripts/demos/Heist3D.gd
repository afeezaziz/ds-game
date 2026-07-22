extends MechDemo3D
## Open-world sandbox: walk the city on foot, ENTER a nearby car to drive fast,
## then climb a WANTED ladder. Crimes (run over peds / FIRE at peds & cops) raise
## stars 0..5; each tier spawns more, faster cop cars that chase and shoot (HP
## drain). Break away ~6s to cool a star. Reach glowing JOB markers to score.
## Touch: stick move · ENTER car · FIRE. Keys: WASD/arrows · E car · SPACE fire.

const BLOCK := 16.0
const FOOT_SPEED := 7.5
const TOP_SPEED := 24.0

var tc: TouchControls
var player: MeshInstance3D
var hud: Label3D
var obj_node: MeshInstance3D
var foot_pos := Vector3(8, 0.9, 8)
var foot_yaw := 0.0
var obj_pos := Vector3.ZERO
var in_car := false
var current_car := -1
var car_yaw := 0.0
var car_speed := 0.0
var hp := 100.0
var wanted := 0
var heat := 0.0
var shake := 0.0
var cars: Array = []
var peds: Array = []
var cops: Array = []


func start() -> void:
	super.start()
	setup_world(Color(0.42, 0.5, 0.6), 0.85)
	mesh_box(Vector3(260, 0.4, 260), Vector3(0, -0.2, 0), Color(0.22, 0.23, 0.26))
	for gx in range(-2, 3):
		for gz in range(-2, 3):
			if gx == 0 and gz == 0:
				continue
			var h := randf_range(6.0, 22.0)
			static_box(Vector3(9, h, 9), Vector3(gx * BLOCK, h * 0.5, gz * BLOCK),
				hue_col(float(gx + gz) * 2.0, 0.25, 0.7))
	for i in 4:
		var c := _make_car(Color(0.3, 0.55, 0.85))
		c.position = _road_point()
		c.rotation.y = randf_range(0.0, TAU)
		cars.append(c)
	player = mesh_box(Vector3(0.8, 1.6, 0.8), foot_pos, Color(0.95, 0.85, 0.3))
	mesh_sphere(0.42, Vector3(0, 1.1, 0), Color(0.9, 0.7, 0.55), player)
	for i in 6:
		_spawn_ped()
	_spawn_objective()
	make_camera(Vector3(0, 8, 22), foot_pos, 62.0)
	hud = label3d("", Vector3(-1.9, 2.6, -4.2), 26, Color.WHITE, cam)
	tc = add_touch_controls([
		{"id": "action", "label": "ENTER", "col": Color(0.55, 0.75, 0.5)},
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.4, 0.35)},
	])
	tc.action.connect(func(id):
		if id == "action":
			_toggle_car()
		elif id == "fire":
			_fire())

func _make_car(col: Color) -> MeshInstance3D:
	var body := mesh_box(Vector3(2.2, 0.8, 4.0), Vector3(0, 0.6, 0), col)
	mesh_box(Vector3(1.8, 0.7, 2.0), Vector3(0, 0.75, -0.2), col.darkened(0.25), body)
	return body

func _road_point() -> Vector3:
	return Vector3(randi_range(-2, 1) * BLOCK + BLOCK * 0.5, 0.6, randi_range(-2, 2) * BLOCK)

func _forward(y: float) -> Vector3:
	return Vector3(sin(y), 0, cos(y))

func _active_pos() -> Vector3:
	return cars[current_car].position if in_car and current_car >= 0 else foot_pos

func _active_yaw() -> float:
	return car_yaw if in_car and current_car >= 0 else foot_yaw

func _pop(t: String, col: Color) -> void:
	Juice.popup(t, Vector2(W * 0.5, H * 0.34), col, 46)

func _spawn_ped() -> void:
	var mi := mesh_box(Vector3(0.6, 1.4, 0.6), _road_point(), hue_col(randf() * 20.0, 0.4, 0.85))
	mi.position.y = 0.8
	var a := randf() * TAU
	peds.append({"node": mi, "vel": Vector3(sin(a), 0, cos(a)) * randf_range(1.5, 3.5), "alive": true})

func _spawn_objective() -> void:
	obj_pos = _road_point()
	obj_pos.y = 0.0
	if obj_node == null:
		obj_node = mesh_cyl(1.6, 6.0, Vector3.ZERO, Color(0.3, 1.0, 0.6))
		var m := obj_node.material_override as StandardMaterial3D
		m.emission_enabled = true
		m.emission = Color(0.3, 1.0, 0.6)
		m.emission_energy_multiplier = 2.0
		label3d("JOB", Vector3(0, 5.0, 0), 40, Color(0.6, 1, 0.8), obj_node)
	obj_node.position = obj_pos + Vector3(0, 3.0, 0)

func _spawn_cop() -> void:
	var c := _make_car(Color(0.85, 0.2, 0.22))
	mesh_box(Vector3(0.5, 0.3, 0.5), Vector3(0, 1.2, 0), Color(0.2, 0.4, 1.0), c)
	var a := randf() * TAU
	c.position = _active_pos() + Vector3(sin(a), 0, cos(a)) * 40.0
	c.position.y = 0.6
	cops.append({"node": c, "fire": 1.5})

func _toggle_car() -> void:
	if not running:
		return
	if in_car:
		foot_pos = cars[current_car].position + _forward(car_yaw + PI * 0.5) * 3.0
		foot_pos.y = 0.9
		in_car = false
		current_car = -1
		player.visible = true
		Juice.sfx("tick")
		_pop("ON FOOT", Color(0.9, 0.9, 0.5))
		return
	var best := -1
	var bd := 6.0
	for i in cars.size():
		var d: float = cars[i].position.distance_to(foot_pos)
		if d < bd:
			bd = d
			best = i
	if best == -1:
		_pop("NO CAR NEAR", Color(0.9, 0.6, 0.5))
		return
	current_car = best
	in_car = true
	car_yaw = cars[best].rotation.y
	car_speed = 0.0
	player.visible = false
	Juice.sfx("chime")
	Juice.haptic(20)
	_pop("DRIVING", Color(0.5, 0.9, 0.6))

func _fire() -> void:
	if not running:
		return
	Juice.sfx("tick")
	Juice.flash(Color(1, 0.9, 0.5), 0.08)
	var fwd := _forward(_active_yaw())
	var ap := _active_pos()
	var loud := false
	for p in peds:
		if not p.alive:
			continue
		var to: Vector3 = p.node.position - ap
		if to.length() < 28.0 and fwd.dot(to.normalized()) > 0.5:
			_kill_ped(p)
			_crime()
			return
		loud = loud or to.length() < 16.0
	for c in cops:
		var to2: Vector3 = c.node.position - ap
		if to2.length() < 30.0 and fwd.dot(to2.normalized()) > 0.4:
			c.node.queue_free()
			cops.erase(c)
			Juice.sfx("thud")
			_crime()
			return
	if loud:
		_crime()

func _kill_ped(p: Dictionary) -> void:
	p.alive = false
	p.node.visible = false
	Juice.sfx("boom", 1.3)
	shake = maxf(shake, 0.5)

func _crime() -> void:
	if wanted >= 5:
		return
	wanted += 1
	heat = 0.0
	Juice.sfx("thud")
	Juice.haptic(30)
	Juice.flash(Color(1, 0.3, 0.3), 0.2)
	_pop("WANTED +1", Color(1, 0.4, 0.4))
	_spawn_cop()
	if wanted >= 3:
		_spawn_cop()

func _process(delta: float) -> void:
	if not running:
		return
	if in_car:
		var car: MeshInstance3D = cars[current_car]
		var throttle := clampf(key_axis_y() - tc.move.y, -1.0, 1.0)
		var steer := tc.move.x + key_axis_x()
		car_speed = lerpf(car_speed, throttle * TOP_SPEED, delta * 2.2)
		car_yaw -= steer * 2.2 * delta * clampf(car_speed / 8.0, -1.0, 1.0)
		car.rotation.y = car_yaw
		car.position += _forward(car_yaw) * car_speed * delta
		car.position.y = 0.6
		for p in peds:
			if p.alive and absf(car_speed) > 5.0 and car.position.distance_to(p.node.position) < 2.8:
				_kill_ped(p)
				shake = maxf(shake, 0.7)
				_pop("HIT AND RUN", Color(1, 0.5, 0.4))
				_crime()
				break
	else:
		var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
		if mv.length() > 0.15:
			mv = mv.limit_length(1.0)
			foot_pos += mv * FOOT_SPEED * delta
			foot_yaw = atan2(mv.x, mv.z)
			player.rotation.y = foot_yaw
		player.position = foot_pos
	_update_actors(delta)
	_update_heat(delta)
	_check_objective()
	_update_camera(delta)
	_update_hud()
	if hp <= 0.0:
		_die()

func _update_actors(delta: float) -> void:
	var ap := _active_pos()
	for p in peds:
		if not p.alive:
			continue
		p.node.position += p.vel * delta
		if absf(p.node.position.x) > 40.0 or absf(p.node.position.z) > 40.0:
			p.vel = -p.vel
	var spd := 10.0 + float(wanted) * 2.0
	for c in cops:
		var to := ap - c.node.position
		to.y = 0.0
		var d := to.length()
		if d > 0.1:
			c.node.position += to.normalized() * spd * delta
			c.node.rotation.y = atan2(to.x, to.z)
		if d < 2.6:
			hp -= 14.0 * delta
			shake = maxf(shake, 0.3)
		c.fire -= delta
		if wanted >= 2 and d < 24.0 and c.fire <= 0.0:
			c.fire = 1.3
			hp -= randf_range(4.0, 8.0)
			Juice.sfx("thud")
			Juice.flash(Color(1, 0.2, 0.2), 0.16)
			shake = maxf(shake, 0.35)

func _update_heat(delta: float) -> void:
	if wanted == 0:
		return
	var nearest := 999.0
	var ap := _active_pos()
	for c in cops:
		nearest = minf(nearest, c.node.position.distance_to(ap))
	if nearest <= 46.0:
		heat = 0.0
		return
	heat += delta
	if heat < 6.0:
		return
	heat = 0.0
	wanted -= 1
	if wanted == 0:
		for c in cops:
			c.node.queue_free()
		cops.clear()
		_pop("LOST THEM", Color(0.6, 0.9, 1.0))
	elif cops.size() > 0:
		var c: Dictionary = cops[0]
		c.node.queue_free()
		cops.erase(c)
		_pop("HEAT DOWN", Color(0.6, 0.9, 1.0))
	Juice.sfx("tick")

func _check_objective() -> void:
	var ap := _active_pos()
	if Vector2(ap.x - obj_pos.x, ap.z - obj_pos.z).length() > 4.5:
		return
	var reward := 100 + wanted * 25
	add_points(reward)
	Juice.sfx("chime")
	Juice.sfx("coin", 1.1)
	Juice.flash(Color(0.4, 1, 0.6), 0.22)
	Juice.haptic(25)
	_pop("JOB DONE +%d" % reward, Color(0.5, 1, 0.7))
	_spawn_objective()

func _update_camera(delta: float) -> void:
	var ap := _active_pos()
	var fwd := _forward(_active_yaw())
	var back := 13.0 if in_car else 9.0
	var high := 8.0 if in_car else 6.0
	var off := Vector3(randf_range(-shake, shake), randf_range(-shake, shake), 0)
	cam.position = cam.position.lerp(ap - fwd * back + Vector3.UP * high + off, clampf(delta * 6.0, 0.0, 1.0))
	cam.look_at(ap + Vector3.UP * 1.5, Vector3.UP)
	shake = lerpf(shake, 0.0, clampf(delta * 4.0, 0.0, 1.0))
	if obj_node:
		obj_node.rotation.y += delta * 1.5

func _update_hud() -> void:
	var ap := _active_pos()
	var dist := int(Vector2(ap.x - obj_pos.x, ap.z - obj_pos.z).length())
	var stars := "*".repeat(wanted) + ".".repeat(5 - wanted)
	var mode := "DRIVING" if in_car else "ON FOOT"
	hud.text = "HP %d\nWANTED [%s]\n%s\nJOB %dm\nSCORE %d" % [int(hp), stars, mode, dist, score]

func _die() -> void:
	Juice.sfx("boom")
	Juice.flash(Color(1, 0.3, 0.3), 0.32)
	Juice.haptic(60)
	_pop("BUSTED", Color(1, 0.4, 0.4))
	end_demo()

func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_toggle_car()
		elif event.keycode == KEY_SPACE:
			_fire()
