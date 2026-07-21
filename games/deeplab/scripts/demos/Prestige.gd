extends MechDemo
## PRESTIGE (deep) — a real incremental. FIVE generator tiers, each with its own
## cost curve and x2 milestones at 10/25/50 owned. Ascend to trade all progress
## for STARS, then spend stars in a permanent PERK TREE (income, cheaper gens,
## stronger taps, starting cash) so each reset is structurally stronger.
## Endless; score = stars.

const GNAMES := ["FARM", "MINE", "FACTORY", "BANK", "LAB"]
const GCOST := [15.0, 100.0, 1100.0, 12000.0, 130000.0]
const GPROD := [0.5, 3.0, 18.0, 110.0, 700.0]
const PERKS := ["income", "cost", "tap", "startcash"]
const PERK_DESC := {
	"income": "GROWTH — +25% all income / lvl",
	"cost": "THRIFT — generators 5% cheaper / lvl",
	"tap": "MIDAS — +100% tap power / lvl",
	"startcash": "NEST EGG — start with +$500 / lvl"}

var cash := 0.0
var lifetime := 0.0
var stars := 0
var gcount := [1, 0, 0, 0, 0]
var perk := {"income": 0, "cost": 0, "tap": 0, "startcash": 0}
var tick := 0.0
var pulse := 0.0
var view := 0  # 0 generators, 1 perks


func start() -> void:
	super.start()
	cash = 0.0
	lifetime = 0.0
	stars = 0
	gcount = [1, 0, 0, 0, 0]
	perk = {"income": 0, "cost": 0, "tap": 0, "startcash": 0}
	view = 0
	queue_redraw()


func _milestone(count: int) -> float:
	var m := 0
	if count >= 10: m += 1
	if count >= 25: m += 1
	if count >= 50: m += 1
	return pow(2.0, m)


func _global() -> float:
	return 1.0 + perk.income * 0.25


func _income() -> float:
	var total := 0.0
	for i in 5:
		total += gcount[i] * GPROD[i] * _milestone(gcount[i])
	return total * _global()


func _tap_power() -> float:
	return (1.0 + perk.tap) * _global()


func _cost(i: int) -> float:
	return GCOST[i] * pow(1.15, gcount[i]) * (1.0 - perk.cost * 0.05)


func _star_gain() -> int:
	return int(sqrt(lifetime / 12000.0))


func _threshold() -> float:
	return 15000.0


func _g_rect(i: int) -> Rect2:
	return Rect2(30, 360 + i * 150, 660, 135)


func _perk_rect(i: int) -> Rect2:
	return Rect2(40, 380 + i * 180, 640, 160)


func _tab_rect() -> Rect2:
	return Rect2(500, 150, 190, 80)


func _prestige_rect() -> Rect2:
	return Rect2(40, 1160, 420, 90)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = event.position
	if _tab_rect().has_point(p):
		view = 1 - view
		queue_redraw()
		return
	if view == 0:
		for i in 5:
			var buy := Rect2(_g_rect(i).position.x + 430, _g_rect(i).position.y + 25, 220, 85)
			if buy.has_point(p) and cash >= _cost(i):
				cash -= _cost(i)
				gcount[i] += 1
				Juice.sfx("coin")
				queue_redraw()
				return
		if _prestige_rect().has_point(p) and lifetime >= _threshold():
			var g := _star_gain()
			stars += g
			cash = perk.startcash * 500.0
			lifetime = 0.0
			gcount = [1, 0, 0, 0, 0]
			set_score(stars)
			Juice.sfx("chime")
			Juice.flash(Color(1, 0.85, 0.4), 0.3)
			queue_redraw()
			return
		# tap anywhere else = earn
		_earn(_tap_power())
		pulse = 0.2
	else:
		for i in PERKS.size():
			if _perk_rect(i).has_point(p):
				var cost := perk[PERKS[i]] + 1
				if stars >= cost:
					stars -= cost
					perk[PERKS[i]] += 1
					set_score(stars)
					Juice.sfx("chime")
					queue_redraw()
				return


