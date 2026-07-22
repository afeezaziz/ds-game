extends MechDemo3D
## POOL — 8-ball physics. Aim the cue with the stick, HOLD STRIKE to build power,
## release to break. Balls collide elastically and drop into the six pockets. Pot
## balls to score; scratch the cue ball and you lose it back. Clear the rack for a
## fresh one. Desktop: A/D aim, SPACE hold-to-strike.

const TW := 20.0            # table half-width (x)
const TH := 11.0            # table half-depth (z)
const R := 0.7             # ball radius

var balls: Array = []       # {pos:Vector2, vel:Vector2, node, cue:bool, live:bool}
var aim := 0.0
var power := 0.0
var charging := false
var moving := false
var potted := 0
var racks := 0
var pockets: Array = []
var aim_line: Node3D
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.1, 0.14, 0.12), 0.9, Vector3(-80, 0, 0))
	static_box(Vector3(TW * 2 + 3, 1, TH * 2 + 3), Vector3(0, -0.5, 0), Color(0.15, 0.35, 0.2))
	pockets = [Vector2(-TW, -TH), Vector2(0, -TH - 0.4), Vector2(TW, -TH),
		Vector2(-TW, TH), Vector2(0, TH + 0.4), Vector2(TW, TH)]
	for p in pockets:
		mesh_cyl(1.3, 0.5, Vector3(p.x, 0.1, p.y), Color(0.05, 0.05, 0.05))
	aim_line = mesh_box(Vector3(0.12, 0.05, 8.0), Vector3.ZERO, Color(1, 1, 0.5, 0.6))
	potted = 0
	racks = 0
	make_camera(Vector3(0, 26, 20), Vector3.ZERO, 50.0)
	hud = label3d("", Vector3(0, 12, 0), 34, Color.WHITE)
	tc = add_touch_controls([{"id": "strike", "label": "STRIKE", "col": Color(0.85, 0.8, 0.5)}])
	tc.action.connect(func(_id): charging = true)
	tc.released.connect(func(_id): _strike())
	_rack()


func _rack() -> void:
	for b in balls:
		if is_instance_valid(b.node):
			b.node.queue_free()
	balls = []
	_add(Vector2(-TW * 0.5, 0), true, Color.WHITE)
	var cols := [Color(1, 0.85, 0.2), Color(0.2, 0.4, 1), Color(1, 0.3, 0.3), Color(0.6, 0.3, 0.8),
		Color(1, 0.55, 0.2), Color(0.2, 0.7, 0.4), Color(0.6, 0.2, 0.2), Color(0.1, 0.1, 0.1),
		Color(1, 0.85, 0.2), Color(0.2, 0.4, 1)]
	var i := 0
	for row in 4:
		for c in range(row + 1):
			var x := TW * 0.45 + row * (R * 1.9)
			var z := (c - row * 0.5) * (R * 2.1)
			_add(Vector2(x, z), false, cols[i % cols.size()])
			i += 1


func _add(p: Vector2, cue: bool, col: Color) -> void:
	var node := mesh_sphere(R, Vector3(p.x, R, p.y), col)
	balls.append({"pos": p, "vel": Vector2.ZERO, "node": node, "cue": cue, "live": true})


func _cue():
	for b in balls:
		if b.cue and b.live:
			return b
	return null


func _strike() -> void:
	if not charging or moving:
		charging = false
		return
	charging = false
	var c = _cue()
	if c == null:
		return
	c.vel = Vector2(sin(aim), -cos(aim)) * (power * 44.0)
	power = 0.0
	moving = true
	Juice.sfx("thud")
	Juice.haptic(20)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and not event.echo and event.keycode == KEY_SPACE:
		if event.pressed:
			charging = true
		else:
			_strike()


func _process(delta: float) -> void:
	if not running:
		return
	if charging:
		power = min(1.0, power + delta * 0.8)
	aim += (tc.move.x + key_axis_x()) * 1.5 * delta

	if moving:
		_sim(delta)
	var c = _cue()
	if c != null:
		aim_line.position = Vector3(c.pos.x, 0.9, c.pos.y) + Vector3(sin(aim), 0, -cos(aim)) * 4.0
		aim_line.rotation.y = aim
		aim_line.visible = not moving
		cam.position = Vector3(c.pos.x * 0.3, 26, 20)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	hud.text = "POTTED %d   rack %d   POWER %d%%%s" % [score, racks + 1, int(power * 100),
		"   ...rolling" if moving else ""]
	hud.position = Vector3(0, 12, 0)


func _sim(delta: float) -> void:
	var any := false
	for b in balls:
		if not b.live:
			continue
		b.pos += b.vel * delta
		b.vel *= 0.985
		# cushions
		if absf(b.pos.x) > TW:
			b.pos.x = clampf(b.pos.x, -TW, TW)
			b.vel.x = -b.vel.x * 0.8
		if absf(b.pos.y) > TH:
			b.pos.y = clampf(b.pos.y, -TH, TH)
			b.vel.y = -b.vel.y * 0.8
		if b.vel.length() > 0.4:
			any = true
		else:
			b.vel = Vector2.ZERO
	# pairwise elastic collisions
	for i in balls.size():
		var a = balls[i]
		if not a.live:
			continue
		for j in range(i + 1, balls.size()):
			var b = balls[j]
			if not b.live:
				continue
			var d: Vector2 = b.pos - a.pos
			var dist := d.length()
			if dist < R * 2.0 and dist > 0.001:
				var n := d / dist
				var overlap := R * 2.0 - dist
				a.pos -= n * overlap * 0.5
				b.pos += n * overlap * 0.5
				var rel := (b.vel - a.vel).dot(n)
				if rel < 0.0:
					a.vel += n * rel
					b.vel -= n * rel
					any = true
	# pockets (erase potted balls so no freed-node dict lingers in `balls`)
	for b in balls.duplicate():
		if not b.live:
			continue
		for p in pockets:
			if b.pos.distance_to(p) < 1.4:
				balls.erase(b)
				b.node.queue_free()
				if b.cue:
					Juice.sfx("boom")
					Juice.popup("SCRATCH", Vector2(W * 0.5, H * 0.4), Color(1, 0.5, 0.4))
					_respawn_cue()
				else:
					potted += 1
					add_points(1)
					Juice.sfx("coin")
				break
	for b in balls:
		if is_instance_valid(b.node):
			b.node.position = Vector3(b.pos.x, R, b.pos.y)
	if not any:
		moving = false
		var reds := balls.filter(func(x): return x.live and not x.cue)
		if reds.is_empty():
			racks += 1
			add_points(3)
			Juice.sfx("chime")
			_rack()


func _respawn_cue() -> void:
	# re-spot the cue ball behind the head string
	_add(Vector2(-TW * 0.6, 0), true, Color.WHITE)
