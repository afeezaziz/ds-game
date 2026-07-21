extends MechDemo
## TERRITORY.IO — the Paper.io capture loop (2016 io era) vs two AI bots.
## Leave your land to draw a trail; close the loop to capture everything
## inside. Anyone who crosses a trail kills its owner. Multiplayer feel,
## zero netcode. Swipe to steer. Score = tiles owned.

const CW := 36
const CH := 52
const CS := 20.0
const OY := 130.0
const COLORS := [Color(0.35, 0.75, 1.0), Color(0.95, 0.5, 0.35), Color(0.6, 0.9, 0.4)]

var own: Array = []
var players: Array = []
var step_t := 0.0
var _touch_start := Vector2.ZERO


func start() -> void:
	super.start()
	own = []
	for x in CW:
		var col := []
		for y in CH:
			col.append(-1)
		own.append(col)
	players = []
	var starts := [Vector2i(8, 12), Vector2i(27, 26), Vector2i(10, 42)]
	for i in 3:
		players.append({"cell": starts[i], "dir": Vector2i(1, 0), "alive": true,
			"home": starts[i], "trail": {}, "respawn": 0.0})
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				own[starts[i].x + dx][starts[i].y + dy] = i
	step_t = 0.0
	set_score(9)
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_touch_start = event.position
		else:
			var d: Vector2 = event.position - _touch_start
			if d.length() < 30.0:
				return
			var nd := Vector2i(signi(int(d.x)), 0) if absf(d.x) > absf(d.y) \
				else Vector2i(0, signi(int(d.y)))
			if nd != -players[0].dir:
				players[0].dir = nd


func _process(delta: float) -> void:
	if not running:
		return
	for i in [1, 2]:
		if not players[i].alive:
			players[i].respawn -= delta
			if players[i].respawn <= 0.0:
				_respawn_bot(i)
	step_t += delta
	if step_t >= 0.085:
		step_t = 0.0
		for i in 3:
			if players[i].alive:
				if i > 0:
					_bot_steer(i)
				_step(i)
				if not running:
					return
	queue_redraw()


func _step(i: int) -> void:
	var pl: Dictionary = players[i]
	var nc: Vector2i = pl.cell + pl.dir
	if nc.x < 0 or nc.x >= CW or nc.y < 0 or nc.y >= CH:
		_kill(i)
		return
	for j in 3:
		if players[j].alive and players[j].trail.has(nc):
			_kill(j)
			if j == i:
				return
	pl.cell = nc
	if own[nc.x][nc.y] != i:
		pl.trail[nc] = true
	elif pl.trail.size() > 0:
		_capture(i)


func _capture(i: int) -> void:
	var pl: Dictionary = players[i]
	# exterior flood: BFS from all border cells through non-mine, non-trail cells
	var blocked := {}
	for c in pl.trail.keys():
		blocked[c] = true
	var outside := {}
	var queue: Array = []
	for x in CW:
		for y in [0, CH - 1]:
			queue.append(Vector2i(x, y))
	for y in CH:
		for x in [0, CW - 1]:
			queue.append(Vector2i(x, y))
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		if c.x < 0 or c.x >= CW or c.y < 0 or c.y >= CH:
			continue
		if outside.has(c) or blocked.has(c) or own[c.x][c.y] == i:
			continue
		outside[c] = true
		queue.append(c + Vector2i(1, 0))
		queue.append(c + Vector2i(-1, 0))
		queue.append(c + Vector2i(0, 1))
		queue.append(c + Vector2i(0, -1))
	for x in CW:
		for y in CH:
			var c := Vector2i(x, y)
			if own[x][y] != i and not outside.has(c):
				own[x][y] = i
	pl.trail.clear()
	if i == 0:
		var count := 0
		for x in CW:
			for y in CH:
				if own[x][y] == 0:
					count += 1
		set_score(count)


func _kill(i: int) -> void:
	players[i].alive = false
	players[i].trail.clear()
	if i == 0:
		end_demo()
	else:
		players[i].respawn = 2.5


func _respawn_bot(i: int) -> void:
	var c := Vector2i(randi_range(3, CW - 4), randi_range(3, CH - 4))
	players[i].cell = c
	players[i].home = c
	players[i].dir = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)].pick_random()
	players[i].alive = true
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			own[c.x + dx][c.y + dy] = i


func _bot_steer(i: int) -> void:
	var pl: Dictionary = players[i]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	if pl.trail.size() > 16:
		var home_d: Vector2i = pl.home - pl.cell
		var want := Vector2i(signi(home_d.x), 0) if absi(home_d.x) > absi(home_d.y) \
			else Vector2i(0, signi(home_d.y))
		if want != Vector2i.ZERO and want != -pl.dir:
			pl.dir = want
	elif randf() < 0.12:
		var nd: Vector2i = dirs.pick_random()
		if nd != -pl.dir:
			pl.dir = nd
	# emergency: avoid walls and own trail
	for attempt in 4:
		var nc: Vector2i = pl.cell + pl.dir
		var bad := nc.x < 0 or nc.x >= CW or nc.y < 0 or nc.y >= CH or pl.trail.has(nc)
		if not bad:
			return
		pl.dir = dirs.pick_random()


func _draw() -> void:
	draw_rect(Rect2(0, OY, CW * CS, CH * CS), Color(0.1, 0.1, 0.13))
	for x in CW:
		for y in CH:
			if own[x][y] >= 0:
				var c: Color = COLORS[own[x][y]]
				c.a = 0.45
				draw_rect(Rect2(x * CS, OY + y * CS, CS, CS), c)
	for i in 3:
		if not players[i].alive:
			continue
		for tc in players[i].trail.keys():
			var c2: Color = COLORS[i]
			c2.a = 0.85
			draw_rect(Rect2(tc.x * CS, OY + tc.y * CS, CS, CS), c2)
		var hc: Vector2i = players[i].cell
		draw_rect(Rect2(hc.x * CS - 3, OY + hc.y * CS - 3, CS + 6, CS + 6), COLORS[i])
	draw_string(f(), Vector2(20, H - 40), "swipe to steer · close loops to capture",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
	draw_string(f(), Vector2(20, H - 12), "cross a trail = its owner dies (yes, yours too)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
