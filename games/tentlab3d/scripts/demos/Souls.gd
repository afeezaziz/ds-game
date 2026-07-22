extends MechDemo3D
## SOULS-LIKE — stamina, roll, estus, boss (Dark Souls). Everything spends STAMINA:
## a heavy ATTACK, and the i-frame ROLL that ghosts you through the boss's telegraphed
## swings. Sip ESTUS to heal (limited). Read the wind-up, roll, punish the recovery.
## Fell the boss for a harder one; a bonfire refills you on death. Desktop: WASD move, J attack, Space roll, H estus.

var player: Node3D
var ppos := Vector3(0, 0, 10)
var pyaw := 0.0
var hp := 100.0
var stamina := 100.0
var estus := 3
var iframe := 0.0
var atk_cd := 0.0
var estus_cd := 0.0

var boss: Node3D
var bpos := Vector3(0, 0, -6)
var bhp := 200.0
var bmax := 200.0
var bstate := 0              # 0 idle,1 wind,2 strike,3 recover
var btimer := 1.2
var battack := 0            # 0 slam, 1 sweep
var tele: MeshInstance3D
var deaths := 0
var felled := 0
var stick := Vector2.ZERO
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.1, 0.1, 0.14), 0.65, Vector3(-55, -15, 0))
	static_box(Vector3(44, 1, 44), Vector3(0, -0.5, 0), Color(0.24, 0.24, 0.28))
	mesh_cyl(2.0, 0.6, Vector3(0, 0.3, 14), Color(0.9, 0.6, 0.25))   # bonfire
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(1.0, 1.9, 1.0), Vector3(0, 0.95, 0), Color(0.55, 0.6, 0.7), player)
	mesh_box(Vector3(0.25, 0.25, 1.6), Vector3(0.5, 1.0, 0.6), Color(0.85, 0.85, 0.95), player)
	boss = Node3D.new()
	add_child(boss)
	mesh_box(Vector3(3.4, 4.4, 3.4), Vector3(0, 2.2, 0), Color(0.55, 0.3, 0.35), boss)
	mesh_box(Vector3(1.6, 1.2, 1.6), Vector3(0, 4.6, 0), Color(0.65, 0.35, 0.4), boss)
	tele = mesh_cyl(6.0, 0.1, Vector3(0, 0.06, 0), Color(1, 0.4, 0.2, 0.0))
	deaths = 0
	felled = 0
	_reset()
	make_camera(Vector3(0, 14, 16), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 12, 0), 32, Color.WHITE)
	tc = add_touch_controls([
		{"id": "attack", "label": "ATTACK", "col": Color(0.9, 0.6, 0.4)},
		{"id": "roll", "label": "ROLL", "col": Color(0.5, 0.75, 0.95)},
		{"id": "estus", "label": "ESTUS", "col": Color(0.5, 0.85, 0.6)},
	])
	tc.action.connect(func(id):
		if id == "attack": _attack()
		elif id == "roll": _roll()
		elif id == "estus": _estus())


func _reset() -> void:
	ppos = Vector3(0, 0, 10)
	hp = 100.0
	stamina = 100.0
	estus = 3
	bhp = bmax
	bstate = 0
	btimer = 1.2


func _attack() -> void:
	if atk_cd > 0.0 or stamina < 25.0:
		return
	atk_cd = 0.5
	stamina -= 25.0
	var to := bpos - ppos
	if to.length() < 4.5 and Vector3(sin(pyaw), 0, cos(pyaw)).dot(to.normalized()) > 0.2:
		bhp -= 18.0
		Juice.sfx("thud"); Juice.hitstop(50)
		Juice.popup("18", Vector2(W * 0.5, H * 0.4), Color(1, 0.9, 0.5), 34)
		if bhp <= 0.0:
			_fell()


func _roll() -> void:
	if stamina < 30.0 or iframe > 0.0:
		return
	stamina -= 30.0
	iframe = 0.5
	Juice.sfx("tick"); Juice.haptic(12)


func _estus() -> void:
	if estus <= 0 or estus_cd > 0.0:
		return
	estus -= 1
	estus_cd = 1.0
	hp = minf(100.0, hp + 40.0)
	Juice.sfx("chime")


