extends MechDemo3D
## FACTORY — conveyor automation (Factorio / Satisfactory). The MINER spews ore; lay
## BELTS to carry it, drop a MAKER in the path to smelt ore into plates, and route the
## line into the HUB for cash. Spend the cash on more belts and makers to widen the
## throughput. Endless; score = value delivered. Desktop: drag to orbit; tap to place.

const N := 12
const CELL := 2.6
const DIRS := [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const DNAME := ["N", "E", "S", "W"]

var grid := {}                # Vector2i -> {kind, dir}
var items: Array = []         # {cell, type, node, wpos}
var money := 40
var delivered := 0
var sel := 0                  # 0 belt, 1 maker
var bdir := 2                 # placing direction (south = toward hub)
var miner := Vector2i(1, 1)
var hub := Vector2i(N - 2, N - 2)
var mine_t := 0.0
var step_t := 0.0
var cam_yaw := 0.7
var _press := Vector2.ZERO
var _drag := 0.0
var tc: TouchControls
var hud: Label3D
const COST := [3, 12]


func start() -> void:
	super.start()
	setup_world(Color(0.4, 0.45, 0.55), 0.9, Vector3(-60, -30, 0))
	static_box(Vector3(N * CELL + 3, 1, N * CELL + 3), Vector3(_w(Vector2i(0, 0)).x + (N - 1) * CELL * 0.5, -0.5, _w(Vector2i(0, 0)).z + (N - 1) * CELL * 0.5), Color(0.25, 0.27, 0.32))
	grid = {}
	items = []
	money = 40
	delivered = 0
	grid[miner] = {"kind": "miner", "dir": 2}
	grid[hub] = {"kind": "hub", "dir": 0}
	mesh_box(Vector3(CELL, 1.6, CELL), _w(miner) + Vector3(0, 0.8, 0), Color(0.8, 0.6, 0.3))
	mesh_box(Vector3(CELL, 1.6, CELL), _w(hub) + Vector3(0, 0.8, 0), Color(0.4, 0.8, 0.5))
	make_camera(Vector3(0, 30, 30), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(_w(Vector2i(N / 2, N / 2)).x, 16, _w(Vector2i(N / 2, N / 2)).z), 30, Color.WHITE)
	tc = add_touch_controls([
		{"id": "belt", "label": "BELT $3", "col": Color(0.6, 0.65, 0.8)},
		{"id": "maker", "label": "MAKER $12", "col": Color(0.85, 0.6, 0.4)},
		{"id": "rot", "label": "ROTATE", "col": Color(0.7, 0.8, 0.6)},
	], false, false)
	tc.action.connect(func(id):
		if id == "belt": sel = 0
		elif id == "maker": sel = 1
		elif id == "rot": bdir = (bdir + 1) % 4)


func _w(c: Vector2i) -> Vector3:
	return Vector3((c.x - N * 0.5) * CELL, 0, (c.y - N * 0.5) * CELL)


func _ground_cell(sp: Vector2) -> Vector2i:
	var from := cam.project_ray_origin(sp)
	var dir := cam.project_ray_normal(sp)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	if hit == null:
		return Vector2i(-1, -1)
	var cx := int(round(hit.x / CELL + N * 0.5))
	var cz := int(round(hit.z / CELL + N * 0.5))
	if cx < 0 or cx >= N or cz < 0 or cz >= N:
		return Vector2i(-1, -1)
	return Vector2i(cx, cz)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press = event.position
			_drag = 0.0
		elif _drag < 16.0:
			var c := _ground_cell(event.position)
			if c != Vector2i(-1, -1) and not grid.has(c) and money >= COST[sel]:
				money -= COST[sel]
				grid[c] = {"kind": "belt" if sel == 0 else "maker", "dir": bdir}
				var col := Color(0.55, 0.6, 0.78) if sel == 0 else Color(0.85, 0.55, 0.35)
				var node := mesh_box(Vector3(CELL - 0.4, 0.3, CELL - 0.4), _w(c) + Vector3(0, 0.15, 0), col)
				# a little arrow nub showing direction
				var d := DIRS[bdir]
				mesh_box(Vector3(0.5, 0.5, 0.5), _w(c) + Vector3(d.x * CELL * 0.3, 0.5, d.y * CELL * 0.3), Color(1, 1, 1, 0.7), node)
				Juice.sfx("tick")
	elif event is InputEventScreenDrag:
		_drag += event.relative.length()
		cam_yaw += event.relative.x * 0.005


func _process(delta: float) -> void:
	if not running:
		return
	# miner emits ore onto its output cell
	mine_t -= delta
	if mine_t <= 0.0:
		mine_t = 1.1
		var out: Vector2i = miner + DIRS[grid[miner].dir]
		if grid.has(out) and items.filter(func(it): return it.cell == out).is_empty():
			var node := mesh_sphere(0.5, _w(out) + Vector3(0, 0.7, 0), Color(0.7, 0.5, 0.4))
			items.append({"cell": out, "type": 0, "node": node, "wpos": _w(out) + Vector3(0, 0.7, 0)})

	# discrete step: advance items along belts
	step_t -= delta
	if step_t <= 0.0:
		step_t = 0.55
		for it in items.duplicate():
			var g = grid.get(it.cell, null)
			if g == null:
				continue
			var nxt: Vector2i = it.cell + DIRS[g.dir]
			var ng = grid.get(nxt, null)
			if ng == null:
				continue
			if ng.kind == "hub":
				money += 3 if it.type == 0 else 8
				delivered += 1
				add_points(1 if it.type == 0 else 3)
				it.node.queue_free()
				items.erase(it)
				Juice.sfx("coin" if it.type == 1 else "tick")
			elif items.filter(func(x): return x.cell == nxt).is_empty():
				it.cell = nxt
				if ng.kind == "maker" and it.type == 0:
					it.type = 1
					(it.node as MeshInstance3D).queue_free()
					it.node = mesh_box(Vector3(0.8, 0.4, 0.8), _w(nxt) + Vector3(0, 0.7, 0), Color(0.8, 0.85, 0.95))
					Juice.sfx("thud")

	# smooth item visuals toward their cell
	for it in items:
		var target := _w(it.cell) + Vector3(0, 0.7, 0)
		it.node.position = it.node.position.move_toward(target, CELL * 2.0 * delta)

	var r := 34.0
	cam.position = Vector3(sin(cam_yaw) * r, 30, cos(cam_yaw) * r)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	hud.text = "MONEY $%d   delivered %d   [%s facing %s]   (tap to place)" % [
		money, delivered, "BELT" if sel == 0 else "MAKER", DNAME[bdir]]
