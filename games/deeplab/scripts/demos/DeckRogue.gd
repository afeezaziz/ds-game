extends MechDemo
## DECK ROGUE — the full Slay the Spire loop: fight with your deck, then draft a
## new card from three, climb floor by floor, rest to heal every fourth floor.
## Death ends the run. Score = floors cleared.

enum S { COMBAT, REWARD, REST }

const CARDS := {
	"strike": {"name": "Strike", "cost": 1, "dmg": 6, "block": 0},
	"defend": {"name": "Defend", "cost": 1, "dmg": 0, "block": 5},
	"bash": {"name": "Bash", "cost": 2, "dmg": 10, "block": 0},
	"heavy": {"name": "Heavy", "cost": 2, "dmg": 8, "block": 4},
	"quick": {"name": "Quick", "cost": 0, "dmg": 3, "block": 0},
	"guard": {"name": "Guard", "cost": 2, "dmg": 0, "block": 12}}
const END_R := Rect2(500, 1130, 190, 120)

var st: S = S.COMBAT
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
var floor_n := 1
var reward: Array = []


func start() -> void:
	super.start()
	php = 60
	pmax = 60
	floor_n = 1
	deck = ["strike", "strike", "strike", "strike", "defend", "defend", "defend", "bash"]
	_combat()


func _combat() -> void:
	st = S.COMBAT
	emax = 24 + floor_n * 9
	ehp = emax
	intent = 6 + floor_n * 2
	draw_pile = deck.duplicate()
	draw_pile.shuffle()
	discard = []
	hand = []
	_start_turn()


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


func _hand_rect(i: int) -> Rect2:
	var n := hand.size()
	var x := (W - n * 168) * 0.5 + i * 168
	return Rect2(x + 6, 950, 156, 160)


func _opt_rect(i: int) -> Rect2:
	return Rect2(80 + i * 190, 600, 170, 220)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	if st == S.COMBAT:
		if END_R.has_point(event.position):
			_end_turn()
			return
		for i in hand.size():
			if _hand_rect(i).has_point(event.position):
				_play(i)
				return
	elif st == S.REWARD:
		for i in reward.size():
			if _opt_rect(i).has_point(event.position):
				deck.append(reward[i])
				Juice.sfx("chime")
				_combat()
				return
	elif st == S.REST:
		if Rect2(200, 700, 320, 160).has_point(event.position):
			php = mini(pmax, php + 25)
			Juice.sfx("chime")
			_combat()


func _play(i: int) -> void:
	var card: Dictionary = CARDS[hand[i]]
	if energy < card.cost:
		return
	energy -= card.cost
	ehp -= card.dmg
	block += card.block
	Juice.sfx("thud" if card.dmg > 0 else "tick")
	discard.append(hand[i])
	hand.remove_at(i)
	if ehp <= 0:
		_win()
	queue_redraw()


func _end_turn() -> void:
	var dmg: int = maxi(0, intent - block)
	php -= dmg
	Juice.sfx("boom" if dmg > 8 else "thud")
	if php <= 0:
		end_demo()
		return
	_start_turn()


func _win() -> void:
	add_points(1)
	floor_n += 1
	if floor_n % 4 == 0:
		st = S.REST
	else:
		var keys: Array = CARDS.keys()
		keys.shuffle()
		reward = keys.slice(0, 3)
		st = S.REWARD
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.09, 0.12))
	draw_string(f(), Vector2(0, 130), "FLOOR %d   ·   deck %d cards" % [floor_n, deck.size()], HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color(1, 1, 1, 0.7))
	if st == S.COMBAT:
		draw_circle(Vector2(360, 300), 76.0, Color(0.75, 0.3, 0.35))
		draw_rect(Rect2(180, 410, 360, 24), Color(0, 0, 0, 0.4))
		draw_rect(Rect2(180, 410, 360 * clampf(float(ehp) / float(emax), 0, 1), 24), Color(0.9, 0.35, 0.35))
		draw_string(f(), Vector2(180, 402), "FOE %d/%d   intent: hit %d" % [max(0, ehp), emax, intent], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		draw_string(f(), Vector2(0, 560), "YOU %d/%d   block %d   energy %d/3" % [max(0, php), pmax, block, energy], HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color(0.6, 0.9, 1.0))
		for i in hand.size():
			var card: Dictionary = CARDS[hand[i]]
			var rr := _hand_rect(i)
			draw_rect(rr, Color(0.4, 0.5, 0.7) if energy >= card.cost else Color(0.3, 0.3, 0.32))
			draw_string(f(), Vector2(rr.position.x, rr.position.y + 46), card.name, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 26, Color.WHITE)
			draw_string(f(), Vector2(rr.position.x, rr.position.y + 92), "%d energy" % card.cost, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 22, Color(1, 1, 1, 0.8))
			var desc := ("%d dmg " % card.dmg if card.dmg > 0 else "") + ("+%d blk" % card.block if card.block > 0 else "")
			draw_string(f(), Vector2(rr.position.x, rr.position.y + 132), desc, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 20, Color(1, 1, 1, 0.7))
		draw_rect(END_R, Color(0.4, 0.35, 0.2))
		draw_string(f(), Vector2(END_R.position.x, END_R.get_center().y + 10), "END\nTURN", HORIZONTAL_ALIGNMENT_CENTER, END_R.size.x, 26, Color.WHITE)
	elif st == S.REWARD:
		draw_string(f(), Vector2(0, 500), "DRAFT A CARD", HORIZONTAL_ALIGNMENT_CENTER, W, 40, Color.WHITE)
		for i in reward.size():
			var card: Dictionary = CARDS[reward[i]]
			var rr := _opt_rect(i)
			draw_rect(rr, Color(0.35, 0.45, 0.6))
			draw_string(f(), Vector2(rr.position.x, rr.position.y + 70), card.name, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 26, Color.WHITE)
			draw_string(f(), Vector2(rr.position.x, rr.position.y + 120), "%d energy" % card.cost, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 22, Color(1, 1, 1, 0.8))
			var desc := ("%d dmg " % card.dmg if card.dmg > 0 else "") + ("+%d blk" % card.block if card.block > 0 else "")
			draw_string(f(), Vector2(rr.position.x, rr.position.y + 160), desc, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 20, Color(1, 1, 1, 0.7))
	else:
		draw_string(f(), Vector2(0, 560), "REST SITE", HORIZONTAL_ALIGNMENT_CENTER, W, 44, Color.WHITE)
		draw_rect(Rect2(200, 700, 320, 160), Color(0.3, 0.45, 0.3))
		draw_string(f(), Vector2(200, 790), "HEAL +25", HORIZONTAL_ALIGNMENT_CENTER, 320, 34, Color.WHITE)
