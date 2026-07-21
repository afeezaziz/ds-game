extends MechDemo3D
## GOLD MINE 3D — walk to the vein to mine, carry ore to the bank to sell,
## stand on pads to upgrade (bigger bag, faster mine, helper). Endless;
## score = gold banked. Desktop: WASD or drag to walk.

var miner: MeshInstance3D
var mpos := Vector2(0, 6)
var stick := false
var origin := Vector2.ZERO
var move := Vector2.ZERO
var carry := 0
var cap := 6
var money := 0
var mine_t := 0.0
var sell_t := 0.0
var pads: Array = []
var stand := -1
var stand_t := 0.0
var helper := false
var helper_pos := Vector2.ZERO
var helper_to := 0
var vein := Vector2(-6, -6)
var bank := Vector2(6, -6)
var carry_label: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.3, 0.35, 0.4), 0.9, Vector3(-65, -25, 0))
	static_box(Vector3(28, 1, 28), Vector3(0, -0.5, 0), Color(0.3, 0.28, 0.24))
	mesh_box(Vector3(2.5, 2.5, 2.5), Vector3(vein.x, 1.25, vein.y), Color(0.9, 0.75, 0.2))
	mesh_box(Vector3(3, 1.5, 3), Vector3(bank.x, 0.75, bank.y), Color(0.3, 0.5, 0.85))
	label3d("MINE", Vector3(vein.x, 3.2, vein.y), 34, Color(1, 0.9, 0.4))
	label3d("BANK", Vector3(bank.x, 2.6, bank.y), 34, Color(0.7, 0.85, 1.0))
	miner = mesh_box(Vector3(0.9, 1.5, 0.9), Vector3(mpos.x, 0.75, mpos.y), Color(0.95, 0.9, 0.5))
	carry_label = label3d("", Vector3(0, 2.2, 0), 32, Color.WHITE)
	mpos = Vector2(0, 6)
	carry = 0
	cap = 6
	money = 0
	helper = false
	helper_pos = Vector2(0, 0)
	pads = [
		{"pos": Vector2(-6, 6), "cost": 40, "label": "BAG+", "code": "bag", "done": false},
		{"pos": Vector2(0, 8), "cost": 60, "label": "MINE+", "code": "mine", "done": false},
		{"pos": Vector2(6, 6), "cost": 120, "label": "HELPER", "code": "helper", "done": false},
	]
	for p in pads:
		mesh_box(Vector3(2, 0.2, 2), Vector3(p.pos.x, 0.1, p.pos.y), Color(1, 1, 1, 0.12))
		label3d("%s $%d" % [p.label, p.cost], Vector3(p.pos.x, 1.4, p.pos.y), 26, Color(1, 1, 0.7))
	stand = -1
	make_camera(Vector3(0, 18, 16), Vector3(0, 0, 0), 55.0)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		stick = event.pressed
		origin = event.position
		move = Vector2.ZERO
	elif event is InputEventScreenDrag and stick:
		move = ((event.position - origin) / 70.0).limit_length(1.0)


var mine_rate := 0.4


func _process(delta: float) -> void:
	if not running:
		return
	var mv := move + Vector2(key_axis_x(), -key_axis_y())
	mpos += mv.limit_length(1.0) * 7.0 * delta
	mpos.x = clampf(mpos.x, -13, 13)
	mpos.y = clampf(mpos.y, -13, 13)
	miner.position = Vector3(mpos.x, 0.75, mpos.y)

	mine_t -= delta
	if mpos.distance_to(vein) < 2.6 and carry < cap and mine_t <= 0.0:
		mine_t = mine_rate
		carry += 1
		Juice.sfx("tick")
	sell_t -= delta
	if mpos.distance_to(bank) < 2.6 and carry > 0 and sell_t <= 0.0:
		sell_t = 0.15
		carry -= 1
		money += 4
		set_score(money)

	var on := -1
	for i in pads.size():
		if not pads[i].done and mpos.distance_to(pads[i].pos) < 1.4:
			on = i
	if on != stand:
		stand = on
		stand_t = 0.0
	elif on != -1:
		stand_t += delta
		if stand_t > 0.8 and money >= pads[on].cost:
			money -= pads[on].cost
			set_score(money)
			pads[on].done = true
			match pads[on].code:
				"bag": cap += 8
				"mine": mine_rate = 0.2
				"helper": helper = true

	if helper:
		var target: Vector2 = vein if helper_to == 0 else bank
		helper_pos += (target - helper_pos).normalized() * 5.0 * delta
		if helper_pos.distance_to(target) < 0.8:
			if helper_to == 0:
				helper_to = 1
			else:
				money += 12
				set_score(money)
				helper_to = 0

	carry_label.text = "%d/%d  $%d" % [carry, cap, money]
	carry_label.position = Vector3(mpos.x, 2.4, mpos.y)
