extends MechDemo3D
## HELIX DROP — a ball bounces down a spiral tower. Drag left/right to rotate
## the whole tower; line the GAP up under the ball and it falls to the next
## ring. Land on a RED sector = over. Score = rings passed. (2018 hyper-casual
## icon.) Desktop: A/D or drag to rotate.

const RING_R := 3.2
const SEG := 20
const RING_GAP_Y := 3.0

var pivot: Node3D
var rings: Array = []   # {y, gap0, gap_size, reds:Array[int]}
var ball: MeshInstance3D
var ball_y := 0.0
var vy := 0.0
var cur := 0
var rot := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.1, 0.12, 0.2), 0.9)
	pivot = Node3D.new()
	add_child(pivot)
	mesh_cyl(0.6, 400.0, Vector3(0, -190, 0), Color(0.3, 0.3, 0.4), pivot)
	rings.clear()
	for i in 40:
		_build_ring(i)
	ball = mesh_sphere(0.5, Vector3(0, 2.0, RING_R), Color(1, 0.9, 0.35))
	ball_y = 2.0
	vy = 0.0
	cur = 0
	rot = 0.0
	make_camera(Vector3(0, 2.0, 9.0), Vector3(0, 0, 0))


func _build_ring(i: int) -> void:
	var y := -float(i) * RING_GAP_Y
	var gap0 := randi() % SEG
	var gap_size := 3 + (i / 8)
	var reds := []
	if i > 2:
		for r in (i / 10 + 1):
			var s := randi() % SEG
			if abs(s - gap0) > gap_size:
				reds.append(s)
	for s in SEG:
		if s >= gap0 and s < gap0 + gap_size:
			continue
		var ang := float(s) / float(SEG) * TAU  # measured as atan2(x,z); 0 = +Z (ball side)
		var is_red := reds.has(s)
		var seg := mesh_box(Vector3(1.05, 0.5, 0.9),
			Vector3(sin(ang) * RING_R, y, cos(ang) * RING_R),
			Color(0.85, 0.25, 0.3) if is_red else hue_col(i, 0.5, 0.85), pivot)
		seg.rotation.y = ang
	rings.append({"y": y, "gap0": gap0, "gap_size": gap_size, "reds": reds})


func _unhandled_input(event: InputEvent) -> void:
	if running and event is InputEventScreenDrag:
		rot -= event.relative.x * 0.006


func _process(delta: float) -> void:
	if not running:
		return
	rot += key_axis_x() * 2.5 * delta
	pivot.rotation.y = rot

	vy -= 20.0 * delta
	ball_y += vy * delta

	if cur < rings.size():
		var ring: Dictionary = rings[cur]
		if ball_y <= ring.y + 0.7 and vy < 0.0:
			var seg_i := _seg_under_ball()
			if seg_i >= ring.gap0 and seg_i < ring.gap0 + ring.gap_size:
				cur += 1
				add_points(1)
				Juice.sfx("tick")
			elif ring.reds.has(seg_i):
				ball_y = ring.y + 0.7
				Juice.haptic(50)
				end_demo()
				return
			else:
				ball_y = ring.y + 0.7
				vy = 9.5
				Juice.sfx("thud")
	else:
		end_demo()
		return

	ball.position.y = ball_y
	cam.position = Vector3(0, ball_y + 2.0, 9.0)
	cam.look_at(Vector3(0, ball_y - 0.5, 0), Vector3.UP)


func _seg_under_ball() -> int:
	# Ball sits at world angle 0 (+Z front). Local seg = (0 - rot) mapped to [0,SEG).
	var local := fposmod(-rot, TAU)
	return int(round(local / TAU * SEG)) % SEG
