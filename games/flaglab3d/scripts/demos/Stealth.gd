extends MechDemo3D
## Stealth: patrolling GUARDS sweep flat VISION CONES across the floor. Stay out
## of the yellow, or a guard's DETECT meter fills → CALM to SUSPICIOUS to ALERT
## (guards converge). Slip BEHIND a guard to TAKEDOWN; reach the EXIT to clear a
## harder level. Touch: stick move · SNEAK (slow/quiet) · TAKEDOWN. Keys: WASD · SHIFT · J.

const ARENA := 20.0
const MOVE_SPEED := 6.0
const SNEAK_MULT := 0.42
const GUARD_SPEED := 2.6
const CHASE_SPEED := 5.6
const CONE_RANGE := 8.0
const CONE_HALF_DEG := 33.0
const CONE_COS := 0.84
const CATCH_DIST := 1.7
const TAKEDOWN_DIST := 2.7
const DETECT_DECAY := 0.6
const ALERT_DECAY := 0.28
const ALERT_MAX_HOLD := 2.5

var tc: TouchControls
var player: MeshInstance3D
var hud: Label3D
var exit_node: MeshInstance3D
var ppos := Vector3.ZERO
var exit_pos := Vector3.ZERO
var level := 0
var takedowns := 0
var alert := 0.0
var alert_hold := 0.0
var shake := 0.0
var sneaking := false
var _j_prev := false
var guards: Array = []
var walls: Array = []
var wall_nodes: Array = []


func start() -> void:
	super.start()
	setup_world(Color(0.13, 0.15, 0.19), 0.55)
	mesh_box(Vector3(ARENA * 2.0, 0.4, ARENA * 2.0), Vector3(0, -0.2, 0), Color(0.19, 0.21, 0.25))
	player = mesh_box(Vector3(0.8, 1.6, 0.8), Vector3.ZERO, Color(0.35, 0.82, 0.55))
	mesh_sphere(0.4, Vector3(0, 1.05, 0), Color(0.9, 0.86, 0.72), player)
	mesh_box(Vector3(0.3, 0.3, 0.55), Vector3(0, 0.5, 0.55), Color(0.15, 0.4, 0.28), player)
	make_camera(Vector3(0, 20, 12), Vector3.ZERO, 58.0)
	hud = label3d("", Vector3(-2.1, 3.1, -5.2), 26, Color.WHITE, cam)
	tc = add_touch_controls(
		[
			{"id": "takedown", "label": "TAKE\nDOWN", "col": Color(0.85, 0.4, 0.4)},
			{"id": "sneak", "label": "SNEAK", "col": Color(0.5, 0.7, 0.9)},
		]
	)
	tc.action.connect(
		func(id):
			if id == "takedown":
				_takedown()
			elif id == "sneak":
				pass
	)
	_build_level()


func _build_level() -> void:
	for g in guards:
		g.node.queue_free()
	guards.clear()
	for w in wall_nodes:
		w.queue_free()
	wall_nodes.clear()
	walls.clear()
	level += 1
	_add_wall(0.0, -ARENA, ARENA, 0.6, Color(0.3, 0.3, 0.37))
	_add_wall(0.0, ARENA, ARENA, 0.6, Color(0.3, 0.3, 0.37))
	_add_wall(-ARENA, 0.0, 0.6, ARENA, Color(0.3, 0.3, 0.37))
	_add_wall(ARENA, 0.0, 0.6, ARENA, Color(0.3, 0.3, 0.37))
	for i in range(2 + level):
		var cx := randf_range(-ARENA + 5.0, ARENA - 5.0)
		var cz := randf_range(-ARENA + 5.0, ARENA - 5.0)
		if randf() < 0.5:
			_add_wall(cx, cz, randf_range(2.0, 5.0), 0.6, Color(0.33, 0.33, 0.42))
		else:
			_add_wall(cx, cz, 0.6, randf_range(2.0, 5.0), Color(0.33, 0.33, 0.42))
	ppos = Vector3(-ARENA + 3.0, 0, -ARENA + 3.0)
	player.position = Vector3(ppos.x, 0.8, ppos.z)
	exit_pos = Vector3(ARENA - 3.0, 0, ARENA - 3.0)
	if exit_node == null:
		exit_node = mesh_cyl(1.4, 5.0, Vector3.ZERO, Color(0.3, 1.0, 0.6))
		var em := exit_node.material_override as StandardMaterial3D
		em.emission_enabled = true
		em.emission = Color(0.3, 1.0, 0.6)
		em.emission_energy_multiplier = 2.0
		label3d("EXIT", Vector3(0, 4.0, 0), 40, Color(0.6, 1, 0.8), exit_node)
	exit_node.position = exit_pos + Vector3(0, 2.5, 0)
	for i in range(1 + level):
		var route: Array = []
		for j in range(3 + level):
			route.append(
				Vector3(
					randf_range(-ARENA + 3.0, ARENA - 3.0),
					0,
					randf_range(-ARENA + 3.0, ARENA - 3.0)
				)
			)
		_make_guard(route)
	alert = 0.0
	alert_hold = 0.0
	Juice.sfx("tick")


