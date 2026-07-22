extends MechDemo3D
## DELIVERY DRIVER — a cargo/taxi run (Euro Truck · Crazy Taxi). Drive the city,
## reach the green PICKUP, then race the fare to the gold DROPOFF before the timer
## runs out. Traffic and buildings hurt: a crash costs speed, time and your rig's
## condition. Score = deliveries. Desktop: W/S throttle, A/D steer, SPACE handbrake.

var car: Node3D
var cpos := Vector3.ZERO
var cyaw := 0.0
var speed := 0.0
var condition := 100.0
var fare_t := 30.0
var has_cargo := false
var pickup := Vector3.ZERO
var dropoff := Vector3.ZERO
var marker: Node3D
var traffic: Array = []       # {node,pos,dir,spd}
var crash_cd := 0.0
var tc: TouchControls
var hud: Label3D
const CITY := 70.0


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.62, 0.78), 0.9)
	static_box(Vector3(CITY * 2, 1, CITY * 2), Vector3(0, -0.5, 0), Color(0.32, 0.32, 0.36))
	# city blocks on a grid, leaving roads between
	for gx in range(-2, 3):
		for gz in range(-2, 3):
			if gx == 0 or gz == 0:
				continue
			var h := randf_range(6, 18)
			static_box(Vector3(14, h, 14), Vector3(gx * 24, h * 0.5, gz * 24), hue_col(gx * gz * 0.1, 0.25, 0.6))
	car = Node3D.new()
	add_child(car)
	mesh_box(Vector3(2.4, 1.4, 4.6), Vector3(0, 0.9, 0), Color(0.9, 0.75, 0.2), car)
	mesh_box(Vector3(2.2, 1.0, 1.8), Vector3(0, 1.7, -0.6), Color(0.2, 0.25, 0.3), car)
	cpos = Vector3.ZERO
	cyaw = 0.0
	speed = 0.0
	condition = 100.0
	fare_t = 30.0
	has_cargo = false
	traffic = []
	marker = Node3D.new()
	add_child(marker)
	mesh_cyl(2.2, 8.0, Vector3(0, 4, 0), Color(0.3, 1, 0.4, 0.6), marker)
	for i in 8:
		var horiz := i % 2 == 0
		var tn := Node3D.new()
		add_child(tn)
		mesh_box(Vector3(2.2, 1.3, 4.2), Vector3(0, 0.8, 0), Color(0.7, 0.3, 0.3), tn)
		var lane := (randi() % 5 - 2) * 24.0
		var p := Vector3(lane if not horiz else randf_range(-CITY, CITY), 0, randf_range(-CITY, CITY) if not horiz else lane)
		tn.position = p
		var d := Vector3(0, 0, 1) if not horiz else Vector3(1, 0, 0)
		traffic.append({"node": tn, "pos": p, "dir": d, "spd": randf_range(8, 16)})
	make_camera(Vector3(0, 8, 12), Vector3.ZERO, 60.0)
	hud = label3d("", Vector3(0, 6, 0), 34, Color.WHITE)
	_new_pickup()


func _new_pickup() -> void:
	has_cargo = false
	pickup = _road_point()
	fare_t = 30.0
	marker.position = pickup
	_tint(Color(0.3, 1, 0.4, 0.6))


func _road_point() -> Vector3:
	# somewhere on a road axis
	var along := randf_range(-CITY + 6, CITY - 6)
	var lane := (randi() % 5 - 2) * 24.0
	return Vector3(lane, 0, along) if randf() < 0.5 else Vector3(along, 0, lane)


func _tint(c: Color) -> void:
	var mi := marker.get_child(0) as MeshInstance3D
	(mi.material_override as StandardMaterial3D).albedo_color = c


func _handbrake() -> void:
	speed *= 0.4


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_handbrake()


func _process(delta: float) -> void:
	if not running:
		return
	crash_cd = maxf(0.0, crash_cd - delta)
	# fare timer only ticks once you're carrying (before that it's "find pickup")
	fare_t -= delta
	if fare_t <= 0.0:
		end_demo()
		return

	var throttle := tc.move.y * -1.0 + key_axis_y()
	var steer := tc.move.x + key_axis_x()
	speed = move_toward(speed, clampf(throttle, -0.5, 1.0) * 34.0, 26.0 * delta)
	cyaw -= steer * (1.8 * clampf(absf(speed) / 20.0, 0.2, 1.0)) * delta
	var fwd := Vector3(sin(cyaw), 0, cos(cyaw))
	cpos += fwd * speed * delta
	cpos.x = clampf(cpos.x, -CITY, CITY)
	cpos.z = clampf(cpos.z, -CITY, CITY)
	car.position = cpos
	car.rotation.y = cyaw

	# traffic drives + wraps; collision with player
	for tr in traffic:
		tr.pos += tr.dir * tr.spd * delta
		if absf(tr.pos.x) > CITY or absf(tr.pos.z) > CITY:
			tr.pos = -tr.pos * 0.9
		tr.node.position = tr.pos
		tr.node.rotation.y = atan2(tr.dir.x, tr.dir.z)
		if crash_cd <= 0.0 and tr.pos.distance_to(cpos) < 3.4:
			crash_cd = 1.0
			condition -= 16.0
			fare_t -= 3.0
			speed *= 0.2
			Juice.sfx("boom")
			Juice.flash(Color(1, 0.3, 0.2), 0.3)
			Juice.haptic(35)
			if condition <= 0.0:
				end_demo()
				return

	# pickup / dropoff logic
	marker.rotation.y += delta * 2.0
	if not has_cargo and cpos.distance_to(pickup) < 4.5:
		has_cargo = true
		dropoff = _road_point()
		fare_t = 34.0
		marker.position = dropoff
		_tint(Color(1, 0.85, 0.3, 0.6))
		Juice.sfx("chime")
	elif has_cargo and cpos.distance_to(dropoff) < 4.5:
		add_points(1)
		condition = minf(100.0, condition + 10.0)
		Juice.sfx("coin")
		Juice.flash(Color(0.4, 1, 0.5), 0.25)
		Juice.popup("DELIVERED +1", Vector2(W * 0.5, H * 0.4), Color(0.5, 1, 0.6))
		_new_pickup()

	cam.position = cpos - fwd * 12.0 + Vector3(0, 8, 0)
	cam.look_at(cpos + fwd * 6.0, Vector3.UP)
	var tgt := pickup if not has_cargo else dropoff
	hud.text = "%s  %.0fm   TIME %d   RIG %d%%   jobs %d" % [
		"PICKUP" if not has_cargo else "DELIVER", cpos.distance_to(tgt), int(fare_t), int(condition), score]
	hud.position = cpos + Vector3(0, 6, 0)
