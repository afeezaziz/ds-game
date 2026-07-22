extends MechDemo3D
## SOCCER — a small-sided match. Chase the ball, dribble it with you, and KICK toward
## the far goal; the keeper and two defenders try to win it back and score on you.
## First to 5 takes the match. Desktop: WASD move, SPACE kick, K tackle.

const FW := 20.0             # field half width (x)
const FL := 30.0             # field half length (z)  attack toward -z

var player: Node3D
var ppos := Vector3(0, 0, 18)
var facing := Vector3(0, 0, -1)
var ball := Vector3(0, 0.4, 0)
var bvel := Vector3.ZERO
var foes: Array = []          # {node,pos}
var keeper: Node3D
var you := 0
var them := 0
var match_no := 1
var kick_cd := 0.0
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.4, 0.7, 0.45), 0.95, Vector3(-55, -30, 0))
	static_box(Vector3(FW * 2, 1, FL * 2), Vector3(0, -0.5, 0), Color(0.3, 0.6, 0.35))
	# goals
	mesh_box(Vector3(8, 3, 1), Vector3(0, 1.5, -FL), Color(0.9, 0.9, 0.95))
	mesh_box(Vector3(8, 3, 1), Vector3(0, 1.5, FL), Color(0.9, 0.5, 0.5))
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(1.1, 1.9, 1.1), Vector3(0, 0.95, 0), Color(0.3, 0.5, 0.95), player)
	mesh_box(Vector3(0.3, 0.3, 0.9), Vector3(0, 0.6, 0.6), Color(0.2, 0.3, 0.7), player)
	var bn := mesh_sphere(0.4, Vector3.ZERO, Color.WHITE)
	bn.name = "Ball"
	keeper = Node3D.new()
	add_child(keeper)
	mesh_box(Vector3(1.2, 1.9, 1.2), Vector3(0, 0.95, 0), Color(0.95, 0.8, 0.3), keeper)
	you = 0
	them = 0
	match_no = 1
	_kickoff()
	for i in 2:
		var fn := Node3D.new()
		add_child(fn)
		mesh_box(Vector3(1.1, 1.9, 1.1), Vector3(0, 0.95, 0), Color(0.9, 0.35, 0.35), fn)
		var fp := Vector3((i * 2 - 1) * 6.0, 0, -8)
		fn.position = fp
		foes.append({"node": fn, "pos": fp})
	make_camera(Vector3(0, 20, 22), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 12, 0), 34, Color.WHITE)
	tc = add_touch_controls([
		{"id": "kick", "label": "KICK", "col": Color(0.9, 0.7, 0.4)},
		{"id": "tackle", "label": "TACKLE", "col": Color(0.5, 0.8, 0.7)},
	])
	tc.action.connect(func(id):
		if id == "kick": _kick()
		elif id == "tackle": _tackle())


func _ball_node() -> Node3D:
	return get_node("Ball")


func _kickoff() -> void:
	ball = Vector3(0, 0.4, 0)
	bvel = Vector3.ZERO
	ppos = Vector3(0, 0, 10)


func _kick() -> void:
	if kick_cd > 0.0 or ppos.distance_to(ball) > 2.4:
		return
	kick_cd = 0.4
	bvel = facing * 26.0 + Vector3(0, 3.0, 0)
	Juice.sfx("thud")
	Juice.haptic(15)


func _tackle() -> void:
	for f in foes:
		if ppos.distance_to(f.pos) < 2.2 and f.pos.distance_to(ball) < 2.2:
			bvel = (ppos - ball).normalized() * 8.0
			Juice.sfx("tick")
			return


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _kick()
		elif event.keycode == KEY_K: _tackle()


func _process(delta: float) -> void:
	if not running:
		return
	kick_cd = maxf(0.0, kick_cd - delta)
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * 10.0 * delta
	ppos.x = clampf(ppos.x, -FW, FW)
	ppos.z = clampf(ppos.z, -FL + 1, FL - 1)
	if mv.length() > 0.1:
		facing = mv.normalized()
		player.rotation.y = atan2(mv.x, mv.z)
	player.position = ppos

	# dribble: nudge the ball ahead of you when close and it's slow
	if ppos.distance_to(ball) < 1.6 and bvel.length() < 6.0:
		ball = ppos + facing * 1.2
		ball.y = 0.4
		bvel = mv * 8.0

	# ball physics
	bvel.y -= 20.0 * delta
	ball += bvel * delta
	if ball.y <= 0.4:
		ball.y = 0.4
		bvel.y = -bvel.y * 0.4 if bvel.y < -2.0 else 0.0
		bvel.x *= 0.96
		bvel.z *= 0.96
	if absf(ball.x) > FW:
		ball.x = clampf(ball.x, -FW, FW)
		bvel.x = -bvel.x * 0.6
	_ball_node().position = ball

	# keeper tracks the ball across its goal line (-z)
	keeper.position = keeper.position.move_toward(Vector3(clampf(ball.x, -4, 4), 0, -FL + 2), 6.0 * delta)

	# defenders chase the ball; nearest kicks it toward your goal (+z)
	for f in foes:
		var to: Vector3 = ball - f.pos
		f.pos += to.normalized() * 7.5 * delta
		f.pos.x = clampf(f.pos.x, -FW, FW)
		f.pos.z = clampf(f.pos.z, -FL, FL)
		f.node.position = f.pos
		if to.length() < 1.5 and bvel.length() < 8.0:
			bvel = Vector3(clampf(-ball.x * 0.2, -6, 6), 3.0, 22.0)  # clear toward your goal
			Juice.sfx("thud")

	# goals
	if ball.z < -FL + 1.2 and absf(ball.x) < 4.0:
		you += 1
		Juice.sfx("coin"); Juice.flash(Color(0.5, 1, 0.6), 0.3)
		Juice.popup("GOAL!  %d-%d" % [you, them], Vector2(W * 0.5, H * 0.34), Color(1, 0.9, 0.4))
		_after_goal(true)
	elif ball.z > FL - 1.2 and absf(ball.x) < 4.0:
		them += 1
		Juice.sfx("boom"); Juice.flash(Color(1, 0.4, 0.4), 0.3)
		Juice.popup("conceded  %d-%d" % [you, them], Vector2(W * 0.5, H * 0.34), Color(1, 0.5, 0.4))
		_after_goal(false)

	cam.position = ppos * 0.3 + Vector3(0, 20, 22)
	cam.look_at(Vector3(0, 0, ball.z * 0.3), Vector3.UP)
	hud.text = "MATCH %d   YOU %d — %d THEM   (first to 5)" % [match_no, you, them]
	hud.position = Vector3(0, 12, 0)


func _after_goal(scored: bool) -> void:
	if you >= 5:
		match_no += 1
		add_points(3)
		you = 0
		them = 0
		Juice.sfx("chime")
	elif them >= 5:
		end_demo()
		return
	else:
		add_points(1 if scored else 0)
	_kickoff()
	for i in foes.size():
		foes[i].pos = Vector3((i * 2 - 1) * 6.0, 0, -8)
