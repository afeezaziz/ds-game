extends MechDemo3D
## BOWLING — line, hook and pin physics. Slide the ball left/right at the foul line,
## set the aim angle, HOLD ROLL for power, release to bowl; add HOOK curve mid-lane.
## Pins topple with real-ish collisions. Ten frames; strikes and spares bank bonus.
## Desktop: A/D move, Q/E has no effect — SPACE hold-to-roll.

const LANE_W := 6.0
const LANE_LEN := 60.0

var ball: Node3D
var bpos := Vector2.ZERO      # x across, z down-lane (0 at foul line)
var bvel := Vector2.ZERO
var rolling := false
var start_x := 0.0
var aim := 0.0
var power := 0.0
var charging := false
var hook := 0.0
var pins: Array = []          # {pos:Vector2, node, down:bool}
var frame := 1
var throw_in_frame := 0
var pins_this_frame := 0
var tc: TouchControls
var hud: Label3D
var aim_arrow: Node3D


func start() -> void:
	super.start()
	setup_world(Color(0.12, 0.13, 0.18), 0.85, Vector3(-70, 0, 0))
	static_box(Vector3(LANE_W, 1, LANE_LEN), Vector3(0, -0.5, -LANE_LEN * 0.5 + 4), Color(0.6, 0.45, 0.25))
	static_box(Vector3(0.5, 1.5, LANE_LEN), Vector3(-LANE_W * 0.5 - 0.3, 0.2, -LANE_LEN * 0.5 + 4), Color(0.2, 0.2, 0.25))
	static_box(Vector3(0.5, 1.5, LANE_LEN), Vector3(LANE_W * 0.5 + 0.3, 0.2, -LANE_LEN * 0.5 + 4), Color(0.2, 0.2, 0.25))
	ball = mesh_sphere(0.6, Vector3.ZERO, Color(0.2, 0.3, 0.9))
	aim_arrow = mesh_box(Vector3(0.15, 0.05, 4.0), Vector3.ZERO, Color(1, 1, 0.4, 0.6))
	frame = 1
	throw_in_frame = 0
	make_camera(Vector3(0, 8, 12), Vector3(0, 0, -20), 55.0)
	hud = label3d("", Vector3(0, 7, 8), 34, Color.WHITE)
	tc = add_touch_controls([{"id": "roll", "label": "ROLL", "col": Color(0.5, 0.6, 0.9)}])
	tc.action.connect(func(_id): charging = true)
	tc.released.connect(func(_id): _roll())
	_setup_pins()
	_reset_ball()


func _setup_pins() -> void:
	for p in pins:
		p.node.queue_free()
	pins = []
	var rows := [1, 2, 3, 4]
	var zbase := -LANE_LEN + 8
	for r in 4:
		for c in range(rows[r]):
			var x := (c - r * 0.5) * 1.3
			var z := zbase - r * 1.3
			var node := mesh_cyl(0.28, 1.6, Vector3(x, 0.8, z), Color(0.95, 0.95, 0.95))
			pins.append({"pos": Vector2(x, z), "node": node, "down": false})


func _reset_ball() -> void:
	bpos = Vector2(start_x, 2.0)
	bvel = Vector2.ZERO
	rolling = false
	hook = 0.0
	ball.position = Vector3(bpos.x, 0.6, bpos.y)


func _roll() -> void:
	if not charging or rolling:
		charging = false
		return
	charging = false
	bvel = Vector2(sin(aim), -cos(aim)) * (18.0 + power * 22.0)
	hook = (tc.move.x + key_axis_x()) * 6.0     # residual lean = hook
	power = 0.0
	rolling = true
	Juice.sfx("thud")


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and not event.echo and event.keycode == KEY_SPACE:
		if event.pressed:
			charging = true
		else:
			_roll()


func _process(delta: float) -> void:
	if not running:
		return
	if charging:
		power = min(1.0, power + delta * 0.9)
	if not rolling:
		start_x = clampf(start_x + (tc.move.x + key_axis_x()) * 4.0 * delta, -LANE_W * 0.4, LANE_W * 0.4)
		aim = clampf(aim + (key_axis_x()) * 0.0, -0.3, 0.3)
		bpos.x = start_x
		ball.position = Vector3(bpos.x, 0.6, bpos.y)
		aim_arrow.position = Vector3(bpos.x, 0.4, bpos.y - 2.5)
		aim_arrow.rotation.y = aim
		aim_arrow.visible = true
	else:
		aim_arrow.visible = false
		bvel.x += hook * delta                  # the hook curves the path
		bvel *= 0.995
		bpos += bvel * delta
		bpos.x = clampf(bpos.x, -LANE_W * 0.5 + 0.6, LANE_W * 0.5 - 0.6)
		ball.position = Vector3(bpos.x, 0.6, bpos.y)
		_ball_pins()
		if bpos.y < -LANE_LEN + 4 or bvel.length() < 2.0:
			_settle_throw()

	cam.position = Vector3(bpos.x * 0.3, 8, bpos.y + 12.0)
	cam.look_at(Vector3(0, 0, -LANE_LEN + 8), Vector3.UP)
	hud.text = "FRAME %d/10   this-frame pins %d   POWER %d%%" % [frame, pins_this_frame, int(power * 100)]


func _ball_pins() -> void:
	for p in pins:
		if p.down:
			continue
		if Vector2(bpos.x - p.pos.x, bpos.y - p.pos.y).length() < 0.9:
			p.down = true
			p.node.rotation.z = 1.4
			p.node.position.y = 0.3
			pins_this_frame += 1
			Juice.sfx("tick")
			# chain: nudge nearby pins
			for q in pins:
				if not q.down and q.pos.distance_to(p.pos) < 1.6 and randf() < 0.55:
					q.down = true
					q.node.rotation.z = 1.2
					q.node.position.y = 0.3
					pins_this_frame += 1


func _settle_throw() -> void:
	throw_in_frame += 1
	var standing := pins.filter(func(x): return not x.down).size()
	if standing == 0 or throw_in_frame >= 2:
		# frame over
		add_points(pins_this_frame)
		if pins_this_frame >= 10:
			Juice.sfx("coin")
			Juice.popup("STRIKE!" if throw_in_frame == 1 else "SPARE!", Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))
			add_points(5)
		frame += 1
		throw_in_frame = 0
		pins_this_frame = 0
		if frame > 10:
			end_demo()
			return
		_setup_pins()
	_reset_ball()
