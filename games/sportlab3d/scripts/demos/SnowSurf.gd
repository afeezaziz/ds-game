extends MechDemo3D
## SNOWBOARD — carve a downhill flow line (SSX). You auto-descend; steer to thread
## the GATES and dodge trees, TUCK for speed, and off a jump hold SPIN to bank air
## tricks — land clean or wipe out. Trees cost speed and a life. Score = gates +
## tricks + distance. Desktop: A/D carve, S tuck, SPACE spin.

var rider: Node3D
var pos := Vector3(0, 0, 0)
var lane := 0.0
var down := 0.0             # distance travelled downhill
var speed := 16.0
var vy := 0.0
var airborne := false
var spinning := false
var spin_amt := 0.0
var lives := 3
var obstacles: Array = []   # {node, x, z, kind}  kind: tree/gate/ramp
var next_z := -20.0
var tc: TouchControls
var hud: Label3D
const SLOPE := 0.28


func start() -> void:
	super.start()
	setup_world(Color(0.7, 0.82, 0.95), 1.0, Vector3(-45, -30, 0))
	static_box(Vector3(30, 1, 400), Vector3(0, -0.5, -180), Color(0.9, 0.93, 1.0))
	rider = Node3D.new()
	add_child(rider)
	mesh_box(Vector3(0.7, 1.6, 0.5), Vector3(0, 0.9, 0), Color(0.9, 0.4, 0.3), rider)
	mesh_box(Vector3(0.5, 0.1, 2.0), Vector3(0, 0.1, 0), Color(0.2, 0.9, 0.9), rider)
	lane = 0.0
	down = 0.0
	speed = 16.0
	lives = 3
	airborne = false
	obstacles = []
	next_z = -20.0
	for i in 14:
		_spawn_row()
	make_camera(Vector3(0, 6, 10), Vector3.ZERO, 62.0)
	hud = label3d("", Vector3(0, 5, 0), 34, Color.WHITE)
	tc = add_touch_controls([{"id": "spin", "label": "SPIN", "col": Color(0.6, 0.7, 0.95)}])
	tc.action.connect(func(_id): _spin())


func _spawn_row() -> void:
	next_z -= randf_range(9, 14)
	var roll := randf()
	var x := randf_range(-12, 12)
	if roll < 0.4:
		var node := mesh_cyl(0.8, 4.0, Vector3(x, 2, next_z), Color(0.2, 0.5, 0.25))
		obstacles.append({"node": node, "x": x, "z": next_z, "kind": "tree"})
	elif roll < 0.7:
		var g := Node3D.new()
		add_child(g)
		mesh_box(Vector3(0.4, 3.0, 0.4), Vector3(-2.5, 1.5, 0), Color(1, 0.3, 0.3), g)
		mesh_box(Vector3(0.4, 3.0, 0.4), Vector3(2.5, 1.5, 0), Color(1, 0.3, 0.3), g)
		g.position = Vector3(x, 0, next_z)
		obstacles.append({"node": g, "x": x, "z": next_z, "kind": "gate"})
	else:
		var node := mesh_box(Vector3(6, 1.2, 4), Vector3(x, 0.6, next_z), Color(0.75, 0.8, 0.95))
		obstacles.append({"node": node, "x": x, "z": next_z, "kind": "ramp"})


func _spin() -> void:
	if airborne and not spinning:
		spinning = true
		spin_amt = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_spin()


func _process(delta: float) -> void:
	if not running:
		return
	var tuck := 1.0
	if Input.is_key_pressed(KEY_S) or tc.move.y > 0.4:
		tuck = 1.5
	speed = move_toward(speed, (16.0 + down * 0.02) * tuck, 8.0 * delta)
	down += speed * delta
	lane = clampf(lane + (tc.move.x + key_axis_x()) * 14.0 * delta, -13, 13)
	pos = Vector3(lane, -down * SLOPE, -down)
	add_points(0)
	set_score(int(down * 0.1) + _bonus)

	if airborne:
		vy -= 20.0 * delta
		pos.y += vy * delta
		if spinning:
			spin_amt += delta * 6.0
			rider.rotation.y = spin_amt
		var ground := -down * SLOPE
		if pos.y <= ground:
			pos.y = ground
			airborne = false
			if spinning:
				var rots := int(spin_amt / TAU)
				if rots >= 1:
					_bonus += rots * 15
					Juice.sfx("coin")
					Juice.popup("%d SPIN +%d" % [rots, rots * 15], Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))
				spinning = false
				rider.rotation.y = 0.0
	rider.position = pos

	# recycle + collide
	for o in obstacles:
		if o.z > -down + 6.0:
			# passed it; recycle to the front
			if o.kind == "gate" and absf(o.x - lane) < 2.2 and absf(o.z - (-down)) < 3.0:
				pass
			o.z -= 14.0 * 14
			o.x = randf_range(-12, 12)
		var ox: float = o.x
		var oz: float = o.z
		o.node.position = Vector3(ox, (-oz) * SLOPE + (0.6 if o.kind == "ramp" else (2 if o.kind == "tree" else 0)), oz)
		var near := absf(oz - (-down)) < 2.0 and absf(ox - lane) < 2.0
		if near:
			if o.kind == "tree" and not airborne:
				_wipeout()
				o.z -= 200.0
			elif o.kind == "gate":
				_bonus += 8
				Juice.sfx("tick")
				o.z -= 200.0
			elif o.kind == "ramp" and not airborne:
				airborne = true
				vy = 9.0

	cam.position = pos + Vector3(0, 6, 11)
	cam.look_at(pos + Vector3(0, 0, -10), Vector3.UP)
	hud.text = "SCORE %d   speed %d   %s   lives %d" % [
		score, int(speed), "AIR" if airborne else "carving", lives]
	hud.position = pos + Vector3(0, 5, 0)


var _bonus := 0
func _wipeout() -> void:
	lives -= 1
	speed = 8.0
	Juice.sfx("boom")
	Juice.flash(Color(1, 0.4, 0.4), 0.3)
	Juice.haptic(35)
	Juice.popup("WIPEOUT", Vector2(W * 0.5, H * 0.4), Color(1, 0.5, 0.4))
	if lives <= 0:
		end_demo()
