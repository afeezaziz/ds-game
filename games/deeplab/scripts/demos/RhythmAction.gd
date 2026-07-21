extends MechDemo
## RHYTHM ACTION — a beatmap drives combat (Hi-Fi Rush / NecroDancer). Notes
## fall in four lanes; tap on the beat to strike the boss and build a combo.
## Let a note slip past and the boss hits you. Beat a boss to face a tougher
## one. Three hits = over. Score = bosses downed.

const LANES := 4
const LW := 180.0
const JUDGE := 1010.0
const LC := [Color(0.9, 0.35, 0.4), Color(0.35, 0.7, 0.95), Color(0.4, 0.9, 0.45), Color(0.95, 0.8, 0.3)]

var notes: Array = []
var beat_t := 0.0
var combo := 0
var lives := 3
var bhp := 60
var bmax := 60
var bosses := 0
var flash_l := -1
var flash_t := 0.0


func start() -> void:
	super.start()
	notes = []
	beat_t = 0.0
	combo = 0
	lives = 3
	bhp = 60
	bmax = 60
	bosses = 0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var lane := clampi(int(event.position.x / LW), 0, LANES - 1)
	flash_l = lane
	flash_t = 0.12
	var best = null
	var bd := 90.0
	for nt in notes:
		if nt.lane == lane and absf(nt.y - JUDGE) < bd:
			bd = absf(nt.y - JUDGE)
			best = nt
	if best != null:
		notes.erase(best)
		combo += 1
		var dmg: int = 6 + combo / 3
		bhp -= dmg
		Juice.sfx("chime", 1.0 + minf(combo, 10) * 0.04)
		if bhp <= 0:
			_next_boss()
	else:
		combo = 0
	queue_redraw()


func _next_boss() -> void:
	add_points(1)
	bosses += 1
	bmax = 60 + bosses * 25
	bhp = bmax
	Juice.flash(Color(0.9, 0.7, 0.4), 0.25)
	Juice.sfx("coin")


func _process(delta: float) -> void:
	if not running:
		return
	flash_t = maxf(0.0, flash_t - delta)
	beat_t += delta
	var interval := maxf(0.32, 0.5 - bosses * 0.02)
	if beat_t >= interval:
		beat_t -= interval
		if randf() < 0.8:
			notes.append({"lane": randi() % LANES, "y": -40.0})
	for nt in notes.duplicate():
		nt.y += 560.0 * delta
		if nt.y > JUDGE + 90.0:
			notes.erase(nt)
			combo = 0
			lives -= 1
			Juice.flash(Color(1, 0.3, 0.3), 0.25)
			Juice.haptic(30)
			if lives <= 0:
				end_demo()
				return
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.07, 0.07, 0.12))
	# boss
	draw_circle(Vector2(360, 200), 70.0, Color(0.8, 0.3, 0.4))
	draw_rect(Rect2(160, 320, 400, 22), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(160, 320, 400 * clampf(float(bhp) / float(bmax), 0, 1), 22), Color(0.9, 0.35, 0.4))
	draw_string(f(), Vector2(160, 312), "BOSS %d" % (bosses + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	for i in range(1, LANES):
		draw_line(Vector2(i * LW, 380), Vector2(i * LW, H), Color(1, 1, 1, 0.08), 2.0)
	if flash_t > 0.0 and flash_l >= 0:
		draw_rect(Rect2(flash_l * LW, JUDGE - 40, LW, 80), Color(1, 1, 1, 0.15))
	draw_rect(Rect2(0, JUDGE - 6, W, 12), Color(1, 1, 1, 0.35))
	for nt in notes:
		draw_rect(Rect2(nt.lane * LW + 16, nt.y - 22, LW - 32, 44), LC[nt.lane])
	if combo > 1:
		draw_string(f(), Vector2(0, 460), "COMBO x%d" % combo, HORIZONTAL_ALIGNMENT_CENTER, W, 34, Color(1, 0.9, 0.4))
	draw_string(f(), Vector2(20, 130), "LIVES " + "* ".repeat(lives), HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 0.5, 0.5))
	draw_string(f(), Vector2(20, H - 16), "tap the lane on the beat", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.5))
