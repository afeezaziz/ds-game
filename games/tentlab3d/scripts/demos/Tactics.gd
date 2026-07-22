extends MechDemo3D
## TACTICS — turn-based squad with cover (XCOM). Tap a tile to MOVE the selected
## trooper (2 action points each), FIRE at the enemy — hit odds drop if they hug cover
## and rise when you flank up close. END TURN and the enemy advances. Wipe them to
## push deeper; lose your squad and it's over. Desktop: tap move, J fire, L select, SPACE end.

const N := 8
const CELL := 2.6
var walls := {}               # Vector2i -> true
var units: Array = []         # {cell, hp, ap, node, alive, foe}
var sel := 0
var your_turn := true
var mission := 1
var msg := ""
var msg_t := 0.0
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.14, 0.15, 0.18), 0.85, Vector3(-60, -25, 0))
	static_box(Vector3(N * CELL, 1, N * CELL), Vector3((N - 1) * CELL * 0.5, -0.5, (N - 1) * CELL * 0.5), Color(0.28, 0.3, 0.34))
	mission = 1
	make_camera(Vector3(N * CELL * 0.5, 22, N * CELL * 1.1), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(N * CELL * 0.5, 13, N * CELL * 0.5), 28, Color.WHITE)
	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.5, 0.4)},
		{"id": "sel", "label": "SELECT", "col": Color(0.6, 0.7, 0.9)},
		{"id": "end", "label": "END TURN", "col": Color(0.9, 0.8, 0.4)},
	], false, false)
	tc.action.connect(func(id):
		if id == "fire": _fire()
		elif id == "sel": _cycle()
		elif id == "end": _end_turn())
	_setup()


func _w(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL, 0, c.y * CELL)


func _setup() -> void:
	for u in units:
		u.node.queue_free()
	units = []
	walls = {}
	for c in get_children():
		if c is MeshInstance3D and c.get_meta("wall", false):
			c.queue_free()
	for i in 8:
		var c := Vector2i(randi_range(1, N - 2), randi_range(1, N - 2))
		walls[c] = true
		var node := mesh_box(Vector3(CELL * 0.8, 1.6, CELL * 0.8), _w(c) + Vector3(0, 0.8, 0), Color(0.4, 0.42, 0.5))
		node.set_meta("wall", true)
	your_turn = true
	for i in 2:
		_unit(Vector2i(i + 1, 0), false)
	for i in 2 + mission:
		var c := Vector2i(randi_range(2, N - 2), N - 1 - (i % 2))
		if walls.has(c):
			continue
		_unit(c, true)
	sel = 0


func _unit(c: Vector2i, foe: bool) -> void:
	if walls.has(c):
		c += Vector2i(1, 0)
	var node := Node3D.new()
	add_child(node)
	mesh_box(Vector3(1.0, 1.9, 1.0), Vector3(0, 0.95, 0), Color(0.85, 0.4, 0.4) if foe else Color(0.4, 0.7, 0.95), node)
	node.position = _w(c)
	units.append({"cell": c, "hp": 6, "ap": 2, "node": node, "alive": true, "foe": foe})


func _unit_at(c: Vector2i):
	for u in units:
		if u.alive and u.cell == c:
			return u
	return null


func _sel_unit():
	if sel >= 0 and sel < units.size() and units[sel].alive and not units[sel].foe:
		return units[sel]
	return null


func _cycle() -> void:
	for k in units.size():
		sel = (sel + 1) % units.size()
		if units[sel].alive and not units[sel].foe:
			return


func _in_cover(u) -> bool:
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if walls.has(u.cell + d):
			return true
	return false


func _hit_chance(att, tgt) -> float:
	var dist := absf(att.cell.x - tgt.cell.x) + absf(att.cell.y - tgt.cell.y)
	var cover := 0.35 if _in_cover(tgt) else 0.0
	var flank := 0.3 if dist <= 2 else 0.0
	return clampf(0.85 - dist * 0.03 - cover + flank, 0.05, 0.95)


func _fire() -> void:
	var u = _sel_unit()
	if u == null or u.ap <= 0:
		return
	var best = null
	var bd := 99
	for e in units:
		if e.alive and e.foe:
			var d: int = absi(u.cell.x - e.cell.x) + absi(u.cell.y - e.cell.y)
			if d < bd:
				bd = d
				best = e
	if best == null:
		return
	u.ap -= 1
	var ch := _hit_chance(u, best)
	if randf() < ch:
		best.hp -= randi_range(3, 5)
		Juice.sfx("thud"); Juice.hitstop(30)
		Juice.popup("HIT %d%%" % int(ch * 100), Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))
		if best.hp <= 0:
			best.alive = false
			best.node.visible = false
			add_points(1)
			Juice.sfx("boom")
	else:
		Juice.sfx("tick")
		Juice.popup("MISS (%d%%)" % int(ch * 100), Vector2(W * 0.5, H * 0.4), Color(0.8, 0.8, 0.9))
	_check_win()


