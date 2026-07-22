extends MechDemo3D
## GRAPPLE SWING — Spider-Man traversal across a city of towers. A fully
## SCRIPTED pendulum: gravity plus a rope-length constraint strips the radial
## velocity so motion goes tangential — you arc, build momentum, fling free on
## release. GRAPPLE (hold=reel/swing, release=let go) · BOOST · stick=air steer.

const GRAV := 24.0
const RANGE := 34.0
const REEL := 6.0
const MIN_ROPE := 6.0
const STEER := 10.0
const BOOST_KICK := 13.0
const STREET := 4.0
const CHUNK := 26.0

var tc: TouchControls
var hud: Label
var mech: MeshInstance3D
var rope: MeshInstance3D
var ppos := Vector3(0, 42, 0)
var vel := Vector3(0, 0, -16)
var attached := false
var anchor := Vector3.ZERO
var rope_len := 0.0
var boost := 3
var lives := 2
var rings_passed := 0
var next_z := -30.0
var last_safe := Vector3(0, 42, 0)
var anchors: Array = []
var towers: Array = []
var rings: Array = []
var _shake := 0.0

func start() -> void:
	super.start()
	setup_world(Color(0.55, 0.68, 0.85), 0.9)
	mesh_box(Vector3(400, 1, 800), Vector3(0, 0, -300), Color(0.24, 0.25, 0.3))
	make_camera(Vector3(0, 48, 14), ppos, 62.0)
	tc = add_touch_controls([
		{"id": "grapple", "label": "GRAPPLE", "col": Color(0.6, 0.8, 0.95)},
		{"id": "boost", "label": "BOOST", "col": Color(1.0, 0.7, 0.3)},
	])
	tc.action.connect(func(id):
		if id == "grapple": _grapple_press()
		elif id == "boost": _boost())
	tc.released.connect(func(id):
		if id == "grapple": _grapple_release())
	mech = mesh_box(Vector3(1.0, 1.6, 1.0), ppos, Color(0.9, 0.3, 0.35))
	mesh_box(Vector3(0.5, 0.5, 0.6), Vector3(0, 0.9, -0.4), Color(0.2, 0.35, 0.9), mech)
	rope = mesh_box(Vector3(0.12, 0.12, 1.0), Vector3.ZERO, Color(0.12, 0.12, 0.16))
	rope.visible = false
	var cl := CanvasLayer.new()
	cl.layer = 2
	add_child(cl)
	hud = Label.new()
	hud.position = Vector2(26, 150)
	hud.add_theme_font_size_override("font_size", 30)
	hud.add_theme_color_override("font_color", Color(0.08, 0.12, 0.18))
	cl.add_child(hud)
	demo_over.connect(func(_s): cl.visible = false)
	for i in 6:
		_spawn_chunk()

func _spawn_chunk() -> void:
	var z := next_z
	for side in [-1.0, 1.0]:
		var h := randf_range(22.0, 50.0)
		var w := randf_range(5.0, 8.0)
		_tower(Vector3(side * randf_range(6.0, 13.0), h * 0.5, z + randf_range(-5.0, 5.0)), Vector3(w, h, w))
	if randf() < 0.6:
		var h2 := randf_range(30.0, 46.0)
		_tower(Vector3(randf_range(-4.0, 4.0), h2 * 0.5, z - 11.0), Vector3(6.0, h2, 6.0))
	_make_ring(Vector3(randf_range(-5.0, 5.0), randf_range(28.0, 40.0), z - CHUNK * 0.5))
	next_z -= CHUNK

func _tower(pos: Vector3, size: Vector3) -> void:
	var body := static_box(size, pos, Color.from_hsv(0.6, 0.13, randf_range(0.5, 0.78)))
	towers.append({"node": body, "z": pos.z})
	var top := pos.y + size.y * 0.5
	for c in [Vector3(size.x * 0.5, 0, size.z * 0.5), Vector3(-size.x * 0.5, 0, -size.z * 0.5)]:
		var ap := Vector3(pos.x + c.x, top, pos.z + c.z)
		anchors.append({"pos": ap, "node": mesh_sphere(0.6, ap, Color(0.5, 0.92, 1.0)), "z": ap.z})

func _make_ring(pos: Vector3) -> void:
	var holder := Node3D.new()
	holder.position = pos
	add_child(holder)
	for i in 12:
		var a := TAU * i / 12.0
		mesh_box(Vector3(0.6, 0.6, 0.6), Vector3(cos(a) * 4.0, sin(a) * 4.0, 0), Color(1.0, 0.85, 0.3), holder)
	rings.append({"pos": pos, "node": holder, "passed": false, "r": 4.0, "z": pos.z})

func _process(delta: float) -> void:
	if not running: return
	vel.x += (tc.move.x + key_axis_x()) * STEER * delta
	if attached and (tc.held("grapple") or Input.is_key_pressed(KEY_SPACE)):
		rope_len = maxf(MIN_ROPE, rope_len - REEL * delta)
	vel.y -= GRAV * delta
	ppos += vel * delta
	if attached:
		_rope_constraint()
	mech.position = ppos
	var flat := Vector3(vel.x, 0, vel.z)
	if flat.length() > 0.5:
		mech.look_at(ppos + flat.normalized(), Vector3.UP)
	_update_rope()
	_check_rings()
	_spawn_cleanup()
	if ppos.y < STREET and not attached:
		_splat()
	_update_cam(delta)
	hud.text = "SPEED %d   RINGS %d\n%s   BOOST %d   LIVES %d" % [int(vel.length()),
		rings_passed, ("ATTACHED" if attached else "FREE-FLY"), boost, lives + 1]

