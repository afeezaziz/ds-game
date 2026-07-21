extends MechDemo3D
## CITY BUILDER 3D — zone a growing city in 3D. Pick a build type, tap a grid
## cell to place it; houses raise pop cap, farms feed, shops earn. Balance food
## vs population. Drag empties to orbit the camera. Endless; score = peak pop.

const N := 10
const CELL := 3.0
const TYPES := ["HOUSE", "FARM", "SHOP"]
const TCOST := [30, 40, 55]
const TCOL := [Color(0.5, 0.7, 0.95), Color(0.5, 0.8, 0.4), Color(0.9, 0.75, 0.35)]

var grid := {}          # Vector2i -> type index
var sel := 0
var coins := 80.0
var pop := 3.0
var peak := 3
var food := 20.0
var cam_yaw := 0.6
var _press := Vector2.ZERO
var _dragged := 0.0
var hud: Label3D
var buttons: Array = []


func start() -> void:
	super.start()
	setup_world(Color(0.5, 0.65, 0.8), 0.95, Vector3(-60, -30, 0))
	static_box(Vector3(N * CELL + 4, 1, N * CELL + 4), Vector3(0, -0.5, 0), Color(0.35, 0.5, 0.35))
	for x in N:
		for z in N:
			mesh_box(Vector3(CELL - 0.2, 0.1, CELL - 0.2), _cell_world(Vector2i(x, z)) + Vector3(0, 0.05, 0), Color(1, 1, 1, 0.06))
	grid = {}
	sel = 0
	coins = 80.0
	pop = 3.0
	peak = 3
	food = 20.0
	cam_yaw = 0.6
	make_camera(Vector3(0, 26, 26), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 12, 0), 40, Color.WHITE)
	_build_ui()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	for i in 3:
		var b := Button.new()
		b.text = "%s $%d" % [TYPES[i], TCOST[i]]
		b.add_theme_font_size_override("font_size", 26)
		b.custom_minimum_size = Vector2(210, 90)
		b.position = Vector2(30 + i * 225, 1150)
		b.pressed.connect(func(): sel = i)
		layer.add_child(b)
		buttons.append(b)


func _cell_world(c: Vector2i) -> Vector3:
	return Vector3((c.x - N * 0.5 + 0.5) * CELL, 0, (c.y - N * 0.5 + 0.5) * CELL)


func _ground_cell(sp: Vector2) -> Vector2i:
	var from := cam.project_ray_origin(sp)
	var dir := cam.project_ray_normal(sp)
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)
	if hit == null:
		return Vector2i(-1, -1)
	var cx := int(round((hit.x / CELL) + N * 0.5 - 0.5))
	var cz := int(round((hit.z / CELL) + N * 0.5 - 0.5))
	if cx < 0 or cx >= N or cz < 0 or cz >= N:
		return Vector2i(-1, -1)
	return Vector2i(cx, cz)


func _count(ti: int) -> int:
	var n := 0
	for v in grid.values():
		if v == ti:
			n += 1
	return n


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_press = event.position
			_dragged = 0.0
		elif _dragged < 18.0:
			var c := _ground_cell(event.position)
			if c != Vector2i(-1, -1) and not grid.has(c) and coins >= TCOST[sel]:
				coins -= TCOST[sel]
				grid[c] = sel
				var h := [2.5, 1.0, 1.8][sel]
				mesh_box(Vector3(CELL - 0.6, h, CELL - 0.6), _cell_world(c) + Vector3(0, h * 0.5, 0), TCOL[sel])
				Juice.sfx("coin")
	elif event is InputEventScreenDrag:
		_dragged += event.relative.length()
		cam_yaw += event.relative.x * 0.005


func _process(delta: float) -> void:
	if not running:
		return
	var cap := _count(0) * 4
	food += (_count(1) * 4.0 - pop) * delta
	coins += _count(2) * min(pop, _count(2) * 3.0) * 0.12 * delta
	if food > 5.0 and pop < cap:
		pop += 0.5 * delta
	elif food < 0.0:
		pop = maxf(0.0, pop - 0.7 * delta)
		food = 0.0
	peak = maxi(peak, int(pop))
	set_score(peak)

	var r := 34.0
	cam.position = Vector3(sin(cam_yaw) * r, 26, cos(cam_yaw) * r)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	hud.text = "POP %d/%d   FOOD %d   COINS %d   [%s]" % [int(pop), _count(0) * 4, int(food), int(coins), TYPES[sel]]
	hud.position = Vector3(0, 12, 0)
