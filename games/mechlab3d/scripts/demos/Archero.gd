extends MechDemo3D
## ARCHERO — stop-to-shoot roguelite. Drag to move; the moment you STAND
## STILL, you auto-fire at the nearest enemy. Enemies chase; touching you
## costs a heart. Score = kills. Desktop: WASD move. (2019 breakout hit.)

var player: MeshInstance3D
var ppos := Vector2.ZERO
var hp := 3
var inv := 0.0
var tc: TouchControls
var enemies: Array = []
var arrows: Array = []
var fire_t := 0.0
var spawn_t := 0.0
var still_t := 0.0
const ARENA := 13.0


func start() -> void:
	super.start()
	setup_world(Color(0.12, 0.14, 0.18), 0.9, Vector3(-70, -30, 0))
	static_box(Vector3(ARENA * 2, 1, ARENA * 2), Vector3(0, -0.5, 0), Color(0.25, 0.27, 0.32))
	player = mesh_box(Vector3(0.9, 1.5, 0.9), Vector3(0, 0.75, 0), Color(0.4, 0.9, 1.0))
	ppos = Vector2.ZERO
	hp = 3
	inv = 0.0
	enemies.clear()
	arrows.clear()
	fire_t = 0.0
	spawn_t = 0.4
	still_t = 0.0
	make_camera(Vector3(0, 18, 15), Vector3(0, 0, 0), 55.0)
	tc = add_touch_controls([])   # move-only: standing still auto-fires


func _process(delta: float) -> void:
	if not running:
		return
	inv -= delta
	var mv := tc.move + Vector2(key_axis_x(), -key_axis_y())
	mv = mv.limit_length(1.0)
	ppos += mv * 8.0 * delta
	ppos.x = clampf(ppos.x, -ARENA + 1, ARENA - 1)
	ppos.y = clampf(ppos.y, -ARENA + 1, ARENA - 1)
	player.position = Vector3(ppos.x, 0.75, ppos.y)

	# stand still -> auto fire
	if mv.length() < 0.1:
		still_t += delta
		fire_t -= delta
		if still_t > 0.15 and fire_t <= 0.0 and not enemies.is_empty():
			fire_t = 0.4
			var tgt = _nearest()
			if tgt:
				var dir: Vector2 = (tgt.pos - ppos).normalized()
				arrows.append({"pos": ppos, "dir": dir,
					"node": mesh_box(Vector3(0.2, 0.2, 0.6), Vector3(ppos.x, 0.9, ppos.y), Color(1, 0.9, 0.4))})
	else:
		still_t = 0.0

	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(0.5, 1.6 - score * 0.02)
		var edge := randf() * TAU
		var p := Vector2(cos(edge), sin(edge)) * ARENA
		enemies.append({"pos": p, "hp": 1 + score / 10,
			"node": mesh_box(Vector3(0.9, 1.3, 0.9), Vector3(p.x, 0.65, p.y), Color(0.85, 0.3, 0.3))})

	for e in enemies:
		e.pos += (ppos - e.pos).normalized() * 3.2 * delta
		e.node.position = Vector3(e.pos.x, 0.65, e.pos.y)
		if inv <= 0.0 and e.pos.distance_to(ppos) < 1.1:
			hp -= 1
			inv = 1.0
			Juice.flash(Color(1, 0.3, 0.3), 0.25)
			Juice.haptic(40)
			if hp <= 0:
				end_demo()
				return

	for a in arrows.duplicate():
		a.pos += a.dir * 16.0 * delta
		a.node.position = Vector3(a.pos.x, 0.9, a.pos.y)
		if a.pos.length() > ARENA + 3.0:
			a.node.queue_free()
			arrows.erase(a)
			continue
		for e in enemies.duplicate():
			if a.pos.distance_to(e.pos) < 0.9:
				a.node.queue_free()
				arrows.erase(a)
				e.hp -= 1
				if e.hp <= 0:
					e.node.queue_free()
					enemies.erase(e)
					add_points(1)
					Juice.sfx("thud")
				break


func _nearest():
	var best = null
	var bd := 9999.0
	for e in enemies:
		var d: float = e.pos.distance_to(ppos)
		if d < bd:
			bd = d
			best = e
	return best
