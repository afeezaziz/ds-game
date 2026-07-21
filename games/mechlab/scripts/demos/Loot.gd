extends MechDemo
## LOOT — the rarity dopamine loop (Diablo / Archero). Open chests to grow your
## power; fight the monster only when you're strong enough. Fight underpowered
## and you lose a life. Score = monsters slain.

const OPEN_R := Rect2(60, 900, 280, 200)
const FIGHT_R := Rect2(380, 900, 280, 200)
const RAR := [
	{"name": "COMMON", "col": Color(0.7, 0.7, 0.7), "w": 55, "val": 2},
	{"name": "RARE", "col": Color(0.4, 0.6, 0.95), "w": 28, "val": 5},
	{"name": "EPIC", "col": Color(0.7, 0.4, 0.9), "w": 13, "val": 12},
	{"name": "LEGENDARY", "col": Color(0.95, 0.7, 0.2), "w": 4, "val": 30}]

var power := 5
var lives := 3
var mon := 12
var last := -1
var pulse := 0.0


func start() -> void:
	super.start()
	power = 5
	lives = 3
	mon = 12
	last = -1
	queue_redraw()


func _open() -> void:
	var total := 0
	for r in RAR:
		total += r.w
	var roll := randi() % total
	var acc := 0
	for i in RAR.size():
		acc += RAR[i].w
		if roll < acc:
			last = i
			power += RAR[i].val
			pulse = 0.4
			Juice.sfx("coin" if i < 2 else "chime")
			if i == 3:
				Juice.flash(RAR[i].col, 0.3)
			break
	queue_redraw()


func _fight() -> void:
	if power >= mon:
		add_points(1)
		mon = int(mon * 1.4) + 3
		Juice.sfx("chime")
		Juice.flash(Color(1, 0.9, 0.5), 0.2)
	else:
		lives -= 1
		Juice.sfx("boom")
		Juice.haptic(40)
		if lives <= 0:
			end_demo()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	if OPEN_R.has_point(event.position):
		_open()
	elif FIGHT_R.has_point(event.position):
		_fight()


func _process(delta: float) -> void:
	if pulse > 0.0:
		pulse -= delta
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.09, 0.13))
	draw_string(f(), Vector2(0, 180), "POWER %d" % power, HORIZONTAL_ALIGNMENT_CENTER, W, 60, Color(0.5, 0.9, 1.0))
	draw_string(f(), Vector2(0, 300), "MONSTER needs %d" % mon, HORIZONTAL_ALIGNMENT_CENTER, W, 40,
		Color(0.5, 0.95, 0.5) if power >= mon else Color(0.95, 0.5, 0.5))
	draw_string(f(), Vector2(0, 370), "LIVES " + "* ".repeat(lives), HORIZONTAL_ALIGNMENT_CENTER, W, 34, Color(1, 0.5, 0.5))
	if last >= 0:
		var r: Dictionary = RAR[last]
		var sz := 150.0 + pulse * 120.0
		draw_circle(Vector2(360, 620), sz, Color(r.col.r, r.col.g, r.col.b, 0.9))
		draw_string(f(), Vector2(0, 630), r.name, HORIZONTAL_ALIGNMENT_CENTER, W, 40, Color(0.1, 0.1, 0.1))
	draw_rect(OPEN_R, Color(0.35, 0.3, 0.2))
	draw_string(f(), Vector2(OPEN_R.position.x, OPEN_R.get_center().y + 12), "OPEN CHEST",
		HORIZONTAL_ALIGNMENT_CENTER, OPEN_R.size.x, 34, Color.WHITE)
	draw_rect(FIGHT_R, Color(0.4, 0.25, 0.25))
	draw_string(f(), Vector2(FIGHT_R.position.x, FIGHT_R.get_center().y + 12), "FIGHT",
		HORIZONTAL_ALIGNMENT_CENTER, FIGHT_R.size.x, 34, Color.WHITE)
