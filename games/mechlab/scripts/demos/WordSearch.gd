extends MechDemo
## WORD SEARCH — drag across a straight line of letters to find the hidden
## words (any direction). 60 seconds. Find all to re-deal. Score = words found.

const G := 8
const CS := 84.0
const OX := 24.0
const OY := 260.0
const POOL := ["CAT", "DOG", "SUN", "MOON", "STAR", "TREE", "FISH", "BIRD",
	"GOLD", "KING", "SHIP", "ROCK", "WIND", "FIRE", "LEAF", "WAVE"]
const AZ := "ABCDEFGHIJKLMNOPQRSTUVWXYZ"

var grid: Array = []
var words: Array = []
var found: Array = []
var sel_a := Vector2i(-1, -1)
var sel_b := Vector2i(-1, -1)
var time_left := 60.0


func start() -> void:
	super.start()
	time_left = 60.0
	_deal()
	queue_redraw()


func _deal() -> void:
	grid = []
	for y in G:
		var row := []
		for x in G:
			row.append("")
		grid.append(row)
	words = []
	found = []
	var pool := POOL.duplicate()
	pool.shuffle()
	for w in pool.slice(0, 5):
		if _place(w):
			words.append(w)
	for y in G:
		for x in G:
			if grid[y][x] == "":
				grid[y][x] = AZ[randi() % 26]


func _place(w: String) -> bool:
	for attempt in 30:
		var horiz := randf() < 0.5
		var x := randi() % (G - (w.length() if horiz else 0))
		var y := randi() % (G - (0 if horiz else w.length()))
		var ok := true
		for i in w.length():
			var cx := x + (i if horiz else 0)
			var cy := y + (0 if horiz else i)
			if grid[cy][cx] != "" and grid[cy][cx] != w[i]:
				ok = false
				break
		if ok:
			for i in w.length():
				var cx := x + (i if horiz else 0)
				var cy := y + (0 if horiz else i)
				grid[cy][cx] = w[i]
			return true
	return false


func _cell(pos: Vector2) -> Vector2i:
	var c := Vector2i(int((pos.x - OX) / CS), int((pos.y - OY) / CS))
	if c.x < 0 or c.x >= G or c.y < 0 or c.y >= G:
		return Vector2i(-1, -1)
	return c


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventScreenTouch and event.pressed:
		sel_a = _cell(event.position)
		sel_b = sel_a
	elif event is InputEventScreenDrag and sel_a != Vector2i(-1, -1):
		sel_b = _cell(event.position)
	elif event is InputEventScreenTouch and not event.pressed and sel_a != Vector2i(-1, -1):
		_test()
		sel_a = Vector2i(-1, -1)
		sel_b = Vector2i(-1, -1)
	queue_redraw()


func _test() -> void:
	if sel_a == Vector2i(-1, -1) or sel_b == Vector2i(-1, -1):
		return
	if sel_a.x != sel_b.x and sel_a.y != sel_b.y:
		return
	var s := ""
	var d := Vector2i(signi(sel_b.x - sel_a.x), signi(sel_b.y - sel_a.y))
	var c := sel_a
	for i in 20:
		s += grid[c.y][c.x]
		if c == sel_b:
			break
		c += d
	var rev := ""
	for i in range(s.length() - 1, -1, -1):
		rev += s[i]
	for w in words:
		if (w == s or w == rev) and not found.has(w):
			found.append(w)
			add_points(1)
			Juice.sfx("chime")
			if found.size() == words.size():
				add_points(10)
				_deal()
			return


func _process(delta: float) -> void:
	if not running:
		return
	time_left -= delta
	if time_left <= 0.0:
		end_demo()
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.1, 0.14))
	draw_string(f(), Vector2(24, 90), "TIME %d" % int(max(0, time_left)), HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color.WHITE)
	var wx := 24.0
	for w in words:
		draw_string(f(), Vector2(wx, 150), w, HORIZONTAL_ALIGNMENT_LEFT, -1, 30,
			Color(0.4, 0.9, 0.5) if found.has(w) else Color(1, 1, 1, 0.6))
		wx += 130.0
	for y in G:
		for x in G:
			var rr := Rect2(OX + x * CS + 3, OY + y * CS + 3, CS - 6, CS - 6)
			var hl := false
			if sel_a != Vector2i(-1, -1) and (sel_a.x == sel_b.x or sel_a.y == sel_b.y):
				var minx := mini(sel_a.x, sel_b.x)
				var maxx := maxi(sel_a.x, sel_b.x)
				var miny := mini(sel_a.y, sel_b.y)
				var maxy := maxi(sel_a.y, sel_b.y)
				if x >= minx and x <= maxx and y >= miny and y <= maxy:
					hl = true
			draw_rect(rr, Color(0.4, 0.55, 0.8) if hl else Color(1, 1, 1, 0.06))
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y + 14), grid[y][x],
				HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 40, Color.WHITE)
