extends MechDemo
## CITY SIM — balance food, population and coins (SimCity / Township). Houses
## raise the pop cap, farms feed them, workplaces earn coins. Let food fall
## behind population and the city starves. Endless; score = peak population.

const N := 12
const CS := 190.0
const OX := 70.0
const OY := 320.0
const BUILD := [
	{"key": "HOUSE", "cost": 30, "col": Color(0.5, 0.7, 0.95)},
	{"key": "FARM", "cost": 40, "col": Color(0.5, 0.8, 0.4)},
	{"key": "WORK", "cost": 55, "col": Color(0.9, 0.75, 0.35)}]

var pads: Array = []
var pop := 3.0
var peak := 3
var food := 20.0
var coins := 60.0
var msg := "grow your city"


func start() -> void:
	super.start()
	pads = []
	for i in N:
		pads.append("")
	pop = 3.0
	peak = 3
	food = 20.0
	coins = 60.0
	msg = "grow your city"
	queue_redraw()


func _count(t: String) -> int:
	var n := 0
	for p in pads:
		if p == t:
			n += 1
	return n


func _pad_rect(i: int) -> Rect2:
	return Rect2(OX + (i % 3) * CS, OY + (i / 3) * CS, CS - 14, CS - 14)


func _btn_rect(i: int) -> Rect2:
	return Rect2(70 + i * 200, 1090, 180, 150)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	for i in BUILD.size():
		if _btn_rect(i).has_point(event.position):
			var b: Dictionary = BUILD[i]
			if coins >= b.cost:
				for j in pads.size():
					if pads[j] == "":
						pads[j] = b.key
						coins -= b.cost
						Juice.sfx("coin")
						break
			else:
				msg = "not enough coins"
			queue_redraw()
			return


func _process(delta: float) -> void:
	if not running:
		return
	var cap := _count("HOUSE") * 4
	var food_rate := _count("FARM") * 4.0 - pop
	food += food_rate * delta
	coins += _count("WORK") * min(pop, _count("WORK") * 3.0) * 0.15 * delta
	if food > 5.0 and pop < cap:
		pop += 0.6 * delta
		msg = "growing…"
	elif food < 0.0:
		pop = maxf(0.0, pop - 0.8 * delta)
		food = 0.0
		msg = "STARVING — build farms!"
	peak = maxi(peak, int(pop))
	set_score(peak)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.14, 0.12))
	draw_string(f(), Vector2(20, 110), "POP %d / %d   FOOD %d   COINS %d" % [int(pop), _count("HOUSE") * 4, int(food), int(coins)], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(f(), Vector2(20, 160), "peak %d   ·   %s" % [peak, msg], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.8, 0.95, 0.8))
	draw_string(f(), Vector2(20, 220), "food/sec: %+d   (farms feed, people eat)" % int(_count("FARM") * 4 - pop), HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.6))
	for i in N:
		var rr := _pad_rect(i)
		if pads[i] == "":
			draw_rect(rr, Color(1, 1, 1, 0.05))
		else:
			var col := Color.WHITE
			for b in BUILD:
				if b.key == pads[i]:
					col = b.col
			draw_rect(rr, col)
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y + 8), pads[i], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 24, Color(0.1, 0.1, 0.1))
	for i in BUILD.size():
		var br := _btn_rect(i)
		var b: Dictionary = BUILD[i]
		draw_rect(br, b.col if coins >= b.cost else Color(0.25, 0.25, 0.28))
		draw_string(f(), Vector2(br.position.x, br.position.y + 66), b.key, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 24, Color(0.1, 0.1, 0.1))
		draw_string(f(), Vector2(br.position.x, br.position.y + 108), "$%d" % b.cost, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 22, Color(0.1, 0.1, 0.1))
