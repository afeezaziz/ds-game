extends MechDemo
## DECK ROGUE (deep) — a real Slay-the-Spire-lite. Status effects that stack and
## interact (block/strength/vulnerable/weak/poison), enemies that telegraph
## intents from scripted patterns, relics with passive triggers, potions, card
## upgrades, and a map where you CHOOSE your next node. Score = floors cleared.

enum S { CHOICE, COMBAT, REWARD, SHOP, REST }

# id -> {n:name, c:cost, t:type, dmg, hits, blk, vuln, weak, psn, str, dex, draw, ex(exhaust), rare}
const CARDS := {
	"strike": {"n": "Strike", "c": 1, "dmg": 6}, "strike+": {"n": "Strike+", "c": 1, "dmg": 9},
	"defend": {"n": "Defend", "c": 1, "blk": 5}, "defend+": {"n": "Defend+", "c": 1, "blk": 8},
	"bash": {"n": "Bash", "c": 2, "dmg": 8, "vuln": 2}, "bash+": {"n": "Bash+", "c": 2, "dmg": 10, "vuln": 3},
	"iron": {"n": "Iron Wave", "c": 1, "dmg": 5, "blk": 5}, "iron+": {"n": "Iron Wave+", "c": 1, "dmg": 7, "blk": 7},
	"twin": {"n": "Twin Strike", "c": 1, "dmg": 5, "hits": 2, "rare": 1}, "twin+": {"n": "Twin Strike+", "c": 1, "dmg": 7, "hits": 2},
	"pommel": {"n": "Pommel", "c": 1, "dmg": 9, "draw": 1, "ex": 1, "rare": 1},
	"inflame": {"n": "Inflame", "c": 1, "t": "power", "str": 2, "rare": 1},
	"footwork": {"n": "Footwork", "c": 1, "t": "power", "dex": 2, "rare": 1},
	"poison": {"n": "Deadly Poison", "c": 1, "psn": 5, "rare": 1}, "poison+": {"n": "Deadly Poison+", "c": 1, "psn": 7},
	"shrug": {"n": "Shrug It Off", "c": 1, "blk": 8, "draw": 1},
	"bludgeon": {"n": "Bludgeon", "c": 3, "dmg": 24, "rare": 2},
	"whirl": {"n": "Cleave", "c": 1, "dmg": 8}}
const RELICS := {
	"blood": "Burning Blood — heal 6 after each win",
	"anchor": "Anchor — start combat with 10 block",
	"vajra": "Vajra — start combat with +1 Strength",
	"coffee": "Coffee Dripper — +1 energy each turn",
	"prep": "Bag of Prep — draw 2 extra on turn 1",
	"scales": "Bronze Scales — deal 3 back when hit"}
const POT := {"fire": "Fire (20 dmg)", "block": "Block (+12)", "str": "Strength (+2)", "heal": "Heal (20)"}

var st: S = S.COMBAT
var floor_n := 0
var hp := 70
var maxhp := 70
var gold := 99
var deck: Array = []
var relics: Array = []
var potions: Array = []

var draw_pile: Array = []
var hand: Array = []
var discard: Array = []
var energy := 3
var block := 0
var p_str := 0
var p_dex := 0
var p_weak := 0
var p_vuln := 0
var first_turn := true

var e: Dictionary = {}
var choice_opts: Array = []
var reward_cards: Array = []
var shop_items: Array = []
var msg := ""


func start() -> void:
	super.start()
	hp = 70
	maxhp = 70
	gold = 99
	floor_n = 0
	deck = ["strike", "strike", "strike", "strike", "defend", "defend", "defend", "bash"]
	relics = []
	potions = ["heal"]
	_next_choice()


# ---------- map / choices ----------

