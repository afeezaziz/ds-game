extends MechDemo
## PUSH YOUR LUCK — keep drawing to build toward 21; bust and you lose the
## round (and a life). Bank to lock in points; 18-21 pays a bonus. Three lives.
## (Blackjack / Balatro tension.) Score = banked points.

const DRAW_R := Rect2(60, 820, 280, 160)
const BANK_R := Rect2(380, 820, 280, 160)

var total := 0
var round_pts := 0
var lives := 3
var last_card := 0
var msg := ""


func start() -> void:
	super.start()
	total = 0
	round_pts = 0
	lives = 3
	last_card = 0
	msg = "draw to start"
	queue_redraw()


func _draw_card() -> void:
	last_card = randi_range(1, 11)
	total += last_card
	round_pts += last_card
	if total > 21:
		lives -= 1
		msg = "BUST! (-1 life)"
		Juice.sfx("boom")
		Juice.haptic(40)
		total = 0
		round_pts = 0
		if lives <= 0:
			end_demo()
	else:
		msg = "drew %d — total %d" % [last_card, total]
		Juice.sfx("tick")
	queue_redraw()


func _bank() -> void:
	if round_pts == 0:
		return
	var bonus := 10 if total >= 18 and total <= 21 else 0
	add_points(round_pts + bonus)
	msg = "banked %d%s" % [round_pts, "  +BONUS" if bonus > 0 else ""]
	Juice.sfx("chime")
	total = 0
	round_pts = 0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	if DRAW_R.has_point(event.position):
		_draw_card()
	elif BANK_R.has_point(event.position):
		_bank()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.12, 0.1, 0.16))
	draw_string(f(), Vector2(0, 240), "PUSH YOUR LUCK", HORIZONTAL_ALIGNMENT_CENTER, W, 44, Color.WHITE)
	draw_string(f(), Vector2(0, 380), str(total), HORIZONTAL_ALIGNMENT_CENTER, W, 150,
		Color(1, 0.4, 0.4) if total > 18 else Color(0.9, 0.85, 0.4))
	draw_string(f(), Vector2(0, 470), "this round: %d" % round_pts, HORIZONTAL_ALIGNMENT_CENTER, W, 32, Color(1, 1, 1, 0.7))
	draw_string(f(), Vector2(0, 540), "LIVES " + "* ".repeat(lives), HORIZONTAL_ALIGNMENT_CENTER, W, 34, Color(1, 0.5, 0.5))
	draw_string(f(), Vector2(0, 620), msg, HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color(0.7, 0.9, 1.0))
	draw_rect(DRAW_R, Color(0.25, 0.45, 0.3))
	draw_string(f(), Vector2(DRAW_R.position.x, DRAW_R.get_center().y + 14), "DRAW",
		HORIZONTAL_ALIGNMENT_CENTER, DRAW_R.size.x, 44, Color.WHITE)
	draw_rect(BANK_R, Color(0.45, 0.4, 0.2))
	draw_string(f(), Vector2(BANK_R.position.x, BANK_R.get_center().y + 14), "BANK",
		HORIZONTAL_ALIGNMENT_CENTER, BANK_R.size.x, 44, Color.WHITE)
