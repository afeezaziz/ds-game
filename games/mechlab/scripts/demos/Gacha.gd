extends MechDemo
## GACHA — a pull mechanic SIMULATION (Genshin / FGO). Earn gems, pull for
## 3-5★ units, pity guarantees a 5★ by pull 20. NO REAL MONEY — this exists to
## study the loop, not to charge for it. Score = collection value.

const WORK_R := Rect2(60, 940, 280, 180)
const PULL_R := Rect2(380, 940, 280, 180)

var gems := 100
var pity := 0
var c3 := 0
var c4 := 0
var c5 := 0
var last := 3
var pulse := 0.0


func start() -> void:
	super.start()
	gems = 100
	pity = 0
	c3 = 0
	c4 = 0
	c5 = 0
	last = 3
	queue_redraw()


func _work() -> void:
	gems += 15
	Juice.sfx("tick")
	queue_redraw()


func _pull() -> void:
	if gems < 10:
		return
	gems -= 10
	pity += 1
	var r := randf()
	if pity >= 20 or r < 0.05:
		c5 += 1
		last = 5
		pity = 0
		Juice.sfx("chime")
		Juice.flash(Color(0.95, 0.7, 0.2), 0.3)
	elif r < 0.30:
		c4 += 1
		last = 4
		Juice.sfx("coin")
	else:
		c3 += 1
		last = 3
		Juice.sfx("tick")
	pulse = 0.4
	set_score(c5 * 100 + c4 * 20 + c3 * 5)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	if WORK_R.has_point(event.position):
		_work()
	elif PULL_R.has_point(event.position):
		_pull()


func _process(delta: float) -> void:
	if pulse > 0.0:
		pulse -= delta
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.11, 0.1, 0.16))
	draw_string(f(), Vector2(0, 120), "SIMULATION — no real money", HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color(1, 0.8, 0.5))
	draw_string(f(), Vector2(0, 210), "GEMS %d" % gems, HORIZONTAL_ALIGNMENT_CENTER, W, 52, Color(0.6, 0.9, 1.0))
	var col := [Color(0.7, 0.7, 0.7), Color(0.4, 0.6, 0.95), Color(0.95, 0.7, 0.2)][last - 3]
	var sz := 130.0 + pulse * 110.0
	draw_circle(Vector2(360, 480), sz, col)
	draw_string(f(), Vector2(0, 495), "%d★" % last, HORIZONTAL_ALIGNMENT_CENTER, W, 60, Color(0.1, 0.1, 0.1))
	draw_string(f(), Vector2(0, 660), "5★ %d    4★ %d    3★ %d" % [c5, c4, c3], HORIZONTAL_ALIGNMENT_CENTER, W, 34, Color.WHITE)
	draw_string(f(), Vector2(0, 720), "odds 5%%/25%%/70%%  ·  pity %d/20" % pity, HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(1, 1, 1, 0.6))
	draw_rect(WORK_R, Color(0.3, 0.4, 0.3))
	draw_string(f(), Vector2(WORK_R.position.x, WORK_R.get_center().y + 4), "WORK\n+15 gems", HORIZONTAL_ALIGNMENT_CENTER, WORK_R.size.x, 30, Color.WHITE)
	draw_rect(PULL_R, Color(0.4, 0.3, 0.45) if gems >= 10 else Color(0.25, 0.25, 0.28))
	draw_string(f(), Vector2(PULL_R.position.x, PULL_R.get_center().y + 4), "PULL\n-10 gems", HORIZONTAL_ALIGNMENT_CENTER, PULL_R.size.x, 30, Color.WHITE)