func _end_turn() -> void:
	your_turn = false
	_msg("enemy turn")
	for e in units:
		if not e.alive or not e.foe:
			continue
		# move one step toward nearest of your units, then fire if adjacent-ish
		var tgt = _nearest_you(e)
		if tgt != null:
			var to := tgt.cell - e.cell
			var step := Vector2i(signi(to.x), 0) if absf(to.x) > absf(to.y) else Vector2i(0, signi(to.y))
			var nc: Vector2i = e.cell + step
			if not walls.has(nc) and _unit_at(nc) == null and nc.x >= 0 and nc.x < N and nc.y >= 0 and nc.y < N:
				e.cell = nc
			var ch := _hit_chance(e, tgt)
			if randf() < ch:
				tgt.hp -= randi_range(2, 4)
				Juice.flash(Color(1, 0.3, 0.3), 0.12)
				if tgt.hp <= 0:
					tgt.alive = false
					tgt.node.visible = false
	your_turn = true
	for u in units:
		if u.alive and not u.foe:
			u.ap = 2
	if units.filter(func(x): return x.alive and not x.foe).is_empty():
		end_demo()
		return
	_check_win()


func _nearest_you(e):
	var best = null
	var bd := 99
	for u in units:
		if u.alive and not u.foe:
			var d: int = absi(u.cell.x - e.cell.x) + absi(u.cell.y - e.cell.y)
			if d < bd:
				bd = d
				best = u
	return best


func _check_win() -> void:
	if units.filter(func(x): return x.alive and x.foe).is_empty():
		mission += 1
		add_points(3)
		Juice.sfx("chime"); Juice.flash(Color(0.6, 0.9, 1.0), 0.3)
		_msg("MISSION CLEAR")
		_setup()


func _msg(t: String) -> void:
	msg = t
	msg_t = 1.6


func _ground_cell(sp: Vector2) -> Vector2i:
	var from := cam.project_ray_origin(sp)
	var dir := cam.project_ray_normal(sp)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	if hit == null:
		return Vector2i(-1, -1)
	var c := Vector2i(int(round(hit.x / CELL)), int(round(hit.z / CELL)))
	if c.x < 0 or c.x >= N or c.y < 0 or c.y >= N:
		return Vector2i(-1, -1)
	return c


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch and event.pressed:
		if not your_turn:
			return
		var c := _ground_cell(event.position)
		if c == Vector2i(-1, -1):
			return
		var u = _sel_unit()
		if u == null:
			# tap your unit to select it
			var t = _unit_at(c)
			if t != null and not t.foe:
				sel = units.find(t)
			return
		var dist := absf(c.x - u.cell.x) + absf(c.y - u.cell.y)
		if _unit_at(c) == null and not walls.has(c) and dist <= 4 and dist > 0 and u.ap > 0:
			u.cell = c
			u.ap -= 1
			Juice.sfx("tick")
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: _fire()
		elif event.keycode == KEY_L: _cycle()
		elif event.keycode == KEY_SPACE: _end_turn()


func _process(delta: float) -> void:
	if not running:
		return
	msg_t = maxf(0.0, msg_t - delta)
	for i in units.size():
		var u = units[i]
		if u.alive:
			u.node.position = u.node.position.move_toward(_w(u.cell) + Vector3(0, 0.4 if (i == sel and not u.foe) else 0.0, 0), 12.0 * delta)
	cam.look_at(_w(Vector2i(N / 2, N / 2)), Vector3.UP)
	var u = _sel_unit()
	var line := "no unit"
	if u != null:
		line = "unit AP %d/2   (tap a tile to move, FIRE to shoot)" % u.ap
	hud.text = "MISSION %d   %s   you %d  foes %d\n%s%s" % [
		mission, "YOUR TURN" if your_turn else "enemy...",
		units.filter(func(x): return x.alive and not x.foe).size(),
		units.filter(func(x): return x.alive and x.foe).size(), line, "  " + msg if msg_t > 0 else ""]
	hud.position = Vector3(N * CELL * 0.5, 13, N * CELL * 0.5)
