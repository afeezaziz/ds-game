extends MechDemo
## DUNGEON — a roguelike grid crawler (Pixel Dungeon / Rogue). Swipe or tap a
## neighbour to move; bump a monster to fight; grab loot; find the stairs to
## descend. Fog hides what you haven't seen. HP 0 = over. Score = floors.

const GW := 9
const GH := 12
const CS := 76.0
const OX := 24.0
const OY := 260.0

var walls: Dictionary = {}
var seen: Dictionary = {}
var monsters: Array = []      # {cell, hp, dmg}
var loot: Array = []          # {cell, kind}
var stairs := Vector2i.ZERO
var pcell := Vector2i.ZERO
var hp := 30
var maxhp := 30
var power := 5
var floor_n := 1
var ts := Vector2.ZERO


func start() -> void:
	super.start()
	hp = 30
	maxhp = 30
	power = 5
	floor_n = 1
	_gen()
	queue_redraw()


func _gen() -> void:
	walls = {}
	seen = {}
	monsters = []
	loot = []
	for x in GW:
		for y in GH:
			if (x == 0 or y == 0 or x == GW - 1 or y == GH - 1 or randf() < 0.14):
				walls[Vector2i(x, y)] = true
	pcell = Vector2i(1, 1)
	walls.erase(pcell)
	stairs = Vector2i(GW - 2, GH - 2)
	walls.erase(stairs)
	for i in 4 + floor_n:
		var c := _rand_free()
		if c != Vector2i(-1, -1):
			monsters.append({"cell": c, "hp": 3 + floor_n * 2, "dmg": 2 + floor_n})
	for i in 3:
		var c := _rand_free()
		if c != Vector2i(-1, -1):
			loot.append({"cell": c, "kind": "power" if randf() < 0.5 else "heal"})
	_reveal()


func _rand_free() -> Vector2i:
	for attempt in 40:
		var c := Vector2i(randi_range(1, GW - 2), randi_range(1, GH - 2))
		if not walls.has(c) and c != pcell and c != stairs and _monster_at(c) == -1:
			return c
	return Vector2i(-1, -1)


func _monster_at(c: Vector2i) -> int:
	for i in monsters.size():
		if monsters[i].cell == c:
			return i
	return -1


func _reveal() -> void:
	for dx in range(-2, 3):
		for dy in range(-2, 3):
			seen[pcell + Vector2i(dx, dy)] = true


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch):
		return
	if event.pressed:
		ts = event.position
		return
	var d: Vector2 = event.position - ts
	var dir := Vector2i.ZERO
	if d.length() > 30.0:
		dir = Vector2i(signi(int(d.x)), 0) if absf(d.x) > absf(d.y) else Vector2i(0, signi(int(d.y)))
	else:
		# tap a neighbour cell
		var c := Vector2i(int((event.position.x - OX) / CS), int((event.position.y - OY) / CS))
		var delta := c - pcell
		if absi(delta.x) + absi(delta.y) == 1:
			dir = delta
	if dir != Vector2i.ZERO:
		_step(dir)


func _step(dir: Vector2i) -> void:
	var nc := pcell + dir
	if walls.has(nc):
		return
	var mi := _monster_at(nc)
	if mi != -1:
		monsters[mi].hp -= power
		Juice.sfx("thud")
		if monsters[mi].hp <= 0:
			monsters.remove_at(mi)
			add_points(0)
		else:
			hp -= monsters[mi].dmg
			Juice.haptic(20)
	else:
		pcell = nc
		for l in loot.duplicate():
			if l.cell == pcell:
				if l.kind == "power":
					power += 2
				else:
					hp = mini(maxhp, hp + 12)
				loot.erase(l)
				Juice.sfx("coin")
		if pcell == stairs:
			floor_n += 1
			add_points(1)
			maxhp += 4
			hp = mini(maxhp, hp + 8)
			Juice.sfx("chime")
			_gen()
			queue_redraw()
			return
	# monsters step toward player
	for m in monsters:
		var toward := Vector2i(signi(pcell.x - m.cell.x), 0) if absi(pcell.x - m.cell.x) > absi(pcell.y - m.cell.y) else Vector2i(0, signi(pcell.y - m.cell.y))
		var mc := m.cell + toward
		if not walls.has(mc) and mc != pcell and _monster_at(mc) == -1:
			m.cell = mc
		elif mc == pcell:
			hp -= m.dmg
	_reveal()
	if hp <= 0:
		Juice.sfx("boom")
		end_demo()
		return
	queue_redraw()


func _sc(c: Vector2i) -> Vector2:
	return Vector2(OX + c.x * CS + CS * 0.5, OY + c.y * CS + CS * 0.5)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.06, 0.06, 0.08))
	draw_string(f(), Vector2(20, 150), "FLOOR %d   HP %d/%d   POW %d" % [floor_n, max(0, hp), maxhp, power], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(f(), Vector2(20, 200), "swipe/tap to move · bump monsters to fight", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
	for x in GW:
		for y in GH:
			var c := Vector2i(x, y)
			var rr := Rect2(OX + x * CS + 1, OY + y * CS + 1, CS - 2, CS - 2)
			if not seen.has(c):
				draw_rect(rr, Color(0.02, 0.02, 0.03))
			elif walls.has(c):
				draw_rect(rr, Color(0.25, 0.25, 0.3))
			else:
				draw_rect(rr, Color(0.14, 0.14, 0.18))
	if seen.has(stairs):
		draw_rect(Rect2(OX + stairs.x * CS + 12, OY + stairs.y * CS + 12, CS - 24, CS - 24), Color(0.4, 0.8, 0.5))
	for l in loot:
		if seen.has(l.cell):
			draw_circle(_sc(l.cell), 14.0, Color(0.9, 0.8, 0.3) if l.kind == "power" else Color(0.4, 0.9, 0.5))
	for m in monsters:
		if seen.has(m.cell):
			draw_circle(_sc(m.cell), 22.0, Color(0.85, 0.35, 0.35))
	draw_circle(_sc(pcell), 24.0, Color(0.95, 0.95, 1.0))
