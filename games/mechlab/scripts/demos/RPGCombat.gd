extends MechDemo
## RPG COMBAT — turn-based menu battle (Final Fantasy / Pokémon). Attack,
## Defend (halve next hit), or Heal. Beat foes to level the fight up. Score =
## foes defeated.

const BTN := [Rect2(40, 1040, 200, 150), Rect2(260, 1040, 200, 150), Rect2(480, 1040, 200, 150)]

var php := 100
var pmax := 100
var patk := 18
var defending := false
var ehp := 40
var emax := 40
var eatk := 8
var elvl := 1
var msg := "Your move"


func start() -> void:
	super.start()
	php = 100
	pmax = 100
	patk = 18
	elvl = 1
	_new_enemy()
	msg = "Your move"
	queue_redraw()


func _new_enemy() -> void:
	emax = 40 + elvl * 16
	ehp = emax
	eatk = 8 + elvl * 3


func _act(kind: int) -> void:
	defending = false
	if kind == 0:
		var d := randi_range(patk - 4, patk + 4)
		ehp -= d
		msg = "You hit for %d" % d
		Juice.sfx("thud")
	elif kind == 1:
		defending = true
		msg = "You brace"
		Juice.sfx("tick")
	else:
		php = mini(pmax, php + 25)
		msg = "You heal 25"
		Juice.sfx("chime")
	if ehp <= 0:
		add_points(1)
		elvl += 1
		patk += 2
		Juice.sfx("chime")
		_new_enemy()
		msg = "Foe down! Next: Lv%d" % elvl
		queue_redraw()
		return
	var ed := randi_range(eatk - 3, eatk + 3)
	if defending:
		ed = int(ed * 0.5)
	php -= ed
	msg += "   ·   Foe hits %d" % ed
	if php <= 0:
		Juice.sfx("boom")
		end_demo()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	for i in 3:
		if BTN[i].has_point(event.position):
			_act(i)
			return


func _bar(x: float, y: float, w: float, frac: float, col: Color) -> void:
	draw_rect(Rect2(x, y, w, 30), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(x, y, w * clampf(frac, 0, 1), 30), col)


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.1, 0.14))
	draw_string(f(), Vector2(0, 200), "FOE  Lv%d" % elvl, HORIZONTAL_ALIGNMENT_CENTER, W, 40, Color.WHITE)
	draw_circle(Vector2(360, 380), 90.0, Color(0.8, 0.3, 0.35))
	_bar(160, 500, 400, float(ehp) / float(emax), Color(0.9, 0.35, 0.35))
	draw_string(f(), Vector2(160, 490), "%d / %d" % [max(0, ehp), emax], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_circle(Vector2(360, 760), 70.0, Color(0.4, 0.7, 0.95))
	_bar(160, 860, 400, float(php) / float(pmax), Color(0.4, 0.85, 0.45))
	draw_string(f(), Vector2(160, 850), "YOU  %d / %d" % [max(0, php), pmax], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	draw_string(f(), Vector2(0, 960), msg, HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(0.8, 0.9, 1.0))
	var labels := ["ATTACK", "DEFEND", "HEAL"]
	var cols := [Color(0.5, 0.3, 0.3), Color(0.3, 0.4, 0.5), Color(0.3, 0.5, 0.35)]
	for i in 3:
		draw_rect(BTN[i], cols[i])
		draw_string(f(), Vector2(BTN[i].position.x, BTN[i].get_center().y + 12), labels[i],
			HORIZONTAL_ALIGNMENT_CENTER, BTN[i].size.x, 30, Color.WHITE)
