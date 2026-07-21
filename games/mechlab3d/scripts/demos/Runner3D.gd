extends MechDemo3D
## SUBWAY RUN — 3-lane endless runner. Auto-forward; swipe L/R to change
## lane, swipe up to jump. Desktop: A/D lanes, Space jump. Dodge blocks,
## grab coins, hit a block = over. Score = distance + coins.

const LANES := [-2.4, 0.0, 2.4]

var player: MeshInstance3D
var lane := 1
var pz := 0.0
var py := 0.0
var vy := 0.0
var speed := 13.0
var coins_got := 0
var items: Array = []   # {z, lane, node, coin, dead}
var next_z := 24.0
var _ts := Vector2.ZERO


func start() -> void:
	super.start()
	setup_world(Color(0.45, 0.6, 0.85))
	static_box(Vector3(14, 1, 400), Vector3(0, -0.5, 190), Color(0.3, 0.32, 0.36))
	for lx in LANES:
		mesh_box(Vector3(0.1, 0.02, 400), Vector3(lx + 1.2, 0.01, 190), Color(1, 1, 1, 0.15))
	player = mesh_box(Vector3(0.9, 1.4, 0.9), Vector3(0, 0.7, 0), Color(0.95, 0.85, 0.4))
	make_camera(Vector3(0, 5.5, -9.5), Vector3(0, 1.5, 6))
	lane = 1
	pz = 0.0
	py = 0.0
	vy = 0.0
	speed = 13.0
	coins_got = 0
	next_z = 24.0


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT:
			lane = maxi(0, lane - 1)
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT:
			lane = mini(2, lane + 1)
		elif event.keycode == KEY_SPACE or event.keycode == KEY_W or event.keycode == KEY_UP:
			_jump()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_ts = event.position
		else:
			var d: Vector2 = event.position - _ts
			if d.length() < 30.0:
				return
			if absf(d.x) > absf(d.y):
				lane = clampi(lane + signi(int(d.x)), 0, 2)
			elif d.y < 0.0:
				_jump()


func _jump() -> void:
	if py <= 0.01:
		vy = 9.5


func _process(delta: float) -> void:
	if not running:
		return
	speed = minf(26.0, speed + delta * 0.4)
	pz += speed * delta
	set_score(int(pz) + coins_got * 5)

	vy -= 26.0 * delta
	py = maxf(0.0, py + vy * delta)
	if py <= 0.0:
		vy = 0.0

	var tx: float = LANES[lane]
	player.position.x = lerpf(player.position.x, tx, 12.0 * delta)
	player.position.y = 0.7 + py
	player.position.z = pz

	cam.position = Vector3(player.position.x * 0.4, 5.5, pz - 9.5)
	cam.look_at(Vector3(0, 1.5, pz + 6), Vector3.UP)

	while next_z < pz + 90.0:
		_spawn_row(next_z)
		next_z += randf_range(9.0, 14.0)

	for it in items.duplicate():
		if it.dead:
			continue
		var dz: float = it.z - pz
		if dz < -4.0:
			it.node.queue_free()
			items.erase(it)
			continue
		if absf(dz) < 1.0 and it.lane == lane:
			if it.coin:
				if not it.dead and py < 1.6:
					it.dead = true
					it.node.queue_free()
					coins_got += 1
					Juice.sfx("coin")
			elif py < 1.3:
				Juice.haptic(50)
				end_demo()
				return


func _spawn_row(z: float) -> void:
	var block_lanes := {}
	var n := 1 + (randi() % 2)
	for i in n:
		block_lanes[randi() % 3] = true
	for li in block_lanes.keys():
		var node := mesh_box(Vector3(1.8, 1.8, 1.2), Vector3(LANES[li], 0.9, z), Color(0.85, 0.3, 0.3))
		items.append({"z": z, "lane": li, "node": node, "coin": false, "dead": false})
	for li in 3:
		if not block_lanes.has(li) and randf() < 0.5:
			var c := mesh_sphere(0.35, Vector3(LANES[li], 1.0, z), Color(1, 0.85, 0.2))
			items.append({"z": z, "lane": li, "node": c, "coin": true, "dead": false})
