extends MechDemo3D
## SLICE MASTER — fruit flies up in arcs; swipe to slice. Slice a BOMB (dark)
## and it's over. Score = fruit sliced. (Fruit Ninja, in 3D.) Desktop: drag
## the mouse across fruit.

var fruit: Array = []   # {pos, vel, node, bomb, dead}
var spawn_t := 0.0
var last_swipe := Vector2.ZERO
var swiping := false


func start() -> void:
	super.start()
	setup_world(Color(0.1, 0.12, 0.18), 0.95)
	fruit.clear()
	spawn_t = 0.4
	swiping = false
	make_camera(Vector3(0, 4, 12), Vector3(0, 4, 0), 60.0)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		swiping = event.pressed
		last_swipe = event.position
	elif event is InputEventScreenDrag:
		_slice_at(event.position)
		last_swipe = event.position


func _slice_at(sp: Vector2) -> void:
	for fr in fruit.duplicate():
		if fr.dead:
			continue
		var screen := cam.unproject_position(fr.node.position)
		if screen.distance_to(sp) < 70.0:
			if fr.bomb:
				fr.dead = true
				Juice.flash(Color(1, 0.3, 0.2), 0.35)
				Juice.haptic(60)
				end_demo()
				return
			fr.dead = true
			fr.node.queue_free()
			add_points(1)
			Juice.sfx("chime", 1.0 + randf() * 0.3)


func _process(delta: float) -> void:
	if not running:
		return
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(0.45, 1.1 - score * 0.01)
		var bomb := randf() < 0.16
		var px := randf_range(-5.0, 5.0)
		var node := mesh_sphere(0.6, Vector3(px, 0.0, 0.0),
			Color(0.12, 0.12, 0.14) if bomb else hue_col(randf() * 8.0, 0.6, 0.95))
		fruit.append({"pos": Vector3(px, 0, 0),
			"vel": Vector3(randf_range(-1.5, 1.5), randf_range(11.0, 14.0), 0),
			"node": node, "bomb": bomb, "dead": false})

	for fr in fruit.duplicate():
		if fr.dead:
			if is_instance_valid(fr.node):
				fr.node.queue_free()
			fruit.erase(fr)
			continue
		fr.vel.y -= 15.0 * delta
		fr.pos += fr.vel * delta
		fr.node.position = fr.pos
		fr.node.rotate_x(delta * 3.0)
		if fr.pos.y < -3.0:
			fr.node.queue_free()
			fruit.erase(fr)