func _earn(v: float) -> void:
	cash += v
	lifetime += v


func _process(delta: float) -> void:
	if not running:
		return
	pulse = maxf(0.0, pulse - delta)
	tick += delta
	if tick >= 0.2:
		tick -= 0.2
		_earn(_income() * 0.2)
	queue_redraw()


func _fmt(v: float) -> String:
	if v >= 1e9: return "%.2fB" % (v / 1e9)
	if v >= 1e6: return "%.2fM" % (v / 1e6)
	if v >= 1e3: return "%.2fK" % (v / 1e3)
	return "%d" % int(v)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.11, 0.1))
	draw_string(f(), Vector2(0, 130), "$ %s" % _fmt(cash), HORIZONTAL_ALIGNMENT_CENTER, W, 56, Color.WHITE)
	draw_string(f(), Vector2(0, 190), "%s / sec   ·   ★%d stars   ·   income x%.2f" % [_fmt(_income()), stars, _global()], HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color(0.7, 0.9, 1.0))
	draw_rect(_tab_rect(), Color(0.3, 0.35, 0.5))
	draw_string(f(), Vector2(_tab_rect().position.x, _tab_rect().get_center().y + 8), "PERKS" if view == 0 else "GENERATORS", HORIZONTAL_ALIGNMENT_CENTER, _tab_rect().size.x, 22, Color.WHITE)
	if view == 0:
		draw_string(f(), Vector2(30, 300), "tap anywhere to earn (+%s)" % _fmt(_tap_power()), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))
		if pulse > 0.0:
			draw_circle(Vector2(360, 250), 40 + pulse * 120, Color(0.9, 0.8, 0.3, 0.5))
		for i in 5:
			var r := _g_rect(i)
			draw_rect(r, Color(1, 1, 1, 0.05))
			var mile := _milestone(gcount[i])
			draw_string(f(), Vector2(r.position.x + 20, r.position.y + 50), "%s x%d" % [GNAMES[i], gcount[i]], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
			draw_string(f(), Vector2(r.position.x + 20, r.position.y + 100), "%s/s%s" % [_fmt(gcount[i] * GPROD[i] * mile * _global()), ("   (x%d milestone)" % int(mile)) if mile > 1 else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(0.7, 0.9, 0.7))
			var buy := Rect2(r.position.x + 430, r.position.y + 25, 220, 85)
			draw_rect(buy, Color(0.3, 0.45, 0.35) if cash >= _cost(i) else Color(0.25, 0.25, 0.27))
			draw_string(f(), Vector2(buy.position.x, buy.position.y + 34), "BUY", HORIZONTAL_ALIGNMENT_CENTER, buy.size.x, 24, Color.WHITE)
			draw_string(f(), Vector2(buy.position.x, buy.position.y + 66), "$%s" % _fmt(_cost(i)), HORIZONTAL_ALIGNMENT_CENTER, buy.size.x, 20, Color(1, 0.9, 0.5))
		var pr := _prestige_rect()
		var ready := lifetime >= _threshold()
		draw_rect(pr, Color(0.45, 0.4, 0.2) if ready else Color(0.22, 0.22, 0.25))
		draw_string(f(), Vector2(pr.position.x, pr.get_center().y + 8), ("ASCEND  +%d ★" % _star_gain()) if ready else "ASCEND (need $%s lifetime)" % _fmt(_threshold()), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 24, Color.WHITE)
	else:
		draw_string(f(), Vector2(0, 320), "PERK TREE   —   ★%d to spend" % stars, HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color(1, 0.9, 0.5))
		for i in PERKS.size():
			var r := _perk_rect(i)
			var key: String = PERKS[i]
			var cost := perk[key] + 1
			draw_rect(r, Color(0.3, 0.35, 0.5) if stars >= cost else Color(0.24, 0.24, 0.28))
			draw_string(f(), Vector2(r.position.x + 20, r.position.y + 55), PERK_DESC[key], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
			draw_string(f(), Vector2(r.position.x + 20, r.position.y + 105), "Lv %d   ·   cost ★%d" % [perk[key], cost], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.9, 0.6))
