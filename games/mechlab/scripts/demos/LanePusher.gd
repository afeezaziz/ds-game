extends MechDemo
## LANE PUSHER — spend regenerating elixir to spawn units that auto-march and
## fight (Clash Royale, PvE). Drop the enemy tower to advance; lose yours and
## it's over. Score = enemy towers destroyed.

const LANE_Y := 720.0
const FX := 90.0     # your tower x
const EX := 630.0    # enemy tower x
const UNITS := {
	"knight": {"cost": 3, "hp": 30, "dmg": 14, "spd": 55, "col": Color(0.4, 0.6, 0.95)},
	"archer": {"cost": 2, "hp": 14, "dmg": 9, "spd": 65, "col": Color(0.5, 0.85, 0.55)},
	"giant": {"cost": 5, "hp": 70, "dmg": 20, "spd": 40, "col": Color(0.85, 0.6, 0.3)}}
const KEYS := ["knight", "archer", "giant"]

var elixir := 5.0
var friends: Array = []
var enemies: Array = []
var ftower := 25.0
var etower := 25.0
var espawn_t := 2.0
var roundn := 1


func start() -> void:
	super.start()
	elixir = 5.0
	friends = []
	enemies = []
	ftower = 25.0
	etower = 25.0
	espawn_t = 2.0
	roundn = 1
	queue_redraw()


func _btn(i: int) -> Rect2:
	return Rect2(40 + i * 220, 1080, 200, 160)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	for i in 3:
		if _btn(i).has_point(event.position):
			var u: Dictionary = UNITS[KEYS[i]]
			if elixir >= u.cost:
				elixir -= u.cost
				friends.append({"x": FX + 20, "hp": float(u.hp), "dmg": u.dmg, "spd": u.spd, "col": u.col})
				Juice.sfx("tick")
			return


func _process(delta: float) -> void:
	if not running:
		return
	elixir = minf(10.0, elixir + delta)

	espawn_t -= delta
	if espawn_t <= 0.0:
		espawn_t = randf_range(1.6, 3.0) - roundn * 0.05
		var k: String = KEYS[randi() % 3]
		var u: Dictionary = UNITS[k]
		enemies.append({"x": EX - 20, "hp": float(u.hp) * (1.0 + roundn * 0.1), "dmg": u.dmg, "spd": u.spd, "col": Color(0.85, 0.35, 0.35)})

	_advance(friends, 1.0, delta)
	_advance(enemies, -1.0, delta)

	friends = friends.filter(func(u): return u.hp > 0.0)
	enemies = enemies.filter(func(u): return u.hp > 0.0)

	if etower <= 0.0:
		add_points(1)
		roundn += 1
		etower = 25.0 + roundn * 8.0
		enemies = []
		Juice.sfx("chime")
	if ftower <= 0.0:
		Juice.sfx("boom")
		end_demo()
		return
	queue_redraw()


func _advance(list: Array, dir: float, delta: float) -> void:
	var foes: Array = enemies if dir > 0.0 else friends
	for u in list:
		var target = null
		var td := 44.0
		for e in foes:
			if absf(e.x - u.x) < td:
				td = absf(e.x - u.x)
				target = e
		if target != null:
			target.hp -= u.dmg * delta
			continue
		# attack tower if at the end
		if dir > 0.0 and u.x >= EX - 30.0:
			etower -= u.dmg * delta
			continue
		if dir < 0.0 and u.x <= FX + 30.0:
			ftower -= u.dmg * delta
			continue
		u.x += dir * u.spd * delta


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.14, 0.1))
	draw_rect(Rect2(0, LANE_Y - 60, W, 120), Color(0.22, 0.28, 0.18))
	# towers
	_tower(FX, ftower, Color(0.4, 0.6, 0.95))
	_tower(EX, etower, Color(0.85, 0.35, 0.35))
	for u in friends:
		draw_circle(Vector2(u.x, LANE_Y), 18.0, u.col)
	for u in enemies:
		draw_circle(Vector2(u.x, LANE_Y), 18.0, u.col)
	# elixir
	draw_rect(Rect2(40, 1000, 640, 40), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(40, 1000, 64.0 * elixir, 40), Color(0.75, 0.35, 0.9))
	draw_string(f(), Vector2(40, 990), "ELIXIR %.0f" % elixir, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	for i in 3:
		var u: Dictionary = UNITS[KEYS[i]]
		var rr := _btn(i)
		draw_rect(rr, u.col if elixir >= u.cost else Color(0.28, 0.28, 0.3))
		draw_string(f(), Vector2(rr.position.x, rr.position.y + 70), KEYS[i].to_upper(), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 28, Color.WHITE)
		draw_string(f(), Vector2(rr.position.x, rr.position.y + 115), "%d elixir" % u.cost, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 24, Color(1, 1, 1, 0.85))


func _tower(x: float, hp: float, col: Color) -> void:
	draw_rect(Rect2(x - 40, LANE_Y - 130, 80, 130), col)
	draw_rect(Rect2(x - 40, LANE_Y - 160, 80, 18), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(x - 40, LANE_Y - 160, 80 * clampf(hp / 25.0, 0, 1), 18), Color(0.4, 0.9, 0.4))
