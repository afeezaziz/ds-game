extends MechDemo
## PRESTIGE — the incremental depth loop (AdVenture Capitalist / Cookie Clicker).
## Tap and buy generators to earn; PRESTIGE resets everything for permanent
## stars that multiply all future income. Endless; score = stars.

const TAP_R := Rect2(60, 720, 600, 200)
const UPT_R := Rect2(40, 960, 300, 130)
const GEN_R := Rect2(380, 960, 300, 130)
const PRE_R := Rect2(160, 1110, 400, 140)
const THRESH := 1000.0

var cash := 0.0
var lifetime := 0.0
var tap_power := 1.0
var gens := 0
var stars := 0
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
	stars = 0
	tap_cost = 15.0
	gen_cost = 25.0
	queue_redraw()


func _mult() -> float:
	return 1.0 + stars * 0.5


func _star_gain() -> int:
	return int(sqrt(lifetime / 300.0))


func _earn(v: float) -> void:
	cash += v
	lifetime += v
	set_score(stars)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = event.position
	if TAP_R.has_point(p):
		_earn(tap_power * _mult())
		pulse = 0.2
		Juice.sfx("tick")
	elif UPT_R.has_point(p) and cash >= tap_cost:
		cash -= tap_cost
		tap_power += 1.0
		tap_cost *= 1.55
		Juice.sfx("coin")
	elif GEN_R.has_point(p) and cash >= gen_cost:
		cash -= gen_cost
		gens += 1
		gen_cost *= 1.32
		Juice.sfx("coin")
	elif PRE_R.has_point(p) and lifetime >= THRESH:
		var g := _star_gain()
		stars += g
		cash = 0.0
		lifetime = 0.0
		tap_power = 1.0
		gens = 0
		tap_cost = 15.0
		gen_cost = 25.0
		set_score(stars)
		Juice.sfx("chime")
		Juice.flash(Color(1, 0.85, 0.4), 0.3)
	queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	pulse = maxf(0.0, pulse - delta)
	tick += delta
	if tick >= 0.25:
		tick -= 0.25
		if gens > 0:
			_earn(gens * 0.5 * _mult())
	queue_redraw()


func _btn(r: Rect2, title: String, sub: String, on: bool) -> void:
	draw_rect(r, Color(0.3, 0.4, 0.35) if on else Color(0.22, 0.22, 0.25))
	draw_string(f(), Vector2(r.position.x, r.position.y + 52), title, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Color.WHITE)
	draw_string(f(), Vector2(r.position.x, r.position.y + 96), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 24, Color(1, 1, 1, 0.75))


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.11, 0.1))
	draw_string(f(), Vector2(0, 150), "STARS %d   (x%.1f income)" % [stars, _mult()], HORIZONTAL_ALIGNMENT_CENTER, W, 40, Color(1, 0.85, 0.4))
	draw_string(f(), Vector2(0, 300), "$ %d" % int(cash), HORIZONTAL_ALIGNMENT_CENTER, W, 90, Color.WHITE)
	draw_string(f(), Vector2(0, 380), "%.0f/tap   ·   %d/sec   ·   lifetime %d" % [tap_power * _mult(), int(gens * 2 * _mult()), int(lifetime)], HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(1, 1, 1, 0.6))
	draw_circle(Vector2(360, 820), 130.0 + pulse * 90.0, Color(0.9, 0.8, 0.3, 0.85))
	draw_string(f(), Vector2(0, 835), "TAP", HORIZONTAL_ALIGNMENT_CENTER, W, 44, Color(0.1, 0.1, 0.1))
	_btn(UPT_R, "UPGRADE TAP", "$%d" % int(tap_cost), cash >= tap_cost)
	_btn(GEN_R, "BUY GENERATOR", "$%d" % int(gen_cost), cash >= gen_cost)
	var ready := lifetime >= THRESH
	_btn(PRE_R, "PRESTIGE", ("+%d stars" % _star_gain()) if ready else "need %d lifetime" % int(THRESH), ready)