func _add_wall(cx: float, cz: float, hx: float, hz: float, col: Color) -> void:
	var b := static_box(Vector3(hx * 2.0, 3.0, hz * 2.0), Vector3(cx, 1.5, cz), col)
	wall_nodes.append(b)
	walls.append({"c": Vector2(cx, cz), "h": Vector2(hx, hz)})


func _make_guard(route: Array) -> void:
	var g := mesh_box(
		Vector3(0.9, 1.7, 0.9), Vector3(route[0].x, 0.85, route[0].z), Color(0.85, 0.32, 0.32)
	)
	mesh_box(Vector3(0.34, 0.34, 0.7), Vector3(0, 0.3, 0.6), Color(0.14, 0.14, 0.18), g)
	var cone := _make_cone()
	g.add_child(cone)
	guards.append(
		{
			"node": g,
			"cone": cone,
			"route": route,
			"wp": 1,
			"see": 0.0,
			"yaw": 0.0,
			"last": Vector3.ZERO,
			"alive": true
		}
	)


func _make_cone() -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = CONE_RANGE * tan(deg_to_rad(CONE_HALF_DEG))
	cm.bottom_radius = 0.0
	cm.height = CONE_RANGE
	cm.radial_segments = 22
	mi.mesh = cm
	mi.rotation_degrees.x = 90.0
	mi.scale = Vector3(1, 1, 0.04)
	mi.position = Vector3(0, -0.75, CONE_RANGE * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.9, 0.2, 0.22)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.emission_enabled = true
	mat.emission = Color(0.9, 0.9, 0.2)
	mat.emission_energy_multiplier = 0.7
	mi.material_override = mat
	return mi


func _process(delta: float) -> void:
	if not running:
		return
	sneaking = tc.held("sneak") or Input.is_key_pressed(KEY_SHIFT)
	var jd := Input.is_key_pressed(KEY_J)
	if jd and not _j_prev:
		_takedown()
	_j_prev = jd
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	var spd := MOVE_SPEED * (SNEAK_MULT if sneaking else 1.0)
	if _state() == "ALERT":
		spd *= 1.2
	if mv.length() > 0.1:
		mv = mv.limit_length(1.0)
		ppos += mv * spd * delta
		player.rotation.y = atan2(mv.x, mv.z)
		ppos = _resolve(ppos)
	player.position = Vector3(ppos.x, 0.8, ppos.z)
	_update_guards(delta)
	_check_exit()
	_update_camera(delta)
	_update_hud()


func _resolve(p: Vector3) -> Vector3:
	p.x = clampf(p.x, -ARENA + 1.0, ARENA - 1.0)
	p.z = clampf(p.z, -ARENA + 1.0, ARENA - 1.0)
	for w in walls:
		var dx: float = p.x - w.c.x
		var dz: float = p.z - w.c.y
		var ox: float = w.h.x + 0.6 - absf(dx)
		var oz: float = w.h.y + 0.6 - absf(dz)
		if ox > 0.0 and oz > 0.0:
			if ox < oz:
				p.x += ox * signf(dx)
			else:
				p.z += oz * signf(dz)
	return p


func _blocked(a: Vector3, b: Vector3) -> bool:
	for i in range(1, 8):
		var t := float(i) / 8.0
		var px := lerpf(a.x, b.x, t)
		var pz := lerpf(a.z, b.z, t)
		for w in walls:
			if absf(px - w.c.x) < w.h.x and absf(pz - w.c.y) < w.h.y:
				return true
	return false


