extends MechDemo3D
## DUNGEON CRAWLER — first-person, grid-stepped (Legend of Grimrock). Move tile by
## tile and turn in 90° steps through the maze; bump ATTACK to strike the monster on
## the tile ahead. Monsters step when you do — it's a dance. Find the STAIRS to
## descend deeper. Desktop: W step, A/D turn, J attack.

const N := 9
const CELL := 4.0
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

var walls := {}               # Vector2i -> true
var cell := Vector2i(1, 1)
var facing := 0               # 0N 1E 2S 3W
var wpos := Vector3.ZERO
var target_wpos := Vector3.ZERO
var yaw := 0.0
var target_yaw := 0.0
var moving := false
var hp := 30
var maxhp := 30
var floor_no := 1
var monsters: Array = []      # {cell,hp,node}
var stairs := Vector2i(7, 7)
var stairs_node: Node3D
var wall_nodes: Array = []
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.04, 0.05, 0.08), 0.35, Vector3(-60, 20, 0))
	make_camera(Vector3(0, 1.6, 0), Vector3(0, 1.6, -1), 70.0)
	hud = Label3D.new()
	hud.font_size = 34
	hud.position = Vector3(-0.6, -0.42, -1.3)
	hud.modulate = Color(0.8, 1, 0.9)
	cam.add_child(hud)
	tc = add_touch_controls([
		{"id": "fwd", "label": "STEP", "col": Color(0.6, 0.8, 0.7)},
		{"id": "left", "label": "◄ TURN", "col": Color(0.6, 0.65, 0.9)},
		{"id": "right", "label": "TURN ►", "col": Color(0.6, 0.65, 0.9)},
		{"id": "attack", "label": "ATTACK", "col": Color(0.9, 0.5, 0.4)},
	], false, false)
	tc.action.connect(func(id):
		if id == "fwd": _step()
		elif id == "left": _turn(-1)
		elif id == "right": _turn(1)
		elif id == "attack": _attack())
	_gen()


func _gen() -> void:
	for n in wall_nodes: n.queue_free()
	for m in monsters: m.node.queue_free()
	wall_nodes = []
	monsters = []
	walls = {}
	static_box(Vector3(N * CELL, 1, N * CELL), Vector3((N - 1) * CELL * 0.5, -0.5, (N - 1) * CELL * 0.5), Color(0.14, 0.13, 0.16))
	for x in N:
		for z in N:
			var c := Vector2i(x, z)
			var edge := x == 0 or z == 0 or x == N - 1 or z == N - 1
			if edge or (randf() < 0.22 and c != Vector2i(1, 1)):
				walls[c] = true
				var node := mesh_box(Vector3(CELL, 3.2, CELL), _w(c) + Vector3(0, 1.6, 0), hue_col((x + z) * 0.05, 0.25, 0.5))
				wall_nodes.append(node)
	cell = Vector2i(1, 1)
	facing = 1
	wpos = _w(cell)
	target_wpos = wpos
	yaw = facing * PI * 0.5
	target_yaw = yaw
	# stairs on a far floor cell
	stairs = Vector2i(N - 2, N - 2)
	walls.erase(stairs)
	if stairs_node == null:
		stairs_node = mesh_cyl(1.4, 0.4, Vector3.ZERO, Color(1, 0.9, 0.3))
	stairs_node.position = _w(stairs) + Vector3(0, 0.2, 0)
	# monsters on random floor cells
	for i in 2 + floor_no:
		var c := Vector2i(randi_range(2, N - 2), randi_range(2, N - 2))
		if walls.has(c) or c == cell or c == stairs:
			continue
		var node := mesh_box(Vector3(1.8, 2.4, 1.8), _w(c) + Vector3(0, 1.2, 0), Color(0.8, 0.35, 0.4))
		monsters.append({"cell": c, "hp": 4 + floor_no, "node": node})
	hp = maxhp


func _w(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL, 0, c.y * CELL)


func _mon_at(c: Vector2i):
	for m in monsters:
		if m.cell == c:
			return m
	return null


func _step() -> void:
	if moving:
		return
	var nc: Vector2i = cell + DIRS[facing]
	if walls.has(nc) or _mon_at(nc) != null:
		Juice.sfx("thud")
		return
	cell = nc
	target_wpos = _w(cell)
	moving = true
	Juice.sfx("tick")
	_monster_turn()
	if cell == stairs:
		_descend()


func _turn(d: int) -> void:
	if moving:
		return
	facing = (facing + d + 4) % 4
	target_yaw = facing * PI * 0.5
	moving = true
	_monster_turn()


func _attack() -> void:
	if moving:
		return
	var fc: Vector2i = cell + DIRS[facing]
	var m = _mon_at(fc)
	Juice.sfx("thud")
	if m != null:
		m.hp -= 3
		Juice.hitstop(30)
		Juice.haptic(12)
		if m.hp <= 0:
			m.node.queue_free()
			monsters.erase(m)
			add_points(1)
			Juice.sfx("boom")
	_monster_turn()


func _monster_turn() -> void:
	for m in monsters:
		var to := cell - m.cell
		if absf(to.x) + absf(to.y) <= 1:
			hp -= 1 + floor_no / 2
			Juice.flash(Color(0.6, 0.1, 0.1), 0.25)
			Juice.haptic(20)
			if hp <= 0:
				end_demo()
				return
			continue
		# step toward player along the larger axis if free
		var options := []
		if absf(to.x) > absf(to.y):
			options = [Vector2i(signi(to.x), 0), Vector2i(0, signi(to.y))]
		else:
			options = [Vector2i(0, signi(to.y)), Vector2i(signi(to.x), 0)]
		for step in options:
			if step == Vector2i.ZERO:
				continue
			var nc: Vector2i = m.cell + step
			if not walls.has(nc) and _mon_at(nc) == null and nc != cell:
				m.cell = nc
				break


func _descend() -> void:
	floor_no += 1
	maxhp += 4
	add_points(5)
	Juice.sfx("chime")
	Juice.flash(Color(1, 0.95, 0.6), 0.4)
	Juice.popup("DESCEND — floor %d" % floor_no, Vector2(W * 0.5, H * 0.34), Color(1, 0.9, 0.4))
	_gen()


func _process(delta: float) -> void:
	if not running:
		return
	wpos = wpos.move_toward(target_wpos, CELL * 4.0 * delta)
	yaw = lerp_angle(yaw, target_yaw, 10.0 * delta)
	if wpos.distance_to(target_wpos) < 0.05 and absf(angle_difference(yaw, target_yaw)) < 0.02:
		moving = false
	var look := Vector3(sin(yaw), 0, -cos(yaw))
	cam.position = wpos + Vector3(0, 1.6, 0)
	cam.look_at(wpos + Vector3(0, 1.6, 0) + look, Vector3.UP)
	for m in monsters:
		m.node.position = _w(m.cell) + Vector3(0, 1.2, 0)
	if not moving and (Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)):
		_step()
	hud.text = "FLOOR %d   HP %d/%d   foes %d   find the stairs" % [floor_no, maxi(0, hp), maxhp, monsters.size()]


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_A or event.keycode == KEY_LEFT: _turn(-1)
		elif event.keycode == KEY_D or event.keycode == KEY_RIGHT: _turn(1)
		elif event.keycode == KEY_J or event.keycode == KEY_SPACE: _attack()
