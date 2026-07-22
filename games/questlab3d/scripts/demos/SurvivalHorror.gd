extends MechDemo3D
## SURVIVAL HORROR — scarcity + dread (Resident Evil). Ammo and health are precious;
## the walkers are slow but soak bullets, so every shot is a choice: fight or slip
## past. Hunt the KEY, reach the EXIT. A flashlight is your only comfort. Escape for
## a deeper, leaner floor. Desktop: WASD move, mouse-look, SPACE fire, H heal.

var player: Node3D
var lamp: OmniLight3D
var ppos := Vector3(0, 0, 16)
var yaw := 0.0
var hp := 100.0
var ammo := 8
var heals := 2
var has_key := false
var walkers: Array = []       # {node,pos,hp}
var pickups: Array = []       # {node,pos,kind}
var keydoor: Node3D
var exit_pos := Vector3(0, 0, -34)
var floor_no := 1
var hurt_cd := 0.0
var fire_cd := 0.0
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.03, 0.03, 0.05), 0.18, Vector3(-70, 0, 0))
	static_box(Vector3(44, 1, 80), Vector3(0, -0.5, -8), Color(0.14, 0.13, 0.16))
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(1.0, 1.9, 1.0), Vector3(0, 0.95, 0), Color(0.5, 0.55, 0.6), player)
	lamp = OmniLight3D.new()
	lamp.omni_range = 16.0
	lamp.light_energy = 2.0
	lamp.position = Vector3(0, 2, 0)
	player.add_child(lamp)
	make_camera(Vector3(0, 14, 12), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 9, 0), 30, Color.WHITE)
	tc = add_touch_controls([
		{"id": "fire", "label": "FIRE", "col": Color(0.9, 0.4, 0.35)},
		{"id": "heal", "label": "HEAL", "col": Color(0.5, 0.8, 0.6)},
	], true)
	tc.action.connect(func(id):
		if id == "fire": _fire()
		elif id == "heal": _heal())
	tc.look.connect(func(rel): yaw -= rel.x * 0.005)
	_build_floor()


func _build_floor() -> void:
	for w in walkers: w.node.queue_free()
	for p in pickups: p.node.queue_free()
	walkers = []
	pickups = []
	has_key = false
	ppos = Vector3(0, 0, 16)
	for i in 3 + floor_no:
		_walker(Vector3(randf_range(-18, 18), 0, randf_range(-30, 6)))
	# scarce supplies — fewer as floors deepen
	for i in maxi(1, 4 - floor_no):
		_pickup(Vector3(randf_range(-18, 18), 0, randf_range(-30, 8)), "ammo")
	_pickup(Vector3(randf_range(-16, 16), 0, randf_range(-28, 0)), "heal")
	_pickup(Vector3(randf_range(-16, 16), 0, -30), "key")
	if keydoor == null:
		keydoor = mesh_box(Vector3(6, 5, 1), Vector3(0, 2.5, -34), Color(0.4, 0.3, 0.2))
	keydoor.visible = true
	exit_pos = Vector3(0, 0, -34)


func _walker(p: Vector3) -> void:
	var node := mesh_box(Vector3(1.1, 1.9, 1.1), p + Vector3(0, 0.95, 0), Color(0.35, 0.45, 0.35))
	walkers.append({"node": node, "pos": p, "hp": 6})


func _pickup(p: Vector3, kind: String) -> void:
	var col := Color(0.9, 0.85, 0.3)
	if kind == "ammo": col = Color(0.8, 0.7, 0.3)
	elif kind == "heal": col = Color(0.4, 0.9, 0.5)
	elif kind == "key": col = Color(0.9, 0.85, 0.2)
	var node := mesh_box(Vector3(0.8, 0.8, 0.8), p + Vector3(0, 0.6, 0), col)
	pickups.append({"node": node, "pos": p, "kind": kind})


func _fire() -> void:
	if fire_cd > 0.0 or ammo <= 0:
		return
	fire_cd = 0.4
	ammo -= 1
	Juice.sfx("thud")
	Juice.flash(Color(1, 0.9, 0.6), 0.08)
	var dir := Vector3(sin(yaw), 0, cos(yaw)) * -1.0
	var origin := ppos + Vector3(0, 1.1, 0)
	var best = null
	var bestdot := 0.94
	for w in walkers:
		var to := (w.pos - origin).normalized()
		var dd := dir.dot(to)
		if dd > bestdot:
			bestdot = dd
			best = w
	if best != null:
		best.hp -= 3
		if best.hp <= 0:
			best.node.queue_free()
			walkers.erase(best)
			add_points(1)
			Juice.sfx("boom")


func _heal() -> void:
	if heals <= 0 or hp >= 100.0:
		return
	heals -= 1
	hp = minf(100.0, hp + 45.0)
	Juice.sfx("chime")


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _fire()
		elif event.keycode == KEY_H: _heal()


func _process(delta: float) -> void:
	if not running:
		return
	fire_cd = maxf(0.0, fire_cd - delta)
	hurt_cd = maxf(0.0, hurt_cd - delta)
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * 6.0 * delta
	ppos.x = clampf(ppos.x, -20, 20)
	ppos.z = clampf(ppos.z, -32, 18)
	player.position = ppos
	player.rotation.y = yaw

	for w in walkers:
		var to: Vector3 = ppos - w.pos
		w.pos += to.normalized() * 2.0 * delta      # slow but relentless
		w.node.position = w.pos + Vector3(0, 0.95, 0)
		if hurt_cd <= 0.0 and to.length() < 1.5:
			hurt_cd = 1.0
			hp -= 14.0
			Juice.flash(Color(0.6, 0.1, 0.1), 0.3)
			Juice.haptic(35)
			if hp <= 0.0:
				end_demo()
				return

	for p in pickups.duplicate():
		if ppos.distance_to(p.pos) < 1.6:
			p.node.queue_free()
			pickups.erase(p)
			if p.kind == "ammo": ammo += 6
			elif p.kind == "heal": heals += 1
			elif p.kind == "key": has_key = true
			Juice.sfx("coin")
			Juice.popup(p.kind.to_upper(), Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.5))

	if has_key and ppos.distance_to(exit_pos) < 3.5:
		floor_no += 1
		add_points(5)
		Juice.sfx("chime")
		Juice.flash(Color(0.6, 0.9, 1.0), 0.3)
		Juice.popup("ESCAPED TO B%d" % floor_no, Vector2(W * 0.5, H * 0.34), Color(0.7, 1, 0.8))
		_build_floor()

	cam.position = ppos + Vector3(0, 14, 12)
	cam.look_at(ppos + Vector3(0, 0, -2), Vector3.UP)
	hud.text = "HP %d   AMMO %d   HEALS %d   %s" % [
		int(max(0, hp)), ammo, heals, "KEY — reach the door" if has_key else "find the key"]
	hud.position = ppos + Vector3(0, 9, 0)
