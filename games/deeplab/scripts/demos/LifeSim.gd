extends MechDemo
## LIFE SIM — keep your person alive and happy (The Sims). Five needs decay;
## tap actions to top them up, WORK for money. Let three needs bottom out at
## once and they collapse. Score = days survived.

const NEEDS := ["HUNGER", "ENERGY", "FUN", "SOCIAL", "HYGIENE"]
const ACTIONS := [
	{"lbl": "EAT", "need": "HUNGER", "amt": 40, "money": -8, "time": 3},
	{"lbl": "SLEEP", "need": "ENERGY", "amt": 60, "money": 0, "time": 8},
	{"lbl": "PLAY", "need": "FUN", "amt": 35, "money": -6, "time": 3},
	{"lbl": "CHAT", "need": "SOCIAL", "amt": 40, "money": 0, "time": 3},
	{"lbl": "SHOWER", "need": "HYGIENE", "amt": 45, "money": 0, "time": 2},
	{"lbl": "WORK", "need": "MONEY", "amt": 0, "money": 25, "time": 6}]

var need := {}
var money := 40
var day := 1
var clock := 0.0
var msg := "keep yourself happy"


func start() -> void:
	super.start()
	need = {}
	for n in NEEDS:
		need[n] = 80.0
	money = 40
	day = 1
	clock = 0.0
	queue_redraw()


func _btn_rect(i: int) -> Rect2:
	return Rect2(40 + (i % 3) * 220, 900 + (i / 3) * 180, 200, 160)


func _do(i: int) -> void:
	var a: Dictionary = ACTIONS[i]
	if a.lbl == "WORK":
		if need["ENERGY"] < 20:
			msg = "too tired to work"
			return
		need["ENERGY"] -= 25
		need["FUN"] -= 15
	elif a.need != "MONEY":
		need[a.need] = minf(100.0, need[a.need] + a.amt)
	money += a.money
	if money < 0:
		money = 0
	# time passes → needs decay
	for n in NEEDS:
		need[n] = maxf(0.0, need[n] - a.time * 2.2)
	clock += a.time
	if clock >= 24.0:
		clock -= 24.0
		day += 1
		add_points(1)
		Juice.sfx("chime")
	msg = "%s" % a.lbl
	Juice.sfx("tick")
	var zeros := 0
	for n in NEEDS:
		if need[n] <= 0.0:
			zeros += 1
	if zeros >= 3:
		Juice.sfx("boom")
		end_demo()
		return
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	for i in ACTIONS.size():
		if _btn_rect(i).has_point(event.position):
			_do(i)
			return


func _mood() -> float:
	var s := 0.0
	for n in NEEDS:
		s += need[n]
	return s / NEEDS.size()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.13, 0.16))
	draw_string(f(), Vector2(0, 120), "DAY %d   ·   %02d:00   ·   $%d" % [day, int(clock), money], HORIZONTAL_ALIGNMENT_CENTER, W, 32, Color.WHITE)
	draw_string(f(), Vector2(0, 175), "mood %d%%   ·   %s" % [int(_mood()), msg], HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(0.8, 0.95, 0.8) if _mood() > 30 else Color(1, 0.6, 0.5))
	for i in NEEDS.size():
		var y := 240 + i * 110
		draw_string(f(), Vector2(40, y + 30), NEEDS[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
		draw_rect(Rect2(280, y, 400, 40), Color(0, 0, 0, 0.4))
		var frac: float = need[NEEDS[i]] / 100.0
		draw_rect(Rect2(280, y, 400 * frac, 40), Color(0.4, 0.85, 0.45) if frac > 0.3 else Color(0.9, 0.4, 0.35))
	for i in ACTIONS.size():
		var r := _btn_rect(i)
		var a: Dictionary = ACTIONS[i]
		draw_rect(r, Color(0.3, 0.4, 0.5))
		draw_string(f(), Vector2(r.position.x, r.position.y + 70), a.lbl, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 30, Color.WHITE)
		var sub := ("$%d" % a.money) if a.money != 0 else ("+%s" % a.need.to_lower())
		draw_string(f(), Vector2(r.position.x, r.position.y + 115), sub, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 22, Color(1, 1, 1, 0.75))
