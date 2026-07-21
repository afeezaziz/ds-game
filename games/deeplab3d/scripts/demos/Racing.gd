extends MechDemo3D
## CIRCUIT RACING — a real lap circuit with AI rivals, drift and boost. Steer to
## follow the track; hold to drift and build boost, release to fire it. Complete
## 3 laps to win and start a faster race. Score = races won. Desktop: A/D steer,
## Space drift.

var checkpoints: Array = []   # Vector3 ring
var kart: Node3D
var kpos := Vector3.ZERO
var kyaw := 0.0
var speed := 0.0
var next_cp := 0
var lap := 0
var boost := 0.0
var boost_t := 0.0
var drifting := false
var race := 1
var rivals: Array = []        # {node, cp, t}
var hud: Label3D
const RX := 34.0
const RZ := 22.0


func start() -> void:
	super.start()
	setup_world(Color(0.45, 0.62, 0.85))
	static_box(Vector3(90, 1, 70), Vector3(0, -0.5, 0), Color(0.3, 0.5, 0.3))
	checkpoints = []
	for i in 24:
		var a := i * TAU / 24.0
		var p := Vector3(cos(a) * RX, 0, sin(a) * RZ)
		checkpoints.append(p)
		mesh_box(Vector3(7, 0.15, 7), p + Vector3(0, 0.08, 0), Color(0.25, 0.25, 0.28))
	kart = Node3D.new()
	add_child(kart)
	mesh_box(Vector3(1.6, 0.6, 2.6), Vector3(0, 0.5, 0), Color(0.9, 0.25, 0.25), kart)
	mesh_box(Vector3(1.2, 0.5, 1.0), Vector3(0, 0.95, -0.3), Color(0.2, 0.2, 0.3), kart)
	kpos = checkpoints[0]
	kyaw = 0.0
	speed = 0.0
	next_cp = 1
	lap = 0
	race = 1
	boost = 0.0
	boost_t = 0.0
	rivals = []
	for i in 2:
		var rn := Node3D.new()
		add_child(rn)
		mesh_box(Vector3(1.6, 0.6, 2.6), Vector3(0, 0.5, 0), Color(0.3, 0.4, 0.9) if i == 0 else Color(0.9, 0.7, 0.2), rn)
		rn.position = checkpoints[checkpoints.size() - 1 - i * 2]
		rivals.append({"node": rn, "cp": 0, "spd": 13.0 + i})
	make_camera(Vector3(0, 6, 12), Vector3.ZERO, 60.0)
	hud = label3d("", Vector3(0, 12, 0), 40, Color.WHITE)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			drifting = true
			boost = 0.0
		else:
			drifting = false
			boost_t = boost
			boost = 0.0
	elif event is InputEventKey and event.keycode == KEY_SPACE:
		if event.pressed:
			drifting = true
		else:
			drifting = false
			boost_t = boost
			boost = 0.0


func _steer() -> float:
	var s := key_axis_x()
	# touch: steer toward finger x handled via drag
	return s


var touch_steer := 0.0


func _input(event: InputEvent) -> void:
	if running and event is InputEventScreenDrag:
		touch_steer = clampf(event.relative.x * 0.15, -1.0, 1.0)


func _process(delta: float) -> void:
	if not running:
		return
	var target := 16.0 + race * 2.0
	speed = move_toward(speed, target, 12.0 * delta)
	var cur := speed
	if boost_t > 0.0:
		boost_t -= delta
		cur *= 1.5
	if drifting:
		boost = minf(1.5, boost + delta)
	var steer := _steer() + touch_steer
	touch_steer = move_toward(touch_steer, 0.0, delta * 3.0)
	kyaw -= steer * (2.4 if drifting else 1.7) * delta
	var fwd := Vector3(sin(kyaw), 0, cos(kyaw))
	kpos += fwd * cur * delta
	# keep on the ring-ish field
	kpos.x = clampf(kpos.x, -46, 46)
	kpos.z = clampf(kpos.z, -36, 36)
	kart.position = kpos
	kart.rotation.y = kyaw

	# checkpoint progression
	if kpos.distance_to(checkpoints[next_cp]) < 7.0:
		next_cp = (next_cp + 1) % checkpoints.size()
		if next_cp == 1:
			lap += 1
			Juice.sfx("tick")
			if lap >= 3:
				add_points(1)
				race += 1
				lap = 0
				Juice.sfx("chime")

	for rv in rivals:
		var tcp: Vector3 = checkpoints[rv.cp]
		rv.node.position = rv.node.position.move_toward(tcp, rv.spd * delta)
		if rv.node.position.distance_to(tcp) < 3.0:
			rv.cp = (rv.cp + 1) % checkpoints.size()
		rv.node.look_at(tcp, Vector3.UP)

	cam.position = kpos - fwd * 12.0 + Vector3(0, 6, 0)
	cam.look_at(kpos + fwd * 6.0, Vector3.UP)
	hud.text = "RACE %d   LAP %d/3   %s" % [race, lap + 1, "BOOST!" if boost_t > 0 else ("drift %.0f%%" % (boost / 1.5 * 100))]
	hud.position = kpos + Vector3(0, 5, 0)
