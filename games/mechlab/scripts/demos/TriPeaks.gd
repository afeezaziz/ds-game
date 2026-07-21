extends MechDemo
## TRIPEAKS — pyramid solitaire. Take any face-up card one rank above or below
## the waste card (wraps A-K). Tap the stock to flip a new waste. Clear the
## pyramid to re-deal. No moves + empty stock = over. Score = cards cleared.

const RANKS := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]
const CW := 96.0
const CH := 132.0
const OY := 220.0

var rows: Array = []      # rows[r] = Array of rank ints or -1
var stock: Array = []
var waste := 0


func start() -> void:
	super.start()
	_deal()
	queue_redraw()


func _deal() -> void:
	var deck := []
	for i in 24:
		deck.append(randi() % 13)
	deck.shuffle()
	rows = []
	for r in 5:
		var row := []
		for i in r + 1:
			row.append(deck.pop_back())
		rows.append(row)
	stock = deck
	waste = stock.pop_back() if not stock.is_empty() else randi() % 13


func _face_up(r: int, i: int) -> bool:
	if rows[r][i] == -1:
		return false
	if r == rows.size() - 1:
		return true
	return rows[r + 1][i] == -1 and rows[r + 1][i + 1] == -1


func _card_rect(r: int, i: int) -> Rect2:
	var count := r + 1
	var total_w := count * (CW + 10) - 10
	var x := (W - total_w) * 0.5 + i * (CW + 10)
	return Rect2(x, OY + r * 70.0, CW, CH)


func _playable(rank: int) -> bool:
	var d: int = absi(rank - waste)
	return d == 1 or d == 12


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	# stock
	if Rect2(60, 980, CW, CH).has_point(event.position):
		if not stock.is_empty():
			waste = stock.pop_back()
			Juice.sfx("tick")
		queue_redraw()
		return
	for r in rows.size():
		for i in rows[r].size():
			if _face_up(r, i) and _card_rect(r, i).has_point(event.position):
				if _playable(rows[r][i]):
					waste = rows[r][i]
					rows[r][i] = -1
					add_points(1)
					Juice.sfx("chime")
					_check()
				return
	_check()


func _check() -> void:
	var cleared := true
	for r in rows:
		for c in r:
			if c != -1:
				cleared = false
	if cleared:
		add_points(20)
		_deal()
		return
	# stuck?
	if stock.is_empty():
		for r in rows.size():
			for i in rows[r].size():
				if _face_up(r, i) and _playable(rows[r][i]):
					return
		end_demo()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.25, 0.15))
	for r in rows.size():
		for i in rows[r].size():
			if rows[r][i] == -1:
				continue
			var rr := _card_rect(r, i)
			var up := _face_up(r, i)
			draw_rect(rr, Color(0.95, 0.95, 0.9) if up else Color(0.3, 0.4, 0.6))
			if up:
				draw_string(f(), Vector2(rr.position.x + 8, rr.position.y + 44), RANKS[rows[r][i]],
					HORIZONTAL_ALIGNMENT_LEFT, -1, 40, Color(0.1, 0.1, 0.1))
	# stock + waste
	draw_rect(Rect2(60, 980, CW, CH), Color(0.25, 0.35, 0.55))
	draw_string(f(), Vector2(60, 1120), "STOCK %d" % stock.size(), HORIZONTAL_ALIGNMENT_LEFT, CW, 22, Color.WHITE)
	draw_rect(Rect2(300, 980, CW, CH), Color(0.95, 0.95, 0.9))
	draw_string(f(), Vector2(300, 1055), RANKS[waste], HORIZONTAL_ALIGNMENT_CENTER, CW, 48, Color(0.1, 0.1, 0.1))
	draw_string(f(), Vector2(460, 1040), "±1 to take", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.7))
