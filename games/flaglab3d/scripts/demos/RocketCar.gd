extends MechDemo3D
## Rocket Car (Rocket League): boost a car around an enclosed pitch and smash a
## giant SCRIPTED ball into the enemy net while an AI rival attacks + defends.
## Car AND ball are hand-integrated (velocity + gravity + bounce); faster/boosted
## contact = harder shot. Touch: stick drive+steer, BOOST hold, JUMP. Desktop: WASD, SPACE, SHIFT.

const HALF_W := 18.0
const HALF_L := 30.0
const GOAL_H := 4.6
const ACCEL := 26.0
const MAX_SPD := 22.0
const BOOST_ACC := 32.0
const BOOST_SPD := 34.0
const TURN := 2.7
const FRICTION := 16.0
const GRAV := 26.0
const JUMP_V := 9.5
const BALL_R := 1.7
const CAR_R := 1.5
const GROUND_REST := 0.62
const WALL_REST := 0.72
const BASE_HIT := 7.0
const HIT_MUL := 1.35
const LIFT := 3.2
const BALL_MAX := 42.0
const TARGET := 5
const MATCH_T := 80.0

var tc: TouchControls
var car := {}
var rival := {}
var ball_node: MeshInstance3D
var ball_pos := Vector3.ZERO
var ball_vel := Vector3.ZERO
var boost := 100.0
var hud: Label3D
var your_goals := 0
var rival_goals := 0
var match_t := MATCH_T
var match_no := 1
var pads: Array = []


func start() -> void:
	super.start()
	setup_world(Color(0.06, 0.09, 0.14), 0.85)
	make_camera(Vector3(0, 8, 20), Vector3.ZERO, 62.0)
	tc = add_touch_controls([
		{"id": "boost", "label": "BOOST", "col": Color(1.0, 0.7, 0.3)},
		{"id": "jump", "label": "JUMP", "col": Color(0.6, 0.85, 0.55)}])
	tc.action.connect(func(id):
		if id == "jump": _jump()
		elif id == "boost": pass)
	_build_arena()
	car = {"pos": Vector3(0, 0, 18), "yaw": PI, "vel": 0.0, "vy": 0.0, "cd": 0.0}
	rival = {"pos": Vector3(0, 0, -18), "yaw": 0.0, "vel": 0.0, "vy": 0.0, "cd": 0.0}
	car.node = mesh_box(Vector3(2.2, 1.1, 3.4), car.pos, Color(0.3, 0.7, 1.0))
	rival.node = mesh_box(Vector3(2.2, 1.1, 3.4), rival.pos, Color(1.0, 0.45, 0.4))
	ball_pos = Vector3(0, BALL_R, 0)
	ball_node = mesh_sphere(BALL_R, ball_pos, Color(0.95, 0.95, 1.0))
	hud = label3d("", Vector3(-3.4, 4.6, -9), 20, Color(0.95, 0.98, 1), cam)
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT


func _build_arena() -> void:
	mesh_box(Vector3(HALF_W * 2, 0.4, HALF_L * 2), Vector3(0, -0.2, 0), Color(0.12, 0.35, 0.2))
	mesh_box(Vector3(HALF_W * 2, 0.05, 0.3), Vector3(0, 0.05, 0), Color(0.9, 0.95, 1.0))
	var wc := Color(0.2, 0.24, 0.32)
	static_box(Vector3(1.0, 3.0, HALF_L * 2), Vector3(HALF_W, 1.5, 0), wc)
	static_box(Vector3(1.0, 3.0, HALF_L * 2), Vector3(-HALF_W, 1.5, 0), wc)
	var seg := HALF_W - GOAL_H
	for sz in [-1.0, 1.0]:
		var gc := Color(0.3, 0.7, 1.0) if sz > 0 else Color(1.0, 0.45, 0.4)
		static_box(Vector3(seg, 3.0, 1.0), Vector3((HALF_W + GOAL_H) * 0.5, 1.5, sz * HALF_L), wc)
		static_box(Vector3(seg, 3.0, 1.0), Vector3(-(HALF_W + GOAL_H) * 0.5, 1.5, sz * HALF_L), wc)
		mesh_box(Vector3(GOAL_H * 2, 4.0, 0.4), Vector3(0, 2, sz * HALF_L), gc)
		label3d("GOAL", Vector3(0, 5, sz * HALF_L), 30, gc)
	for pp in [Vector3(0, 0.06, 12), Vector3(0, 0.06, -12), Vector3(12, 0.06, 0), Vector3(-12, 0.06, 0)]:
		pads.append({"pos": pp, "node": mesh_cyl(1.0, 0.1, pp, Color(1.0, 0.8, 0.3)), "cd": 0.0})


