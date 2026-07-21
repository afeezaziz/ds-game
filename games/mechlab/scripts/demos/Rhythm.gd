extends MechDemo
## RHYTHM — falling notes, four lanes, tap on the judgment line.
## Silent metronome version: the timing skill without the licensing bill.

const LANES := 4
const LW := 180.0
const JUDGE_Y := 1020.0
const LANE_COLORS := [Color(0.9, 0.35, 0.4), Color(0.35, 0.7, 0.95),
	Color(0.4, 0.9, 0.45), Color(0.95, 0.8, 0.3)]

var notes: Array = []
var beat_t := 0.0
var misses := 0
var combo := 0
var judge_flash := 0.0


func start() -> void:
	super.start()
	notes.clear()
	beat_t = 0.0
	misses = 0
	combo = 0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var lane := clampi(int(event.position.x / LW), 0, LANES - 1)
	var best = null
	var best_dy := 95.0
	for n in notes:
		if n.lane == lane and absf(n.y - JUDGE_Y) < best_dy:
			best = n
			best_dy = absf(n.y - JUDGE_Y)
	if best != null:
		notes.erase(best)
		combo += 1
		judge_flash = 0.15
		add_points((10 if best_dy < 34.0 else 5) * (1 + combo / 10))
	else:
		combo = 0


func _process(delta: float) -> void:
	if not running:
		return
	judge_flash = maxf(0.0, judge_flash - delta)
	beat_t += delta
	if beat_t >= 0.42:
		beat_t -= 0.42
		if randf() < 0.75:
			notes.append({"lane": randi() % LANES, "y": -40.0})
	for n in notes.duplicate():
		n.y += 640.0 * delta
		if n.y > JUDGE_Y + 100.0:
			notes.erase(n)
			misses += 1
			combo = 0
			if misses >= 10:
				end_demo()
				return
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.07, 0.07, 0.12))
	for i in range(1, LANES):
		draw_line(Vector2(i * LW, 120), Vector2(i * LW, H), Color(1, 1, 1, 0.08), 2.0)
	draw_rect(Rect2(0, JUDGE_Y - 8.0, W, 16.0),
		Color(1, 1, 1, 0.6 if judge_flash > 0.0 else 0.25))
	for n in notes:
		draw_rect(Rect2(n.lane * LW + 16.0, n.y - 22.0, LW - 32.0, 44.0), LANE_COLORS[n.lane])
	if combo > 1:
		draw_string(f(), Vector2(W * 0.5 - 100, 200), "COMBO x%d" % combo,
			HORIZONTAL_ALIGNMENT_CENTER, 200, 34, Color(1, 0.9, 0.4))
	draw_string(f(), Vector2(20, 150), "MISSES %d/10" % misses,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 0.5, 0.5, 0.8))
	draw_string(f(), Vector2(20, H - 16), "tap the lane when the note hits the line",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
