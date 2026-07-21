extends MechDemo3D
## STACK SMASH — a ball drops down a tower of platforms. Every platform has a
## black DANGER arc. Rotate so the safe part is under the ball, then TAP to
## smash through. Tap while black is under you = over. Score = platforms
## smashed. Desktop: A/D rotate, Space smash.

const RING_R := 3.0
const SEG := 18
const RING_GAP_Y := 2.4
const DANGER := 5   # segments of black danger per ring

var pivot: Node3D
var rings: Array = []   # {y, danger:Array[int], nodes:Array}
var ball: MeshInstance3D
var ball_y := 1.0
var cur := 0
var rot := 0.0
var speed := 3.0


func start() -> void:
	super.start()
	setup_world(Color(0.12, 0.1, 0.16), 0.9)
	pivot = Node3D.new()
	add_child(pivot)
	mesh_cyl(0.5, 300.0, Vector3(0, -140, 0), Color(0.35, 0.3, 0.45), pivot)
	rings.clear()
	for i in 50:
		_build_ring(i)
	ball = mesh_sphere(0.55, Vector3(0, 1.0, RING_R), Color(0.4, 0.9, 1.0))
	ball_y = 1.0
	cur = 0
	rot = 0.0
	speed = 3.0
	make_camera(Vector3(0, 1.0, 8.5), Vector3(0, -0.5, 0))


func _build_ring(i: int) -> void:
	var y := -float(i) * RING_GAP_Y
	var d0 := randi() % SEG
	var danger := []
	for k in DANGER:
		danger.append((d0 + k) % SEG)
	var nodes := []
	for s in SEG:
		var ang := float(s) / float(SEG) * TAU
		var is_d := danger.has(s)
		var seg := mesh_box(Vector3(1.0, 0.45, 0.85),
			Vector3(sin(ang) * RING_R, y, cos(ang) * RING_R),
			Color(0.1, 0.1, 0.12) if is_d else hue_col(i, 0.55, 0.9), pivot)
		seg.rotation.y = ang
		nodes.append(seg)
	rings.append({"y": y, "danger": danger, "nodes": nodes})


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenDrag:
		rot -= event.relative.x * 0.006
	elif event is InputEventScreenTouch and event.pressed:
		_smash()
	elif event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		_smash()


func _smash() -> void:
	if cur >= rings.size():
		return
	var ring: Dictionary = rings[cur]
	if ring.danger.has(_seg_under_ball()):
		Juice.haptic(50)
		end_demo()
		return
	for n in ring.nodes:
		if is_instance_valid(n):
			n.queue_free()
	cur += 1
	add_points(1)
	speed = minf(9.0, speed + 0.06)
	Juice.sfx("thud")


func _process(delta: float) -> void:
	if not running:
		return
	rot += key_axis_x() * 2.5 * delta
	pivot.rotation.y = rot
	if cur >= rings.size():
		end_demo()
		return
	var floor_y: float = rings[cur].y + 0.6
	ball_y = maxf(floor_y, ball_y - speed * delta)
	ball.position.y = ball_y
	cam.position = Vector3(0, ball_y + 1.0, 8.5)
	cam.look_at(Vector3(0, ball_y - 1.0, 0), Vector3.UP)


func _seg_under_ball() -> int:
	return int(round(fposmod(-rot, TAU) / TAU * SEG)) % SEG
