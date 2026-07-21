extends Node3D
## BridgeHop shell: 3D world + code-built UI. HOLD to grow the beam,
## RELEASE to drop it. Wired to the shared platform services.

enum State { MENU, PLAYING, OVER }

var state: State = State.MENU
var bridge: BridgeWorld
var cam: Camera3D
var _over_at := 0.0

var menu_box: Control
var hud_box: Control
var over_box: Control
var score_label: Label
var combo_label: Label
var best_label: Label
var over_score: Label
var over_best: Label
var lb_title: Label
var lb_box: VBoxContainer
var promo_box: HBoxContainer
var flash_rect: ColorRect
var offline_label: Label


func _ready() -> void:
	_build_world()
	_build_ui()
	_show_menu()


func _build_world() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.from_hsv(0.75, 0.45, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.7
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 25, 0)
	sun.light_energy = 1.1
	add_child(sun)

	bridge = BridgeWorld.new()
	add_child(bridge)
	bridge.score_changed.connect(_on_score_changed)
	bridge.game_ended.connect(_on_game_ended)
	bridge.perfect_landed.connect(_on_perfect)

	cam = Camera3D.new()
	cam.fov = 65.0
	cam.position = Vector3(2.5, 4.0, 12.0)
	cam.rotation_degrees = Vector3(-12, 0, 0)
	add_child(cam)
	cam.make_current()


func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	menu_box = _center_box(root)
	_label(menu_box, "BRIDGEHOP", 80, Color.WHITE)
	best_label = _label(menu_box, "BEST 0", 36, Color(1, 1, 1, 0.75))
	_spacer(menu_box, 60)
	_label(menu_box, "TAP TO PLAY", 44, Color(1, 1, 0.6))
	_label(menu_box, "hold = grow beam · release = drop", 26, Color(1, 1, 1, 0.5))

	hud_box = Control.new()
	hud_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_box)
	score_label = Label.new()
	score_label.text = "0"
	score_label.add_theme_font_size_override("font_size", 96)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_label.position = Vector2(-100, 60)
	score_label.size = Vector2(200, 110)
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(score_label)
	combo_label = Label.new()
	combo_label.text = ""
	combo_label.add_theme_font_size_override("font_size", 40)
	combo_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	combo_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	combo_label.position = Vector2(-150, 175)
	combo_label.size = Vector2(300, 50)
	combo_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(combo_label)

	over_box = Control.new()
	over_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(over_box)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_box.add_child(dim)
	var over_center := _center_box(over_box)
	_label(over_center, "GAME OVER", 64, Color.WHITE)
	over_score = _label(over_center, "0", 110, Color(1, 0.85, 0.3))
	over_best = _label(over_center, "", 34, Color(1, 1, 1, 0.8))
	_spacer(over_center, 20)
	lb_title = _label(over_center, "", 26, Color(1, 1, 1, 0.6))
	lb_box = VBoxContainer.new()
	lb_box.alignment = BoxContainer.ALIGNMENT_CENTER
	over_center.add_child(lb_box)
	_spacer(over_center, 24)
	_label(over_center, "TAP TO RETRY", 40, Color(1, 1, 0.6))
	_spacer(over_center, 24)
	promo_box = HBoxContainer.new()
	promo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	promo_box.add_theme_constant_override("separation", 16)
	over_center.add_child(promo_box)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)
	offline_label = Label.new()
	offline_label.text = "OFFLINE"
	offline_label.add_theme_font_size_override("font_size", 22)
	offline_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	offline_label.position = Vector2(20, 20)
	offline_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(offline_label)


func _center_box(parent: Control) -> VBoxContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cc)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cc.add_child(box)
	return box


func _label(box: Control, text: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return l


func _spacer(box: Control, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(s)


# ---------- state flow ----------

func _show_menu() -> void:
	state = State.MENU
	menu_box.visible = true
	hud_box.visible = false
	over_box.visible = false
	best_label.text = "BEST %d" % GameState.best_score


func _start_game() -> void:
	state = State.PLAYING
	menu_box.visible = false
	over_box.visible = false
	hud_box.visible = true
	score_label.text = "0"
	combo_label.text = ""
	bridge.start_game()
	Analytics.track("game_start", {})


func _on_score_changed(score: int) -> void:
	score_label.text = str(score)
	if bridge.combo == 0:
		combo_label.text = ""


func _on_perfect(combo: int) -> void:
	combo_label.text = "PERFECT x%d" % combo
	_flash(0.18 if combo < 5 else 0.35)
	if combo == 5:
		Analytics.track("fever", {"score": bridge.score})


func _on_game_ended(score: int) -> void:
	state = State.OVER
	_over_at = Time.get_ticks_msec() / 1000.0
	GameState.register_death()
	var improved := GameState.report_score(score)
	Analytics.track("game_over", {"score": score, "best": GameState.best_score})
	Analytics.flush()
	Ads.maybe_show_interstitial()
	await Ads.interstitial_closed
	hud_box.visible = false
	over_box.visible = true
	over_score.text = str(score)
	over_best.text = "NEW BEST!" if improved else "BEST %d" % GameState.best_score
	_populate_online_panels(score)


func _populate_online_panels(score: int) -> void:
	lb_title.text = ""
	for c in lb_box.get_children():
		c.queue_free()
	for c in promo_box.get_children():
		c.queue_free()
	if not Backend.online:
		return
	await Backend.submit_score(score)
	var lb: Dictionary = await Backend.get_leaderboard(5)
	if state != State.OVER:
		return
	var entries: Array = lb.get("entries", [])
	if not entries.is_empty():
		lb_title.text = "— TOP PLAYERS —"
		for e in entries:
			var row := Label.new()
			row.text = "%d. %s   %d" % [e.get("rank", 0), e.get("name", "?"), e.get("score", 0)]
			row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_theme_font_size_override("font_size", 30)
			if e.get("you", false):
				row.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
			lb_box.add_child(row)
		var me: Variant = lb.get("me")
		if me is Dictionary and not entries.any(func(e2): return e2.get("you", false)):
			var mine := Label.new()
			mine.text = "YOU: #%d (%d)" % [me.get("rank", 0), me.get("score", 0)]
			mine.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			mine.add_theme_font_size_override("font_size", 30)
			mine.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
			lb_box.add_child(mine)
	if bool(Backend.cfg("crosspromo_enabled", true)):
		var games: Array = await Backend.get_crosspromo()
		for g in games.slice(0, 3):
			var b := Button.new()
			b.text = str(g.get("name", "Play"))
			b.add_theme_font_size_override("font_size", 26)
			var url := str(g.get("android_url", ""))
			b.pressed.connect(func():
				Analytics.track("crosspromo_tap", {"target": g.get("game_id", "")})
				if url != "":
					OS.shell_open(url))
			promo_box.add_child(b)


# ---------- input & per-frame ----------

func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch):
		return
	var touch := event as InputEventScreenTouch
	match state:
		State.MENU:
			if touch.pressed:
				_start_game()
		State.PLAYING:
			if touch.pressed:
				bridge.press_start()
			else:
				bridge.press_end()
		State.OVER:
			if touch.pressed and Time.get_ticks_msec() / 1000.0 - _over_at > 0.9:
				_start_game()


func _process(delta: float) -> void:
	offline_label.visible = not Backend.online
	var want_x := bridge.player_x() + 2.5
	cam.position.x = lerpf(cam.position.x, want_x, 1.0 - pow(0.002, delta))


func _flash(strength: float) -> void:
	flash_rect.color = Color(1, 1, 1, strength)
	var t := create_tween()
	t.tween_property(flash_rect, "color:a", 0.0, 0.25)
