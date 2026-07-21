extends MechDemo3D
## MECH COMBAT — a Titanfall / Armored-Core-lite. You pilot a mech with TWO weapon
## systems on shared HEAT: the CANNON is hitscan and cheap; MISSILES need a LOCK
## (hold aim on a foe until the reticle fills) and hit hard but spike heat. Overheat
## = a forced cooldown lockout where you can't fire. BOOST-dash burns energy for
## i-frames and repositioning. Down enemy mechs before they wear your armor down.
## Score = kills. Touch: left pad move, look-drag right, CANNON / MISSILE / BOOST.
## Desktop: WASD move, mouse-drag look, J cannon, K missile, Shift boost.

var mech: Node3D
var mpos := Vector3(0, 2, 0)
var yaw := 0.0
var pitch := 0.0
var vel := Vector3.ZERO
var armor := 100.0
var heat := 0.0
var overheat := false
var energy := 100.0
var boost_t := 0.0
var cannon_cd := 0.0
var missile_cd := 0.0

var lock_target := -1
var lock_prog := 0.0
var foes: Array = []          # {node,pos,hp,fire,vy}
var missiles: Array = []      # {pos,vel,target,life,node}
var ebul: Array = []
var spawn_t := 2.0
var kills := 0

var tc: TouchControls
var hud: Label3D
var t := 0.0
const HEAT_MAX := 100.0
const CANNON_HEAT := 8.0
const MISSILE_HEAT := 34.0


func start() -> void:
	super.start()
	setup_world(Color(0.35, 0.4, 0.5), 0.75, Vector3(-50, -35, 0))
	static_box(Vector3(220, 1, 220), Vector3(0, 0, 0), Color(0.28, 0.3, 0.34))
	# cover blocks
	for i in 14:
		var a := randf() * TAU
		var r := randf_range(18, 70)
		var h := randf_range(4, 12)
		static_box(Vector3(6, h, 6), Vector3(cos(a) * r, h * 0.5, sin(a) * r), Color(0.32, 0.34, 0.4))
	mech = Node3D.new()
	add_child(mech)
	mesh_box(Vector3(2.2, 2.6, 2.0), Vector3(0, 2.6, 0), Color(0.55, 0.6, 0.7), mech)
	mesh_box(Vector3(1.4, 1.0, 1.4), Vector3(0, 4.2, 0), Color(0.6, 0.65, 0.78), mech)
	mesh_box(Vector3(0.7, 0.7, 2.6), Vector3(1.4, 3.0, -0.6), Color(0.4, 0.44, 0.55), mech)  # arm cannon
	mpos = Vector3(0, 2, 0)
	armor = 100.0
	heat = 0.0
	energy = 100.0
	overheat = false
	kills = 0
	foes = []
	missiles = []
	ebul = []
	spawn_t = 1.5
	make_camera(Vector3(0, 6, 10), Vector3.ZERO, 70.0)
	hud = Label3D.new()
	hud.font_size = 34
	hud.position = Vector3(-0.62, -0.42, -1.2)
	hud.modulate = Color(0.7, 1, 0.9)
	cam.add_child(hud)
	tc = add_touch_controls([
		{"id": "cannon", "label": "CANNON", "col": Color(0.8, 0.85, 1.0)},
		{"id": "missile", "label": "MISSILE", "col": Color(1.0, 0.7, 0.3)},
		{"id": "boost", "label": "BOOST", "col": Color(0.5, 0.9, 0.7)},
	], true)
	tc.action.connect(func(id):
		if id == "cannon": _cannon()
		elif id == "missile": _missile()
		elif id == "boost": _boost())
	tc.look.connect(_on_look)


func _on_look(rel: Vector2) -> void:
	yaw -= rel.x * 0.004
	pitch = clampf(pitch - rel.y * 0.003, -0.7, 0.7)


func _add_heat(h: float) -> void:
	heat += h
	if heat >= HEAT_MAX:
		heat = HEAT_MAX
		overheat = true
		Juice.sfx("boom")
		Juice.flash(Color(1, 0.5, 0.1), 0.3)