func _next_choice() -> void:
	floor_n += 1
	if floor_n % 5 == 0:
		_enter_combat("boss")
		return
	var pool := ["FIGHT", "FIGHT", "ELITE", "REST", "SHOP", "TREASURE"]
	pool.shuffle()
	choice_opts = [pool[0], pool[1]]
	st = S.CHOICE
	msg = "choose your path"
	queue_redraw()


func _take_node(kind: String) -> void:
	match kind:
		"FIGHT":
			_enter_combat("normal")
		"ELITE":
			_enter_combat("elite")
		"REST":
			st = S.REST
			queue_redraw()
		"SHOP":
			_open_shop()
		"TREASURE":
			_grant_relic()
			msg = "found a relic!"
			_next_choice()


# ---------- combat ----------

func _enter_combat(kind: String) -> void:
	e = _make_enemy(kind)
	energy = 4 if _has("coffee") else 3
	block = 0
	p_str = 1 if _has("vajra") else 0
	p_dex = 0
	p_weak = 0
	p_vuln = 0
	if _has("anchor"):
		block += 10
	draw_pile = deck.duplicate()
	draw_pile.shuffle()
	discard = []
	hand = []
	first_turn = true
	st = S.COMBAT
	_start_turn()


func _make_enemy(kind: String) -> Dictionary:
	var f := floor_n
	if kind == "boss":
		return {"n": "THE GUARDIAN", "hp": 70 + f * 12, "maxhp": 70 + f * 12, "blk": 0, "str": 0,
			"vuln": 0, "weak": 0, "psn": 0, "mi": 0,
			"moves": [{"k": "atk", "v": 10 + f, "h": 1}, {"k": "buff", "v": 2}, {"k": "atk", "v": 7 + f, "h": 2}, {"k": "debuff", "v": 2}], "elite": true, "boss": true}
	if kind == "elite":
		return {"n": "GREMLIN NOB", "hp": 40 + f * 8, "maxhp": 40 + f * 8, "blk": 0, "str": 0,
			"vuln": 0, "weak": 0, "psn": 0, "mi": 0,
			"moves": [{"k": "buff", "v": 3}, {"k": "atk", "v": 8 + f, "h": 1}, {"k": "atk", "v": 8 + f, "h": 1}], "elite": true, "boss": false}
	var kinds := [
		{"n": "CULTIST", "hp": 22 + f * 4, "moves": [{"k": "buff", "v": 2}, {"k": "atk", "v": 5 + f, "h": 1}]},
		{"n": "JAW WORM", "hp": 26 + f * 4, "moves": [{"k": "atk", "v": 7 + f, "h": 1}, {"k": "def", "v": 6}]},
		{"n": "SLAVER", "hp": 24 + f * 4, "moves": [{"k": "atk", "v": 6 + f, "h": 1}, {"k": "debuff", "v": 1}]}]
	var pick: Dictionary = kinds[randi() % kinds.size()]
	return {"n": pick.n, "hp": pick.hp, "maxhp": pick.hp, "blk": 0, "str": 0, "vuln": 0, "weak": 0, "psn": 0,
		"mi": 0, "moves": pick.moves, "elite": false, "boss": false}


func _start_turn() -> void:
	energy = 4 if _has("coffee") else 3
	block = 0
	if _has("anchor") and false:
		pass
	for c in hand:
		discard.append(c)
	hand = []
	var n := 5 + (2 if first_turn and _has("prep") else 0)
	for i in n:
		_draw_one()
	first_turn = false
	queue_redraw()


func _draw_one() -> void:
	if draw_pile.is_empty():
		draw_pile = discard.duplicate()
		draw_pile.shuffle()
		discard = []
	if not draw_pile.is_empty():
		hand.append(draw_pile.pop_back())


func _atk_dmg(base: int) -> int:
	var d := base + p_str
	if p_weak > 0:
		d = int(d * 0.75)
	if e.vuln > 0:
		d = int(d * 1.5)
	return maxi(0, d)


