extends MechDemo
## NARRATIVE — swipe-to-decide with resource meters (Reigns). Each card is a
## choice; every choice shifts money / army / faith / people. Push any meter to
## empty OR full and your reign ends. Score = years survived.

const METERS := ["MONEY", "ARMY", "FAITH", "PEOPLE"]
const MCOL := [Color(0.9, 0.8, 0.3), Color(0.9, 0.4, 0.4), Color(0.6, 0.5, 0.9), Color(0.4, 0.8, 0.5)]
const CARDS := [
	{"c": "ADVISOR", "t": "The treasury runs low. Raise taxes?", "l": {"lbl": "No", "e": {"MONEY": -8, "PEOPLE": 6}}, "r": {"lbl": "Yes", "e": {"MONEY": 12, "PEOPLE": -9}}},
	{"c": "GENERAL", "t": "A rival masses troops. Strike first?", "l": {"lbl": "Wait", "e": {"ARMY": -6, "FAITH": 4}}, "r": {"lbl": "Attack", "e": {"ARMY": 10, "MONEY": -8, "PEOPLE": -4}}},
	{"c": "PRIEST", "t": "Build a grand temple to the gods?", "l": {"lbl": "No", "e": {"FAITH": -9, "MONEY": 6}}, "r": {"lbl": "Yes", "e": {"FAITH": 12, "MONEY": -10}}},
	{"c": "PEASANT", "t": "The harvest failed. Open the granaries?", "l": {"lbl": "No", "e": {"PEOPLE": -11, "MONEY": 6}}, "r": {"lbl": "Yes", "e": {"PEOPLE": 10, "MONEY": -8}}},
	{"c": "MERCHANT", "t": "Grant trade rights to foreigners?", "l": {"lbl": "No", "e": {"MONEY": -6, "FAITH": 4}}, "r": {"lbl": "Yes", "e": {"MONEY": 13, "FAITH": -7}}},
	{"c": "SPY", "t": "A rebel plot brews. Purge the suspects?", "l": {"lbl": "No", "e": {"PEOPLE": 6, "ARMY": -5}}, "r": {"lbl": "Purge", "e": {"PEOPLE": -11, "ARMY": 8}}},
	{"c": "WITCH", "t": "She offers a blessing — for gold.", "l": {"lbl": "Refuse", "e": {"FAITH": -5, "MONEY": 4}}, "r": {"lbl": "Pay", "e": {"FAITH": 10, "MONEY": -9}}},
	{"c": "GENERAL", "t": "Conscript the young into the army?", "l": {"lbl": "No", "e": {"ARMY": -6, "PEOPLE": 6}}, "r": {"lbl": "Yes", "e": {"ARMY": 11, "PEOPLE": -9}}},
	{"c": "ENVOY", "t": "A royal marriage alliance is offered.", "l": {"lbl": "Decline", "e": {"ARMY": -4, "FAITH": 5}}, "r": {"lbl": "Accept", "e": {"ARMY": 9, "MONEY": -6}}},
	{"c": "BARD", "t": "Fund festivals and the arts?", "l": {"lbl": "No", "e": {"PEOPLE": -7, "MONEY": 6}}, "r": {"lbl": "Yes", "e": {"PEOPLE": 10, "MONEY": -9}}}]

var meters := {}
var card: Dictionary = {}
var msg := ""
var ts := Vector2.ZERO


func start() -> void:
	super.start()
	meters = {"MONEY": 50, "ARMY": 50, "FAITH": 50, "PEOPLE": 50}
	msg = "swipe left or right to decide"
	_next()
	queue_redraw()


func _next() -> void:
	card = CARDS[randi() % CARDS.size()]


func _choose(side: String) -> void:
	var choice: Dictionary = card[side]
	for k in choice.e:
		meters[k] = meters[k] + choice.e[k]
	msg = "%s: %s" % [card.c, choice.lbl]
	Juice.sfx("tick")
	for k in meters:
		if meters[k] <= 0 or meters[k] >= 100:
			Juice.sfx("boom")
			Juice.flash(Color(0.8, 0.2, 0.2), 0.3)
			end_demo()
			return
	add_points(1)
	_next()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch):
		return
	if event.pressed:
		ts = event.position
	else:
		var d: Vector2 = event.position - ts
		if absf(d.x) < 40.0:
			return
		_choose("l" if d.x < 0 else "r")


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.1, 0.14))
	# meters
	for i in 4:
		var x := 60 + i * 160
		draw_rect(Rect2(x, 120, 40, 200), Color(0, 0, 0, 0.4))
		var frac: float = clampf(meters[METERS[i]] / 100.0, 0, 1)
		draw_rect(Rect2(x, 120 + 200 * (1.0 - frac), 40, 200 * frac), MCOL[i])
		draw_string(f(), Vector2(x - 30, 350), METERS[i], HORIZONTAL_ALIGNMENT_CENTER, 100, 20, Color.WHITE)
	# card
	draw_rect(Rect2(90, 440, 540, 520), Color(0.2, 0.2, 0.26))
	draw_circle(Vector2(360, 560), 70.0, Color(0.5, 0.45, 0.6))
	draw_string(f(), Vector2(90, 660), card.get("c", ""), HORIZONTAL_ALIGNMENT_CENTER, 540, 30, Color(1, 0.9, 0.6))
	draw_string(f(), Vector2(120, 740), card.get("t", ""), HORIZONTAL_ALIGNMENT_CENTER, 480, 30, Color.WHITE)
	draw_string(f(), Vector2(120, 900), "◄ %s" % card.get("l", {}).get("lbl", ""), HORIZONTAL_ALIGNMENT_LEFT, 200, 30, Color(0.9, 0.6, 0.6))
	draw_string(f(), Vector2(400, 900), "%s ►" % card.get("r", {}).get("lbl", ""), HORIZONTAL_ALIGNMENT_RIGHT, 200, 30, Color(0.6, 0.9, 0.7))
	draw_string(f(), Vector2(0, 1040), "YEARS: %d" % score, HORIZONTAL_ALIGNMENT_CENTER, W, 34, Color(1, 1, 1, 0.8))
	draw_string(f(), Vector2(0, 1100), msg, HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color(0.7, 0.9, 1.0))
