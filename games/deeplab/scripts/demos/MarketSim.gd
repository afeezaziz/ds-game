extends MechDemo
## MARKET SIM — buy low, sell high across three goods with drifting prices and
## sudden supply shocks (the tycoon/trading loop). Grow your net worth.
## Endless; score = peak net worth.

const GOODS := ["GRAIN", "ORE", "SPICE"]
const GCOL := [Color(0.9, 0.8, 0.4), Color(0.6, 0.65, 0.7), Color(0.9, 0.45, 0.35)]

var price := [10.0, 25.0, 60.0]
var hist := [[], [], []]
var inv := [0, 0, 0]
var cash := 200.0
var peak := 200
var tick := 0.0
var news := "the market opens"


func start() -> void:
	super.start()
	price = [10.0, 25.0, 60.0]
	hist = [[], [], []]
	inv = [0, 0, 0]
	cash = 200.0
	peak = 200
	news = "the market opens"
	queue_redraw()


func _net() -> float:
	var n := cash
	for i in 3:
		n += inv[i] * price[i]
	return n


func _row_rect(i: int) -> Rect2:
	return Rect2(30, 420 + i * 220, 660, 200)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	for i in 3:
		var r := _row_rect(i)
		var buy := Rect2(r.position.x + 360, r.position.y + 110, 140, 70)
		var sell := Rect2(r.position.x + 510, r.position.y + 110, 140, 70)
		if buy.has_point(event.position) and cash >= price[i]:
			cash -= price[i]
			inv[i] += 1
			Juice.sfx("tick")
		elif sell.has_point(event.position) and inv[i] > 0:
			cash += price[i]
			inv[i] -= 1
			Juice.sfx("coin")
	queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	tick += delta
	if tick >= 1.0:
		tick -= 1.0
		for i in 3:
			price[i] = clampf(price[i] * (1.0 + randf_range(-0.06, 0.06)), 2.0, 9999.0)
			hist[i].append(price[i])
			if hist[i].size() > 60:
				hist[i].pop_front()
		if randf() < 0.18:
			var g := randi() % 3
			var up := randf() < 0.5
			price[g] *= randf_range(1.3, 1.8) if up else randf_range(0.5, 0.75)
			news = "%s %s — %s!" % [GOODS[g], "SHORTAGE" if up else "GLUT", "prices spike" if up else "prices crash"]
			Juice.flash(Color(0.9, 0.8, 0.4) if up else Color(0.4, 0.5, 0.9), 0.15)
		peak = maxi(peak, int(_net()))
		set_score(peak)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.11, 0.13))
	draw_string(f(), Vector2(0, 130), "NET WORTH $%d" % int(_net()), HORIZONTAL_ALIGNMENT_CENTER, W, 44, Color(0.5, 0.95, 0.6))
	draw_string(f(), Vector2(0, 190), "cash $%d   ·   peak $%d" % [int(cash), peak], HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color.WHITE)
	draw_string(f(), Vector2(0, 250), news, HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(1, 0.85, 0.5))
	for i in 3:
		var r := _row_rect(i)
		draw_rect(r, Color(1, 1, 1, 0.04))
		draw_string(f(), Vector2(r.position.x + 16, r.position.y + 54), GOODS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 34, GCOL[i])
		draw_string(f(), Vector2(r.position.x + 16, r.position.y + 110), "$%.1f   held: %d" % [price[i], inv[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
		# sparkline
		if hist[i].size() > 1:
			var mn := 9999.0
			var mx := 0.0
			for v in hist[i]:
				mn = minf(mn, v)
				mx = maxf(mx, v)
			var rng: float = maxf(1.0, mx - mn)
			var pts := PackedVector2Array()
			for j in hist[i].size():
				pts.append(Vector2(r.position.x + 16 + j * 5.0, r.position.y + 90 - (hist[i][j] - mn) / rng * 60.0))
			draw_polyline(pts, GCOL[i], 2.0)
		draw_rect(Rect2(r.position.x + 360, r.position.y + 110, 140, 70), Color(0.3, 0.45, 0.3) if cash >= price[i] else Color(0.25, 0.25, 0.27))
		draw_string(f(), Vector2(r.position.x + 360, r.position.y + 155), "BUY", HORIZONTAL_ALIGNMENT_CENTER, 140, 28, Color.WHITE)
		draw_rect(Rect2(r.position.x + 510, r.position.y + 110, 140, 70), Color(0.45, 0.35, 0.25) if inv[i] > 0 else Color(0.25, 0.25, 0.27))
		draw_string(f(), Vector2(r.position.x + 510, r.position.y + 155), "SELL", HORIZONTAL_ALIGNMENT_CENTER, 140, 28, Color.WHITE)
