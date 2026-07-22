extends MechDemo3D
## IMMERSIVE SIM — many ways in (Dishonored / Deus Ex). A guarded VAULT: BLINK past
## walls and guards (spends focus), sneak up for a silent TAKEDOWN, or go loud and
## FIRE (raises the alarm and brings guards running). Reach the objective, extract,
## repeat deeper. Guards see in cones. Desktop: WASD move, mouse-look, B blink, F takedown, SPACE fire.

var player: Node3D
var ppos := Vector3(0, 0, 18)
var yaw := 0.0
var focus := 100.0
var hp := 100.0
var alarm := 0.0
var guards: Array = []        # {node,pos,yaw,route,ri,alert,alive}
var objective := Vector3(0, 0, -22)
var goal_node: Node3D
var mission := 1
var hurt_cd := 0.0
var cones: Array = []
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.12, 0.13, 0.17), 0.7, Vector3(-55, 15, 0))
	static_box(Vector3(40, 1, 52), Vector3(0, -0.5, -4), Color(0.24, 0.25, 0.3))
	# some walls to blink past
	static_box(Vector3(14, 4, 1), Vector3(-6, 2, 4), Color(0.3, 0.32, 0.38))
	static_box(Vector3(14, 4, 1), Vector3(8, 2, -6), Color(0.3, 0.32, 0.38))
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(1.0, 1.9, 1.0), Vector3(0, 0.95, 0), Color(0.4, 0.75, 0.9), player)
	goal_node = Node3D.new()
	add_child(goal_node)
	mesh_box(Vector3(2, 2, 2), Vector3(0, 1, 0), Color(1, 0.85, 0.3), goal_node)
	make_camera(Vector3(0, 15, 13), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 9, 0), 30, Color.WHITE)
	tc = add_touch_controls([
		{"id": "blink", "label": "BLINK", "col": Color(0.5, 0.7, 0.95)},
		{"id": "takedown", "label": "TAKEDOWN", "col": Color(0.6, 0.85, 0.6)},
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.45, 0.35)},
	], true)
	tc.action.connect(func(id):
		if id == "blink": _blink()
		elif id == "takedown": _takedown()
		elif id == "fire": _fire())
	tc.look.connect(func(rel): yaw -= rel.x * 0.005)
	_build()


func _build() -> void:
	for g in guards: g.node.queue_free()
	for c in cones: c.queue_free()
	guards = []
	cones = []
	ppos = Vector3(0, 0, 18)
	alarm = 0.0
	focus = 100.0
	for i in 2 + mission:
		var route := [Vector3(randf_range(-15, 15), 0, randf_range(-18, 6)), Vector3(randf_range(-15, 15), 0, randf_range(-18, 6))]
		var node := Node3D.new()
		add_child(node)
		mesh_box(Vector3(1.0, 1.9, 1.0), Vector3(0, 0.95, 0), Color(0.85, 0.45, 0.4), node)
		mesh_box(Vector3(0.3, 0.3, 1.2), Vector3(0, 1.2, 0.7), Color(0.2, 0.2, 0.25), node)
		node.position = route[0]
		var cone := mesh_cyl(0.1, 0.1, Vector3.ZERO, Color(1, 0.9, 0.3, 0.14))
		cones.append(cone)
		guards.append({"node": node, "pos": route[0], "yaw": 0.0, "route": route, "ri": 0, "alert": 0.0, "alive": true, "cone": cone})
	objective = Vector3(randf_range(-12, 12), 0, -24)
	goal_node.position = objective


func _aim() -> Vector3:
	return Vector3(sin(yaw), 0, cos(yaw)) * -1.0


func _blink() -> void:
	if focus < 30.0:
		return
	focus -= 30.0
	ppos += _aim() * 8.0
	ppos.x = clampf(ppos.x, -19, 19)
	ppos.z = clampf(ppos.z, -26, 20)
	Juice.sfx("tick")
	Juice.flash(Color(0.5, 0.7, 1.0), 0.15)
	Juice.haptic(15)


