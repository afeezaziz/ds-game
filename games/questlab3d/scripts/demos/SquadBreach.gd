extends MechDemo3D
## SQUAD BREACH — lead a fireteam room to room (Rainbow Six). You drive the point man
## (move + aim + fire); two AI teammates follow, take cover and lay down covering fire.
## REGROUP to stack them on you, BREACH a cleared door to push the next room. Clear
## rooms; a squad wipe ends it. Desktop: WASD move, mouse-look, SPACE fire, R regroup, B breach.

var lead: Node3D
var lpos := Vector3(0, 0, 10)
var yaw := 0.0
var hp := 100.0
var mates: Array = []         # {node,pos,hp,cd,alive}
var foes: Array = []          # {node,pos,hp,cd,cover}
var room := 1
var door: Node3D
var fire_cd := 0.0
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.14, 0.15, 0.18), 0.7, Vector3(-55, 10, 0))
	static_box(Vector3(40, 1, 40), Vector3(0, -0.5, -6), Color(0.28, 0.29, 0.33))
	lead = Node3D.new()
	add_child(lead)
	mesh_box(Vector3(1.0, 1.9, 1.0), Vector3(0, 0.95, 0), Color(0.4, 0.7, 0.95), lead)
	mesh_box(Vector3(0.3, 0.3, 1.4), Vector3(0.4, 1.1, 0.6), Color(0.2, 0.2, 0.25), lead)
	lpos = Vector3(0, 0, 12)
	hp = 100.0
	room = 1
	mates = []
	for i in 2:
		var node := Node3D.new()
		add_child(node)
		mesh_box(Vector3(1.0, 1.9, 1.0), Vector3(0, 0.95, 0), Color(0.45, 0.8, 0.6), node)
		node.position = Vector3((i * 2 - 1) * 2.0, 0, 14)
		mates.append({"node": node, "pos": node.position, "hp": 80.0, "cd": 0.0, "alive": true})
	door = Node3D.new()
	add_child(door)
	mesh_box(Vector3(3.0, 4.0, 0.5), Vector3(0, 2, 0), Color(0.6, 0.5, 0.3), door)
	make_camera(Vector3(0, 14, 14), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 9, 0), 32, Color.WHITE)
	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.45, 0.35)},
		{"id": "regroup", "label": "REGROUP", "col": Color(0.5, 0.8, 0.7)},
		{"id": "breach", "label": "BREACH", "col": Color(0.9, 0.8, 0.4)},
	], true)
	tc.action.connect(func(id):
		if id == "fire": _fire(true)
		elif id == "regroup": _regroup()
		elif id == "breach": _breach())
	tc.look.connect(func(rel): yaw -= rel.x * 0.005)
	_spawn_room()


func _spawn_room() -> void:
	foes = []
	var n := 2 + room
	for i in n:
		var node := Node3D.new()
		add_child(node)
		mesh_box(Vector3(1.0, 1.9, 1.0), Vector3(0, 0.95, 0), Color(0.85, 0.4, 0.4), node)
		var p := Vector3(randf_range(-16, 16), 0, randf_range(-24, -8))
		node.position = p
		# a cover crate near each foe
		static_box(Vector3(2, 1.4, 2), p + Vector3(0, 0.7, 2.0), Color(0.4, 0.4, 0.45))
		foes.append({"node": node, "pos": p, "hp": 24.0, "cd": randf_range(1, 3), "cover": p + Vector3(0, 0, 2.0)})
	door.position = Vector3(0, 0, -30)


func _regroup() -> void:
	for m in mates:
		if m.alive:
			m.pos = lpos + Vector3(randf_range(-2, 2), 0, 2.5)
	Juice.sfx("tick")


func _breach() -> void:
	if not foes.is_empty():
		Juice.sfx("thud")
		return
	room += 1
	add_points(2)
	hp = minf(100.0, hp + 20.0)
	Juice.sfx("chime")
	Juice.flash(Color(0.8, 0.9, 1.0), 0.2)
	lpos = Vector3(0, 0, 12)
	_spawn_room()


func _fire(from_lead: bool) -> void:
	if from_lead and fire_cd > 0.0:
		return
	if from_lead:
		fire_cd = 0.18
	var origin := lpos + Vector3(0, 1.1, 0)
	var dir := Vector3(sin(yaw), 0, cos(yaw)) * -1.0
	var best = null
	var bestdot := 0.95
	for f in foes:
		var to := (f.pos - origin).normalized()
		var dd := dir.dot(to)
		if dd > bestdot:
			bestdot = dd
			best = f
	Juice.sfx("tick")
	if best != null:
		best.hp -= 10.0
		if best.hp <= 0.0:
			best.node.queue_free()
			foes.erase(best)
			add_points(1)
			Juice.sfx("boom")


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _fire(true)
		elif event.keycode == KEY_R: _regroup()
		elif event.keycode == KEY_B: _breach()


func _process(delta: float) -> void:
	if not running:
		return
	fire_cd -= delta
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	lpos += mv * 7.0 * delta
	lpos.x = clampf(lpos.x, -18, 18)
	lpos.z = clampf(lpos.z, -26, 14)
	lead.position = lpos
	lead.rotation.y = yaw

	# teammates: follow, seek cover-ish, auto-fire
	for m in mates:
		if not m.alive:
			continue
		var goal := lpos + Vector3(0, 0, 3.0)
		m.pos = m.pos.move_toward(goal, 6.0 * delta)
		m.node.position = m.pos
		m.cd -= delta
		if m.cd <= 0.0 and not foes.is_empty():
			m.cd = randf_range(0.5, 1.1)
			var f = foes[randi() % foes.size()]
			f.hp -= 6.0
			if f.hp <= 0.0:
				f.node.queue_free()
				foes.erase(f)
				add_points(1)

	# foes: use cover, shoot the nearest squad member
	for f in foes:
		f.node.position = f.pos
		f.cd -= delta
		if f.cd <= 0.0:
			f.cd = randf_range(1.4, 2.6)
			var victims := [lpos]
			for m in mates:
				if m.alive:
					victims.append(m.pos)
			# hit the lead sometimes, mates otherwise
			if randf() < 0.5:
				hp -= 9.0
				Juice.flash(Color(1, 0.3, 0.3), 0.15)
				Juice.haptic(18)
				if hp <= 0.0:
					_squad_check(true)
					return
			else:
				for m in mates:
					if m.alive:
						m.hp -= 12.0
						if m.hp <= 0.0:
							m.alive = false
							m.node.visible = false
						break
	if hp <= 0.0:
		return
	_squad_check(false)

	cam.position = lpos + Vector3(0, 14, 13)
	cam.look_at(lpos + Vector3(0, 0, -4), Vector3.UP)
	var alive_mates := mates.filter(func(m): return m.alive).size()
	hud.text = "ROOM %d   YOU %d   squad %d   hostiles %d   %s" % [
		room, int(max(0, hp)), alive_mates, foes.size(),
		"BREACH READY" if foes.is_empty() else ""]
	hud.position = lpos + Vector3(0, 9, 0)


func _squad_check(lead_down: bool) -> void:
	var alive_mates := mates.filter(func(m): return m.alive).size()
	if lead_down and alive_mates == 0:
		end_demo()
