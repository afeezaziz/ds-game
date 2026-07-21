extends MechDemo
## MAZE TD — the tower-defense maze variant. Tap empty cells to build towers;
## creeps pathfind AROUND them, so you route the maze to buy time. You can't
## fully wall them off. Towers auto-shoot. Score = waves survived.

const GW := 8
const GH := 11
const CS := 84.0
const OX := 24.0
const OY := 250.0
const ENTRANCE := Vector2i(0, 0)
const EXIT := Vector2i(7, 10)
const COST := 20
const RANGE := 170.0

var towers: Dictionary = {}   # Vector2i -> cooldown float
var creeps: Array = []
var beams: Array = []
var gold := 80
var lives := 10
var wave := 0
var to_spawn := 0
var spawn_t := 0.0
var wave_t := 3.0


func start() -> void:
	super.start()
	towers = {}
	creeps = []
	beams = []
	gold = 80
	lives = 10
	wave = 0
	to_spawn = 0
	wave_t = 3.0
	queue_redraw()


func _center(c: Vector2i) -> Vector2:
	return Vector2(OX + c.x * CS + CS * 0.5, OY + c.y * CS + CS * 0.5)


func _cell(pos: Vector2) -> Vector2i:
	var c := Vector2i(int((pos.x - OX) / CS), int((pos.y - OY) / CS))
	if c.x < 0 or c.x >= GW or c.y < 0 or c.y >= GH:
		return Vector2i(-1, -1)
	return c


func _bfs(from: Vector2i) -> Vector2i:
	if from == EXIT:
		return from
	var q := [from]
	var came := {from: from}
	while not q.is_empty():
		var c: Vector2i = q.pop_front()
		if c == EXIT:
			break
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if nb.x < 0 or nb.x >= GW or nb.y < 0 or nb.y >= GH:
				continue
			if towers.has(nb):
				continue
			if came.has(nb):
				continue
			came[nb] = c
			q.append(nb)
	if not came.has(EXIT):
		return from
	var cur := EXIT
	while came[cur] != from:
		cur = came[cur]
	return cur


func _reachable() -> bool:
	return _bfs(ENTRANCE) != ENTRANCE or ENTRANCE == EXIT


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var c := _cell(event.position)
	if c == Vector2i(-1, -1) or c == ENTRANCE or c == EXIT or towers.has(c) or gold < COST:
		return
	towers[c] = 0.0
	if not _reachable():
		towers.erase(c)
		Juice.sfx("thud")
		return
	var ok := true
	for cr in creeps:
		if _bfs(cr.cell) == cr.cell and cr.cell != EXIT:
			ok = false
			break
	if not ok:
		towers.erase(c)
		return
	gold -= COST
	for cr in creeps:
		cr.next = _bfs(cr.cell)
	Juice.sfx("coin")
	queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	if to_spawn > 0:
		spawn_t -= delta
		if spawn_t <= 0.0:
			spawn_t = 0.7
			to_spawn -= 1
			var hp := 3 + wave
			creeps.append({"cell": ENTRANCE, "next": _bfs(ENTRANCE), "pos": _center(ENTRANCE), "hp": hp, "maxhp": hp})
	elif creeps.is_empty():
		wave_t -= delta
		if wave_t <= 0.0:
			wave += 1
			to_spawn = 4 + wave
			wave_t = 3.0
			gold += 12 + wave * 3
			set_score(wave)

	var speed := 80.0 + wave * 3.0
	for cr in creeps.duplicate():
		var target := _center(cr.next)
		cr.pos = cr.pos.move_toward(target, speed * delta)
		if cr.pos.distance_to(target) < 3.0:
			cr.cell = cr.next
			if cr.cell == EXIT:
				creeps.erase(cr)
				lives -= 1
				Juice.sfx("boom")
				if lives <= 0:
					end_demo()
					return
				continue
			cr.next = _bfs(cr.cell)

	for cell in towers:
		towers[cell] -= delta
		if towers[cell] > 0.0:
			continue
		var tc := _center(cell)
		var best = null
		var bd := RANGE
		for cr in creeps:
			var d: float = tc.distance_to(cr.pos)
			if d < bd:
				bd = d
				best = cr
		if best != null:
			towers[cell] = 0.45
			best.hp -= 1
			beams.append({"a": tc, "b": best.pos, "t": 0.12})
			if best.hp <= 0:
				creeps.erase(best)
				gold += 4
	for b in beams.duplicate():
		b.t -= delta
		if b.t <= 0.0:
			beams.erase(b)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.13, 0.1))
	draw_string(f(), Vector2(20, 150), "GOLD %d   LIVES %d   WAVE %d" % [gold, lives, wave], HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color.WHITE)
	draw_string(f(), Vector2(20, 200), "tap to build towers (20g) · route the maze", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.55))
	for x in GW:
		for y in GH:
			var c := Vector2i(x, y)
			var rr := Rect2(OX + x * CS + 2, OY + y * CS + 2, CS - 4, CS - 4)
			if c == ENTRANCE:
				draw_rect(rr, Color(0.3, 0.6, 0.35))
			elif c == EXIT:
				draw_rect(rr, Color(0.6, 0.3, 0.3))
			elif towers.has(c):
				draw_rect(rr, Color(0.4, 0.55, 0.9))
				draw_circle(rr.get_center(), 14.0, Color(0.7, 0.8, 1.0))
			else:
				draw_rect(rr, Color(1, 1, 1, 0.04))
	for cr in creeps:
		draw_circle(cr.pos, 16.0, Color(0.9, 0.4, 0.4))
		draw_rect(Rect2(cr.pos.x - 18, cr.pos.y - 26, 36 * clampf(float(cr.hp) / float(cr.maxhp), 0, 1), 5), Color(0.4, 0.9, 0.4))
	for b in beams:
		draw_line(b.a, b.b, Color(1, 1, 0.6, b.t * 7.0), 3.0)