func _process(delta: float) -> void:
	if not running: return
	_drive_player(delta)
	_drive_rival(delta)
	_integrate_ball(delta)
	_pads(delta)
	match_t -= delta
	if your_goals >= TARGET or rival_goals >= TARGET or match_t <= 0.0:
		_match_end()
	var f := _fwd(car.yaw)
	cam.position = car.pos + Vector3(0, 6.5, 0) - f * 12.0
	cam.look_at(car.pos + f * 5.0 + Vector3(0, 1.2, 0), Vector3.UP)
	_hud()


func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _jump()


func _fwd(yaw: float) -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw))


func _drive_player(delta: float) -> void:
	var thr := -tc.move.y + key_axis_y()
	var steer := tc.move.x + key_axis_x()
	var boosting := (tc.held("boost") or Input.is_key_pressed(KEY_SHIFT)) and boost > 0.0
	var acc := thr * ACCEL
	var top := MAX_SPD
	if boosting:
		acc += BOOST_ACC
		top = BOOST_SPD
		boost = maxf(0.0, boost - 40.0 * delta)
		if fmod(match_t, 0.12) < delta: Juice.sfx("tick", 1.4)
	else:
		boost = minf(100.0, boost + 8.0 * delta)
	car.vel += acc * delta
	if absf(thr) < 0.1 and not boosting:
		car.vel = move_toward(car.vel, 0.0, FRICTION * delta)
	car.vel = clampf(car.vel, -MAX_SPD * 0.6, top)
	var resp := clampf(absf(car.vel) / 6.0, 0.2, 1.0)
	car.yaw += steer * TURN * delta * resp * signf(car.vel if absf(car.vel) > 0.4 else 1.0)
	_move_car(car, delta)
	_hit_ball(car, true)


func _drive_rival(delta: float) -> void:
	var to_goal := Vector3(ball_pos.x, 0, HALF_L) - Vector3(ball_pos.x, 0, ball_pos.z)
	var behind := ball_pos - to_goal.normalized() * 4.0
	var want := Vector3(behind.x - rival.pos.x, 0, behind.z - rival.pos.z)
	rival.yaw = _turn_to(rival.yaw, atan2(want.x, want.z), 2.4 * delta)
	rival.vel = move_toward(rival.vel, MAX_SPD * 0.85, ACCEL * delta)
	_move_car(rival, delta)
	_hit_ball(rival, false)


func _turn_to(cur: float, target: float, step: float) -> float:
	var d := wrapf(target - cur, -PI, PI)
	return cur + clampf(d, -step, step)


func _move_car(c: Dictionary, delta: float) -> void:
	c.cd = maxf(0.0, c.cd - delta)
	var p: Vector3 = c.pos
	c.vy -= GRAV * delta
	p.y = maxf(0.0, p.y + c.vy * delta)
	if p.y <= 0.0: c.vy = 0.0
	p += _fwd(c.yaw) * c.vel * delta
	p.x = clampf(p.x, -HALF_W + CAR_R, HALF_W - CAR_R)
	p.z = clampf(p.z, -HALF_L + CAR_R, HALF_L - CAR_R)
	c.pos = p
	var nd: MeshInstance3D = c.node
	nd.position = p
	nd.rotation.y = c.yaw


func _jump() -> void:
	if not running: return
	if car.pos.y <= 0.05:
		car.vy = JUMP_V
		Juice.sfx("tick", 0.8); Juice.haptic(12)


func _hit_ball(c: Dictionary, is_player: bool) -> void:
	var cp: Vector3 = c.pos + Vector3(0, 0.6, 0)
	var off := ball_pos - cp
	if off.length() > CAR_R + BALL_R:
		return
	if off.length() < 0.01: off = _fwd(c.yaw)
	var dir := off.normalized()
	var spd: float = absf(c.vel)
	var boosting := is_player and (tc.held("boost") or Input.is_key_pressed(KEY_SHIFT)) and boost > 0.0
	var power := BASE_HIT + spd * HIT_MUL + (10.0 if boosting else 0.0)
	ball_vel = (dir * power + _fwd(c.yaw) * spd * 0.4 + Vector3(0, LIFT, 0)).limit_length(BALL_MAX)
	ball_pos = cp + dir * (CAR_R + BALL_R + 0.05)
	if c.cd <= 0.0:
		c.cd = 0.12
		var hard := clampf(power / 30.0, 0.4, 1.4)
		Juice.sfx("thud", 0.7 + hard * 0.5)
		if is_player:
			Juice.haptic(int(10 + hard * 20)); Juice.flash(Color(0.4, 0.7, 1), 0.12 * hard)


