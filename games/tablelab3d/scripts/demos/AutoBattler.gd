extends MechDemo3D
## AUTO BATTLER — draft, combine, auto-fight (auto-chess / TFT). Spend gold to BUY
## units from the shop; three of a kind auto-COMBINE into a starred unit. When ready,
## FIGHT: your board resolves on its own against a scaling enemy — you win by drafting
## and combining, not by clicking. Lose all HP and it's over. Desktop: J buy, K reroll, SPACE fight.

var gold := 4
var hp := 30
var round_no := 1
var shop: Array = []          # names
var board := {}               # name -> {count, star}
var msg := ""
var msg_t := 0.0
var tc: TouchControls
var hud: Label3D
var unit_nodes: Array = []
const UNITS := ["Knight", "Archer", "Mage", "Golem", "Rogue"]
const BASE := {"Knight": 6, "Archer": 5, "Mage": 7, "Golem": 9, "Rogue": 4}


func start() -> void:
	super.start()
	setup_world(Color(0.14, 0.12, 0.18), 0.85, Vector3(-55, -25, 0))
	static_box(Vector3(30, 1, 20), Vector3(0, -0.5, 0), Color(0.22, 0.2, 0.28))
	gold = 4
	hp = 30
	round_no = 1
	board = {}
	_reroll()
	make_camera(Vector3(0, 13, 16), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 8, 0), 28, Color.WHITE)
	tc = add_touch_controls([
		{"id": "buy", "label": "BUY", "col": Color(0.6, 0.85, 0.5)},
		{"id": "reroll", "label": "REROLL $1", "col": Color(0.6, 0.65, 0.9)},
		{"id": "fight", "label": "FIGHT", "col": Color(0.9, 0.5, 0.4)},
	], false, false)
	tc.action.connect(func(id):
		if id == "buy": _buy()
		elif id == "reroll": _reroll(true)
		elif id == "fight": _fight())


func _reroll(paid := false) -> void:
	if paid:
		if gold < 1:
			return
		gold -= 1
	shop = []
	for i in 4:
		shop.append(UNITS[randi() % UNITS.size()])


func _buy() -> void:
	if shop.is_empty() or gold < 3:
		return
	gold -= 3
	var name: String = shop.pop_front()
	if not board.has(name):
		board[name] = {"count": 0, "star": 1}
	board[name].count += 1
	# combine three-of-a-kind into a star-up
	if board[name].count >= 3:
		board[name].count -= 3
		board[name].star += 1
		Juice.sfx("coin")
		Juice.flash(Color(1, 0.9, 0.5), 0.25)
		Juice.popup("%s ★%d!" % [name, board[name].star], Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))
	else:
		Juice.sfx("tick")
	_redraw_units()


func _power() -> int:
	var p := 0
	for name in board.keys():
		var b = board[name]
		p += BASE[name] * b.star * b.star * (b.count + (b.star - 1) * 3)
	return p


func _fight() -> void:
	var mine := _power()
	var foe := 20 + round_no * 14
	gold += 3 + mini(gold / 10, 3)      # interest
	if mine >= foe:
		round_no += 1
		add_points(2)
		Juice.sfx("chime")
		Juice.flash(Color(0.6, 0.9, 1.0), 0.25)
		_say("WON round %d  (%d vs %d)" % [round_no - 1, mine, foe])
	else:
		var dmg := 3 + (foe - mine) / 12
		hp -= dmg
		Juice.sfx("boom")
		Juice.flash(Color(1, 0.3, 0.3), 0.3)
		Juice.haptic(30)
		_say("LOST  (%d vs %d)  -%d HP" % [mine, foe, dmg])
		if hp <= 0:
			end_demo()
			return
	_reroll()


func _say(t: String) -> void:
	msg = t
	msg_t = 2.5


func _redraw_units() -> void:
	for n in unit_nodes:
		n.queue_free()
	unit_nodes = []
	var i := 0
	for name in board.keys():
		var b = board[name]
		if b.count <= 0 and b.star <= 1:
			continue
		var node := mesh_box(Vector3(1.4, 1.0 + b.star * 0.6, 1.4), Vector3((i - 2) * 2.4, 0.6, -4), hue_col(UNITS.find(name) * 0.18, 0.6, 0.9))
		unit_nodes.append(node)
		i += 1


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: _buy()
		elif event.keycode == KEY_K: _reroll(true)
		elif event.keycode == KEY_SPACE: _fight()


func _process(_delta: float) -> void:
	if not running:
		return
	msg_t = maxf(0.0, msg_t - _delta)
	cam.look_at(Vector3.ZERO, Vector3.UP)
	var shop_s := ""
	for s in shop:
		shop_s += "%s($3) " % s
	var board_s := ""
	for name in board.keys():
		var b = board[name]
		if b.count > 0 or b.star > 1:
			board_s += "%s★%dx%d " % [name, b.star, b.count]
	hud.text = "ROUND %d   HP %d   GOLD %d   power %d\nSHOP: %s\nBOARD: %s\n%s" % [
		round_no, hp, gold, _power(), shop_s if shop_s != "" else "-",
		board_s if board_s != "" else "-", msg if msg_t > 0.0 else ""]
	hud.position = Vector3(0, 8, 0)