func _hit_enemy(dmg: int) -> void:
	var rem := dmg
	if e.blk > 0:
		var absorbed: int = mini(e.blk, rem)
		e.blk -= absorbed
		rem -= absorbed
	e.hp -= rem
	if e.hp <= 0:
		_win_combat()


func _play(i: int) -> void:
	if st != S.COMBAT or i >= hand.size():
		return
	var card: Dictionary = CARDS[hand[i]]
	if energy < card.get("c", 0):
		return
	energy -= card.get("c", 0)
	var hits: int = card.get("hits", 1)
	for h in hits:
		if card.get("dmg", 0) > 0:
			_hit_enemy(_atk_dmg(card.dmg))
			if e.is_empty():
				break
	if not e.is_empty():
		if card.get("blk", 0) > 0:
			block += card.blk + p_dex
		if card.get("vuln", 0) > 0:
			e.vuln += card.vuln
		if card.get("weak", 0) > 0:
			e.weak += card.weak
		if card.get("psn", 0) > 0:
			e.psn += card.psn
		if card.get("str", 0) > 0:
			p_str += card.str
		if card.get("dex", 0) > 0:
			p_dex += card.dex
		for d in card.get("draw", 0):
			_draw_one()
	Juice.sfx("thud" if card.get("dmg", 0) > 0 else "tick")
	var id: String = hand[i]
	hand.remove_at(i)
	if not card.get("ex", 0):
		discard.append(id)
	queue_redraw()


func _end_turn() -> void:
	if st != S.COMBAT:
		return
	# enemy poison ticks
	if e.psn > 0:
		e.hp -= e.psn
		e.psn = maxi(0, e.psn - 1)
		if e.hp <= 0:
			_win_combat()
			return
	# resolve enemy intent
	var mv: Dictionary = e.moves[e.mi]
	match mv.k:
		"atk":
			for h in mv.get("h", 1):
				var d := mv.v + e.str
				if e.weak > 0:
					d = int(d * 0.75)
				var rem := d - block
				block = maxi(0, block - d)
				if rem > 0:
					hp -= rem
					if _has("scales"):
						_hit_enemy(3)
		"def":
			e.blk += mv.v
		"buff":
			e.str += mv.v
		"debuff":
			p_weak += mv.v
			p_vuln += mv.v
	e.mi = (e.mi + 1) % e.moves.size()
	if p_weak > 0:
		p_weak -= 1
	if p_vuln > 0:
		p_vuln -= 1
	if e.vuln > 0:
		e.vuln -= 1
	if e.weak > 0:
		e.weak -= 1
	if hp <= 0:
		Juice.sfx("boom")
		end_demo()
		return
	if not e.is_empty():
		_start_turn()


func _win_combat() -> void:
	add_points(1)
	Juice.sfx("chime")
	if _has("blood"):
		hp = mini(maxhp, hp + 6)
	if _has("meat") and hp < maxhp / 2:
		hp = mini(maxhp, hp + 12)
	var elite: bool = e.get("elite", false)
	gold += 15 + floor_n * 3 + (20 if elite else 0)
	if elite:
		_grant_relic()
		if randf() < 0.5:
			_grant_potion()
	e = {}
	# card reward
	var pool := CARDS.keys().filter(func(k): return not str(k).ends_with("+"))
	pool.shuffle()
	reward_cards = pool.slice(0, 3)
	st = S.REWARD
	queue_redraw()


# ---------- rewards / shop / rest ----------

func _grant_relic() -> void:
	var avail := RELICS.keys().filter(func(r): return not relics.has(r))
	if not avail.is_empty():
		relics.append(avail[randi() % avail.size()])


func _grant_potion() -> void:
	if potions.size() < 3:
		potions.append(POT.keys()[randi() % POT.size()])


