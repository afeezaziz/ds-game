extends MechDemo
## ARCADE IDLE — the My Mini Mart loop (2021+): walk to the tree to collect,
## carry the stack to the counter to sell, spend on expansions. The genre
## that made "walking = the whole game" a billion-dollar idea. Endless.

var ppos := Vector2(360, 800)
var stick_on := false
var stick_origin := Vector2.ZERO
var move := Vector2.ZERO

var carry := 0
var cap := 8
var money := 0
var trees: Array = [Vector2(150, 480)]
var sell_pos := Vector2(570, 480)
var collect_t := 0.0
var sell_t := 0.0
var helper_on := false
var helper_pos := Vector2.ZERO
var helper_carry := 0
var helper_target := 0  # 0 = to tree, 1 = to counter
var pads: Array = []
var stand_t := 0.0
var stand_pad := -1


func start() -> void:
	super.start()
	ppos = Vector2(360, 800)
	move = Vector2.ZERO
	carry = 0
	cap = 8
	money = 0
	trees = [Vector2(150, 480)]
	helper_on = false
	helper_carry = 0
	helper_pos = Vector2(360, 480)
	pads = [
		{"pos": Vector2(150, 1040), "cost": 60, "label": "2nd TREE", "code": "tree", "done": false},
		{"pos": Vector2(360, 1040), "cost": 80, "label": "BIG BAG", "code": "bag", "done": false},
		{"pos": Vector2(570, 1040), "cost": 150, "label": "HELPER", "code": "helper", "done": false},
	]
	stand_pad = -1
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			stick_on = true
			stick_origin = event.position
			move = Vector2.ZERO
		else:
			stick_on = false
			move = Vector2.ZERO
	elif event is InputEventScreenDrag and stick_on:
		move = ((event.position - stick_origin) / 70.0).limit_length(1.0)


func _process(delta: float) -> void:
	if not running:
		return
	ppos += move * 260.0 * delta
	ppos.x = clampf(ppos.x, 40.0, W - 40.0)
	ppos.y = clampf(ppos.y, 180.0, H - 60.0)

	# collect from any tree
	collect_t -= delta
	for tp in trees:
		if ppos.distance_to(tp) < 80.0 and carry < cap and collect_t <= 0.0:
			collect_t = 0.45
			carry += 1
	# sell at counter
	sell_t -= delta
	if ppos.distance_to(sell_pos) < 80.0 and carry > 0 and sell_t <= 0.0:
		sell_t = 0.22
		carry -= 1
		money += 3
		set_score(score + 3)

	# purchase pads (stand still on one)
	var on_pad := -1
	for i in pads.size():
		if not pads[i].done and ppos.distance_to(pads[i].pos) < 70.0:
			on_pad = i
	if on_pad != stand_pad:
		stand_pad = on_pad
		stand_t = 0.0
	elif on_pad != -1:
		stand_t += delta
		if stand_t > 1.0 and money >= pads[on_pad].cost:
			money -= pads[on_pad].cost
			pads[on_pad].done = true
			match pads[on_pad].code:
				"tree": trees.append(Vector2(150, 720))
				"bag": cap += 8
				"helper": helper_on = true

	# helper NPC ferries goods automatically
	if helper_on:
		var target: Vector2 = trees[0] if helper_target == 0 else sell_pos
		helper_pos += (target - helper_pos).normalized() * 150.0 * delta
		if helper_pos.distance_to(target) < 20.0:
			if helper_target == 0:
				helper_carry = 4
				helper_target = 1
			else:
				money += helper_carry * 3
				set_score(score + helper_carry * 3)
				helper_carry = 0
				helper_target = 0
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.16, 0.2, 0.14))
	for tp in trees:
		draw_circle(tp, 58.0, Color(0.2, 0.5, 0.25))
		draw_circle(tp + Vector2(0, 40), 16.0, Color(0.4, 0.28, 0.18))
	draw_rect(Rect2(sell_pos.x - 70, sell_pos.y - 40, 140, 80), Color(0.3, 0.4, 0.7))
	draw_string(f(), Vector2(sell_pos.x - 70, sell_pos.y + 8), "SELL",
		HORIZONTAL_ALIGNMENT_CENTER, 140, 26, Color.WHITE)
	for p in pads:
		if p.done:
			continue
		draw_rect(Rect2(p.pos.x - 70, p.pos.y - 50, 140, 100), Color(1, 1, 1, 0.08))
		draw_string(f(), Vector2(p.pos.x - 70, p.pos.y - 8), p.label,
			HORIZONTAL_ALIGNMENT_CENTER, 140, 24, Color(1, 1, 0.7))
		draw_string(f(), Vector2(p.pos.x - 70, p.pos.y + 26), "$%d · stand" % p.cost,
			HORIZONTAL_ALIGNMENT_CENTER, 140, 22, Color(1, 1, 1, 0.6))
	if helper_on:
		draw_circle(helper_pos, 16.0, Color(0.9, 0.7, 0.4))
	draw_circle(ppos, 20.0, Color.WHITE)
	for i in carry:
		draw_rect(Rect2(ppos.x - 12, ppos.y - 40 - i * 10.0, 24, 8), Color(0.95, 0.6, 0.3))
	draw_string(f(), Vector2(20, 160), "$ %d    bag %d/%d" % [money, carry, cap],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	draw_string(f(), Vector2(20, H - 16), "drag = walk · tree collects · counter sells · endless",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
