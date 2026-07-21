extends MechDemo
## AUTO-BATTLER — buy units, they auto-fight the wave (TFT / auto-chess). Win
## on total power, earn gold + interest, reroll the shop. Lose three rounds =
## out. Score = rounds won.

var gold := 10
var lives := 3
var roundn := 1
var units: Array = []
var shop: Array = []
var msg := "buy units, then FIGHT"

const REROLL_R := Rect2(60, 1120, 260, 130)
const FIGHT_R := Rect2(400, 1120, 260, 130)


func start() -> void:
	super.start()
	gold = 10
	lives = 3
	roundn = 1
	units = []
	_roll()
	msg = "buy units, then FIGHT"
	queue_redraw()


func _roll() -> void:
	shop = []
	for i in 3:
		shop.append(randi_range(1, 3))


func _shop_rect(i: int) -> Rect2:
	return Rect2(60 + i * 210, 880, 190, 190)


func _buy(i: int) -> void:
	if gold >= 3 and shop[i] > 0:
		gold -= 3
		units.append(shop[i])
		shop[i] = 0
		Juice.sfx("coin")
		queue_redraw()


func _fight() -> void:
	var wave := 6 * roundn
	var total := 0
	for u in units:
		total += u
	if total >= wave:
		add_points(1)
		roundn += 1
		var interest := int(gold * 0.1)
		gold += 5 + interest
		_roll()
		msg = "WON! +gold (interest %d)" % interest
		Juice.sfx("chime")
	else:
		lives -= 1
		msg = "lost — need %d power (had %d)" % [wave, total]
		Juice.sfx("boom")
		if lives <= 0:
			end_demo()
			return
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	if REROLL_R.has_point(event.position):
		if gold >= 1:
			gold -= 1
			_roll()
			Juice.sfx("tick")
			queue_redraw()
		return
	if FIGHT_R.has_point(event.position):
		_fight()
		return
	for i in 3:
		if _shop_rect(i).has_point(event.position):
			_buy(i)
			return


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.11, 0.12, 0.16))
	draw_string(f(), Vector2(0, 120), "ROUND %d   GOLD %d   LIVES %s" % [roundn, gold, "* ".repeat(lives)], HORIZONTAL_ALIGNMENT_CENTER, W, 32, Color.WHITE)
	var total := 0
	for u in units:
		total += u
	draw_string(f(), Vector2(0, 190), "your army power: %d   (wave needs %d)" % [total, 6 * roundn], HORIZONTAL_ALIGNMENT_CENTER, W, 28, Color(0.6, 0.9, 1.0))
	# army
	for i in units.size():
		var x := 70 + (i % 8) * 78
		var y := 300 + (i / 8) * 78
		draw_circle(Vector2(x, y), 30.0, Color.from_hsv(0.55, 0.5, 0.6 + units[i] * 0.13))
		draw_string(f(), Vector2(x - 30, y + 12), str(units[i]), HORIZONTAL_ALIGNMENT_CENTER, 60, 30, Color.WHITE)
	draw_string(f(), Vector2(0, 840), msg, HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(0.9, 0.9, 0.6))
	# shop
	for i in 3:
		var rr := _shop_rect(i)
		if shop[i] > 0:
			draw_rect(rr, Color(0.3, 0.35, 0.45))
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y - 10), "PWR %d" % shop[i], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 32, Color.WHITE)
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y + 40), "$3", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 26, Color(1, 0.9, 0.5))
		else:
			draw_rect(rr, Color(0.2, 0.2, 0.22))
	draw_rect(REROLL_R, Color(0.35, 0.3, 0.35))
	draw_string(f(), Vector2(REROLL_R.position.x, REROLL_R.get_center().y + 10), "REROLL $1", HORIZONTAL_ALIGNMENT_CENTER, REROLL_R.size.x, 28, Color.WHITE)
	draw_rect(FIGHT_R, Color(0.4, 0.3, 0.3))
	draw_string(f(), Vector2(FIGHT_R.position.x, FIGHT_R.get_center().y + 10), "FIGHT", HORIZONTAL_ALIGNMENT_CENTER, FIGHT_R.size.x, 32, Color.WHITE)