func _open_shop() -> void:
	var cpool := CARDS.keys().filter(func(k): return not str(k).ends_with("+"))
	cpool.shuffle()
	shop_items = [
		{"kind": "card", "id": cpool[0], "cost": 45},
		{"kind": "card", "id": cpool[1], "cost": 55},
		{"kind": "potion", "id": POT.keys()[randi() % POT.size()], "cost": 40},
		{"kind": "heal", "cost": 30}, {"kind": "leave", "cost": 0}]
	if RELICS.keys().any(func(r): return not relics.has(r)):
		shop_items.insert(2, {"kind": "relic", "cost": 90})
	st = S.SHOP
	queue_redraw()


func _has(r: String) -> bool:
	return relics.has(r)


# ---------- input ----------

func _rect_hand(i: int) -> Rect2:
	var n := hand.size()
	var x := (W - n * 150) * 0.5 + i * 150
	return Rect2(x + 4, 980, 142, 170)


func _rect_opt(i: int) -> Rect2:
	return Rect2(90, 560 + i * 200, 540, 170)


func _rect_pot(i: int) -> Rect2:
	return Rect2(20 + i * 130, 300, 120, 90)


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = event.position
	match st:
		S.COMBAT:
			if Rect2(500, 1160, 200, 90).has_point(p):
				_end_turn()
				return
			for i in potions.size():
				if _rect_pot(i).has_point(p):
					_use_potion(i)
					return
			for i in hand.size():
				if _rect_hand(i).has_point(p):
					_play(i)
					return
		S.CHOICE:
			for i in choice_opts.size():
				if _rect_opt(i).has_point(p):
					_take_node(choice_opts[i])
					return
		S.REWARD:
			for i in reward_cards.size():
				if _rect_opt(i).has_point(p):
					deck.append(reward_cards[i])
					Juice.sfx("chime")
					_next_choice()
					return
			if Rect2(200, 1180, 320, 80).has_point(p):
				_next_choice()
		S.REST:
			if Rect2(120, 600, 480, 130).has_point(p):
				hp = mini(maxhp, hp + int(maxhp * 0.3))
				Juice.sfx("chime")
				_next_choice()
			elif Rect2(120, 780, 480, 130).has_point(p):
				_upgrade_random()
				_next_choice()
		S.SHOP:
			for i in shop_items.size():
				if Rect2(80, 480 + i * 110, 560, 100).has_point(p):
					_buy(i)
					return


func _use_potion(i: int) -> void:
	if st != S.COMBAT or i >= potions.size():
		return
	match potions[i]:
		"fire": _hit_enemy(20)
		"block": block += 12
		"str": p_str += 2
		"heal": hp = mini(maxhp, hp + 20)
	potions.remove_at(i)
	Juice.sfx("coin")
	queue_redraw()


func _upgrade_random() -> void:
	var idx := []
	for i in deck.size():
		if CARDS.has(deck[i] + "+"):
			idx.append(i)
	if not idx.is_empty():
		deck[idx[randi() % idx.size()]] += "+"
		Juice.sfx("chime")


func _buy(i: int) -> void:
	var it: Dictionary = shop_items[i]
	if it.kind == "leave":
		_next_choice()
		return
	if gold < it.cost:
		return
	gold -= it.cost
	match it.kind:
		"card": deck.append(it.id)
		"potion": _grant_potion()
		"relic": _grant_relic()
		"heal": hp = mini(maxhp, hp + 25)
	Juice.sfx("coin")
	shop_items.remove_at(i)
	queue_redraw()


# ---------- draw ----------

func _bar(x: float, y: float, w: float, frac: float, col: Color) -> void:
	draw_rect(Rect2(x, y, w, 22), Color(0, 0, 0, 0.4))
	draw_rect(Rect2(x, y, w * clampf(frac, 0, 1), 22), col)


