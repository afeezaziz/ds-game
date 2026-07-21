extends MechDemo3D
## CROWD RUN 3D — steer your crowd forward through math gates (x2 / -N), then
## slam the enemy army. Bigger number wins the clash. Score = crowd banked.
## (Count Masters, in 3D.) Desktop: A/D or drag to steer.

const GOOD := ["+5", "+10", "x2"]
const BAD := ["-8", "-15", "/2"]
const LANE_HW := 5.0

var crowd := 8
var px := 0.0
var pz := 0.0
var runners: Array = []
var gates: Array = []
var round_i := 1
var enemy := 0
var enemy_node: Node3D
var enemy_label: Label3D
var count_label: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.4, 0.55, 0.75))
	static_box(Vector3(LANE_HW * 2 + 2, 1, 800), Vector3(0, -0.5, 380), Color(0.3, 0.32, 0.4))
	crowd = 8
	px = 0.0
	pz = 0.0
	round_i = 1
	count_label = label3d("8", Vector3(0, 3, 0), 64, Color.WHITE)
	_sync_runners()
	_new_round()
	make_camera(Vector3(0, 6, -10), Vector3(0, 1, 10))


func _sync_runners() -> void:
	var target := mini(crowd, 40)
	while runners.size() < target:
		var r := mesh_box(Vector3(0.5, 1.2, 0.5), Vector3.ZERO, Color(0.4, 0.8, 1.0))
		runners.append(r)
	while runners.size() > target:
		var r = runners.pop_back()
		r.queue_free()


func _new_round() -> void:
	for g in gates:
		g.node.queue_free()
	gates.clear()
	for i in 5:
		var z := 40.0 + i * 55.0 + pz
		var left_good := randf() < 0.5
		var lc := GOOD.pick_random() if left_good else BAD.pick_random()
		var rc := BAD.pick_random() if left_good else GOOD.pick_random()
		gates.append(_make_gate(z, -LANE_HW * 0.5, str(lc)))
		gates.append(_make_gate(z, LANE_HW * 0.5, str(rc)))
	enemy = 12 * round_i + randi() % (8 * round_i)
	if enemy_node:
		enemy_node.queue_free()
	enemy_node = Node3D.new()
	enemy_node.position = Vector3(0, 0, gates[gates.size() - 1].z + 60.0)
	add_child(enemy_node)
	mesh_box(Vector3(LANE_HW * 2, 2.5, 2), Vector3(0, 1.25, 0), Color(0.7, 0.2, 0.2), enemy_node)
	enemy_label = label3d(str(enemy), Vector3(0, 3.5, 0), 56, Color.WHITE, enemy_node)


func _make_gate(z: float, x: float, txt: String) -> Dictionary:
	var node := Node3D.new()
	node.position = Vector3(x, 0, z)
	add_child(node)
	var good := txt.begins_with("+") or txt.begins_with("x")
	mesh_box(Vector3(LANE_HW - 0.2, 4, 0.3), Vector3(0, 2, 0),
		Color(0.2, 0.6, 0.3, 1) if good else Color(0.6, 0.2, 0.2, 1), node)
	label3d(txt, Vector3(0, 2.4, 0.3), 48, Color.WHITE, node)
	return {"z": z, "x": x, "txt": txt, "node": node, "hit": false}


func _apply(op: String) -> void:
	match op:
		"+5": crowd += 5
		"+10": crowd += 10
		"x2": crowd *= 2
		"-8": crowd -= 8
		"-15": crowd -= 15
		"/2": crowd = int(ceil(crowd / 2.0))
	crowd = clampi(crowd, 0, 400)
	_sync_runners()
	if crowd <= 0:
		end_demo()


func _unhandled_input(event: InputEvent) -> void:
	if running and event is InputEventScreenDrag:
		px = clampf(px + event.relative.x * 0.03, -LANE_HW + 0.5, LANE_HW - 0.5)


func _process(delta: float) -> void:
	if not running:
		return
	var speed := 22.0 + round_i * 1.5
	pz += speed * delta
	px = clampf(px + key_axis_x() * 8.0 * delta, -LANE_HW + 0.5, LANE_HW - 0.5)

	# arrange runners in a blob
	for i in runners.size():
		var a := float(i) * 2.399963
		var rr := 0.35 + 0.28 * sqrt(float(i))
		runners[i].position = Vector3(px + cos(a) * rr, 0.6, pz + sin(a) * rr)
	count_label.text = str(crowd)
	count_label.position = Vector3(px, 3, pz + 2)

	cam.position = Vector3(px * 0.4, 6, pz - 10)
	cam.look_at(Vector3(0, 1, pz + 12), Vector3.UP)

	for g in gates:
		if not g.hit and g.z <= pz and absf(g.x - px) < LANE_HW * 0.5:
			g.hit = true
			_apply(str(g.txt))
			Juice.sfx("tick")

	if enemy_node and enemy_node.position.z <= pz + 1.0:
		if crowd > enemy:
			add_points(crowd)
			round_i += 1
			crowd = maxi(3, crowd - enemy)
			_sync_runners()
			_new_round()
		else:
			end_demo()
			return
