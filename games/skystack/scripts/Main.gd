extends Node2D
## Game shell: mode-select menu -> playing -> game over. All UI built in code.
## The menu lists every enabled mechanic from SkyStack.MODES; each mode has its
## own best score, its own leaderboard (backend board == mode key), and its own
## analytics tag — so play data can crown the winning mechanic.

enum State { MENU, PLAYING, OVER }

var state: State = State.MENU
var stack: SkyStack
var cam: Camera2D
var shake := 0.0
var current_mode := "classic"
var _over_at := 0.0

# UI refs
var bg: ColorRect
var menu_box: Control
var mode_list: VBoxContainer
var hud_box: Control
var over_box: Control
var score_label: Label
var combo_label: Label
var mode_label: Label
var wind_label: Label
var best_label: Label
var over_score: Label
var over_best: Label
var lb_title: Label
var lb_box: VBoxContainer
var promo_box: HBoxContainer
var flash_rect: ColorRect
var offline_label: Label


func _ready() -> void:
	stack = SkyStack.new()
	add_child(stack)
	stack.layer_placed.connect(_on_layer_placed)
	stack.stack_failed.connect(_on_stack_failed)
	stack.wind_changed.connect(_on_wind_changed)

	cam = Camera2D.new()
	cam.position = Vector2(360, 640)
	add_child(cam)
	cam.make_current()

	_build_ui()
	_show_menu()


func _build_ui() -> void:
	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	bg = ColorRect.new()
	bg.color = Color.from_hsv(0.62, 0.55, 0.20)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(bg)

	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	# ----- menu (mode select) -----
	menu_box = _center_box(root)
	_label(menu_box, "SKY STACK", 78, Color.WHITE)
	_label(menu_box, "MECHANICS LAB", 26, Color(1, 1, 1, 0.5))
	best_label = _label(menu_box, "BEST 0", 32, Color(1, 1, 1, 0.75))
	_spacer(menu_box, 30)
	mode_list = VBoxContainer.new()
	mode_list.alignment = BoxContainer.ALIGNMENT_CENTER
	mode_list.add_theme_constant_override("separation", 14)
	menu_box.add_child(mode_list)

	# ----- HUD -----
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
	mode_label = Label.new()
	mode_label.text = ""
	mode_label.add_theme_font_size_override("font_size", 24)
	mode_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.45))
	mode_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mode_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	mode_label.position = Vector2(-150, 20)
	mode_label.size = Vector2(300, 32)
	mode_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(mode_label)
	wind_label = Label.new()
	wind_label.text = ""
	wind_label.add_theme_font_size_override("font_size", 38)
	wind_label.add_theme_color_override("font_color", Color(0.6, 0.9, 1.0))
	wind_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wind_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wind_label.position = Vector2(-150, 230)
	wind_label.size = Vector2(300, 46)
	wind_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(wind_label)

	# ----- game over -----
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
	_spacer(over_center, 20)
	_label(over_center, "TAP TO RETRY", 40, Color(1, 1, 0.6))
	var modes_btn := Button.new()
	modes_btn.text = "MODES"
	modes_btn.add_theme_font_size_override("font_size", 30)
	modes_btn.custom_minimum_size = Vector2(220, 64)
	modes_btn.pressed.connect(_show_menu)
	over_center.add_child(modes_btn)
	_spacer(over_center, 20)
	promo_box = HBoxContainer.new()
	promo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	promo_box.add_theme_constant_override("separation", 16)
	over_center.add_child(promo_box)

	# ----- extras -----
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
	## Adds a full-rect CenterContainer to `parent` and returns the VBox inside it.
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
	cam.position = Vector2(360, 640)
	_rebuild_mode_buttons()


func _rebuild_mode_buttons() -> void:
	for c in mode_list.get_children():
		c.queue_free()
	for m in SkyStack.enabled_modes():
		var def: Dictionary = SkyStack.MODES[m]
		var b := Button.new()
		var best := GameState.best_for(m)
		b.text = "%s  —  %s%s" % [def["title"], def["tagline"],
			("\nBEST %d" % best) if best > 0 else ""]
		b.add_theme_font_size_override("font_size", 28)
		b.custom_minimum_size = Vector2(480, 92)
		b.pressed.connect(_start_game.bind(str(m)))
		mode_list.add_child(b)