func _rope_constraint() -> void:
	# scripted pendulum: clamp onto the rope sphere, then kill outward radial velocity
	var to_p := ppos - anchor
	var d := to_p.length()
	if d < 0.01 or d <= rope_len:
		return
	var n := to_p / d
	ppos = anchor + n * rope_len
	var radial := vel.dot(n)
	if radial > 0.0:
		vel -= n * radial

func _update_rope() -> void:
	rope.visible = attached
	if not attached:
		return
	var hand := ppos + Vector3(0, 0.6, 0)
	rope.position = (hand + anchor) * 0.5
	var dir := (anchor - rope.position).normalized()
	rope.look_at(anchor, Vector3.FORWARD if absf(dir.dot(Vector3.UP)) > 0.99 else Vector3.UP)
	rope.scale = Vector3(1, 1, hand.distance_to(anchor))

func _check_rings() -> void:
	for ring in rings:
		if ring["passed"] or ppos.z > ring["pos"].z:
			continue
		ring["passed"] = true
		if Vector2(ppos.x - ring["pos"].x, ppos.y - ring["pos"].y).length() >= ring["r"]:
			continue
		rings_passed += 1
		add_points(5)
		last_safe = ring["pos"] + Vector3(0, 6, 0)
		boost = mini(3, boost + 1)
		sfx("chime")
		flash(Color(0.5, 0.9, 1.0), 0.18)
		popup("RING %d" % rings_passed, Color(1.0, 0.9, 0.4))
		haptic(15)

func _spawn_cleanup() -> void:
	while next_z > ppos.z - 160.0:
		_spawn_chunk()
	var behind := ppos.z + 60.0
	_cull(towers, behind)
	_cull(anchors, behind)
	_cull(rings, behind)

func _cull(arr: Array, behind: float) -> void:
	for i in range(arr.size() - 1, -1, -1):
		if arr[i]["z"] > behind:
			if is_instance_valid(arr[i]["node"]): arr[i]["node"].queue_free()
			arr.remove_at(i)

func _grapple_press() -> void:
	if not running: return
	var best := RANGE + 0.01
	var ok := false
	for a in anchors:
		var ap: Vector3 = a["pos"]
		if ap.y < ppos.y - 3.0 or ap.z > ppos.z + 3.0:
			continue
		var d := ppos.distance_to(ap)
		if d < best:
			best = d
			anchor = ap
			ok = true
	if not ok:
		haptic(4)
		return
	attached = true
	rope_len = ppos.distance_to(anchor)
	sfx("tick")
	haptic(10)
	flash(Color(0.6, 0.8, 0.95), 0.1)

func _grapple_release() -> void:
	if not attached: return
	attached = false
	rope.visible = false
	sfx("thud")
	haptic(6)

func _boost() -> void:
	if not running or boost <= 0: return
	boost -= 1
	vel += Vector3(0, 4.0, -BOOST_KICK)
	sfx("coin")
	flash(Color(1.0, 0.7, 0.3), 0.15)
	popup("BOOST", Color(1.0, 0.8, 0.4))
	haptic(18)

func _splat() -> void:
	sfx("boom")
	flash(Color(0.9, 0.2, 0.2), 0.35)
	shake2d(14.0)
	haptic(40)
	if lives > 0:
		lives -= 1
		popup("SPLAT — %d LEFT" % (lives + 1), Color(1.0, 0.4, 0.4))
		ppos = last_safe
		vel = Vector3(0, 2.0, -12.0)
		attached = false
	else:
		popup("SPLAT!", Color(1.0, 0.3, 0.3))
		end_demo()

func _update_cam(delta: float) -> void:
	cam.position = cam.position.lerp(ppos + Vector3(0, 6.0, 14.0), clampf(delta * 4.0, 0.0, 1.0))
	if _shake > 0.01:
		cam.position += Vector3(randf_range(-_shake, _shake), randf_range(-_shake, _shake), 0)
		_shake = maxf(0.0, _shake - delta * 20.0)
	cam.look_at(ppos + Vector3(vel.x, 0, vel.z).limit_length(6.0), Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if not running: return
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_SPACE:
			if event.pressed: _grapple_press()
			else: _grapple_release()
		elif event.keycode == KEY_SHIFT and event.pressed:
			_boost()

# juice wrappers: adapt the task vocab to the shared Juice autoload
func sfx(n: String) -> void: Juice.sfx(n)
func flash(col: Color, dur := 0.2) -> void: Juice.flash(col, dur)
func popup(text: String, col := Color(1, 0.9, 0.4)) -> void: Juice.popup(text, Vector2(W * 0.5, H * 0.4), col)
func haptic(ms := 20) -> void: Juice.haptic(ms)
func shake2d(amt := 6.0) -> void: _shake = maxf(_shake, amt * 0.12)
