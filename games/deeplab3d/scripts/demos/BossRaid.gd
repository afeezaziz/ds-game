extends MechDemo3D
## BOSS RAID 3D — a Monster-Hunter / MMO-raid boss fight, the deep way. The boss
## runs a scripted MOVE SET that changes per PHASE (100/60/25% hp). Every attack
## TELEGRAPHS (a ground marker grows) then RESOLVES — dodge out of the marker in
## time or eat it. Hits to the glowing WEAK POINT (its back) deal 2x. Miss the
## DPS check and it ENRAGES (faster, harder). Dodge-roll has i-frames + stamina.
## Score = bosses felled. Touch: left pad = move, DODGE + ATTACK buttons.
## Desktop: WASD move, Space dodge, J attack.

var player: Node3D
var ppos := Vector3(0, 0, 16)
var pyaw := 0.0
var php := 120.0
var stam := 100.0
var iframe := 0.0
var atk_cd := 0.0

var boss: Node3D
var weak: MeshInstance3D
var bpos := Vector3(0, 0, -6)
var byaw := 0.0
var bhp := 900.0
var bmax := 900.0
var phase := 1
var enraged := false
var enrage_t := 75.0
var kills := 0

var move_t := 1.2                 # time until next attack is chosen
var tele: Array = []              # active telegraphs: {kind,pos,dir,r,ang,t,dur,dmg,node}
var stick := Vector2.ZERO
var stick_on := false
var origin := Vector2.ZERO
var hud: Label3D
var t := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.28, 0.24, 0.3), 0.7, Vector3(-55, -20, 0))
	static_box(Vector3(70, 1, 70), Vector3(0, -0.5, 0), Color(0.32, 0.3, 0.34))
	# arena ring markers
	for i in 16:
		var a := i * TAU / 16.0
		mesh_box(Vector3(2, 0.4, 2), Vector3(cos(a) * 30, 0.2, sin(a) * 30), Color(0.4, 0.36, 0.42))
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(1.0, 1.8, 1.0), Vector3(0, 0.9, 0), Color(0.4, 0.7, 0.95), player)
	mesh_box(Vector3(0.3, 0.3, 1.6), Vector3(0.5, 1.0, -0.6), Color(0.85, 0.85, 0.5), player)  # weapon
	_spawn_boss()
	ppos = Vector3(0, 0, 16)
	php = 120.0
	stam = 100.0
	kills = 0
	make_camera(Vector3(0, 20, 22), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 16, 0), 38, Color.WHITE)


func _spawn_boss() -> void:
	boss = Node3D.new()
	add_child(boss)
	mesh_box(Vector3(4.2, 4.6, 4.2), Vector3(0, 2.3, 0), Color(0.6, 0.25, 0.28), boss)
	mesh_box(Vector3(2.0, 1.4, 1.2), Vector3(0, 4.0, 2.0), Color(0.75, 0.3, 0.32), boss)  # head
	mesh_sphere(0.5, Vector3(-0.9, 4.1, 2.7), Color(1, 0.9, 0.3), boss)
	mesh_sphere(0.5, Vector3(0.9, 4.1, 2.7), Color(1, 0.9, 0.3), boss)
	weak = mesh_sphere(1.1, Vector3(0, 2.6, -2.2), Color(1.0, 0.85, 0.2), boss)  # weak point on back
	bpos = Vector3(0, 0, -6)
	byaw = 0.0
	bhp = bmax
	phase = 1
	enraged = false
	enrage_t = 75.0
	move_t = 1.5


func _dodge() -> void:
	if stam < 30.0 or iframe > 0.0:
		return
	stam -= 30.0
	iframe = 0.45
	Juice.sfx("tick")
	Juice.haptic(15)


func _attack() -> void:
	if atk_cd > 0.0:
		return
	atk_cd = 0.5
	var to := bpos - ppos
	if to.length() > 6.0:
		return
	# facing check
	var face := Vector3(sin(pyaw), 0, cos(pyaw))
	if face.dot(to.normalized()) < 0.3:
		return
	# positional: hitting the back (weak point faces -byaw*z) doubles damage
	var back := Vector3(-sin(byaw), 0, -cos(byaw))
	var mult := 2.0 if back.dot((ppos - bpos).normalized()) > 0.4 else 1.0
	var dmg := 26.0 * mult
	bhp -= dmg
	Juice.sfx("thud" if mult < 2.0 else "coin")
	Juice.hitstop(0.05)
	Juice.popup(str(int(dmg)) + ("!" if mult > 1.0 else ""), Color(1, 0.9, 0.4) if mult > 1 else Color.WHITE)
	if bhp <= 0.0:
		_boss_down()


func _boss_down() -> void:
	kills += 1
	add_points(1)
	Juice.sfx("chime")
	Juice.flash(Color(1, 1, 0.7), 0.3)
	for x in tele:
		if x.node:
			x.node.queue_free()
	tele = []
	boss.queue_free()
	bmax += 350.0
	php = minf(120.0, php + 40.0)
	_spawn_boss()


# ---- attack library: each telegraphs then resolves ----

func _telegraph(kind: String, pos: Vector3, dir: Vector3, r: float, ang: float, dur: float, dmg: float) -> void:
	var col := Color(1, 0.4, 0.2, 0.5)
	var node: MeshInstance3D
	if kind == "aoe":
		node = mesh_cyl(r, 0.1, pos + Vector3(0, 0.06, 0), col)
	elif kind == "cone":
		node = mesh_box(Vector3(r * 1.4, 0.1, r), pos + dir * (r * 0.5) + Vector3(0, 0.06, 0), col)
		node.look_at(pos + dir + Vector3(0, 0.06, 0), Vector3.UP)
	else:  # line / charge
		node = mesh_box(Vector3(3.0, 0.1, r), pos + dir * (r * 0.5) + Vector3(0, 0.06, 0), col)
		node.look_at(pos + dir + Vector3(0, 0.06, 0), Vector3.UP)
	tele.append({"kind": kind, "pos": pos, "dir": dir, "r": r, "ang": ang, "t": 0.0, "dur": dur, "dmg": dmg, "node": node})


