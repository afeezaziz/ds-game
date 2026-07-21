extends MechDemo
## WORD GUESS — the Wordle loop (2022): guess-with-feedback deduction.
## Green = right spot, yellow = wrong spot, dark = not in the word.
## Solve fast for more points; a fail ends the run.

const WORDS := "ABOUT,AFTER,AGAIN,APPLE,BEACH,BEGIN,BLACK,BLOCK,BOARD,BRAIN,BREAD,BREAK,BRING,BROWN,BUILD,CHAIR,CHART,CHEST,CHILD,CLAIM,CLASS,CLEAN,CLEAR,CLIMB,CLOCK,CLOSE,CLOUD,COACH,COAST,COUNT,COURT,COVER,CRAFT,CRASH,CREAM,CRIME,CROSS,CROWD,DANCE,DREAM,DRINK,DRIVE,EARLY,EARTH,EIGHT,ENJOY,ENTER,EQUAL,EVENT,FIELD,FIGHT,FINAL,FIRST,FLOOR,FOCUS,FORCE,FRESH,FRONT,FRUIT,GLASS,GRAND,GRASS,GREAT,GREEN,GROUP,GUARD,GUESS,HAPPY,HEART,HEAVY,HORSE,HOTEL,HOUSE,HUMAN,IMAGE,JUICE,LARGE,LAUGH,LEARN,LEVEL,LIGHT,LOCAL,LUCKY,LUNCH,MAGIC,MAJOR,MARCH,MATCH,METAL,MONEY,MONTH,MUSIC,NIGHT,NOISE,NORTH,OCEAN,OFFER,ORDER,OTHER,PAINT,PAPER,PARTY,PEACE,PHONE,PIECE,PILOT,PLACE,PLANE,PLANT,PLATE,POINT,POWER,PRESS,PRICE,PRIDE,PRIZE,QUEEN,QUICK,QUIET,RADIO,RAISE,RANGE,REACH,RIGHT,RIVER,ROUND,ROYAL,SCALE,SCENE,SCORE,SENSE,SEVEN,SHAPE,SHARE,SHARP,SHEEP,SHELF,SHINE,SHIRT,SHORE,SHORT,SIGHT,SKILL,SLEEP,SMALL,SMART,SMILE,SOUND,SOUTH,SPACE,SPEAK,SPEED,SPEND,SPORT,STAGE,STAND,START,STEAM,STEEL,STICK,STONE,STORE,STORM,STORY,SUGAR,SWEET,TABLE,TASTE,TEACH,THANK,THEME,THING,THINK,THREE,TIGER,TITLE,TODAY,TOUCH,TOWER,TRACK,TRADE,TRAIN,TREAT,TREND,TRUST,TRUTH,UNCLE,UNDER,UNION,UNITY,URBAN,VALUE,VIDEO,VISIT,VOICE,WASTE,WATCH,WATER,WHEEL,WHITE,WHOLE,WOMAN,WORLD,WORTH,WRITE,YOUNG"
const KB_ROWS := ["QWERTYUIOP", "ASDFGHJKL", "ZXCVBNM"]
const KB_Y := 920.0
const KH := 78.0

var words: PackedStringArray
var answer := ""
var guesses: Array = []
var results: Array = []
var cur := ""
var solved_count := 0
var reveal := ""


func start() -> void:
	super.start()
	words = WORDS.split(",")
	solved_count = 0
	_new_word()
	queue_redraw()


func _new_word() -> void:
	answer = words[randi() % words.size()]
	guesses.clear()
	results.clear()
	cur = ""
	reveal = ""


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = event.position
	if p.y < KB_Y or p.y > KB_Y + KH * 3:
		return
	var row := int((p.y - KB_Y) / KH)
	var key := ""
	if row == 0:
		key = KB_ROWS[0][clampi(int(p.x / 72.0), 0, 9)]
	elif row == 1:
		var idx := int((p.x - 36.0) / 72.0)
		if idx >= 0 and idx < 9:
			key = KB_ROWS[1][idx]
	else:
		if p.x < 108.0:
			key = "ENTER"
		elif p.x >= 612.0:
			key = "DEL"
		else:
			var idx2 := int((p.x - 108.0) / 72.0)
			if idx2 >= 0 and idx2 < 7:
				key = KB_ROWS[2][idx2]
	_press(key)
	queue_redraw()


