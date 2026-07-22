extends MechDemo3D
## BASKETBALL — drive and shoot (arcade streetball). Dribble past the defender and
## SHOOT: the ball arcs at the rim, and being open + closer makes it drop; far shots
## bank 3. On defense, STEAL the ball back. First to 21. Desktop: WASD move, SPACE shoot, K steal.

const CW := 14.0
const CL := 22.0
var player: Node3D
var ppos := Vector3(0, 0, 14)
var facing := Vector3(0, 0, -1)
var defender: Node3D
var dpos := Vector3(0, 0, -6)
var ball := Vector3.ZERO
var bvel := Vector3.ZERO
var flying := false
var have := true              # true = player possesses, false = defender
var shot_from := 0.0
var you := 0
var them := 0
var hoop := Vector3(0, 3.0, -CL + 1.5)
var opp_hoop := Vector3(0, 3.0, CL - 1.5)
var tc: TouchControls
var hud: Label3D
var ai_t := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.55, 0.62), 0.9, Vector3(-55, -25, 0))
	static_box(Vector3(CW * 2, 1, CL * 2), Vector3(0, -0.5, 0), Color(0.55, 0.4, 0.3))
	mesh_cyl(1.6, 0.2, hoop, Color(1, 0.5, 0.2))
	mesh_box(Vector3(4, 3, 0.4), hoop + Vector3(0, 1.6, -1.2), Color(0.9, 0.9, 0.95))
	mesh_cyl(1.6, 0.2, opp_hoop, Color(1, 0.5, 0.2))
	mesh_box(Vector3(4, 3, 0.4), opp_hoop + Vector3(0, 1.6, 1.2), Color(0.9, 0.9, 0.95))
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(1.1, 2.1, 1.1), Vector3(0, 1.05, 0), Color(0.3, 0.55, 0.95), player)
	defender = Node3D.new()
	add_child(defender)
	mesh_box(Vector3(1.1, 2.1, 1.1), Vector3(0, 1.05, 0), Color(0.9, 0.4, 0.4), defender)
	var bn := mesh_sphere(0.35, Vector3.ZERO, Color(0.95, 0.55, 0.2))
	bn.name = "Ball"
	you = 0
	them = 0
	have = true
	flying = false
	make_camera(Vector3(0, 16, 20), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 11, 0), 34, Color.WHITE)
	tc = add_touch_controls([
		{"id": "shoot", "label": "SHOOT", "col": Color(0.95, 0.7, 0.3)},
		{"id": "steal", "label": "STEAL", "col": Color(0.5, 0.8, 0.7)},
	])
	tc.action.connect(func(id):
		if id == "shoot": _shoot()
		elif id == "steal": _steal())


func _ball_node() -> Node3D:
	return get_node("Ball")


func _shoot() -> void:
	if not have or flying:
		return
	var dist := ppos.distance_to(hoop)
	shot_from = dist
	flying = true
	have = false
	# aim at the rim with error scaled by distance and how close the defender is
	var contest := clampf(2.5 - ppos.distance_to(dpos), 0.0, 1.5)
	var err := (dist * 0.012 + contest * 0.25)
	var target: Vector3 = hoop + Vector3(randf_range(-err, err), 0, randf_range(-err, err)) * 3.0
	var flat := Vector3(target.x - ball.x, 0, target.z - ball.z)
	# fixed arc time: solve horizontal speed so it reaches the rim as it descends
	var vy := 9.5
	var tflight := 1.1
	bvel = Vector3(flat.x / tflight, vy, flat.z / tflight)
	Juice.sfx("tick")


func _steal() -> void:
	if have:
		return
	if ppos.distance_to(dpos) < 2.2 and not flying:
		have = true
		Juice.sfx("thud")


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _shoot()
		elif event.keycode == KEY_K: _steal()


func _process(delta: float) -> void:
	if not running:
		return
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * 9.0 * delta
	ppos.x = clampf(ppos.x, -CW, CW)
	ppos.z = clampf(ppos.z, -CL + 1, CL - 1)
	if mv.length() > 0.1:
		facing = mv.normalized()
	player.position = ppos

	if flying:
		bvel.y -= 20.0 * delta
		ball += bvel * delta
		if bvel.y < 0 and ball.y < hoop.y + 0.3 and ball.y > hoop.y - 0.5:
			if Vector2(ball.x - hoop.x, ball.z - hoop.z).length() < 1.1:
				var pts := 3 if shot_from > 14.0 else 2
				you += pts
				Juice.sfx("coin"); Juice.flash(Color(1, 0.9, 0.5), 0.25)
				Juice.popup("+%d!" % pts, Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))
				_reset_possession(false)
				return
		if ball.y <= 0.35:
			Juice.sfx("thud")
			_reset_possession(false)      # miss -> defender rebounds
			return
	elif have:
		ball = ppos + facing * 0.8 + Vector3(0, 1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.3, 0)
	else:
		ball = dpos + Vector3(0, 1.2, 0)
	_ball_node().position = ball

	# defender AI
	ai_t -= delta
	if have:
		# defend: stay between you and the rim
		var guard := ppos.lerp(hoop, 0.4)
		dpos = dpos.move_toward(guard, 7.5 * delta)
	elif not flying:
		# defender drives to its hoop and shoots
		dpos = dpos.move_toward(opp_hoop, 8.0 * delta)
		if dpos.distance_to(opp_hoop) < 6.0 and ai_t <= 0.0:
			ai_t = 1.0
			if randf() < 0.55:
				them += 2
				Juice.sfx("boom"); Juice.flash(Color(1, 0.4, 0.4), 0.2)
				Juice.popup("they score  %d" % them, Vector2(W * 0.5, H * 0.34), Color(1, 0.5, 0.4))
			_reset_possession(true)
	dpos.x = clampf(dpos.x, -CW, CW)
	dpos.z = clampf(dpos.z, -CL + 1, CL - 1)
	defender.position = dpos

	if you >= 21:
		add_points(3); you = 0; them = 0
		Juice.sfx("chime")
		Juice.popup("GAME! next opponent", Vector2(W * 0.5, H * 0.3), Color(1, 0.9, 0.4))
	elif them >= 21:
		end_demo()
		return

	cam.position = ppos * 0.3 + Vector3(0, 16, 20)
	cam.look_at(Vector3(0, 1, ball.z * 0.3), Vector3.UP)
	hud.text = "YOU %d — %d THEM  (to 21)   %s" % [you, them, "you have it" if have else ("shooting" if flying else "defense — STEAL")]
	hud.position = Vector3(0, 11, 0)


func _reset_possession(player_gets: bool) -> void:
	flying = false
	have = player_gets
	bvel = Vector3.ZERO
	ppos = Vector3(0, 0, 8)
	dpos = Vector3(0, 0, -8)
	add_points(1 if you > them else 0)
