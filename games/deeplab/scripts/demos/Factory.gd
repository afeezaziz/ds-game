extends MechDemo
## FACTORY — build a production chain and watch it flow (Factorio / AdVenture
## automation). Each stage converts the previous stage's output; buy stages to
## clear bottlenecks. Money comes off the end. Endless; score = money.

const STAGES := ["MINE", "SMELT", "ASSEMBLE", "MARKET"]
const BASE_COST := [10, 25, 60, 150]

var counts := [1, 0, 0, 0]
var buf := [0.0, 0.0, 0.0]     # ore, bar, widget buffers
var money := 40.0
var tick := 0.0


func start() -> void:
	super.start()
	counts = [1, 0, 0, 0]
	buf = [0.0, 0.0, 0.0]
	money = 40.0
	queue_redraw()


func _cost(i: int) -> int:
	return int(BASE_COST[i] * pow(1.4, counts[i]))


func _row_rect(i: int) -> Rect2:
	return Rect2(40, 340 + i * 190, 640, 170)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	for i in 4:
		var r := _row_rect(i)
		var buy := Rect2(r.position.x + 440, r.position.y + 35, 190, 100)
		if buy.has_point(event.position) and money >= _cost(i):
			money -= _cost(i)
			counts[i] += 1
			Juice.sfx("coin")
			queue_redraw()
			return


func _process(delta: float) -> void:
	if not running:
		return
	tick += delta
	if tick >= 0.3:
		tick -= 0.3
		buf[0] += counts[0]
		var smelt: float = minf(counts[1], buf[0])
		buf[0] -= smelt
		buf[1] += smelt
		var asm: float = minf(counts[2], buf[1])
		buf[1] -= asm
		buf[2] += asm
		var sold: float = minf(counts[3], buf[2])
		buf[2] -= sold
		money += sold * 3.0
		set_score(int(money))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.11, 0.13))
	draw_string(f(), Vector2(0, 150), "$ %d" % int(money), HORIZONTAL_ALIGNMENT_CENTER, W, 60, Color(0.5, 0.95, 0.6))
	draw_string(f(), Vector2(0, 230), "build the chain · each stage feeds the next", HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color(1, 1, 1, 0.6))
	for i in 4:
		var r := _row_rect(i)
		draw_rect(r, Color(1, 1, 1, 0.05))
		draw_string(f(), Vector2(r.position.x + 20, r.position.y + 55), STAGES[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color.WHITE)
		draw_string(f(), Vector2(r.position.x + 20, r.position.y + 110), "x%d   rate %d/s" % [counts[i], int(counts[i] / 0.3)], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.7, 0.9, 0.9))
		if i < 3:
			draw_string(f(), Vector2(r.position.x + 250, r.position.y + 110), "buffer %d" % int(buf[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.9, 0.5))
		var buy := Rect2(r.position.x + 440, r.position.y + 35, 190, 100)
		draw_rect(buy, Color(0.3, 0.45, 0.35) if money >= _cost(i) else Color(0.25, 0.25, 0.27))
		draw_string(f(), Vector2(buy.position.x, buy.position.y + 44), "BUILD +1", HORIZONTAL_ALIGNMENT_CENTER, buy.size.x, 24, Color.WHITE)
		draw_string(f(), Vector2(buy.position.x, buy.position.y + 78), "$%d" % _cost(i), HORIZONTAL_ALIGNMENT_CENTER, buy.size.x, 22, Color(1, 0.9, 0.5))