func _intent() -> String:
	var mv: Dictionary = e.moves[e.mi]
	match mv.k:
		"atk": return "ATTACK %d%s" % [mv.v + e.str, (" x%d" % mv.h) if mv.get("h", 1) > 1 else ""]
		"def": return "BLOCK %d" % mv.v
		"buff": return "BUFF +%d str" % mv.v
		"debuff": return "DEBUFF you"
	return ""


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.09, 0.08, 0.11))
	draw_string(f(), Vector2(20, 60), "FLOOR %d   HP %d/%d   GOLD %d   deck %d" % [floor_n, max(0, hp), maxhp, gold, deck.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
	var rtxt := ""
	for r in relics:
		rtxt += r.substr(0, 3).to_upper() + " "
	draw_string(f(), Vector2(20, 100), "relics: " + (rtxt if rtxt != "" else "none"), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.85, 0.4))
	if st == S.COMBAT:
		draw_circle(Vector2(360, 260), 70.0, Color(0.7, 0.3, 0.35))
		draw_string(f(), Vector2(0, 190), e.n, HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color.WHITE)
		_bar(200, 360, 320, float(e.hp) / float(e.maxhp), Color(0.9, 0.35, 0.35))
		draw_string(f(), Vector2(200, 355), "%d/%d  %s" % [max(0, e.hp), e.maxhp, ("blk %d" % e.blk) if e.blk > 0 else ""], HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
		draw_string(f(), Vector2(0, 410), "INTENT: " + _intent(), HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color(1, 0.6, 0.5))
		var es := ""
		if e.vuln > 0: es += "Vuln %d  " % e.vuln
		if e.weak > 0: es += "Weak %d  " % e.weak
		if e.psn > 0: es += "Poison %d  " % e.psn
		draw_string(f(), Vector2(0, 450), es, HORIZONTAL_ALIGNMENT_CENTER, W, 22, Color(0.7, 0.9, 0.6))
		# potions
		for i in potions.size():
			var pr := _rect_pot(i)
			draw_rect(pr, Color(0.4, 0.3, 0.5))
			draw_string(f(), Vector2(pr.position.x, pr.get_center().y + 6), POT[potions[i]].substr(0, 5), HORIZONTAL_ALIGNMENT_CENTER, pr.size.x, 18, Color.WHITE)
		# player status
		draw_string(f(), Vector2(0, 700), "YOU  block %d   energy %d   Str %d Dex %d %s%s" % [block, energy, p_str, p_dex, ("Weak %d " % p_weak) if p_weak > 0 else "", ("Vuln %d" % p_vuln) if p_vuln > 0 else ""], HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color(0.6, 0.9, 1.0))
		_bar(200, 740, 320, float(hp) / float(maxhp), Color(0.4, 0.85, 0.45))
		for i in hand.size():
			var card: Dictionary = CARDS[hand[i]]
			var rr := _rect_hand(i)
			draw_rect(rr, Color(0.4, 0.45, 0.65) if energy >= card.get("c", 0) else Color(0.3, 0.3, 0.32))
			draw_string(f(), Vector2(rr.position.x, rr.position.y + 40), card.n, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 20, Color.WHITE)
			draw_string(f(), Vector2(rr.position.x, rr.position.y + 74), "%d E" % card.get("c", 0), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 20, Color(1, 0.9, 0.5))
			draw_string(f(), Vector2(rr.position.x, rr.position.y + 110), _card_desc(card), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 17, Color(1, 1, 1, 0.75))
		draw_rect(Rect2(500, 1160, 200, 90), Color(0.4, 0.35, 0.2))
		draw_string(f(), Vector2(500, 1215), "END TURN", HORIZONTAL_ALIGNMENT_CENTER, 200, 24, Color.WHITE)
	elif st == S.CHOICE:
		draw_string(f(), Vector2(0, 440), "CHOOSE YOUR PATH", HORIZONTAL_ALIGNMENT_CENTER, W, 40, Color.WHITE)
		for i in choice_opts.size():
			var rr := _rect_opt(i)
			draw_rect(rr, Color(0.3, 0.4, 0.55))
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y - 6), choice_opts[i], HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 34, Color.WHITE)
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y + 40), _node_hint(choice_opts[i]), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 20, Color(1, 1, 1, 0.7))
	elif st == S.REWARD:
		draw_string(f(), Vector2(0, 480), "DRAFT A CARD (or skip)", HORIZONTAL_ALIGNMENT_CENTER, W, 36, Color.WHITE)
		for i in reward_cards.size():
			var card: Dictionary = CARDS[reward_cards[i]]
			var rr := _rect_opt(i)
			draw_rect(rr, Color(0.35, 0.45, 0.6))
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y - 10), card.n, HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 28, Color.WHITE)
			draw_string(f(), Vector2(rr.position.x, rr.get_center().y + 34), _card_desc(card), HORIZONTAL_ALIGNMENT_CENTER, rr.size.x, 20, Color(1, 1, 1, 0.75))
		draw_rect(Rect2(200, 1180, 320, 80), Color(0.3, 0.3, 0.32))
		draw_string(f(), Vector2(200, 1230), "SKIP", HORIZONTAL_ALIGNMENT_CENTER, 320, 28, Color.WHITE)
	elif st == S.REST:
		draw_string(f(), Vector2(0, 480), "REST SITE", HORIZONTAL_ALIGNMENT_CENTER, W, 44, Color.WHITE)
		draw_rect(Rect2(120, 600, 480, 130), Color(0.3, 0.45, 0.3))
		draw_string(f(), Vector2(120, 675), "HEAL +%d" % int(maxhp * 0.3), HORIZONTAL_ALIGNMENT_CENTER, 480, 32, Color.WHITE)
		draw_rect(Rect2(120, 780, 480, 130), Color(0.4, 0.35, 0.5))
		draw_string(f(), Vector2(120, 855), "UPGRADE A CARD", HORIZONTAL_ALIGNMENT_CENTER, 480, 32, Color.WHITE)
	elif st == S.SHOP:
		draw_string(f(), Vector2(0, 420), "SHOP   (gold %d)" % gold, HORIZONTAL_ALIGNMENT_CENTER, W, 36, Color(1, 0.9, 0.5))
		for i in shop_items.size():
			var it: Dictionary = shop_items[i]
			var rr := Rect2(80, 480 + i * 110, 560, 100)
			draw_rect(rr, Color(0.3, 0.35, 0.45) if (it.kind == "leave" or gold >= it.cost) else Color(0.25, 0.25, 0.27))
			var label := _shop_label(it)
			draw_string(f(), Vector2(rr.position.x + 20, rr.get_center().y + 10), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color.WHITE)


