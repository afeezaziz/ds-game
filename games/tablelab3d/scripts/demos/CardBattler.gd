extends MechDemo3D
## CARD BATTLER — mana, minions, lethal (Hearthstone). Each turn your mana grows;
## SELECT a card and PLAY it (minions cost mana), then END TURN — your board trades
## into the enemy board or swings at their hero. Drop the enemy hero to face a tougher
## one; your hero at 0 ends it. Desktop: J select, K play, SPACE end turn.

var php := 30
var ehp := 30
var mana := 1
var mana_max := 1
var hand: Array = []          # {cost,atk,hp}
var pboard: Array = []        # {atk,hp,ready}
var eboard: Array = []        # {atk,hp}
var sel := 0
var opp := 1
var msg := ""
var msg_t := 0.0
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.12, 0.1, 0.16), 0.85, Vector3(-55, -20, 0))
	static_box(Vector3(30, 1, 18), Vector3(0, -0.5, 0), Color(0.2, 0.22, 0.3))
	php = 30
	ehp = 30
	mana = 1
	mana_max = 1
	opp = 1
	hand = []
	pboard = []
	eboard = []
	for i in 3:
		_draw()
	make_camera(Vector3(0, 12, 15), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 8, 0), 28, Color.WHITE)
	tc = add_touch_controls([
		{"id": "select", "label": "SELECT", "col": Color(0.6, 0.65, 0.9)},
		{"id": "play", "label": "PLAY", "col": Color(0.6, 0.85, 0.5)},
		{"id": "end", "label": "END TURN", "col": Color(0.9, 0.7, 0.4)},
	], false, false)
	tc.action.connect(func(id):
		if id == "select": sel = (sel + 1) % maxi(1, hand.size())
		elif id == "play": _play()
		elif id == "end": _end_turn())


func _draw() -> void:
	if hand.size() >= 6:
		return
	var cost := randi_range(1, 6)
	hand.append({"cost": cost, "atk": cost + randi_range(0, 1), "hp": cost + randi_range(0, 2)})


func _play() -> void:
	if hand.is_empty():
		return
	sel = clampi(sel, 0, hand.size() - 1)
	var c = hand[sel]
	if c.cost > mana:
		_say("not enough mana")
		return
	mana -= c.cost
	pboard.append({"atk": c.atk, "hp": c.hp, "ready": false})
	hand.remove_at(sel)
	sel = 0
	Juice.sfx("tick")


func _end_turn() -> void:
	# your minions attack
	for m in pboard:
		if not m.ready:
			continue
		if not eboard.is_empty():
			var t = eboard[0]
			t.hp -= m.atk
			m.hp -= t.atk
			if t.hp <= 0: eboard.pop_front()
		else:
			ehp -= m.atk
			Juice.sfx("thud")
	pboard = pboard.filter(func(m): return m.hp > 0)
	if ehp <= 0:
		_beat_opp()
		return
	# enemy turn
	mana_max = mini(10, mana_max + 1)
	var emana := mana_max
	while emana >= 2 and eboard.size() < 6:
		var cost := randi_range(2, mini(emana, 5))
		emana -= cost
		eboard.append({"atk": cost, "hp": cost + 1})
	for e in eboard:
		if not pboard.is_empty():
			var t = pboard[0]
			t.hp -= e.atk
			e.hp -= t.atk
			if t.hp <= 0: pboard.pop_front()
		else:
			php -= e.atk
			Juice.flash(Color(1, 0.3, 0.3), 0.15)
			Juice.haptic(15)
	eboard = eboard.filter(func(e): return e.hp > 0)
	pboard = pboard.filter(func(m): return m.hp > 0)
	if php <= 0:
		end_demo()
		return
	# your new turn
	mana = mana_max
	for m in pboard:
		m.ready = true
	_draw()
	_say("your turn — mana %d" % mana)


func _beat_opp() -> void:
	opp += 1
	add_points(2)
	php = mini(30, php + 8)
	ehp = 30 + opp * 4
	eboard = []
	Juice.sfx("coin")
	Juice.flash(Color(1, 0.9, 0.5), 0.3)
	_say("Hero down! Opponent %d" % opp)
	mana = mana_max
	for m in pboard:
		m.ready = true


func _say(t: String) -> void:
	msg = t
	msg_t = 2.0


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: sel = (sel + 1) % maxi(1, hand.size())
		elif event.keycode == KEY_K: _play()
		elif event.keycode == KEY_SPACE: _end_turn()


func _process(_delta: float) -> void:
	if not running:
		return
	msg_t = maxf(0.0, msg_t - _delta)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	var hand_s := ""
	for i in hand.size():
		var c = hand[i]
		hand_s += "%s[%d/%d/%d]%s " % ["▶" if i == sel else "", c.cost, c.atk, c.hp, ""]
	var pb := ""
	for m in pboard:
		pb += "(%d/%d)%s " % [m.atk, m.hp, "" if m.ready else "z"]
	var eb := ""
	for e in eboard:
		eb += "(%d/%d) " % [e.atk, e.hp]
	hud.text = "YOU %d  vs  OPP#%d %d   MANA %d/%d\nhand: %s\nyour board: %s\nenemy board: %s\n%s" % [
		php, opp, ehp, mana, mana_max, hand_s if hand_s != "" else "-",
		pb if pb != "" else "-", eb if eb != "" else "-", msg if msg_t > 0.0 else ""]
	hud.position = Vector3(0, 8, 0)
