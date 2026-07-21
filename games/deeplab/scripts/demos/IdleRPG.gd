extends MechDemo
## IDLE RPG — the AFK auto-battler (AFK Arena / Idle Heroes). Your team fights
## waves on its own; spend gold to level heroes, ascend them at level 10 for a
## bigger base. Idle gold keeps flowing. Score = highest stage reached.

var heroes: Array = []        # {name, level, base}
var gold := 50.0
var stage := 1
var battle_t := 0.0
var msg := "your team fights automatically"


func start() -> void:
	super.start()
	heroes = [
		{"name": "KNIGHT", "level": 1, "base": 4},
		{"name": "MAGE", "level": 1, "base": 3},
		{"name": "ROGUE", "level": 1, "base": 5}]
	gold = 50.0
	stage = 1
	battle_t = 0.0
	queue_redraw()


func _power() -> int:
	var p := 0
	for h in heroes:
		p += h.level * h.base
	return p


func _hero_rect(i: int) -> Rect2:
	return Rect2(40, 480 + i * 200, 640, 180)


func _lvl_cost(h: Dictionary) -> int:
	return h.level * 12


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	for i in heroes.size():
		var r := _hero_rect(i)
		var lvl_btn := Rect2(r.position.x + 360, r.position.y + 40, 130, 100)
		var asc_btn := Rect2(r.position.x + 500, r.position.y + 40, 130, 100)
		var h: Dictionary = heroes[i]
		if lvl_btn.has_point(event.position) and gold >= _lvl_cost(h):
			gold -= _lvl_cost(h)
			h.level += 1
			Juice.sfx("coin")
		elif asc_btn.has_point(event.position) and h.level >= 10:
			h.level = 1
			h.base += 3
			Juice.sfx("chime")
			Juice.flash(Color(0.9, 0.8, 0.4), 0.2)
		queue_redraw()


func _process(delta: float) -> void:
	if not running:
		return
	gold += _power() * 0.04 * delta
	battle_t += delta
	if battle_t >= 1.2:
		battle_t = 0.0
		var foe := 8 * stage
		if _power() >= foe:
			stage += 1
			gold += stage * 4
			set_score(stage)
			msg = "cleared stage %d!" % (stage - 1)
			Juice.sfx("tick")
		else:
			gold += stage
			msg = "stuck at stage %d — level up (need %d power)" % [stage, foe]
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 0, W, H), Color(0.1, 0.09, 0.14))
	draw_string(f(), Vector2(0, 150), "STAGE %d" % stage, HORIZONTAL_ALIGNMENT_CENTER, W, 46, Color(1, 0.85, 0.4))
	draw_string(f(), Vector2(0, 220), "team power %d   ·   foe %d   ·   GOLD %d" % [_power(), 8 * stage, int(gold)], HORIZONTAL_ALIGNMENT_CENTER, W, 26, Color.WHITE)
	draw_string(f(), Vector2(0, 280), msg, HORIZONTAL_ALIGNMENT_CENTER, W, 24, Color(0.7, 0.9, 1.0))
	# battle vignette
	draw_rect(Rect2(160, 320, 400, 120), Color(0.15, 0.15, 0.2))
	draw_string(f(), Vector2(160, 390), "auto-battling…", HORIZONTAL_ALIGNMENT_CENTER, 400, 28, Color(0.7, 0.8, 0.9))
	for i in heroes.size():
		var h: Dictionary = heroes[i]
		var r := _hero_rect(i)
		draw_rect(r, Color(1, 1, 1, 0.05))
		draw_circle(Vector2(r.position.x + 80, r.get_center().y), 50.0, Color.from_hsv(i * 0.2 + 0.5, 0.5, 0.8))
		draw_string(f(), Vector2(r.position.x + 160, r.position.y + 70), "%s  Lv%d" % [h.name, h.level], HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
		draw_string(f(), Vector2(r.position.x + 160, r.position.y + 120), "power %d" % (h.level * h.base), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(0.7, 0.9, 0.7))
		var lvl_btn := Rect2(r.position.x + 360, r.position.y + 40, 130, 100)
		draw_rect(lvl_btn, Color(0.3, 0.45, 0.35) if gold >= _lvl_cost(h) else Color(0.25, 0.25, 0.27))
		draw_string(f(), Vector2(lvl_btn.position.x, lvl_btn.position.y + 44), "LEVEL", HORIZONTAL_ALIGNMENT_CENTER, lvl_btn.size.x, 22, Color.WHITE)
		draw_string(f(), Vector2(lvl_btn.position.x, lvl_btn.position.y + 78), "$%d" % _lvl_cost(h), HORIZONTAL_ALIGNMENT_CENTER, lvl_btn.size.x, 22, Color(1, 0.9, 0.5))
		var asc_btn := Rect2(r.position.x + 500, r.position.y + 40, 130, 100)
		draw_rect(asc_btn, Color(0.4, 0.35, 0.5) if h.level >= 10 else Color(0.22, 0.22, 0.25))
		draw_string(f(), Vector2(asc_btn.position.x, asc_btn.position.y + 44), "ASCEND", HORIZONTAL_ALIGNMENT_CENTER, asc_btn.size.x, 20, Color.WHITE)
		draw_string(f(), Vector2(asc_btn.position.x, asc_btn.position.y + 78), "Lv10", HORIZONTAL_ALIGNMENT_CENTER, asc_btn.size.x, 20, Color(1, 1, 1, 0.7))
