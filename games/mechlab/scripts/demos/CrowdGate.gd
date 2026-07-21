extends MechDemo
## CROWD GATES — the Count Masters / Mob Control runner (2021 ad-genre king):
## steer your crowd through math gates (x2 or -10?), then slam into the
## enemy army. Bigger number wins. Drag to steer.

const LANE_Y := 1000.0
const GOOD := ["+4", "+8", "x2"]
const BAD := ["-6", "-12", "/2"]

var crowd := 5
var px := 360.0
var gates: Array = []
var round_i := 1
var enemy := 0
var enemy_y := -400.0
var state := "run"  # run | boss


func start() -> void:
	super.start()
	crowd = 5
	px = 360.0
	round_i = 1
	_new_round()
	queue_redraw()


func _new_round() -> void:
	state = "run"
	gates.clear()
	for i in 6:
		var good_left := randf() < 0.5
		gates.append({
			"y": -200.0 - i * 460.0,
			"l": GOOD.pick_random() if good_left else BAD.pick_random(),
			"r": BAD.pick_random() if good_left else GOOD.pick_random(),
		})
	enemy = 8 * round_i + randi() % (6 * round_i)
	enemy_y = gates[5].y - 700.0


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenDrag or (event is InputEventScreenTouch and event.pressed):
		px = clampf(event.position.x, 70.0, W - 70.0)


func _apply(op: String) -> void:
	match op:
		"+4": crowd += 4
		"+8": crowd += 8
		"x2": crowd *= 2
		"-6": crowd -= 6
		"-12": crowd -= 12
		"/2": crowd = int(ceil(crowd / 2.0))
	crowd = mini(crowd, 999)
	if crowd <= 0:
		end_demo()


func _process(delta: float) -> void:
	if not running:
		return
	var speed := 340.0 + round_i * 15.0
	for g in gates.duplicate():
		g.y += speed * delta
		if g.y >= LANE_Y:
			_apply(g.l if px < W * 0.5 else g.r)
			gates.erase(g)
			if not running:
				return
	enemy_y += speed * delta
	if enemy_y >= LANE_Y - 60.0:
		# the clash
		if crowd > enemy:
			add_points(crowd)
			round_i += 1
			crowd = maxi(5, crowd - enemy)
			_new_round()
		else:
			end_demo()
			return
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.13, 0.1, 0.16))
	draw_rect(Rect2(40, 0, W - 80, H), Color(0.2, 0.16, 0.24))
	for g in gates:
		if g.y > -80.0 and g.y < H + 80.0:
			_gate(Rect2(40, g.y - 55, 320, 110), str(g.l))
			_gate(Rect2(360, g.y - 55, 320, 110), str(g.r))
	if enemy_y > -100.0:
		draw_rect(Rect2(40, enemy_y - 70, W - 80, 140), Color(0.5, 0.15, 0.15))
		draw_string(f(), Vector2(0, enemy_y + 12), "ENEMY %d" % enemy,
			HORIZONTAL_ALIGNMENT_CENTER, W, 44, Color.WHITE)
	# the crowd
	var n := mini(crowd, 60)
	for i in n:
		var a := float(i) * 2.399963  # golden angle spiral
		var r := 8.0 + 6.5 * sqrt(float(i))
		draw_circle(Vector2(px, LANE_Y) + Vector2(cos(a), sin(a)) * r, 8.0, Color(0.4, 0.8, 1.0))
	draw_string(f(), Vector2(px - 80, LANE_Y - 70), str(crowd),
		HORIZONTAL_ALIGNMENT_CENTER, 160, 42, Color.WHITE)
	draw_string(f(), Vector2(20, 150), "ROUND %d" % round_i,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.7))
	draw_string(f(), Vector2(20, H - 16), "drag to steer into the good gates",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))


func _gate(r: Rect2, txt: String) -> void:
	var good := txt.begins_with("+") or txt.begins_with("x")
	var c := Color(0.2, 0.55, 0.3, 0.85) if good else Color(0.6, 0.2, 0.2, 0.85)
	draw_rect(r, c)
	draw_string(f(), Vector2(r.position.x, r.get_center().y + 14), txt,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 46, Color.WHITE)