func _start_game(m: String = "") -> void:
	if m != "":
		current_mode = m
	state = State.PLAYING
	menu_box.visible = false
	over_box.visible = false
	hud_box.visible = true
	score_label.text = "0"
	combo_label.text = ""
	wind_label.text = ""
	mode_label.text = str(SkyStack.MODES[current_mode]["title"])
	bg.color = Color.from_hsv(0.62, 0.55, 0.20)
	stack.start_game(current_mode)
	Analytics.track("game_start", {"mode": current_mode})


func _on_layer_placed(score: int, was_perfect: bool, combo: int) -> void:
	score_label.text = str(score)
	var t := create_tween()
	t.tween_property(score_label, "scale", Vector2(1.25, 1.25), 0.05)
	t.tween_property(score_label, "scale", Vector2.ONE, 0.1)
	score_label.pivot_offset = score_label.size * 0.5
	if was_perfect:
		combo_label.text = "PERFECT x%d" % combo
		_flash(0.18 if combo < stack.fever_streak else 0.35)
		Juice.sfx("chime", 1.0 + minf(combo, 8.0) * 0.06)
		Juice.popup("PERFECT x%d" % combo, Vector2(360, 430))
		Juice.haptic(18)
		if combo == stack.fever_streak:
			Juice.hitstop(70)
			Juice.sfx("coin")
			Analytics.track("fever", {"score": score, "mode": current_mode})
	else:
		combo_label.text = ""
		shake = 6.0
		Juice.sfx("thud")
		Juice.haptic(12)
	bg.color = Color.from_hsv(fmod(0.62 + score * 0.004, 1.0), 0.55, 0.20)


func _on_wind_changed(wind: float) -> void:
	if current_mode != "wind":
		wind_label.text = ""
		return
	var strength := int(ceil(absf(wind) / 75.0))
	wind_label.text = (">".repeat(strength)) if wind > 0.0 else ("<".repeat(strength))


func _on_stack_failed(score: int) -> void:
	state = State.OVER
	_over_at = Time.get_ticks_msec() / 1000.0
	shake = 14.0
	Juice.sfx("boom")
	Juice.flash(Color(1, 0.35, 0.3), 0.3)
	Juice.haptic(60)
	GameState.register_death()
	var improved := GameState.report_score(score, current_mode)
	Analytics.track("game_over", {"score": score, "mode": current_mode,
		"best": GameState.best_for(current_mode)})
	Analytics.flush()
	Ads.maybe_show_interstitial()
	await Ads.interstitial_closed
	hud_box.visible = false
	over_box.visible = true
	over_score.text = str(score)
	over_best.text = "NEW BEST!" if improved else "BEST %d" % GameState.best_for(current_mode)
	_populate_online_panels(score)


func _populate_online_panels(score: int) -> void:
	lb_title.text = ""
	for c in lb_box.get_children():
		c.queue_free()
	for c in promo_box.get_children():
		c.queue_free()
	if not Backend.online:
		return
	await Backend.submit_score(score, current_mode)
	var lb: Dictionary = await Backend.get_leaderboard(5, current_mode)
	if state != State.OVER:
		return  # player already restarted while we were fetching
	var entries: Array = lb.get("entries", [])
	if not entries.is_empty():
		lb_title.text = "— TOP · %s —" % str(SkyStack.MODES[current_mode]["title"])
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
	var tapped: bool = (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	match state:
		State.MENU:
			pass  # mode buttons handle input
		State.PLAYING:
			stack.drop()
		State.OVER:
			if Time.get_ticks_msec() / 1000.0 - _over_at > 0.9:
				_start_game()


func _process(delta: float) -> void:
	offline_label.visible = not Backend.online
	if state == State.PLAYING:
		var target_y: float = minf(640.0, stack.top_y() - 640.0 + 950.0)
		cam.position.y = lerpf(cam.position.y, target_y, 1.0 - pow(0.001, delta))
	cam.position.x = 360.0
	if shake > 0.05:
		shake = lerpf(shake, 0.0, 10.0 * delta)
		cam.offset = Vector2(randf_range(-shake, shake), randf_range(-shake, shake))
	else:
		cam.offset = Vector2.ZERO


func _flash(strength: float) -> void:
	flash_rect.color = Color(1, 1, 1, strength)
	var t := create_tween()
	t.tween_property(flash_rect, "color:a", 0.0, 0.25)