func _fell() -> void:
	felled += 1
	add_points(2)
	bmax += 80.0
	Juice.sfx("coin"); Juice.flash(Color(1, 0.9, 0.6), 0.4)
	Juice.popup("VICTORY — bonfire lit", Vector2(W * 0.5, H * 0.32), Color(1, 0.9, 0.4))
	_reset()


func _die() -> void:
	deaths += 1
	Juice.sfx("boom"); Juice.flash(Color(0.6, 0.1, 0.1), 0.5)
	Juice.popup("YOU DIED", Vector2(W * 0.5, H * 0.36), Color(0.9, 0.2, 0.2), 56)
	if deaths >= 5:
		end_demo()
		return
	_reset()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: _attack()
		elif event.keycode == KEY_SPACE: _roll()
		elif event.keycode == KEY_H: _estus()


func _process(delta: float) -> void:
	if not running:
		return
	atk_cd = maxf(0.0, atk_cd - delta)
	estus_cd = maxf(0.0, estus_cd - delta)
	iframe = maxf(0.0, iframe - delta)
	stamina = minf(100.0, stamina + 22.0 * delta)

	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 0.05:
		if mv.length() > 1.0:
			mv = mv.normalized()
		var spd := 10.0 if iframe > 0.0 else 6.5
		ppos += mv * spd * delta
		pyaw = atan2(mv.x, mv.z)
	ppos.x = clampf(ppos.x, -20, 20)
	ppos.z = clampf(ppos.z, -20, 20)
	player.position = ppos
	player.rotation.y = pyaw
	# bonfire rest heals when you stand on it and the boss is far
	if ppos.distance_to(Vector3(0, 0, 14)) < 2.5:
		hp = minf(100.0, hp + 20.0 * delta)
		estus = mini(3, estus + (1 if fmod(hp, 100.0) < 0.1 else 0))

	# boss state machine: telegraph -> strike -> recover
	boss.position = bpos
	var to := ppos - bpos
	btimer -= delta
	match bstate:
		0:
			# approach + choose attack
			if to.length() > 6.0:
				bpos += to.normalized() * 3.5 * delta
			boss.rotation.y = atan2(to.x, to.z)
			if btimer <= 0.0:
				bstate = 1
				battack = randi() % 2
				btimer = 0.9
		1:
			# wind-up: show the telegraph
			var m := tele.material_override as StandardMaterial3D
			if battack == 0:
				tele.position = ppos + Vector3(0, 0.06, 0)
				tele.scale = Vector3(1, 1, 1)
			else:
				tele.position = bpos + to.normalized() * 6.0 + Vector3(0, 0.06, 0)
				tele.scale = Vector3(2, 1, 2)
			m.albedo_color = Color(1, 0.4, 0.2, 0.2 + 0.4 * (1.0 - btimer / 0.9))
			if btimer <= 0.0:
				bstate = 2
				btimer = 0.2
		2:
			if btimer <= 0.0:
				_resolve_boss()
				bstate = 3
				btimer = 0.8
				(tele.material_override as StandardMaterial3D).albedo_color = Color(1, 0.4, 0.2, 0.0)
		3:
			if btimer <= 0.0:
				bstate = 0
				btimer = randf_range(1.0, 1.8)

	cam.position = ppos * 0.3 + Vector3(0, 14, 16)
	cam.look_at(bpos.lerp(ppos, 0.4), Vector3.UP)
	hud.text = "HP %d   STAM %d   ESTUS %d   BOSS %d%%   felled %d  deaths %d/5" % [
		int(max(0, hp)), int(stamina), estus, int(bhp / bmax * 100), felled, deaths]
	hud.position = Vector3(0, 12, 0)


func _resolve_boss() -> void:
	if iframe > 0.0:
		return
	var hit := false
	if battack == 0:
		hit = ppos.distance_to(tele.position) < 6.0
	else:
		hit = ppos.distance_to(tele.position) < 6.0
	if hit:
		hp -= 34.0
		Juice.flash(Color(1, 0.2, 0.2), 0.3); Juice.haptic(35)
		if hp <= 0.0:
			_die()
