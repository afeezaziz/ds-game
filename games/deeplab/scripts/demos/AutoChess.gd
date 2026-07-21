extends MechDemo
## AUTO-CHESS — buy units whose TRAITS form synergies (TFT). 2 of a trait buffs
## them; 4 buffs them more. Total effective power fights the wave. Win for gold
## + interest; reroll the shop. Three losses = out. Score = rounds won.

const TRAITS := ["WAR", "MAGE", "BEAST"]
const TCOL := {"WAR": Color(0.85, 0.4, 0.35), "MAGE": Color(0.45, 0.6, 0.95), "BEAST": Color(0.5, 0.8, 0.45)}
const REROLL_R := Rect2(60, 1130, 260, 120)
const FIGHT_R := Rect2(400, 1130, 260, 120)

var gold := 10
var lives := 3
var roundn := 1
var board: Array = []      # {trait, power}
var shop: Array = []
var msg := "build synergies, then FIGHT"


func start() -> void:
	super.start()
	gold = 10
	lives = 3
	roundn = 1
	board = []
	_roll()
	msg = "build synergies, then FIGHT"
	queue_redraw()


func _roll() -> void:
	shop = []
	for i in 3:
		shop.append({"trait": TRAITS[randi() % 3], "power": randi_range(1, 3)})


func _bonus() -> Dictionary:
	var counts := {"WAR": 0, "MAGE": 0, "BEAST": 0}
	for u in board:
		counts[u.trait] += 1
	var b := {}
	for tr in counts:
		b[tr] = 5 if counts[tr] >= 4 else (2 if counts[tr] >= 2 else 0)
	return b


func _eff() -> int:
	var b := _bonus()
	var total := 0
	for u in board:
		total += u.power + b[u.trait]
	return total


func _shop_rect(i: int) -> Rect2:
	return Rect2(60 + i * 210, 900, 190, 190)


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
		if _shop_rect(i).has_point(event.position) and shop[i] != null:
			if gold >= 3:
				gold -= 3
				board.append(shop[i])
				shop[i] = null
				Juice.sfx("coin")
				queue_redraw()
			return


func _fight() -> void:
	var wave := 7 * roundn
	var e := _eff()
	if e >= wave:
		add_points(1)
		roundn += 1
		var interest := int(gold * 0.1)
		gold += 5 + interest
		_roll()
		msg = "WON round %d (interest +%d)" % [roundn - 1, interest]
		Juice.sfx("chime")
	else:
		lives -= 1
		msg = "lost — power %d < wave %d" % [e, wave]
		Juice.sfx("boom")
		if lives <= 0:
			end_demo()
			return
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.11, 0.16))
	draw_string(f(), Vector2(0, 110), "ROUND %d   GOLD %d   LIVES %s" % [roundn, gold, "* ".repeat(lives)], HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color.WHITE)
	var b := _bonus()
	var syn := ""
	for tr in TRAITS:
		if b[tr] > 0:
			syn += "%s+%d  " % [tr, b[tr]]
	draw_string(f(), Vector2(0, 165), "power %d vs wave %d    %s" % [_eff(), 7 * roundn, syn], HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(0.6, 0.95, 0.7))
	# board
	for i in board.size():
		var u: Dictionary = board[i]
		var x := 70 + (i % 7) * 90
		var y := 280 + (i / 7) * 90
		draw_circle(Vector2(x, y), 34.0, TCOL[u.trait])
		draw_string(f(), Vector2(x - 34, y - 4), u.trait.substr(0, 1), HORIZONTAL_ALIGNMENT_CENTER, 68, 24, Color.WHITE)
		draw_string(f(), Vector2(x - 34, y + 26), str(u.power), HORIZONTAL_ALIGNMENT_CENTER, 68, 22, Color(0.1, 0.1, 0.1))
	draw_string(f(), Vector2(0, 860), msg, HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color(0.9, 0.9, 0.6))
	for i in 3:
		var rr := _shop_rect(i)
		if shop[i] != null:
			var u: Dictionary = shop[i]
			draw_rect(rr, TCOL[u.trait])
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y - 10), u.trait, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 26, Color.WHITE)
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y + 34), "pwr %d · $3" % u.power, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 24, Color(0.1, 0.1, 0.1))
		else:
			draw_rect(rr, Color(0.2, 0.2, 0.22))
	draw_rect(REROLL_R, Color(0.35, 0.3, 0.35))
	draw_string(f(), Vector2(REROLL_R.position.x, REROLL_R.get_center().y + 10), "REROLL $1", HORIZONTAL_ALIGNMENT_CENTER, REROLL_R.size.x, 28, Color.WHITE)
	draw_rect(FIGHT_R, Color(0.4, 0.3, 0.3))
	draw_string(f(), Vector2(FIGHT_R.position.x, FIGHT_R.get_center().y + 10), "FIGHT", HORIZONTAL_ALIGNMENT_CENTER, FIGHT_R.size.x, 32, Color.WHITE)