func _update_guards(delta: float) -> void:
	var st := _state()
	var top_see := 0.0
	for g in guards:
		if not g.alive:
			continue
		var gpos: Vector3 = g.node.position
		var to: Vector3
		if g.see > 0.45:
			to = g.last - gpos
			to.y = 0
			var chase: float = CHASE_SPEED if st == "ALERT" else GUARD_SPEED
			if to.length() > 0.4:
				gpos += to.normalized() * chase * delta
				g.yaw = atan2(to.x, to.z)
		else:
			to = g.route[g.wp] - gpos
			to.y = 0
			if to.length() < 0.7:
				g.wp = (g.wp + 1) % g.route.size()
			else:
				gpos += to.normalized() * GUARD_SPEED * delta
				g.yaw = atan2(to.x, to.z)
		g.node.position = Vector3(gpos.x, 0.85, gpos.z)
		g.node.rotation.y = g.yaw
		var vec := Vector3(ppos.x - gpos.x, 0, ppos.z - gpos.z)
		var dist := vec.length()
		var fwd := Vector3(sin(g.yaw), 0, cos(g.yaw))
		var seen := (
			dist < CONE_RANGE
			and dist > 0.05
			and fwd.dot(vec / dist) > CONE_COS
			and not _blocked(gpos, ppos)
		)
		if seen:
			g.last = Vector3(ppos.x, 0, ppos.z)
			var rate: float = (0.4 if sneaking else 0.9) * (1.0 + (CONE_RANGE - dist) / CONE_RANGE)
			g.see = minf(1.0, g.see + rate * delta)
		else:
			g.see = maxf(0.0, g.see - DETECT_DECAY * delta)
		top_see = maxf(top_see, g.see)
		var col := Color(0.3, 0.9, 0.35).lerp(Color(1.0, 0.24, 0.2), g.see)
		var m := g.cone.material_override as StandardMaterial3D
		m.albedo_color = Color(col.r, col.g, col.b, 0.22)
		m.emission = col
		if st == "ALERT" and dist < CATCH_DIST:
			_caught()
			return
	alert = maxf(top_see, alert - ALERT_DECAY * delta)
	if alert >= 1.0:
		alert_hold += delta
		if alert_hold > ALERT_MAX_HOLD:
			_caught()
	else:
		alert_hold = maxf(0.0, alert_hold - delta)


func _takedown() -> void:
	if not running:
		return
	var best := -1
	var bd := TAKEDOWN_DIST
	for i in guards.size():
		var g: Dictionary = guards[i]
		if not g.alive:
			continue
		var d := Vector2(g.node.position.x - ppos.x, g.node.position.z - ppos.z).length()
		if d < bd:
			bd = d
			best = i
	if best == -1:
		Juice.sfx("tick")
		return
	var g: Dictionary = guards[best]
	var fwd := Vector3(sin(g.yaw), 0, cos(g.yaw))
	var to := Vector3(ppos.x - g.node.position.x, 0, ppos.z - g.node.position.z).normalized()
	if fwd.dot(to) < 0.1:
		g.alive = false
		g.node.visible = false
		g.cone.visible = false
		takedowns += 1
		add_points(1)
		Juice.sfx("thud")
		Juice.haptic(25)
		Juice.flash(Color(0.5, 0.9, 0.5), 0.12)
		Juice.popup("TAKEDOWN", Vector2(W * 0.5, H * 0.3), Color(0.6, 1, 0.7), 46)
	else:
		g.see = 1.0
		alert = 1.0
		Juice.sfx("boom")
		Juice.flash(Color(1.0, 0.3, 0.2), 0.2)
		Juice.popup("SPOTTED!", Vector2(W * 0.5, H * 0.3), Color(1.0, 0.4, 0.3), 46)


func _check_exit() -> void:
	if Vector2(ppos.x - exit_pos.x, ppos.z - exit_pos.z).length() > 2.2:
		return
	add_points(3)
	Juice.sfx("chime")
	Juice.sfx("coin", 1.1)
	Juice.flash(Color(0.4, 1.0, 0.6), 0.25)
	Juice.haptic(30)
	Juice.popup("LEVEL CLEAR +3", Vector2(W * 0.5, H * 0.34), Color(0.5, 1, 0.7), 48)
	_build_level()


func _caught() -> void:
	if not running:
		return
	Juice.sfx("boom")
	Juice.flash(Color(1.0, 0.25, 0.2), 0.35)
	Juice.haptic(60)
	Juice.popup("CAUGHT", Vector2(W * 0.5, H * 0.34), Color(1.0, 0.4, 0.3), 52)
	end_demo()


func _update_camera(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.0)
	if _state() == "ALERT":
		shake = 0.25
	var off := Vector3(randf_range(-shake, shake), 0, randf_range(-shake, shake))
	var want := Vector3(ppos.x, 20.0, ppos.z + 11.0) + off
	cam.position = cam.position.lerp(want, clampf(delta * 5.0, 0.0, 1.0))
	cam.look_at(Vector3(ppos.x, 0, ppos.z), Vector3.UP)
	if exit_node:
		exit_node.rotation.y += delta * 1.4


func _update_hud() -> void:
	hud.text = (
		"STATE: %s\nDETECT %d%%\nGUARDS %d\nLEVEL %d\nREACH EXIT\nSCORE %d"
		% [_state(), int(alert * 100.0), _alive_count(), level, score]
	)


func _state() -> String:
	if alert >= 1.0:
		return "ALERT"
	if alert >= 0.34:
		return "SUSPICIOUS"
	return "CALM"


func _alive_count() -> int:
	var n := 0
	for g in guards:
		if g.alive:
			n += 1
	return n
