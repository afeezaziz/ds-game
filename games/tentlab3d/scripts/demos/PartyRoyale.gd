extends MechDemo3D
## PARTY ROYALE — obstacle-gauntlet knockout (Fall Guys). Sprint the course past
## sweeping bars and gaps, JUMP and DIVE, and cross the finish among the qualifiers —
## the field shrinks each round. Get knocked into a gap and you respawn back a beat.
## Finish out of the qualifying spots and you're out. Desktop: WASD run, SPACE jump, Shift dive.

var runner: Node3D
var pos := Vector3(0, 0, 0)
var vy := 0.0
var grounded := true
var dive_t := 0.0
var checkpoint := Vector3(0, 0, 0)
var bars: Array = []          # {node, z, ang, spd}
var gaps: Array = []          # z ranges with no ground
var rivals: Array = []        # {node, pos, spd, done}
var finished_order := []
var round_no := 1
var qualified := 0
var tc: TouchControls
var hud: Label3D
const FINISH := -90.0
const FIELD := 6


func start() -> void:
	super.start()
	setup_world(Color(0.55, 0.72, 0.95), 0.95, Vector3(-50, -25, 0))
	runner = Node3D.new()
	add_child(runner)
	mesh_box(Vector3(1.2, 1.8, 1.2), Vector3(0, 0.9, 0), Color(0.95, 0.5, 0.6), runner)
	round_no = 1
	make_camera(Vector3(0, 8, 12), Vector3.ZERO, 60.0)
	hud = label3d("", Vector3(0, 6, 0), 32, Color.WHITE)
	tc = add_touch_controls([
		{"id": "jump", "label": "JUMP", "col": Color(0.5, 0.85, 0.7)},
		{"id": "dive", "label": "DIVE", "col": Color(0.9, 0.7, 0.4)},
	])
	tc.action.connect(func(id):
		if id == "jump": _jump()
		elif id == "dive": _dive())
	_build_course()


func _build_course() -> void:
	for b in bars: b.node.queue_free()
	for r in rivals: r.node.queue_free()
	bars = []
	gaps = []
	rivals = []
	finished_order = []
	qualified = 0
	pos = Vector3(0, 0, 4)
	checkpoint = pos
	vy = 0.0
	# ground strips with a couple of gaps
	var z := 0.0
	while z > FINISH - 6:
		var gap := z < -20 and randf() < 0.16
		if gap:
			gaps.append(z)
			z -= 5.0
		else:
			static_box(Vector3(16, 1, 6), Vector3(0, -0.5, z - 3), Color(0.6, 0.75, 0.6) if int(z) % 12 == 0 else Color(0.5, 0.68, 0.55))
			z -= 6.0
	# sweeping bars
	for i in 3 + round_no:
		var bz := -14.0 - i * (70.0 / (3 + round_no))
		var node := mesh_box(Vector3(14, 1.2, 0.8), Vector3(0, 1.0, 0), Color(0.95, 0.4, 0.4))
		node.position = Vector3(0, 1.0, bz)
		bars.append({"node": node, "z": bz, "ang": randf() * TAU, "spd": randf_range(1.5, 2.6) * (1 if i % 2 == 0 else -1)})
	# finish line marker
	static_box(Vector3(18, 0.2, 2), Vector3(0, 0.1, FINISH), Color(1, 0.9, 0.3))
	# rival racers
	for i in FIELD - 1:
		var rn := Node3D.new()
		add_child(rn)
		mesh_box(Vector3(1.2, 1.8, 1.2), Vector3(0, 0.9, 0), hue_col(i * 0.2, 0.5, 0.85), rn)
		var rp := Vector3(randf_range(-6, 6), 0, 2)
		rn.position = rp
		rivals.append({"node": rn, "pos": rp, "spd": randf_range(6.5, 9.0), "done": false})


func _jump() -> void:
	if grounded:
		vy = 12.0
		grounded = false
		Juice.sfx("tick")


func _dive() -> void:
	dive_t = 0.35
	Juice.sfx("thud")


func _over_gap(z: float) -> bool:
	for gz in gaps:
		if z < gz + 1.0 and z > gz - 6.0:
			return true
	return false


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE: _jump()
		elif event.keycode == KEY_SHIFT: _dive()


func _process(delta: float) -> void:
	if not running:
		return
	dive_t = maxf(0.0, dive_t - delta)
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	var spd := 11.0 if dive_t > 0.0 else 8.0
	pos += mv * spd * delta
	pos.x = clampf(pos.x, -8, 8)

	if not grounded:
		vy -= 26.0 * delta
		pos.y += vy * delta
		if pos.y <= 0.0:
			pos.y = 0.0
			grounded = true
	# fall into a gap if grounded over one
	if grounded and _over_gap(pos.z):
		_fall()
	if pos.z <= checkpoint.z - 0.1 and not _over_gap(pos.z) and grounded:
		checkpoint = Vector3(pos.x, 0, pos.z)   # rolling checkpoint as you progress
	runner.position = pos

	# sweeping bars knock you back
	for b in bars:
		b.ang += b.spd * delta
		b.node.rotation.y = b.ang
		if absf(pos.z - b.z) < 1.4:
			# the bar sweeps a rotating line; when it swings across your side, it shoves you back
			var side := sin(b.ang)
			if absf(pos.x) < 7.0 and absf(side) > 0.3:
				pos.z += 14.0 * delta          # knocked back up the course
				Juice.haptic(10)

	# rivals advance toward the finish
	for r in rivals:
		if r.done:
			continue
		r.pos.z -= r.spd * delta
		r.node.position = r.pos
		if r.pos.z <= FINISH:
			r.done = true
			finished_order.append("cpu")
			qualified += 1

	# you cross the finish
	if pos.z <= FINISH:
		var place := qualified + 1
		if place <= (FIELD + 1) / 2:
			round_no += 1
			add_points(1)
			Juice.sfx("chime")
			Juice.flash(Color(0.6, 1, 0.7), 0.3)
			Juice.popup("QUALIFIED! round %d" % round_no, Vector2(W * 0.5, H * 0.34), Color(1, 0.9, 0.4))
			_build_course()
		else:
			end_demo()
			return
	# eliminated if enough rivals finish before you
	if qualified >= (FIELD + 1) / 2 and pos.z > FINISH:
		end_demo()
		return

	cam.position = pos + Vector3(0, 8, 12)
	cam.look_at(pos + Vector3(0, 0, -6), Vector3.UP)
	hud.text = "ROUND %d   %.0fm to finish   qualified %d/%d" % [
		round_no, maxf(0, pos.z - FINISH), qualified, (FIELD + 1) / 2]
	hud.position = pos + Vector3(0, 6, 0)


func _fall() -> void:
	pos = checkpoint + Vector3(0, 0, 2)
	vy = 0.0
	grounded = true
	Juice.sfx("boom")
	Juice.flash(Color(1, 0.4, 0.4), 0.25)
	Juice.haptic(30)
