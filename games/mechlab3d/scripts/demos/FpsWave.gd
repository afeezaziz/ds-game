extends MechDemo3D
## ZOMBIE FPS — first-person wave shooter. Drag to look; the crosshair is
## fixed center; TAP (no drag) to fire at whatever's centered. Zombies close
## in; let one reach you and lose a heart. Score = kills. Desktop: drag look,
## click fire.

var yaw := 0.0
var hp := 5
var zombies: Array = []   # {ang, dist, node, dead}
var spawn_t := 0.0
var inv := 0.0
var _dragged := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.08, 0.09, 0.12), 0.7, Vector3(-60, 20, 0))
	static_box(Vector3(80, 1, 80), Vector3(0, -0.5, 0), Color(0.18, 0.2, 0.18))
	yaw = 0.0
	hp = 5
	inv = 0.0
	zombies.clear()
	spawn_t = 0.6
	make_camera(Vector3(0, 1.6, 0), Vector3(0, 1.6, 1))


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_dragged = 0.0
		elif _dragged < 16.0:
			_fire()
	elif event is InputEventScreenDrag:
		_dragged += event.relative.length()
		yaw -= event.relative.x * 0.006


func _fire() -> void:
	Juice.sfx("thud")
	Juice.flash(Color(1, 1, 0.8), 0.08)
	var best = null
	var bestdot := 0.985
	var fwd := Vector2(sin(yaw), cos(yaw))
	for z in zombies:
		if z.dead:
			continue
		var zdir := Vector2(sin(z.ang), cos(z.ang))
		var dot := fwd.dot(zdir)
		if dot > bestdot:
			bestdot = dot
			best = z
	if best:
		best.dead = true
		best.node.queue_free()
		add_points(1)
		Juice.haptic(15)


func _process(delta: float) -> void:
	if not running:
		return
	inv -= delta
	cam.rotation.y = yaw

	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(0.5, 1.6 - score * 0.02)
		var ang := randf() * TAU
		var node := mesh_box(Vector3(0.9, 1.7, 0.9), Vector3.ZERO, Color(0.35, 0.6, 0.35))
		zombies.append({"ang": ang, "dist": 26.0, "node": node, "dead": false})

	for z in zombies.duplicate():
		if z.dead:
			zombies.erase(z)
			continue
		z.dist -= 2.6 * delta
		z.node.position = Vector3(sin(z.ang) * z.dist, 0.85, cos(z.ang) * z.dist)
		if z.dist < 1.2:
			z.node.queue_free()
			zombies.erase(z)
			if inv <= 0.0:
				hp -= 1
				inv = 0.6
				Juice.flash(Color(1, 0.2, 0.2), 0.3)
				Juice.haptic(50)
				if hp <= 0:
					end_demo()
					return
