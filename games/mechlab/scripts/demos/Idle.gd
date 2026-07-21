extends MechDemo
## IDLE / CLICKER — tap income, compound generators, exponential costs.
## The purest monetization-psychology mechanic ever shipped. Endless:
## your score (lifetime earnings) submits when you leave.

const BTN_TAP := Rect2(40, 950, 300, 130)
const BTN_GEN := Rect2(380, 950, 300, 130)

var cash := 0.0
var lifetime := 0.0
var tap_power := 1.0
var gens := 0
var tap_cost := 15.0
var gen_cost := 25.0
var tick := 0.0
var pulse := 0.0


func start() -> void:
	super.start()
	cash = 0.0
	lifetime = 0.0
	tap_power = 1.0
	gens = 0
	tap_cost = 15.0
	gen_cost = 25.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = event.position
	if BTN_TAP.has_point(p):
		if cash >= tap_cost:
			cash -= tap_cost
			tap_power += 1.0
			tap_cost *= 1.6
	elif BTN_GEN.has_point(p):
		if cash >= gen_cost:
			cash -= gen_cost
			gens += 1
			gen_cost *= 1.35
	else:
		cash += tap_power
		lifetime += tap_power
		pulse = 0.2
	set_score(int(lifetime))
	queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	pulse = maxf(0.0, pulse - delta)
	tick += delta
	if tick >= 0.25:
		tick -= 0.25
		var inc := gens * 0.25
		cash += inc
		lifetime += inc
		set_score(int(lifetime))
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.11, 0.09))
	draw_circle(Vector2(360, 560), 150.0 + pulse * 120.0, Color(0.95, 0.8, 0.25, 0.9))
	draw_string(f(), Vector2(60, 400), "$ %d" % int(cash),
		HORIZONTAL_ALIGNMENT_CENTER, 600, 64, Color.WHITE)
	draw_string(f(), Vector2(60, 460), "%.0f / tap    ·    %d / sec" % [tap_power, gens],
		HORIZONTAL_ALIGNMENT_CENTER, 600, 28, Color(1, 1, 1, 0.6))
	_btn(BTN_TAP, "UPGRADE TAP", "$%d" % int(tap_cost), cash >= tap_cost)
	_btn(BTN_GEN, "BUY GENERATOR", "$%d" % int(gen_cost), cash >= gen_cost)
	draw_string(f(), Vector2(60, 760), "TAP THE COIN",
		HORIZONTAL_ALIGNMENT_CENTER, 600, 30, Color(1, 1, 1, 0.45))
	draw_string(f(), Vector2(20, H - 16), "endless — score = lifetime earnings",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))


func _btn(r: Rect2, title: String, cost: String, affordable: bool) -> void:
	draw_rect(r, Color(0.25, 0.45, 0.3) if affordable else Color(0.2, 0.2, 0.22))
	draw_string(f(), Vector2(r.position.x, r.position.y + 52), title,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 28, Color.WHITE)
	draw_string(f(), Vector2(r.position.x, r.position.y + 96), cost,
		HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 26,
		Color(0.7, 1, 0.7) if affordable else Color(1, 0.6, 0.6))