func _takedown() -> void:
	for g in guards:
		if not g.alive:
			continue
		var to: Vector3 = g.pos - ppos
		var behind := Vector3(sin(g.yaw), 0, cos(g.yaw)).dot(to.normalized()) < -0.3
		if to.length() < 2.4 and behind:
			g.alive = false
			g.node.visible = false
			g.cone.visible = false
			add_points(1)
			Juice.sfx("thud")
			Juice.popup("TAKEDOWN", Vector2(W * 0.5, H * 0.34), Color(0.6, 1, 0.7))
			return
	Juice.sfx("tick")


func _fire() -> void:
	alarm = minf(1.0, alarm + 0.5)     # loud!
	Juice.sfx("boom")
	Juice.flash(Color(1, 0.9, 0.6), 0.1)
	var best = null
	var bestdot := 0.94
	for g in guards:
		if not g.alive:
			continue
		var to := (g.pos - ppos).normalized()
		var dd := _aim().dot(to)
		if dd > bestdot:
			bestdot = dd
			best = g
	if best != null:
		best.alive = false
		best.node.visible = false
		best.cone.visible = false
		add_points(1)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_B: _blink()
		elif event.keycode == KEY_F: _takedown()
		elif event.keycode == KEY_SPACE: _fire()


func _process(delta: float) -> void:
	if not running:
		return
	hurt_cd = maxf(0.0, hurt_cd - delta)
	focus = minf(100.0, focus + 10.0 * delta)
	alarm = maxf(0.0, alarm - 0.05 * delta)
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * 6.5 * delta
	ppos.x = clampf(ppos.x, -19, 19)
	ppos.z = clampf(ppos.z, -26, 20)
	player.position = ppos
	player.rotation.y = yaw

	for g in guards:
		if not g.alive:
			continue
		var alerted := alarm > 0.3 or g.alert > 0.5
		var goal: Vector3 = ppos if alerted else g.route[g.ri]
		var to: Vector3 = goal - g.pos
		if to.length() > 0.5:
			g.pos += to.normalized() * (5.0 if alerted else 2.5) * delta
			g.yaw = atan2(to.x, to.z)
		elif not alerted:
			g.ri = (g.ri + 1) % g.route.size()
		g.node.position = g.pos
		g.node.rotation.y = g.yaw
		g.cone.position = g.pos + Vector3(sin(g.yaw), 0.1, cos(g.yaw)) * 5.0
		g.cone.scale = Vector3(6, 1, 6)
		# vision: in front + close + line of sight → build alert
		var pv: Vector3 = ppos - g.pos
		var seen := pv.length() < 11.0 and Vector3(sin(g.yaw), 0, cos(g.yaw)).dot(pv.normalized()) > 0.7
		if seen:
			g.alert = minf(1.0, g.alert + delta)
			if g.alert > 0.5:
				alarm = minf(1.0, alarm + delta * 0.3)
		else:
			g.alert = maxf(0.0, g.alert - delta * 0.5)
		# attack if adjacent while alerted
		if alerted and hurt_cd <= 0.0 and pv.length() < 2.2:
			hurt_cd = 1.0
			hp -= 16.0
			Juice.flash(Color(1, 0.3, 0.3), 0.25)
			Juice.haptic(30)
			if hp <= 0.0:
				end_demo()
				return

	if ppos.distance_to(objective) < 2.5:
		mission += 1
		add_points(5)
		Juice.sfx("chime")
		Juice.flash(Color(1, 0.95, 0.6), 0.3)
		Juice.popup("VAULT REACHED", Vector2(W * 0.5, H * 0.34), Color(1, 0.9, 0.4))
		hp = minf(100.0, hp + 20.0)
		_build()

	goal_node.rotation.y += delta
	cam.position = ppos + Vector3(0, 15, 12)
	cam.look_at(ppos + Vector3(0, 0, -2), Vector3.UP)
	hud.text = "HP %d   FOCUS %d   ALARM %d%%   guards %d   mission %d" % [
		int(max(0, hp)), int(focus), int(alarm * 100), guards.filter(func(g): return g.alive).size(), mission]
	hud.position = ppos + Vector3(0, 9, 0)