func _cannon() -> void:
	if overheat or cannon_cd > 0.0:
		return
	cannon_cd = 0.12
	_add_heat(CANNON_HEAT)
	var fwd := _aim_dir()
	# hitscan: the most-aligned foe inside a tight aim cone
	var best := -1
	var bestdot := 0.985
	for i in foes.size():
		var to: Vector3 = foes[i].pos - _muzzle()
		var dd := fwd.dot(to.normalized())
		if to.length() < 120.0 and dd > bestdot:
			bestdot = dd
			best = i
	Juice.sfx("tick")
	if best >= 0:
		foes[best].hp -= 10.0
		Juice.popup("10", Color(0.8, 0.9, 1))
		if foes[best].hp <= 0.0:
			_kill(best)


func _missile() -> void:
	if overheat or missile_cd > 0.0 or lock_target < 0 or lock_prog < 1.0:
		return
	missile_cd = 0.8
	_add_heat(MISSILE_HEAT)
	var tgt: Dictionary = foes[lock_target]
	var node := mesh_box(Vector3(0.4, 0.4, 1.4), _muzzle(), Color(1, 0.7, 0.3))
	missiles.append({"pos": _muzzle(), "vel": _aim_dir() * 40.0, "target": tgt, "life": 4.0, "node": node})
	Juice.sfx("thud")
	Juice.haptic(20)


func _boost() -> void:
	if energy < 34.0 or boost_t > 0.0:
		return
	energy -= 34.0
	boost_t = 0.5
	var fwd := _aim_dir()
	vel += Vector3(fwd.x, 0, fwd.z).normalized() * 26.0
	Juice.sfx("tick")
	Juice.haptic(15)


func _aim_dir() -> Vector3:
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()


func _muzzle() -> Vector3:
	return mpos + Vector3(0, 3.0, 0) + _aim_dir() * 2.0


