extends MechDemo3D
## DOGFIGHT — 3D air combat (Ace Combat-lite). Your plane flies forward; drag to
## steer pitch/yaw, FIRE to shoot. Down enemy planes, dodge their fire. Score =
## kills. HP 0 = over. Desktop: WASD steer, click fire.

var plane: Node3D
var yaw := 0.0
var pitch := 0.0
var ppos := Vector3(0, 20, 0)
var speed := 22.0
var hp := 100.0
var fire_cd := 0.0
var pbul: Array = []
var ebul: Array = []
var foes: Array = []
var spawn_t := 0.0
var t := 0.0
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.45, 0.62, 0.9), 1.0, Vector3(-45, -30, 0))
	static_box(Vector3(400, 1, 400), Vector3(0, -2, 0), Color(0.35, 0.5, 0.32))
	plane = Node3D.new()
	add_child(plane)
	mesh_box(Vector3(2.6, 0.3, 1.6), Vector3(0, 0, 0), Color(0.9, 0.9, 0.95), plane)
	mesh_box(Vector3(0.4, 0.6, 1.0), Vector3(0, 0.3, 0.4), Color(0.7, 0.3, 0.3), plane)
	ppos = Vector3(0, 20, 0)
	yaw = 0.0
	pitch = 0.0
	hp = 100.0
	pbul = []
	ebul = []
	foes = []
	spawn_t = 0.5
	t = 0.0
	make_camera(Vector3(0, 22, 12), Vector3.ZERO, 65.0)
	hud = Label3D.new()
	hud.font_size = 40
	hud.position = Vector3(-0.5, -0.4, -1.3)
	hud.modulate = Color(0.9, 1, 0.9)
	cam.add_child(hud)


func _fire() -> void:
	if fire_cd > 0.0:
		return
	fire_cd = 0.18
	var fwd := -plane.global_transform.basis.z
	pbul.append({"pos": ppos + fwd * 2.0, "vel": fwd * 260.0, "life": 2.0})
	Juice.sfx("tick")


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch and event.pressed:
		if Rect2(W - 200, H - 220, 180, 180).has_point(event.position):
			_fire()
	elif event is InputEventScreenDrag:
		yaw -= event.relative.x * 0.004
		pitch = clampf(pitch - event.relative.y * 0.003, -0.9, 0.9)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_fire()


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	fire_cd -= delta
	yaw -= key_axis_x() * 1.0 * delta
	pitch = clampf(pitch + key_axis_y() * 0.8 * delta, -0.9, 0.9)
	plane.rotation = Vector3(pitch, yaw, 0)
	var fwd := -plane.global_transform.basis.z
	ppos += fwd * speed * delta
	ppos.y = clampf(ppos.y, 4, 120)
	plane.position = ppos

	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(1.2, 3.0 - t * 0.02)
		var p := ppos + fwd * 90.0 + Vector3(randf_range(-40, 40), randf_range(-15, 15), 0)
		var node := mesh_box(Vector3(2.4, 0.3, 1.5), p, Color(0.85, 0.4, 0.35))
		foes.append({"node": node, "pos": p, "hp": 3, "fire": randf_range(1, 3)})

	for b in pbul.duplicate():
		b.pos += b.vel * delta
		b.life -= delta
		if b.life <= 0:
			pbul.erase(b)
			continue
		for e in foes.duplicate():
			if b.pos.distance_to(e.pos) < 2.5:
				pbul.erase(b)
				e.hp -= 1
				if e.hp <= 0:
					e.node.queue_free()
					foes.erase(e)
					add_points(1)
					Juice.sfx("boom")
				break

	for e in foes:
		var to: Vector3 = ppos - e.pos
		e.pos += to.normalized() * 14.0 * delta
		e.node.position = e.pos
		e.node.look_at(ppos, Vector3.UP)
		e.fire -= delta
		if e.fire <= 0.0 and to.length() < 80.0:
			e.fire = randf_range(1.5, 3.0)
			ebul.append({"pos": e.pos, "vel": to.normalized() * 90.0, "life": 3.0})

	for b in ebul.duplicate():
		b.pos += b.vel * delta
		b.life -= delta
		if b.life <= 0:
			ebul.erase(b)
			continue
		if b.pos.distance_to(ppos) < 2.5:
			ebul.erase(b)
			hp -= 12.0
			Juice.flash(Color(1, 0.3, 0.3), 0.25)
			Juice.haptic(25)
			if hp <= 0.0:
				end_demo()
				return

	cam.position = ppos - fwd * 12.0 + plane.global_transform.basis.y * 4.0
	cam.look_at(ppos + fwd * 8.0, Vector3.UP)
	hud.text = "HP %d   foes %d" % [int(max(0, hp)), foes.size()]
