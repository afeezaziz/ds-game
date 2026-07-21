extends Node2D
## Game shell: menu -> playing -> game over. Generic — talks to Gameplay only
## through its contract (start_game / on_tap / score_changed / game_ended).
## You normally DON'T edit this file for a new game; edit Gameplay.gd.

enum State { MENU, PLAYING, OVER }

var state: State = State.MENU
var gameplay: Gameplay
var _over_at := 0.0

var bg: ColorRect
var menu_box: Control
var hud_box: Control
var over_box: Control
var score_label: Label
var best_label: Label
var over_score: Label
var over_best: Label
var lb_box: VBoxContainer
var promo_box: HBoxContainer
var offline_label: Label


func _ready() -> void:
	gameplay = Gameplay.new()
	add_child(gameplay)
	gameplay.score_changed.connect(_on_score_changed)
	gameplay.game_ended.connect(_on_game_ended)
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

	menu_box = _center_box(root)
	_label(menu_box, ProjectSettings.get_setting("application/config/name", "GAME"), 72, Color.WHITE)
	best_label = _label(menu_box, "BEST 0", 36, Color(1, 1, 1, 0.75))
	_spacer(menu_box, 60)
	_label(menu_box, "TAP TO PLAY", 44, Color(1, 1, 0.6))

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
	_spacer(over_center, 24)
	lb_box = VBoxContainer.new()
	lb_box.alignment = BoxContainer.ALIGNMENT_CENTER
	over_center.add_child(lb_box)
	_spacer(over_center, 24)
	_label(over_center, "TAP TO RETRY", 40, Color(1, 1, 0.6))
	_spacer(over_center, 30)
	promo_box = HBoxContainer.new()
	promo_box.alignment = BoxContainer.ALIGNMENT_CENTER
	promo_box.add_theme_constant_override("separation", 16)
	over_center.add_child(promo_box)

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
	gameplay.start_game()
	Analytics.track("game_start", {})


func _on_score_changed(score: int) -> void:
	score_label.text = str(score)


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
		var title := Label.new()
		title.text = "— TOP PLAYERS —"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.add_theme_font_size_override("font_size", 26)
		title.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
		lb_box.add_child(title)
		for e in entries:
			var row := Label.new()
			row.text = "%d. %s   %d" % [e.get("rank", 0), e.get("name", "?"), e.get("score", 0)]
			row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			row.add_theme_font_size_override("font_size", 30)
			if e.get("you", false):
				row.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
			lb_box.add_child(row)
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


# ---------- input ----------

func _unhandled_input(event: InputEvent) -> void:
	var tapped: bool = (event is InputEventScreenTouch and event.pressed)
	if not tapped:
		return
	match state:
		State.MENU:
			_start_game()
		State.PLAYING:
			gameplay.on_tap()
		State.OVER:
			if Time.get_ticks_msec() / 1000.0 - _over_at > 0.9:
				_start_game()


func _process(_delta: float) -> void:
	offline_label.visible = not Backend.online