func _press(key: String) -> void:
	if key == "":
		return
	if key == "DEL":
		cur = cur.left(maxi(0, cur.length() - 1))
	elif key == "ENTER":
		if cur.length() != 5:
			return
		var res := _eval(cur, answer)
		guesses.append(cur)
		results.append(res)
		if cur == answer:
			solved_count += 1
			add_points(maxi(10, 80 - guesses.size() * 10))
			_new_word()
		elif guesses.size() >= 6:
			reveal = answer
			end_demo()
		cur = ""
	elif cur.length() < 5:
		cur += key


func _eval(guess: String, ans: String) -> Array:
	var res := [0, 0, 0, 0, 0]
	var counts := {}
	for i in 5:
		if guess[i] == ans[i]:
			res[i] = 2
		else:
			counts[ans[i]] = counts.get(ans[i], 0) + 1
	for i in 5:
		if res[i] == 0 and counts.get(guess[i], 0) > 0:
			res[i] = 1
			counts[guess[i]] -= 1
	return res


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.09, 0.1))
	var ts := 92.0
	var ox := (W - 5 * ts - 4 * 10.0) * 0.5
	for row in 6:
		for col in 5:
			var r := Rect2(ox + col * (ts + 10.0), 180.0 + row * (ts + 10.0), ts, ts)
			var bg := Color(1, 1, 1, 0.07)
			var ch := ""
			if row < guesses.size():
				ch = guesses[row][col]
				var v: int = results[row][col]
				bg = Color(0.35, 0.65, 0.35) if v == 2 else (Color(0.75, 0.65, 0.25) if v == 1 else Color(0.22, 0.22, 0.25))
			elif row == guesses.size() and col < cur.length():
				ch = cur[col]
				bg = Color(1, 1, 1, 0.14)
			draw_rect(r, bg)
			if ch != "":
				draw_string(f(), Vector2(r.position.x, r.position.y + 64), ch,
					HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 44, Color.WHITE)
	# keyboard
	for row in 3:
		var letters: String = KB_ROWS[row]
		var offset := [0.0, 36.0, 108.0][row]
		for i in letters.length():
			var kr := Rect2(offset + i * 72.0 + 3, KB_Y + row * KH + 3, 66.0, KH - 6.0)
			draw_rect(kr, Color(0.25, 0.25, 0.3))
			draw_string(f(), Vector2(kr.position.x, kr.position.y + 50), letters[i],
				HORIZONTAL_ALIGNMENT_CENTER, kr.size.x, 30, Color.WHITE)
		if row == 2:
			draw_rect(Rect2(3, KB_Y + 2 * KH + 3, 100, KH - 6), Color(0.3, 0.45, 0.3))
			draw_string(f(), Vector2(3, KB_Y + 2 * KH + 50), "GO",
				HORIZONTAL_ALIGNMENT_CENTER, 100, 26, Color.WHITE)
			draw_rect(Rect2(615, KB_Y + 2 * KH + 3, 102, KH - 6), Color(0.45, 0.3, 0.3))
			draw_string(f(), Vector2(615, KB_Y + 2 * KH + 50), "DEL",
				HORIZONTAL_ALIGNMENT_CENTER, 102, 26, Color.WHITE)
	draw_string(f(), Vector2(20, 160), "SOLVED %d" % solved_count,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1, 1, 1, 0.7))
	if reveal != "":
		draw_string(f(), Vector2(0, KB_Y - 20), "it was: %s" % reveal,
			HORIZONTAL_ALIGNMENT_CENTER, W, 30, Color(1, 0.6, 0.6))