func _choose_attack() -> void:
	var to := ppos - bpos
	byaw = atan2(to.x, to.z)
	var speed := 1.0 if not enraged else 0.72
	var roll := randi() % (3 if phase >= 2 else 2)
	if phase >= 3:
		roll = randi() % 4
	match roll:
		0:  # slam at player location (dodge out)
			_telegraph("aoe", ppos, Vector3.ZERO, 5.0, 0, 0.9 * speed, 34.0)
		1:  # cone sweep in facing dir
			_telegraph("cone", bpos, to.normalized(), 12.0, 1.0, 1.1 * speed, 30.0)
		2:  # charge line toward player
			_telegraph("line", bpos, to.normalized(), 26.0, 0, 1.0 * speed, 40.0)
		3:  # phase-3: ring — must be near boss to be safe (inverse)
			_telegraph("ring", bpos, Vector3.ZERO, 26.0, 0, 1.2 * speed, 45.0)
	move_t = randf_range(1.6, 2.6) * speed


func _resolve(x: Dictionary) -> void:
	var hit := false
	var d := ppos.distance_to(x.pos)
	if x.kind == "aoe":
		hit = d < x.r
	elif x.kind == "ring":
		hit = d > 7.0  # safe only if hugging the boss
	elif x.kind == "cone":
		var to := (ppos - x.pos)
		hit = to.length() < x.r and to.normalized().dot(x.dir) > cos(x.ang)
	else:  # line / charge — box around the ray
		var along := (ppos - x.pos).dot(x.dir)
		var perp := (ppos - x.pos - x.dir * along).length()
		hit = along > 0 and along < x.r and perp < 2.4
		bpos = x.pos + x.dir * minf(x.r, 20.0)  # charge relocates the boss
	if hit and iframe <= 0.0:
		php -= x.dmg
		Juice.flash(Color(1, 0.2, 0.2), 0.25)
		Juice.shake2d(6.0)
		Juice.haptic(35)
		if php <= 0.0:
			end_demo()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed and Rect2(W - 190, H - 220, 170, 170).has_point(event.position):
			_attack()
		elif event.pressed and Rect2(W - 190, H - 420, 170, 170).has_point(event.position):
			_dodge()
		elif event.pressed and event.position.x < W * 0.5:
			stick_on = true
			origin = event.position
			stick = Vector2.ZERO
		elif not event.pressed:
			stick_on = false
			stick = Vector2.ZERO
	elif event is InputEventScreenDrag and stick_on:
		stick = ((event.position - origin) / 70.0).limit_length(1.0)
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_dodge()
		elif event.keycode == KEY_J:
			_attack()


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	atk_cd -= delta
	iframe = maxf(0.0, iframe - delta)
	stam = minf(100.0, stam + 18.0 * delta)

	# player move
	var mv := Vector3(stick.x + key_axis_x(), 0, stick.y - key_axis_y())
	if mv.length() > 0.05:
		if mv.length() > 1.0:
			mv = mv.normalized()
		var spd := 9.0 if iframe > 0.0 else 7.0
		ppos += mv * spd * delta
		pyaw = atan2(mv.x, mv.z)
	ppos.x = clampf(ppos.x, -30, 30)
	ppos.z = clampf(ppos.z, -30, 30)
	player.position = ppos
	player.rotation.y = pyaw

	# phase transitions
	var frac := bhp / bmax
	var np := 3 if frac <= 0.25 else (2 if frac <= 0.6 else 1)
	if np != phase:
		phase = np
		Juice.flash(Color(1, 0.5, 0.2), 0.3)
		Juice.sfx("boom")
	# enrage / DPS check
	enrage_t -= delta
	if enrage_t <= 0.0 and not enraged:
		enraged = true
		Juice.flash(Color(1, 0.2, 0.1), 0.5)

	# boss faces & slowly repositions toward player between attacks
	boss.position = bpos
	boss.rotation.y = byaw
	var to := ppos - bpos
	byaw = lerp_angle(byaw, atan2(to.x, to.z), 2.0 * delta)
	# close distance toward the player between attacks
	if tele.is_empty() and to.length() > 9.0:
		bpos += to.normalized() * (6.0 if enraged else 4.0) * delta
	move_t -= delta
	if move_t <= 0.0 and tele.is_empty():
		_choose_attack()

	# resolve telegraphs
	for x in tele.duplicate():
		x.t += delta
		var k := clampf(x.t / x.dur, 0.0, 1.0)
		if x.node:
			var c: Color = x.node.material_override.albedo_color
			c.a = 0.25 + 0.5 * k
			x.node.material_override.albedo_color = c
		if x.t >= x.dur:
			_resolve(x)
			if x.node:
				x.node.queue_free()
			tele.erase(x)

	# camera tracks the midpoint player<->boss
	var mid := (ppos + bpos) * 0.5
	cam.position = mid + Vector3(0, 20, 22)
	cam.look_at(mid, Vector3.UP)
	hud.text = "HP %d   STAM %d   BOSS %d%%  P%d%s   enrage %ds   felled %d" % [
		int(max(0, php)), int(stam), int(frac * 100), phase,
		"  ENRAGED" if enraged else "", int(max(0, enrage_t)), kills]
	hud.position = mid + Vector3(0, 14, 0)
