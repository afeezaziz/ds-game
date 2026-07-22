extends MechDemo3D
## PINBALL — flippers, bumpers, physics (scripted). The ball rolls down the tilted
## table under gravity; time the LEFT/RIGHT flippers to launch it back up into the
## bumpers and targets for points. Let it drain past the flippers and you lose a ball
## — three and you're out. Desktop: A/Left = left flip, D/Right = right flip.

const TW := 9.0              # table half width (x)
const TOP := -22.0           # top of table (z)
const BOTTOM := 4.0          # drain line (z)
const R := 0.6               # ball radius

var ball := Vector2(6, -10)
var bvel := Vector2.ZERO
var ball_node: Node3D
var balls_left := 3
var lflip := 0.0             # sweep timer
var rflip := 0.0
var lnode: Node3D
var rnode: Node3D
var bumpers: Array = []      # {pos:Vector2, node}
var tc: TouchControls
var hud: Label3D
const LF := Vector2(-3.0, 0.5)
const RF := Vector2(3.0, 0.5)


func start() -> void:
	super.start()
	setup_world(Color(0.05, 0.06, 0.12), 0.85, Vector3(-75, 0, 0))
	static_box(Vector3(TW * 2 + 2, 1, (BOTTOM - TOP) + 2), Vector3(0, -0.5, (TOP + BOTTOM) * 0.5), Color(0.12, 0.13, 0.2))
	# side walls (visual)
	mesh_box(Vector3(0.6, 1.5, BOTTOM - TOP), Vector3(-TW - 0.3, 0.5, (TOP + BOTTOM) * 0.5), Color(0.3, 0.3, 0.4))
	mesh_box(Vector3(0.6, 1.5, BOTTOM - TOP), Vector3(TW + 0.3, 0.5, (TOP + BOTTOM) * 0.5), Color(0.3, 0.3, 0.4))
	mesh_box(Vector3(TW * 2, 1.5, 0.6), Vector3(0, 0.5, TOP - 0.3), Color(0.3, 0.3, 0.4))
	bumpers = []
	for p in [Vector2(-3.5, -15), Vector2(3.5, -15), Vector2(0, -18), Vector2(-5, -9), Vector2(5, -9)]:
		var node := mesh_cyl(1.1, 1.0, Vector3(p.x, 0.5, p.y), Color(0.9, 0.5, 0.9))
		bumpers.append({"pos": p, "node": node})
	lnode = mesh_box(Vector3(3.4, 0.5, 0.7), Vector3(LF.x, 0.4, LF.y), Color(0.4, 0.8, 1.0))
	rnode = mesh_box(Vector3(3.4, 0.5, 0.7), Vector3(RF.x, 0.4, RF.y), Color(0.4, 0.8, 1.0))
	ball_node = mesh_sphere(R, Vector3.ZERO, Color(0.9, 0.9, 1.0))
	balls_left = 3
	_launch()
	make_camera(Vector3(0, 20, 14), Vector3(0, 0, -9), 50.0)
	hud = label3d("", Vector3(0, 10, 2), 32, Color.WHITE)
	tc = add_touch_controls([
		{"id": "left", "label": "◄ FLIP", "col": Color(0.4, 0.75, 1.0)},
		{"id": "right", "label": "FLIP ►", "col": Color(0.4, 0.75, 1.0)},
	], false, false)
	tc.action.connect(func(id):
		if id == "left": lflip = 0.16
		elif id == "right": rflip = 0.16)


func _launch() -> void:
	ball = Vector2(TW - 1.0, -2.0)
	bvel = Vector2(randf_range(-1, 1), -34.0)   # shoot up the table


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT: lflip = 0.16
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT: rflip = 0.16


func _flip(fpos: Vector2, active: float, dirx: float) -> void:
	if active <= 0.0:
		return
	var d := ball - fpos
	if d.length() < 3.6 and bvel.y > -2.0:
		# launch the ball up and outward
		bvel = Vector2(dirx * 8.0 + d.x * 1.5, -30.0)
		Juice.sfx("tick")
		Juice.haptic(10)


func _process(delta: float) -> void:
	if not running:
		return
	lflip = maxf(0.0, lflip - delta)
	rflip = maxf(0.0, rflip - delta)
	lnode.rotation.z = -lflip * 3.0
	rnode.rotation.z = rflip * 3.0

	# gravity pulls DOWN the table (+z)
	bvel.y += 22.0 * delta
	bvel *= 0.999
	ball += bvel * delta

	# walls
	if ball.x < -TW + R:
		ball.x = -TW + R
		bvel.x = absf(bvel.x) * 0.85
	elif ball.x > TW - R:
		ball.x = TW - R
		bvel.x = -absf(bvel.x) * 0.85
	if ball.y < TOP + R:
		ball.y = TOP + R
		bvel.y = absf(bvel.y) * 0.85

	# bumpers
	for b in bumpers:
		var d: Vector2 = ball - b.pos
		if d.length() < 1.1 + R:
			var n := d.normalized()
			ball = b.pos + n * (1.1 + R)
			bvel = n * maxf(bvel.length(), 18.0)
			add_points(10)
			Juice.sfx("coin")
			Juice.flash(Color(0.9, 0.6, 1.0), 0.08)

	# flippers
	_flip(LF, lflip, -1.0)
	_flip(RF, rflip, 1.0)

	# drain
	if ball.y > BOTTOM:
		balls_left -= 1
		Juice.sfx("boom")
		Juice.flash(Color(1, 0.4, 0.4), 0.3)
		Juice.haptic(30)
		if balls_left <= 0:
			end_demo()
			return
		_launch()

	ball_node.position = Vector3(ball.x, R, ball.y)
	hud.text = "SCORE %d   BALLS %d" % [score, balls_left]
	hud.position = Vector3(0, 10, 2)
