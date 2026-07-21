extends MechDemo
## ROGUELIKE RUN — a branching map of encounters (Slay the Spire / FTL / Hades).
## Tap a reachable node to take that path; it resolves against your HP, power,
## gold and relics. Beat the boss to ascend into a harder map. HP 0 = run over.
## Score = bosses felled.

const COLS := 6
const TYPES := ["FIGHT", "ELITE", "SHOP", "REST", "TREASURE"]
const TCOL := {
	"START": Color(0.6, 0.6, 0.65), "FIGHT": Color(0.85, 0.35, 0.35),
	"ELITE": Color(0.9, 0.55, 0.25), "SHOP": Color(0.4, 0.6, 0.95),
	"REST": Color(0.4, 0.85, 0.5), "TREASURE": Color(0.9, 0.8, 0.3),
	"BOSS": Color(0.7, 0.35, 0.85)}

var cols: Array = []
var current: Dictionary = {}
var reachable: Array = []
var hp := 60
var maxhp := 60
var power := 10
var gold := 0
var relics := 0
var asc := 1
var depth := 0
var msg := "Choose your path"


func start() -> void:
	super.start()
	hp = 60
	maxhp = 60
	power = 10
	gold = 0
	relics = 0
	asc = 1
	_gen()
	msg = "Choose your path"
	queue_redraw()


func _gen() -> void:
	depth = 0
	cols = []
	var start_node := {"type": "START", "pos": Vector2(90, 680), "next": []}
	cols.append([start_node])
	for c in range(1, COLS - 1):
		var n := 2 + (randi() % 2)
		var arr := []
		for i in n:
			var y := 380.0 + i * (620.0 / maxf(1, n - 1)) if n > 1 else 680.0
			arr.append({"type": TYPES[randi() % TYPES.size()],
				"pos": Vector2(90 + c * 108.0, y), "next": []})
		cols.append(arr)
	cols.append([{"type": "BOSS", "pos": Vector2(90 + (COLS - 1) * 108.0, 680), "next": []}])
	for c in range(cols.size() - 1):
		for node in cols[c]:
			var nxt: Array = cols[c + 1].duplicate()
			nxt.sort_custom(func(a, b): return absf(a.pos.y - node.pos.y) < absf(b.pos.y - node.pos.y))
			var k := 1 + (1 if randf() < 0.5 and nxt.size() > 1 else 0)
			for i in mini(k, nxt.size()):
				node.next.append(nxt[i])
	current = start_node
	reachable = start_node.next


func _resolve(node: Dictionary) -> void:
	depth += 1
	match node.type:
		"FIGHT":
			var e := 8 + depth * 4
			var d: int = maxi(0, e - power)
			hp -= d
			gold += 10 + depth * 3
			msg = "Fight — took %d, +gold" % d
			Juice.sfx("thud")
		"ELITE":
			var e := 14 + depth * 6
			var d: int = maxi(0, e - power)
			hp -= d
			relics += 1
			power += 4
			gold += 15
			msg = "Elite! relic: +4 power (took %d)" % d
			Juice.sfx("chime")
		"SHOP":
			if gold >= 20:
				gold -= 20
				power += 3
				msg = "Shop — bought +3 power"
			else:
				hp = mini(maxhp, hp + 10)
				msg = "Shop — browsed (+10 HP)"
			Juice.sfx("coin")
		"REST":
			hp = mini(maxhp, hp + 25)
			msg = "Rest — +25 HP"
			Juice.sfx("tick")
		"TREASURE":
			gold += 25
			if randf() < 0.4:
				power += 3
				msg = "Treasure — gold + relic!"
			else:
				msg = "Treasure — +25 gold"
			Juice.sfx("coin")
		"BOSS":
			var e := 30 + asc * 12
			var d: int = maxi(0, e - power)
			hp -= d
			if hp > 0:
				asc += 1
				add_points(1)
				power += 3
				hp = mini(maxhp, hp + 20)
				msg = "BOSS DOWN — ascend to %d!" % asc
				Juice.sfx("chime")
				Juice.flash(Color(0.8, 0.5, 0.9), 0.25)
				_gen()
				queue_redraw()
				return
	current = node
	reachable = node.next
	if hp <= 0:
		Juice.sfx("boom")
		end_demo()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	for node in reachable:
		if event.position.distance_to(node.pos) < 44.0:
			_resolve(node)
			return


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.08, 0.12))
	draw_string(f(), Vector2(20, 60), "HP %d/%d   POW %d   GOLD %d   RELIC %d   ASC %d" % [max(0, hp), maxhp, power, gold, relics, asc],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)
	draw_string(f(), Vector2(20, 110), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(0.8, 0.9, 1.0))
	for c in range(cols.size() - 1):
		for node in cols[c]:
			for nx in node.next:
				draw_line(node.pos, nx.pos, Color(1, 1, 1, 0.15), 3.0)
	for c in cols.size():
		for node in cols[c]:
			var col: Color = TCOL[node.type]
			var is_reach := reachable.has(node)
			draw_circle(node.pos, 40.0, col if (is_reach or node == current) else Color(col.r, col.g, col.b, 0.35))
			if is_reach:
				draw_arc(node.pos, 46.0, 0, TAU, 32, Color(1, 1, 1, 0.9), 3.0)
			if node == current:
				draw_arc(node.pos, 48.0, 0, TAU, 32, Color(1, 0.9, 0.4), 4.0)
			var t: String = node.type.substr(0, 4)
			draw_string(f(), Vector2(node.pos.x - 40, node.pos.y + 6), t, HORIZONTAL_ALIGNMENT_CENTER, 80, 20, Color(0.1, 0.1, 0.1))
	draw_string(f(), Vector2(20, H - 16), "tap a highlighted node to take that path",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
