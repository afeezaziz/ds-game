extends MechDemo3D
## BOXING — read, defend, punish (Punch-Out!-style timing). The opponent WINDS UP a
## punch on the left or right; BLOCK to chip it or SLIP the correct way to dodge and
## open a counter WINDOW; then JAB/HOOK into the opening. Punches cost stamina. Drop
## the foe to advance rounds; your HP 0 ends it. Desktop: A/D slip, SPACE block, J jab, K hook.

enum FS { IDLE, WIND, STRIKE, STUN }
var foe: Node3D
var fs: FS = FS.IDLE
var f_side := 1               # -1 left, 1 right
var f_timer := 0.0
var opening := 0.0
var foe_hp := 100.0
var hp := 100.0
var stamina := 100.0
var slip := 0.0               # -1..1 current lean
var blocking := false
var round_no := 1
var tc: TouchControls
var hud: Label3D
var head: Node3D


func start() -> void:
	super.start()
	setup_world(Color(0.15, 0.1, 0.12), 0.8, Vector3(-50, 0, 0))
	static_box(Vector3(30, 1, 30), Vector3(0, -0.5, -6), Color(0.35, 0.28, 0.3))
	foe = Node3D.new()
	add_child(foe)
	mesh_box(Vector3(3.0, 4.0, 1.6), Vector3(0, 2.5, 0), Color(0.75, 0.45, 0.4), foe)
	head = mesh_sphere(1.0, Vector3(0, 5.0, 0), Color(0.8, 0.55, 0.5), foe)
	foe.position = Vector3(0, 0, -8)
	fs = FS.IDLE
	f_timer = 1.2
	foe_hp = 100.0
	hp = 100.0
	stamina = 100.0
	round_no = 1
	make_camera(Vector3(0, 3.0, 4.5), Vector3(0, 3.0, -8), 60.0)
	hud = label3d("", Vector3(0, 7.5, -8), 34, Color.WHITE)
	tc = add_touch_controls([
		{"id": "block", "label": "BLOCK", "col": Color(0.5, 0.7, 0.95)},
		{"id": "jab", "label": "JAB", "col": Color(0.9, 0.7, 0.4)},
		{"id": "hook", "label": "HOOK", "col": Color(0.9, 0.45, 0.4)},
	])
	tc.action.connect(func(id):
		if id == "jab": _punch(9, 8)
		elif id == "hook": _punch(18, 20))


func _punch(dmg: int, cost: int) -> void:
	if stamina < cost:
		return
	stamina -= cost
	var mult := 2.2 if opening > 0.0 else 0.6   # counters in the opening hurt
	foe_hp -= dmg * mult
	Juice.sfx("thud" if mult < 1.0 else "coin")
	Juice.hitstop(40)
	Juice.haptic(15)
	head.position = Vector3(0, 5.0 - 0.3, 0.4)   # head snap
	if opening > 0.0:
		Juice.popup("COUNTER!", Vector2(W * 0.5, H * 0.34), Color(1, 0.9, 0.4))
	if foe_hp <= 0.0:
		_drop()


func _drop() -> void:
	round_no += 1
	add_points(1)
	foe_hp = 100.0 + round_no * 20.0
	hp = minf(100.0, hp + 25.0)
	fs = FS.STUN
	f_timer = 1.5
	Juice.sfx("chime")
	Juice.flash(Color(1, 0.9, 0.5), 0.3)
	Juice.popup("DOWN! round %d" % round_no, Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J:
			_punch(9, 8)
		elif event.keycode == KEY_K:
			_punch(18, 20)


func _process(delta: float) -> void:
	if not running:
		return
	stamina = minf(100.0, stamina + 18.0 * delta)
	opening = maxf(0.0, opening - delta)
	blocking = tc.held("block") or Input.is_key_pressed(KEY_SPACE)
	slip = move_toward(slip, tc.move.x + key_axis_x(), delta * 6.0)
	head.position = head.position.move_toward(Vector3(0, 5.0, 0), delta * 4.0)

	var speed := maxf(0.5, 1.3 - round_no * 0.06)
	f_timer -= delta
	match fs:
		FS.IDLE:
			if f_timer <= 0.0:
				fs = FS.WIND
				f_side = 1 if randf() < 0.5 else -1
				f_timer = speed
		FS.WIND:
			# telegraph: the foe leans to the punch side
			foe.rotation.z = -f_side * 0.3 * (1.0 - f_timer / speed)
			if f_timer <= 0.0:
				fs = FS.STRIKE
				f_timer = 0.25
		FS.STRIKE:
			foe.position.z = -8.0 + 2.5 * sin((0.25 - f_timer) / 0.25 * PI)
			if f_timer <= 0.0:
				_resolve_strike()
				fs = FS.IDLE
				f_timer = randf_range(0.5, 1.1)
				foe.rotation.z = 0.0
				foe.position.z = -8.0
		FS.STUN:
			foe.rotation.x = 0.5
			if f_timer <= 0.0:
				fs = FS.IDLE
				foe.rotation.x = 0.0
				f_timer = 1.0

	cam.position = Vector3(slip * 1.5, 3.0, 4.5)
	cam.look_at(Vector3(0, 3.2, -8), Vector3.UP)
	hud.text = "YOU %d   FOE %d   STAM %d   round %d\n%s" % [
		int(max(0, hp)), int(max(0, foe_hp)), int(stamina), round_no,
		("WIND %s" % ("RIGHT" if f_side > 0 else "LEFT")) if fs == FS.WIND else ("BLOCK!" if blocking else "")]
	hud.position = Vector3(0, 7.5, -8)


func _resolve_strike() -> void:
	# dodged if you slipped AWAY from the punch side; blocked = chip; else full hit
	var slipped_away := (f_side > 0 and slip < -0.4) or (f_side < 0 and slip > 0.4)
	if slipped_away:
		opening = 0.9
		Juice.sfx("tick")
		Juice.popup("SLIP!", Vector2(W * 0.5, H * 0.4), Color(0.6, 1, 0.7))
	elif blocking:
		hp -= 4.0
		Juice.sfx("thud")
		Juice.haptic(12)
	else:
		hp -= 16.0
		Juice.sfx("boom")
		Juice.flash(Color(1, 0.3, 0.3), 0.3)
		Juice.haptic(35)
		if hp <= 0.0:
			end_demo()