func _integrate_ball(delta: float) -> void:
	if ball_pos.y > BALL_R + 0.01:
		ball_vel.y -= GRAV * delta
	ball_pos += ball_vel * delta
	if ball_pos.y < BALL_R:
		ball_pos.y = BALL_R
		if ball_vel.y < 0.0: ball_vel.y = -ball_vel.y * GROUND_REST
		if absf(ball_vel.y) < 1.0: ball_vel.y = 0.0
		ball_vel.x *= 1.0 - 1.4 * delta
		ball_vel.z *= 1.0 - 1.4 * delta
	if absf(ball_pos.x) > HALF_W - BALL_R:
		ball_pos.x = clampf(ball_pos.x, -HALF_W + BALL_R, HALF_W - BALL_R)
		ball_vel.x = -ball_vel.x * WALL_REST
		Juice.sfx("thud", 0.6)
	if ball_pos.z < -HALF_L + 0.4 and absf(ball_pos.x) < GOAL_H and ball_pos.y < 4.0:
		_goal(true); return
	if ball_pos.z > HALF_L - 0.4 and absf(ball_pos.x) < GOAL_H and ball_pos.y < 4.0:
		_goal(false); return
	if absf(ball_pos.z) > HALF_L - BALL_R and absf(ball_pos.x) >= GOAL_H:
		ball_pos.z = clampf(ball_pos.z, -HALF_L + BALL_R, HALF_L - BALL_R)
		ball_vel.z = -ball_vel.z * WALL_REST
	ball_vel = ball_vel.limit_length(BALL_MAX)
	ball_node.position = ball_pos
	ball_node.rotation.x += ball_vel.z * delta * 0.3
	ball_node.rotation.z -= ball_vel.x * delta * 0.3


func _pads(delta: float) -> void:
	for p in pads:
		p.cd = maxf(0.0, p.cd - delta)
		if p.cd <= 0.0 and Vector2(car.pos.x - p.pos.x, car.pos.z - p.pos.z).length() < 2.2:
			boost = minf(100.0, boost + 45.0)
			p.cd = 6.0
			Juice.sfx("tick", 1.6); Juice.haptic(8)
		p.node.visible = p.cd <= 0.0


func _goal(you_scored: bool) -> void:
	if you_scored:
		your_goals += 1
		add_points(1)
		Juice.sfx("coin"); Juice.flash(Color(0.3, 0.7, 1), 0.4); Juice.hitstop(90); Juice.haptic(30)
		Juice.popup("GOAL!  YOU +1", Vector2(360, 500), Color(0.4, 0.8, 1))
	else:
		rival_goals += 1
		Juice.sfx("boom"); Juice.flash(Color(0.9, 0.3, 0.3), 0.4); Juice.haptic(25)
		Juice.popup("RIVAL SCORES", Vector2(360, 500), Color(1, 0.5, 0.5))
	_kickoff()


func _kickoff() -> void:
	ball_pos = Vector3(0, BALL_R, 0)
	ball_vel = Vector3.ZERO
	ball_node.position = ball_pos
	car.pos = Vector3(0, 0, 18); car.yaw = PI; car.vel = 0.0; car.vy = 0.0
	rival.pos = Vector3(0, 0, -18); rival.yaw = 0.0; rival.vel = 0.0; rival.vy = 0.0


func _match_end() -> void:
	var won := your_goals > rival_goals
	if rival_goals >= TARGET:
		Juice.sfx("boom"); Juice.flash(Color(0.9, 0.2, 0.2), 0.6); Juice.hitstop(120)
		Juice.popup("RIVAL WINS THE MATCH", Vector2(360, 620), Color(1, 0.4, 0.4))
		end_demo(); return
	Juice.sfx("chime"); Juice.flash(Color(1, 0.9, 0.4) if won else Color(0.7, 0.8, 1), 0.4)
	Juice.popup("MATCH %d: %s" % [match_no, "YOU WIN!" if won else "TIME UP"], Vector2(360, 620), Color(1, 0.9, 0.4))
	match_no += 1
	your_goals = 0; rival_goals = 0; match_t = MATCH_T; boost = 100.0
	_kickoff()


func _hud() -> void:
	var n := int(boost / 10.0)
	var bar := "|".repeat(n) + ".".repeat(10 - n)
	hud.text = "YOU %d   -   %d RIVAL   (first to %d)\nBOOST [%s]\nMATCH %d   %ds left" % [
		your_goals, rival_goals, TARGET, bar, match_no, int(maxf(0.0, match_t))]
