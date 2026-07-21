extends MechDemo
## DECKBUILDER — Slay the Spire-lite. Spend energy to play cards from your
## hand; block the enemy's telegraphed hit; win to grow your deck and climb.
## Score = floors cleared.

const END_R := Rect2(480, 1120, 200, 130)
const CARDS := {
	"strike": {"name": "Strike", "cost": 1, "dmg": 6, "block": 0, "col": Color(0.8, 0.35, 0.35)},
	"defend": {"name": "Defend", "cost": 1, "dmg": 0, "block": 5, "col": Color(0.35, 0.55, 0.85)},
	"bash": {"name": "Bash", "cost": 2, "dmg": 10, "block": 0, "col": Color(0.85, 0.5, 0.25)},
	"heavy": {"name": "Heavy", "cost": 2, "dmg": 8, "block": 4, "col": Color(0.6, 0.4, 0.7)}}

var deck: Array = []
var draw_pile: Array = []
var hand: Array = []
var discard: Array = []
var php := 60
var pmax := 60
var energy := 3
var block := 0
var ehp := 30
var emax := 30
var intent := 8
var elvl := 1


func start() -> void:
	super.start()
	php = 60
	pmax = 60
	elvl = 1
	deck = []
	for i in 5:
		deck.append("strike")
	for i in 4:
		deck.append("defend")
	deck.append("bash")
	_new_enemy()
	draw_pile = deck.duplicate()
	draw_pile.shuffle()
	discard = []
	hand = []
	_start_turn()


func _new_enemy() -> void:
	emax = 30 + elvl * 14
	ehp = emax
	intent = 7 + elvl * 3


func _start_turn() -> void:
	energy = 3
	block = 0
	for c in hand:
		discard.append(c)
	hand = []
	for i in 5:
		if draw_pile.is_empty():
			draw_pile = discard.duplicate()
			draw_pile.shuffle()
			discard = []
		if not draw_pile.is_empty():
			hand.append(draw_pile.pop_back())
	queue_redraw()


func _play(i: int) -> void:
	if i >= hand.size():
		return
	var card: Dictionary = CARDS[hand[i]]
	if energy < card.cost:
		return
	energy -= card.cost
	ehp -= card.dmg
	block += card.block
	if card.dmg > 0:
		Juice.sfx("thud")
	else:
		Juice.sfx("tick")
	discard.append(hand[i])
	hand.remove_at(i)
	if ehp <= 0:
		add_points(1)
		elvl += 1
		deck.append(CARDS.keys()[randi() % CARDS.size()])
		Juice.sfx("chime")
		_new_enemy()
		draw_pile = deck.duplicate()
		draw_pile.shuffle()
		discard = []
		for c in hand:
			discard.append(c)
		hand = []
		_start_turn()
	queue_redraw()


func _end_turn() -> void:
	var dmg: int = maxi(0, intent - block)
	php -= dmg
	Juice.sfx("boom" if dmg > 8 else "thud")
	if php <= 0:
		end_demo()
		return
	_start_turn()


func _hand_rect(i: int) -> Rect2:
	var n := hand.size()
	var total := n * 170
	var x := (W - total) * 0.5 + i * 170
	return Rect2(x + 8, 940, 154, 160)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	if END_R.has_point(event.position):
		_end_turn()
		return
	for i in hand.size():
		if _hand_rect(i).has_point(event.position):
			_play(i)
			return


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.09, 0.12))
	draw_string(f(), Vector2(0, 160), "FLOOR %d" % elvl, HORIZONTAL_ALIGNMENT_CENTER, W, 34, Color(1, 1, 1, 0.7))
	draw_circle(Vector2(360, 320), 80.0, Color(0.75, 0.3, 0.35))
	draw_rect(Rect2(180, 430, 360, 26), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(180, 430, 360 * clampf(float(ehp) / float(emax), 0, 1), 26), Color(0.9, 0.35, 0.35))
	draw_string(f(), Vector2(180, 425), "FOE %d/%d   intent: hit %d" % [max(0, ehp), emax, intent], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(f(), Vector2(0, 600), "YOU %d/%d   block %d   energy %d/3" % [max(0, php), pmax, block, energy], HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color(0.6, 0.9, 1.0))
	for i in hand.size():
		var card: Dictionary = CARDS[hand[i]]
		var rr := _hand_rect(i)
		draw_rect(rr, card.col if energy >= card.cost else Color(0.3, 0.3, 0.32))
		draw_string(f(), Vector2(rr.position.x, rr.position.y + 44), card.name, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 26, Color.WHITE)
		draw_string(f(), Vector2(rr.position.x, rr.position.y + 90), "%d energy" % card.cost, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 22, Color(1, 1, 1, 0.8))
		var desc := ("%d dmg " % card.dmg if card.dmg > 0 else "") + ("+%d blk" % card.block if card.block > 0 else "")
		draw_string(f(), Vector2(rr.position.x, rr.position.y + 130), desc, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 20, Color(1, 1, 1, 0.7))
	draw_rect(END_R, Color(0.4, 0.35, 0.2))
	draw_string(f(), Vector2(END_R.position.x, END_R.get_center().y + 10), "END\nTURN", HORIZONTAL_ALIGNMENT_CENTER, END_R.size.x, 28, Color.WHITE)
