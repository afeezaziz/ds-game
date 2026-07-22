extends MechDemo3D
## SKATEBOARDING — trick-combo lines (Tony Hawk). Roll the park, OLLIE off ramps,
## then stack FLIP/GRAB tricks in the air; variety multiplies the combo. Land clean
## to BANK it — but touch ground mid-trick and you BAIL and lose the combo (3 bails
## ends the run). Desktop: WASD roll, SPACE ollie, J flip, K grab.

var deck: Node3D
var ppos := Vector3.ZERO
var vel := Vector3.ZERO
var vy := 0.0
var grounded := true
var trick_busy := 0.0
var combo := 0
var combo_pts := 0
var variety := {}
var bails := 3
var ramps: Array = []
var tc: TouchControls
var hud: Label3D
var flash_t := 0.0
var flash_txt := ""


func start() -> void:
	super.start()
	setup_world(Color(0.55, 0.68, 0.85), 0.95)
	static_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0), Color(0.4, 0.4, 0.45))
	# quarter-pipe ramps: rolling onto one launches you
	for i in 5:
		var p := Vector3(randf_range(-30, 30), 0, randf_range(-30, 30))
		var node := mesh_box(Vector3(8, 1.4, 8), p + Vector3(0, 0.7, 0), Color(0.5, 0.45, 0.6))
		ramps.append({"pos": p, "node": node})
	deck = Node3D.new()
	add_child(deck)
	mesh_box(Vector3(0.9, 0.25, 2.4), Vector3(0, 0.3, 0), Color(0.85, 0.3, 0.4), deck)
	mesh_box(Vector3(0.7, 1.4, 0.7), Vector3(0, 1.2, 0), Color(0.4, 0.8, 1.0), deck)
	ppos = Vector3.ZERO
	vel = Vector3.ZERO
	vy = 0.0
	grounded = true
	combo = 0
	bails = 3
	make_camera(Vector3(0, 8, 12), Vector3.ZERO, 60.0)
	hud = label3d("", Vector3(0, 5, 0), 34, Color.WHITE)
	tc = add_touch_controls([
		{"id": "ollie", "label": "OLLIE", "col": Color(0.5, 0.85, 0.6)},
		{"id": "flip", "label": "FLIP", "col": Color(0.9, 0.6, 0.4)},
		{"id": "grab", "label": "GRAB", "col": Color(0.6, 0.6, 0.95)},
	])
	tc.action.connect(func(id):
		if id == "ollie": _ollie()
		elif id == "flip": _trick("FLIP", 10)
		elif id == "grab": _trick("GRAB", 8))


func _ollie() -> void:
	if grounded:
		vy = 11.0
		grounded = false
		Juice.sfx("tick")


func _trick(name: String, pts: int) -> void:
	if grounded:
		return
	trick_busy = 0.32
	combo += 1
	var bonus := 0
	if not variety.has(name):
		variety[name] = true
		bonus = 5
	combo_pts += pts + bonus
	_pop("%s%s  x%d" % [name, "!" if bonus > 0 else "", combo])
	Juice.sfx("thud")


func _pop(txt: String) -> void:
	flash_txt = txt
	flash_t = 0.8
	Juice.popup(txt, Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_ollie()
		elif event.keycode == KEY_J:
			_trick("FLIP", 10)
		elif event.keycode == KEY_K:
			_trick("GRAB", 8)


func _process(delta: float) -> void:
	if not running:
		return
	trick_busy = maxf(0.0, trick_busy - delta)
	flash_t = maxf(0.0, flash_t - delta)

	var wish := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if wish.length() > 1.0:
		wish = wish.normalized()
	vel = vel.move_toward(wish * 12.0, 30.0 * delta) if grounded else vel
	ppos += vel * delta
	if wish.length() > 0.1:
		deck.rotation.y = atan2(vel.x, vel.z)

	if not grounded:
		vy -= 22.0 * delta
		ppos.y += vy * delta
		deck.rotation.x += delta * 8.0        # spin visual while airborne
		if ppos.y <= 0.0:
			ppos.y = 0.0
			deck.rotation.x = 0.0
			grounded = true
			if trick_busy > 0.0:
				_bail()
			elif combo > 0:
				var gain := combo_pts
				add_points(gain)
				_pop("LANDED +%d" % gain)
				Juice.sfx("coin")
				combo = 0
				combo_pts = 0
				variety = {}
	else:
		# ramp launch
		for r in ramps:
			if Vector2(ppos.x - r.pos.x, ppos.z - r.pos.z).length() < 4.5 and vel.length() > 4.0:
				vy = 12.0
				grounded = false
				Juice.sfx("tick")
				break
	ppos.x = clampf(ppos.x, -38, 38)
	ppos.z = clampf(ppos.z, -38, 38)
	deck.position = ppos

	cam.position = ppos + Vector3(0, 8, 12)
	cam.look_at(ppos + Vector3(0, 1, 0), Vector3.UP)
	hud.text = "SCORE %d   combo x%d (%dpt)   bails left %d" % [score, combo, combo_pts, bails]
	hud.position = ppos + Vector3(0, 5, 0)


func _bail() -> void:
	bails -= 1
	combo = 0
	combo_pts = 0
	variety = {}
	vel = Vector3.ZERO
	_pop("BAIL!")
	Juice.sfx("boom")
	Juice.flash(Color(1, 0.3, 0.3), 0.3)
	Juice.haptic(35)
	if bails <= 0:
		end_demo()
