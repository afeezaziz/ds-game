extends MechDemo
## CARD BATTLE — the minion-board card game (Hearthstone, PvE). Spend mana to
## summon minions; tap your minion then a target to attack. End turn and the AI
## answers. Drop the enemy hero to advance. Score = heroes defeated.

const END_R := Rect2(500, 1150, 190, 100)
const POOL := [
	{"n": "Rat", "cost": 1, "a": 1, "h": 2}, {"n": "Wolf", "cost": 2, "a": 3, "h": 2},
	{"n": "Ogre", "cost": 3, "a": 4, "h": 4}, {"n": "Golem", "cost": 4, "a": 5, "h": 6},
	{"n": "Drake", "cost": 5, "a": 6, "h": 5}]

var mana := 1
var mana_max := 1
var hand: Array = []
var my_board: Array = []      # {a, h, sick}
var foe_board: Array = []
var my_hp := 30
var foe_hp := 30
var elvl := 1
var sel := -1                 # index into my_board


func start() -> void:
	super.start()
	my_hp = 30
	elvl = 1
	mana_max = 1
	_new_foe()
	hand = []
	for i in 4:
		_draw_card()
	_start_turn()


func _new_foe() -> void:
	foe_hp = 30 + elvl * 6
	foe_board = []


func _draw_card() -> void:
	hand.append(POOL[randi() % POOL.size()])


func _start_turn() -> void:
	mana_max = mini(10, mana_max + 1)
	mana = mana_max
	for m in my_board:
		m.sick = false
	_draw_card()
	sel = -1
	queue_redraw()


func _hand_rect(i: int) -> Rect2:
	return Rect2(20 + i * 138, 980, 128, 160)


func _mb_rect(i: int) -> Rect2:
	return Rect2(60 + i * 130, 680, 116, 150)


func _fb_rect(i: int) -> Rect2:
	return Rect2(60 + i * 130, 300, 116, 150)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = event.position
	if END_R.has_point(p):
		_end_turn()
		return
	for i in hand.size():
		if _hand_rect(i).has_point(p):
			_play(i)
			return
	for i in my_board.size():
		if _mb_rect(i).has_point(p):
			sel = i if not my_board[i].sick else -1
			queue_redraw()
			return
	if sel >= 0 and sel < my_board.size():
		for i in foe_board.size():
			if _fb_rect(i).has_point(p):
				_attack_minion(sel, i)
				return
		if Rect2(240, 140, 240, 120).has_point(p):
			foe_hp -= my_board[sel].a
			my_board[sel].sick = true
			sel = -1
			Juice.sfx("thud")
			_check()
			return


func _play(i: int) -> void:
	var c: Dictionary = hand[i]
	if mana < c.cost or my_board.size() >= 5:
		return
	mana -= c.cost
	my_board.append({"a": c.a, "h": c.h, "sick": true})
	hand.remove_at(i)
	Juice.sfx("tick")
	queue_redraw()


func _attack_minion(mi: int, fi: int) -> void:
	var m: Dictionary = my_board[mi]
	var e: Dictionary = foe_board[fi]
	e.h -= m.a
	m.h -= e.a
	m.sick = true
	Juice.sfx("thud")
	if e.h <= 0:
		foe_board.remove_at(fi)
	my_board = my_board.filter(func(x): return x.h > 0)
	sel = -1
	queue_redraw()


func _end_turn() -> void:
	# enemy plays + attacks (simple AI)
	var emana := mana_max
	for c in POOL:
		if emana >= c.cost and foe_board.size() < 5:
			emana -= c.cost
			foe_board.append({"a": c.a, "h": c.h, "sick": false})
	for e in foe_board.duplicate():
		if my_board.is_empty():
			my_hp -= e.a
		else:
			var tgt: Dictionary = my_board[randi() % my_board.size()]
			tgt.h -= e.a
			e.h -= tgt.a
	my_board = my_board.filter(func(x): return x.h > 0)
	foe_board = foe_board.filter(func(x): return x.h > 0)
	if my_hp <= 0:
		Juice.sfx("boom")
		end_demo()
		return
	_start_turn()


func _check() -> void:
	if foe_hp <= 0:
		add_points(1)
		elvl += 1
		Juice.sfx("chime")
		_new_foe()
		queue_redraw()


func _minion(rr: Rect2, m: Dictionary, mine: bool) -> void:
	draw_rect(rr, Color(0.35, 0.5, 0.7) if mine else Color(0.6, 0.35, 0.35))
	if mine and m.sick:
		draw_rect(rr, Color(0, 0, 0, 0.3))
	draw_string(f(), Vector2(rr.position.x, rr.get_center().y - 6), "%d/%d" % [m.a, m.h], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 32, Color.WHITE)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.11, 0.14))
	draw_rect(Rect2(240, 140, 240, 120), Color(0.5, 0.25, 0.25))
	draw_string(f(), Vector2(240, 210), "FOE HERO %d" % max(0, foe_hp), HORIZONTAL_ALIGNMENT_CENTER, 240, 28, Color.WHITE)
	draw_string(f(), Vector2(0, 285), "Lv%d" % elvl, HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color(1, 1, 1, 0.6))
	for i in foe_board.size():
		_minion(_fb_rect(i), foe_board[i], false)
	for i in my_board.size():
		_minion(_mb_rect(i), my_board[i], true)
		if i == sel:
			draw_rect(_mb_rect(i), Color(1, 0.9, 0.4), false, 4.0)
	draw_string(f(), Vector2(20, 900), "YOU %d hp    MANA %d/%d" % [max(0, my_hp), mana, mana_max], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.6, 0.9, 1.0))
	for i in hand.size():
		var c: Dictionary = hand[i]
		var rr := _hand_rect(i)
		draw_rect(rr, Color(0.4, 0.45, 0.6) if mana >= c.cost else Color(0.3, 0.3, 0.32))
		draw_string(f(), Vector2(rr.position.x, rr.position.y + 44), c.n, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 24, Color.WHITE)
		draw_string(f(), Vector2(rr.position.x, rr.position.y + 88), "%d mana" % c.cost, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 22, Color(1, 0.9, 0.5))
		draw_string(f(), Vector2(rr.position.x, rr.position.y + 128), "%d/%d" % [c.a, c.h], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 22, Color(1, 1, 1, 0.8))
	draw_rect(END_R, Color(0.4, 0.35, 0.2))
	draw_string(f(), Vector2(END_R.position.x, END_R.get_center().y + 8), "END", HORIZONTAL_ALIGNMENT_CENTER, END_R.size.x, 28, Color.WHITE)