func _kill(i: int) -> void:
	foes[i].node.queue_free()
	foes.remove_at(i)
	if lock_target == i:
		lock_target = -1
		lock_prog = 0.0
	kills += 1
	add_points(1)
	Juice.sfx("chime")
	Juice.hitstop(0.05)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_K:
			_missile()
		elif event.keycode == KEY_SHIFT:
			_boost()


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	cannon_cd -= delta
	missile_cd -= delta
	boost_t = maxf(0.0, boost_t - delta)
	# heat dissipation (slower while overheated to punish it)
	var cool := 14.0 if not overheat else 22.0
	heat = maxf(0.0, heat - cool * delta)
	if overheat and heat <= 20.0:
		overheat = false
	energy = minf(100.0, energy + 22.0 * delta)

	# hold CANNON (or J) to auto-fire at the weapon's cadence
	if tc.held("cannon") or Input.is_key_pressed(KEY_J):
		_cannon()

	# movement: camera-relative on the ground plane
	var flat := Vector3(-sin(yaw), 0, -cos(yaw))
	var right := Vector3(cos(yaw), 0, -sin(yaw))
	var wish := flat * (tc.move.y * -1.0 + key_axis_y()) + right * (tc.move.x + key_axis_x())
	if wish.length() > 1.0:
		wish = wish.normalized()
	vel = vel.move_toward(wish * 12.0, 40.0 * delta)
	mpos += vel * delta
	mpos.x = clampf(mpos.x, -95, 95)
	mpos.z = clampf(mpos.z, -95, 95)
	mech.position = mpos
	mech.rotation.y = yaw

	# lock-on: keep the most-aligned foe within cone; fill the lock over time
	var fwd := _aim_dir()
	var cand := -1
	var cdot := 0.95
	for i in foes.size():
		var to: Vector3 = foes[i].pos - _muzzle()
		var dd := fwd.dot(to.normalized())
		if to.length() < 90.0 and dd > cdot:
			cdot = dd
			cand = i
	if cand >= 0 and cand == lock_target:
		lock_prog = minf(1.0, lock_prog + delta * 1.6)
	elif cand >= 0:
		lock_target = cand
		lock_prog = 0.2
	else:
		lock_prog = maxf(0.0, lock_prog - delta * 2.0)
		if lock_prog <= 0.0:
			lock_target = -1

	# spawn foes
	spawn_t -= delta
	if spawn_t <= 0.0 and foes.size() < 6:
		spawn_t = maxf(1.5, 4.0 - t * 0.02)
		var a := randf() * TAU
		var p := mpos + Vector3(cos(a), 0, sin(a)) * randf_range(40, 70)
		p.y = 2.0
		var node := Node3D.new()
		add_child(node)
		mesh_box(Vector3(2.0, 2.4, 1.8), Vector3(0, 1.6, 0), Color(0.7, 0.4, 0.4), node)
		mesh_box(Vector3(1.2, 0.9, 1.2), Vector3(0, 3.0, 0), Color(0.8, 0.45, 0.42), node)
		node.position = p
		foes.append({"node": node, "pos": p, "hp": 26.0, "fire": randf_range(1.5, 3.0)})

	# drive foes: strafe toward mid-range, fire
	for f in foes:
		var to: Vector3 = mpos - f.pos
		var dist := to.length()
		var dir := to.normalized()
		if dist > 34.0:
			f.pos += dir * 8.0 * delta
		elif dist < 22.0:
			f.pos -= dir * 6.0 * delta
		else:
			# strafe
			f.pos += Vector3(-dir.z, 0, dir.x) * 6.0 * delta * (1.0 if int(f.fire * 3.0) % 2 == 0 else -1.0)
		f.node.position = f.pos
		f.node.look_at(mpos, Vector3.UP)
		f.fire -= delta
		if f.fire <= 0.0 and dist < 60.0:
			f.fire = randf_range(1.4, 2.6)
			ebul.append({"pos": f.pos + Vector3(0, 2.5, 0), "vel": (mpos + Vector3(0, 3, 0) - f.pos).normalized() * 55.0, "life": 3.0})

	# missiles home toward their target
	for m in missiles.duplicate():
		m.life -= delta
		if m.life <= 0.0 or not is_instance_valid(m.node):
			if is_instance_valid(m.node):
				m.node.queue_free()
			missiles.erase(m)
			continue
		if m.target in foes:
			var desired: Vector3 = (m.target.pos - m.pos).normalized() * 46.0
			m.vel = m.vel.move_toward(desired, 120.0 * delta)
		m.pos += m.vel * delta
		m.node.position = m.pos
		m.node.look_at(m.pos + m.vel, Vector3.UP)
		for i in foes.size():
			if m.pos.distance_to(foes[i].pos) < 3.0:
				foes[i].hp -= 22.0
				Juice.sfx("boom")
				Juice.flash(Color(1, 0.6, 0.2), 0.15)
				m.node.queue_free()
				missiles.erase(m)
				if foes[i].hp <= 0.0:
					_kill(i)
				break

	# enemy bullets
	for b in ebul.duplicate():
		b.pos += b.vel * delta
		b.life -= delta
		if b.life <= 0.0:
			ebul.erase(b)
			continue
		if boost_t <= 0.0 and b.pos.distance_to(mpos + Vector3(0, 3, 0)) < 2.6:
			ebul.erase(b)
			armor -= 9.0
			Juice.flash(Color(1, 0.25, 0.25), 0.2)
			Juice.shake2d(5.0)
			Juice.haptic(28)
			if armor <= 0.0:
				end_demo()
				return

	# first-person-ish chase camera behind the head
	cam.position = mpos + Vector3(0, 5.5, 0) - Vector3(-sin(yaw), -0.4, -cos(yaw)) * 8.0
	cam.rotation = Vector3(pitch, yaw, 0)
	var lock_str := "LOCK %d%%" % int(lock_prog * 100) if lock_target >= 0 else "no lock"
	hud.text = "ARMOR %d   HEAT %d%%%s   NRG %d   %s   kills %d" % [
		int(max(0, armor)), int(heat), "  !OVERHEAT!" if overheat else "", int(energy), lock_str, kills]
