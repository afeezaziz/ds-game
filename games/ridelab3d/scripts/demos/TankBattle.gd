extends MechDemo3D
## TANK BATTLE — armor-duel (World of Tanks). Drive a slow hull while the TURRET
## aims independently (look-drag). Shells have a reload; hits on ANGLED front armor
## BOUNCE, side/rear PENETRATE — so keep your thick front to the enemy. Kill enemy
## tanks before they wear you down. Desktop: WASD drive, mouse-drag aim, SPACE fire.

var hull: Node3D
var turret: Node3D
var hpos := Vector3(0, 0, 18)
var hyaw := 0.0
var tyaw := 0.0
var armor := 100.0
var reload := 0.0
var foes: Array = []          # {node,turret,pos,yaw,hp,cd}
var spawn_t := 0.0
var kills := 0
var t := 0.0
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.55, 0.6, 0.55), 0.85, Vector3(-55, -25, 0))
	static_box(Vector3(120, 1, 120), Vector3(0, -0.5, 0), Color(0.4, 0.45, 0.33))
	for i in 10:
		var a := randf() * TAU
		static_box(Vector3(5, 4, 5), Vector3(cos(a) * randf_range(14, 48), 2, sin(a) * randf_range(14, 48)), Color(0.35, 0.34, 0.3))
	hull = Node3D.new()
	add_child(hull)
	mesh_box(Vector3(3.2, 1.2, 4.6), Vector3(0, 0.8, 0), Color(0.4, 0.5, 0.35), hull)
	turret = Node3D.new()
	turret.position = Vector3(0, 1.5, 0)
	hull.add_child(turret)
	mesh_box(Vector3(2.0, 0.9, 2.2), Vector3(0, 0, 0), Color(0.45, 0.55, 0.4), turret)
	mesh_box(Vector3(0.3, 0.3, 3.0), Vector3(0, 0, 1.8), Color(0.3, 0.35, 0.28), turret)
	hpos = Vector3(0, 0, 18)
	hyaw = 0.0
	tyaw = 0.0
	armor = 100.0
	kills = 0
	foes = []
	spawn_t = 0.5
	t = 0.0
	make_camera(Vector3(0, 12, 20), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 9, 0), 34, Color.WHITE)
	tc = add_touch_controls([{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.5, 0.35)}], true)
	tc.action.connect(func(_id): _fire())
	tc.look.connect(func(rel): tyaw -= rel.x * 0.005)


func _pen(target_pos: Vector3, target_yaw: float, from: Vector3) -> float:
	# angle between shot direction and the target's forward → front hits bounce
	var to_shooter := (from - target_pos).normalized()
	var facing := Vector3(sin(target_yaw), 0, cos(target_yaw))
	var d := facing.dot(to_shooter)          # 1 = hit dead front, -1 = rear
	if d > 0.6:
		return 0.35                           # glancing off angled front
	elif d > 0.0:
		return 1.0
	return 1.6                                # side/rear = extra damage


func _fire() -> void:
	if reload > 0.0:
		return
	reload = 2.0
	Juice.sfx("boom")
	Juice.flash(Color(1, 0.9, 0.6), 0.12)
	var muzzle := turret.global_transform.basis.z * -1.0
	muzzle = Vector3(sin(hyaw + tyaw), 0, cos(hyaw + tyaw))
	var best = null
	var bestdot := 0.985
	var origin := hpos + Vector3(0, 1.5, 0)
	for f in foes:
		var to := (f.pos - origin).normalized()
		var dd := muzzle.dot(to)
		if dd > bestdot:
			bestdot = dd
			best = f
	if best != null:
		var mult := _pen(best.pos, best.yaw, origin)
		if mult < 0.5:
			Juice.popup("BOUNCE!", Vector2(W * 0.5, H * 0.38), Color(0.8, 0.85, 1))
		best.hp -= 34.0 * mult
		if best.hp <= 0.0:
			best.node.queue_free()
			foes.erase(best)
			kills += 1
			add_points(1)
			Juice.popup("KILL", Vector2(W * 0.5, H * 0.4), Color(1, 0.9, 0.4))


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_fire()


func _spawn() -> void:
	var a := randf() * TAU
	var p := Vector3(cos(a), 0, sin(a)) * randf_range(30, 50)
	var node := Node3D.new()
	add_child(node)
	mesh_box(Vector3(3.0, 1.2, 4.4), Vector3(0, 0.8, 0), Color(0.55, 0.35, 0.32), node)
	var tt := mesh_box(Vector3(1.8, 0.8, 2.0), Vector3(0, 1.6, 0), Color(0.6, 0.4, 0.35), node)
	mesh_box(Vector3(0.3, 0.3, 2.6), Vector3(0, 1.6, 1.6), Color(0.4, 0.3, 0.28), node)
	node.position = p
	foes.append({"node": node, "turret": tt, "pos": p, "yaw": 0.0, "hp": 60.0, "cd": randf_range(2, 4)})


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	reload = maxf(0.0, reload - delta)

	var throttle := tc.move.y * -1.0 + key_axis_y()
	hyaw -= (tc.move.x + key_axis_x()) * 1.1 * delta
	var fwd := Vector3(sin(hyaw), 0, cos(hyaw))
	hpos += fwd * clampf(throttle, -0.6, 1.0) * 9.0 * delta
	hpos.x = clampf(hpos.x, -58, 58)
	hpos.z = clampf(hpos.z, -58, 58)
	hull.position = hpos
	hull.rotation.y = hyaw
	turret.rotation.y = tyaw

	spawn_t -= delta
	if spawn_t <= 0.0 and foes.size() < 5:
		spawn_t = maxf(2.0, 5.0 - t * 0.03)
		_spawn()

	var origin := hpos + Vector3(0, 1.5, 0)
	for f in foes:
		var to: Vector3 = hpos - f.pos
		f.yaw = atan2(to.x, to.z)
		var dist := to.length()
		if dist > 26.0:
			f.pos += to.normalized() * 6.0 * delta
		elif dist < 16.0:
			f.pos -= to.normalized() * 4.0 * delta
		f.node.position = f.pos
		f.node.rotation.y = f.yaw
		f.turret.look_at(origin, Vector3.UP)
		f.cd -= delta
		if f.cd <= 0.0 and dist < 55.0:
			f.cd = randf_range(2.5, 4.0)
			var mult := _pen(hpos, hyaw, f.pos)
			if mult >= 0.5:
				armor -= 12.0 * mult
				Juice.flash(Color(1, 0.3, 0.25), 0.2)
				Juice.haptic(28)
				if armor <= 0.0:
					end_demo()
					return

	cam.position = hpos - fwd * 16.0 + Vector3(0, 12, 0)
	cam.look_at(hpos + fwd * 6.0, Vector3.UP)
	hud.text = "ARMOR %d   %s   tanks %d   kills %d" % [
		int(max(0, armor)), "RELOADING" if reload > 0.5 else "READY", foes.size(), kills]
	hud.position = hpos + Vector3(0, 9, 0)
