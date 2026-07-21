extends MechDemo
## TURN TACTICS — grid squad battle (Into the Breach / Fire Emblem). Tap your
## unit, tap a tile in range to move, tap an adjacent foe to strike. END TURN
## and the enemy advances. Wipe the enemy squad to face a tougher one. Score =
## squads defeated.

const N := 8
const CS := 88.0
const OX := 8.0
const OY := 300.0
const END_R := Rect2(220, 1130, 280, 120)

var units: Array = []
var selected: int = -1
var elvl := 1
var msg := "your turn"


func start() -> void:
	super.start()
	elvl = 1
	_setup()
	queue_redraw()


func _setup() -> void:
	units = []
	for i in 3:
		units.append({"side": 0, "x": 2 + i * 2, "y": 6, "hp": 20, "maxhp": 20, "dmg": 7, "mv": 3, "acted": false})
	for i in 2 + elvl:
		units.append({"side": 1, "x": 1 + i, "y": 1, "hp": 14 + elvl * 2, "maxhp": 14 + elvl * 2, "dmg": 5 + elvl, "mv": 2, "acted": false})
	selected = -1
	msg = "your turn"


func _at(x: int, y: int) -> int:
	for i in units.size():
		if units[i].x == x and units[i].y == y and units[i].hp > 0:
			return i
	return -1


func _cell(pos: Vector2) -> Vector2i:
	var c := Vector2i(int((pos.x - OX) / CS), int((pos.y - OY) / CS))
	if c.x < 0 or c.x >= N or c.y < 0 or c.y >= N:
		return Vector2i(-1, -1)
	return c


func _man(a: Dictionary, x: int, y: int) -> int:
	return absi(a.x - x) + absi(a.y - y)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	if END_R.has_point(event.position):
		_enemy_turn()
		return
	var c := _cell(event.position)
	if c == Vector2i(-1, -1):
		return
	var hit := _at(c.x, c.y)
	if selected == -1:
		if hit != -1 and units[hit].side == 0 and not units[hit].acted:
			selected = hit
	else:
		var u: Dictionary = units[selected]
		if hit != -1 and units[hit].side == 1 and _man(u, c.x, c.y) == 1:
			units[hit].hp -= u.dmg
			u.acted = true
			Juice.sfx("thud")
			if units[hit].hp <= 0:
				Juice.sfx("chime")
			selected = -1
			_check()
		elif hit == -1 and _man(u, c.x, c.y) <= u.mv:
			u.x = c.x
			u.y = c.y
			u.acted = true
			Juice.sfx("tick")
			selected = -1
		elif hit != -1 and units[hit].side == 0:
			selected = hit
		else:
			selected = -1
	queue_redraw()


func _enemy_turn() -> void:
	for e in units:
		if e.side != 1 or e.hp <= 0:
			continue
		var tp = _nearest_player(e)
		if tp == null:
			continue
		for step in e.mv:
			if _man(e, tp.x, tp.y) <= 1:
				break
			var nx := e.x + signi(tp.x - e.x)
			var ny := e.y
			if nx == e.x or _at(nx, e.y) != -1:
				nx = e.x
				ny = e.y + signi(tp.y - e.y)
			if _at(nx, ny) == -1 and nx >= 0 and nx < N and ny >= 0 and ny < N:
				e.x = nx
				e.y = ny
		if _man(e, tp.x, tp.y) == 1:
			tp.hp -= e.dmg
			Juice.sfx("thud")
	units = units.filter(func(u): return u.hp > 0)
	for u in units:
		u.acted = false
	var alive := 0
	for u in units:
		if u.side == 0:
			alive += 1
	if alive == 0:
		Juice.sfx("boom")
		end_demo()
		return
	msg = "your turn"
	queue_redraw()


func _nearest_player(e: Dictionary):
	var best = null
	var bd := 999
	for u in units:
		if u.side == 0 and u.hp > 0:
			var d: int = _man(e, u.x, u.y)
			if d < bd:
				bd = d
				best = u
	return best


func _check() -> void:
	units = units.filter(func(u): return u.hp > 0)
	var foes := 0
	for u in units:
		if u.side == 1:
			foes += 1
	if foes == 0:
		add_points(1)
		elvl += 1
		Juice.flash(Color(0.6, 0.9, 0.6), 0.2)
		_setup()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.12, 0.14))
	draw_string(f(), Vector2(20, 130), "SQUAD BATTLE  ·  wave %d" % elvl, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
	draw_string(f(), Vector2(20, 180), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.8, 0.9, 1.0))
	for x in N:
		for y in N:
			draw_rect(Rect2(OX + x * CS + 2, OY + y * CS + 2, CS - 4, CS - 4), Color(1, 1, 1, 0.05 if (x + y) % 2 == 0 else 0.02))
	if selected != -1:
		var u: Dictionary = units[selected]
		for x in N:
			for y in N:
				if _man(u, x, y) <= u.mv and _at(x, y) == -1:
					draw_rect(Rect2(OX + x * CS + 2, OY + y * CS + 2, CS - 4, CS - 4), Color(0.4, 0.7, 1.0, 0.2))
	for i in units.size():
		var u: Dictionary = units[i]
		var cx := OX + u.x * CS + CS * 0.5
		var cy := OY + u.y * CS + CS * 0.5
		draw_circle(Vector2(cx, cy), CS * 0.34, Color(0.4, 0.7, 1.0) if u.side == 0 else Color(0.9, 0.4, 0.4))
		if i == selected:
			draw_arc(Vector2(cx, cy), CS * 0.4, 0, TAU, 24, Color(1, 0.9, 0.4), 3.0)
		draw_rect(Rect2(cx - 28, cy + 24, 56, 6), Color(0, 0, 0, 0.5))
		draw_rect(Rect2(cx - 28, cy + 24, 56 * clampf(float(u.hp) / float(u.maxhp), 0, 1), 6), Color(0.4, 0.9, 0.4))
	draw_rect(END_R, Color(0.4, 0.35, 0.2))
	draw_string(f(), Vector2(END_R.position.x, END_R.get_center().y + 10), "END TURN", HORIZONTAL_ALIGNMENT_CENTER, END_R.size.x, 30, Color.WHITE)
