extends MechDemo
## FARM — plant, wait, harvest, expand (FarmVille / Hay Day). Tap an empty plot
## to plant; tap a ripe (gold) plot to harvest coins; buy more plots. Endless;
## score = coins.

const GROW := 4.0
const CS := 200.0
const OX := 60.0
const OY := 320.0
const BUY_R := Rect2(200, 1120, 320, 130)

var plots: Array = []   # {state:0/1/2, t}
var coins := 0


func start() -> void:
	super.start()
	plots = []
	for i in 6:
		plots.append({"state": 0, "t": 0.0})
	coins = 0
	queue_redraw()


func _rect(i: int) -> Rect2:
	var c := i % 3
	var r := i / 3
	return Rect2(OX + c * CS, OY + r * CS, CS - 16, CS - 16)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	if BUY_R.has_point(event.position):
		var cost := plots.size() * 15
		if coins >= cost:
			coins -= cost
			plots.append({"state": 0, "t": 0.0})
			set_score(coins)
			Juice.sfx("tick")
		queue_redraw()
		return
	for i in plots.size():
		if _rect(i).has_point(event.position):
			var p: Dictionary = plots[i]
			if p.state == 0:
				p.state = 1
				p.t = GROW
				Juice.sfx("tick")
			elif p.state == 2:
				p.state = 0
				coins += 8
				set_score(coins)
				Juice.sfx("coin")
			queue_redraw()
			return


func _process(delta: float) -> void:
	if not running:
		return
	var dirty := false
	for p in plots:
		if p.state == 1:
			p.t -= delta
			if p.t <= 0.0:
				p.state = 2
				dirty = true
	if dirty:
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.35, 0.5, 0.3))
	draw_string(f(), Vector2(0, 220), "COINS %d" % coins, HORIZONTAL_ALIGNMENT_CENTER, W, 48, Color(1, 0.9, 0.4))
	for i in plots.size():
		var rr := _rect(i)
		var p: Dictionary = plots[i]
		var col := Color(0.45, 0.32, 0.2)
		if p.state == 1:
			col = Color(0.4, 0.6, 0.35)
		elif p.state == 2:
			col = Color(0.95, 0.8, 0.3)
		draw_rect(rr, col)
		if p.state == 1:
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y), "%.0fs" % max(0.0, p.t), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 34, Color.WHITE)
		elif p.state == 2:
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y), "HARVEST", HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 28, Color(0.2, 0.2, 0.1))
	draw_rect(BUY_R, Color(0.3, 0.4, 0.5))
	draw_string(f(), Vector2(BUY_R.position.x, BUY_R.get_center().y + 10), "BUY PLOT  $%d" % (plots.size() * 15), HORIZONTAL_ALIGNMENT_CENTER, BUY_R.size.x, 30, Color.WHITE)
