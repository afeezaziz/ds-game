extends MechDemo
## BASE BUILD + RAID — build economy + defense, raise an army, raid a scaling
## enemy base (Clash of Clans). The enemy raids back, so defense matters. Tap
## a build button to fill the next pad. Score = raids won.

const N := 9
const CS := 200.0
const OX := 60.0
const OY := 300.0
const BUILD := [
	{"key": "MINE", "cost": 20, "col": Color(0.9, 0.8, 0.3)},
	{"key": "BARRACKS", "cost": 40, "col": Color(0.85, 0.4, 0.35)},
	{"key": "WALL", "cost": 30, "col": Color(0.6, 0.6, 0.65)},
	{"key": "TOWER", "cost": 60, "col": Color(0.5, 0.6, 0.95)}]
const RAID_R := Rect2(200, 1130, 320, 120)

var pads: Array = []      # type string or ""
var gold := 60.0
var army := 0.0
var enemy_def := 15.0
var raid_in := 18.0
var msg := "build, then RAID"


func start() -> void:
	super.start()
	pads = []
	for i in N:
		pads.append("")
	gold = 60.0
	army = 0.0
	enemy_def = 15.0
	raid_in = 18.0
	msg = "build, then RAID"
	queue_redraw()


func _count(t: String) -> int:
	var n := 0
	for p in pads:
		if p == t:
			n += 1
	return n


func _defense() -> float:
	return _count("WALL") * 4.0 + _count("TOWER") * 8.0


func _pad_rect(i: int) -> Rect2:
	return Rect2(OX + (i % 3) * CS, OY + (i / 3) * CS, CS - 14, CS - 14)


func _btn_rect(i: int) -> Rect2:
	return Rect2(30 + i * 168, 950, 158, 150)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	if RAID_R.has_point(event.position):
		_raid()
		return
	for i in BUILD.size():
		if _btn_rect(i).has_point(event.position):
			_build(i)
			return


func _build(i: int) -> void:
	var b: Dictionary = BUILD[i]
	if gold < b.cost:
		return
	for j in pads.size():
		if pads[j] == "":
			pads[j] = b.key
			gold -= b.cost
			Juice.sfx("coin")
			queue_redraw()
			return
	msg = "no free pads"


func _raid() -> void:
	if army >= enemy_def:
		add_points(1)
		gold += enemy_def * 1.5
		army -= enemy_def * 0.5
		enemy_def = enemy_def * 1.35 + 5.0
		msg = "RAID WON! +loot"
		Juice.sfx("chime")
	else:
		msg = "army too small (need %d)" % int(enemy_def)
		Juice.sfx("thud")
	queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	gold += _count("MINE") * 2.0 * delta
	army += _count("BARRACKS") * 1.0 * delta
	raid_in -= delta
	if raid_in <= 0.0:
		raid_in = 18.0
		var incoming := enemy_def * 0.8
		if _defense() >= incoming:
			msg = "defended an incoming raid!"
			Juice.sfx("tick")
		else:
			gold *= 0.7
			msg = "raided! lost gold (weak defense)"
			Juice.sfx("boom")
			Juice.flash(Color(0.9, 0.3, 0.3), 0.2)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.14, 0.11))
	draw_string(f(), Vector2(20, 120), "GOLD %d   ARMY %d   DEF %d" % [int(gold), int(army), int(_defense())], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	draw_string(f(), Vector2(20, 170), "enemy base needs %d army   ·   next raid %ds" % [int(enemy_def), int(raid_in)], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 0.7, 0.6))
	draw_string(f(), Vector2(20, 220), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.8, 0.95, 0.8))
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
		draw_rect(br, b.col if gold >= b.cost else Color(0.25, 0.25, 0.28))
		draw_string(f(), Vector2(br.position.x, br.position.y + 66), b.key, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 22, Color(0.1, 0.1, 0.1))
		draw_string(f(), Vector2(br.position.x, br.position.y + 108), "$%d" % b.cost, HORIZONTAL_ALIGNMENT_CENTER, br.size.x, 22, Color(0.1, 0.1, 0.1))
	draw_rect(RAID_R, Color(0.5, 0.3, 0.3))
	draw_string(f(), Vector2(RAID_R.position.x, RAID_R.get_center().y + 10), "RAID", HORIZONTAL_ALIGNMENT_CENTER, RAID_R.size.x, 34, Color.WHITE)