func _card_desc(c: Dictionary) -> String:
	var s := ""
	if c.get("dmg", 0) > 0: s += "%d dmg%s " % [c.dmg, ("x%d" % c.hits) if c.get("hits", 1) > 1 else ""]
	if c.get("blk", 0) > 0: s += "+%d blk " % c.blk
	if c.get("vuln", 0) > 0: s += "vuln %d " % c.vuln
	if c.get("psn", 0) > 0: s += "poison %d " % c.psn
	if c.get("str", 0) > 0: s += "+%d Str " % c.str
	if c.get("dex", 0) > 0: s += "+%d Dex " % c.dex
	if c.get("draw", 0) > 0: s += "draw %d " % c.draw
	return s


func _node_hint(k: String) -> String:
	match k:
		"FIGHT": return "enemy · card + gold"
		"ELITE": return "hard · relic reward"
		"REST": return "heal or upgrade"
		"SHOP": return "spend your gold"
		"TREASURE": return "free relic"
	return ""


func _shop_label(it: Dictionary) -> String:
	match it.kind:
		"card": return "%s  —  %dg" % [CARDS[it.id].n, it.cost]
		"potion": return "Potion: %s  —  %dg" % [POT[it.id], it.cost]
		"relic": return "Random Relic  —  %dg" % it.cost
		"heal": return "Heal 25  —  %dg" % it.cost
		"leave": return "LEAVE"
	return ""
