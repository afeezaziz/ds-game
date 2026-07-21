extends Node2D
## MechLab shell: a museum of playable mechanics. Registry-driven menu;
## each demo gets its own leaderboard (board == demo key), local best and
## analytics tag. Adding a demo = one script + one DEMOS entry.

enum State { MENU, PLAYING, OVER }

const DEMOS := {
	"roguerun": {"title": "ROGUELIKE RUN", "era": "map · relics · ascension (Hades/StS)", "script": preload("res://scripts/demos/RogueRun.gd")},
	"prestige": {"title": "PRESTIGE", "era": "reset-for-multiplier (AdCap)", "script": preload("res://scripts/demos/Prestige.gd")},
	"basebuild": {"title": "BASE BUILD + RAID", "era": "build-and-battle (Clash)", "script": preload("res://scripts/demos/BaseBuild.gd")},
	"tactics": {"title": "TURN TACTICS", "era": "grid battle (Into the Breach)", "script": preload("res://scripts/demos/Tactics.gd")},
	"bosshell": {"title": "BOSS BULLET-HELL", "era": "telegraph-dodge-punish", "script": preload("res://scripts/demos/BossHell.gd")},
	"citysim": {"title": "CITY SIM", "era": "food/pop/coin balance (SimCity)", "script": preload("res://scripts/demos/CitySim.gd")},
}
const ORDER := ["roguerun", "prestige", "basebuild", "tactics", "bosshell", "citysim"]

var state: State = State.MENU
var current_key := ""
var demo: MechDemo = null
var _over_at := 0.0

var menu_box: Control
var grid: GridContainer
var hud_box: Control
var over_box: Control
var score_label: Label
var title_label: Label
var over_score: Label
var over_best: Label
var lb_title: Label
var lb_box: VBoxContainer
var offline_label: Label


func _ready() -> void:
	_build_ui()
	_show_menu()


func _build_ui() -> void:
	var ui := CanvasLayer.new()
	ui.layer = 1
	add_child(ui)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(root)

	# menu
	menu_box = Control.new()
	menu_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu_box)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.14)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_box.add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.add_theme_constant_override("separation", 8)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_box.add_child(v)
	_lbl(v, "DEEPLAB", 72, Color.WHITE)
	_lbl(v, "deep / systemic mechanics · pick an exhibit", 24, Color(1, 1, 1, 0.5))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 20)
	v.add_child(sp)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(700, 980)
	sc.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(sc)
	var scc := CenterContainer.new()
	scc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(scc)
	grid = GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 14)
	scc.add_child(grid)

	# HUD
	hud_box = Control.new()
	hud_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_box)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 26)
	title_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	title_label.position = Vector2(20, 18)
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(title_label)
	score_label = Label.new()
	score_label.text = "0"
	score_label.add_theme_font_size_override("font_size", 56)
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	score_label.position = Vector2(-100, 44)
	score_label.size = Vector2(200, 70)
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(score_label)
	var back := Button.new()
	back.text = "MENU"
	back.add_theme_font_size_override("font_size", 24)
	back.custom_minimum_size = Vector2(110, 60)
	back.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	back.position = Vector2(-130, 20)
	back.pressed.connect(_back_to_menu)
	hud_box.add_child(back)

	# over overlay
	over_box = Control.new()
	over_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	over_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(over_box)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_box.add_child(dim)
	var occ := CenterContainer.new()
	occ.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	occ.mouse_filter = Control.MOUSE_FILTER_IGNORE
	over_box.add_child(occ)
	var ov := VBoxContainer.new()
	ov.alignment = BoxContainer.ALIGNMENT_CENTER
	ov.add_theme_constant_override("separation", 10)
	occ.add_child(ov)
	_lbl(ov, "RUN OVER", 56, Color.WHITE)
	over_score = _lbl(ov, "0", 100, Color(1, 0.85, 0.3))
	over_best = _lbl(ov, "", 32, Color(1, 1, 1, 0.8))
	lb_title = _lbl(ov, "", 26, Color(1, 1, 1, 0.6))
	lb_box = VBoxContainer.new()
	lb_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ov.add_child(lb_box)
	_lbl(ov, "TAP TO RETRY", 36, Color(1, 1, 0.6))
	var menu_btn := Button.new()
	menu_btn.text = "ALL MECHANICS"
	menu_btn.add_theme_font_size_override("font_size", 26)
	menu_btn.custom_minimum_size = Vector2(260, 64)
	menu_btn.pressed.connect(_back_to_menu)
	ov.add_child(menu_btn)

	offline_label = Label.new()
	offline_label.text = "OFFLINE"
	offline_label.add_theme_font_size_override("font_size", 22)
	offline_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	offline_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	offline_label.position = Vector2(20, -44)
	offline_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(offline_label)


func _lbl(box: Control, text: String, font_size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(l)
	return l


# ---------- flow ----------

func _enabled() -> Array:
	var cfg: Variant = Backend.cfg("enabled_demos", [])
	if cfg is Array and not (cfg as Array).is_empty():
		var known := (cfg as Array).filter(func(k): return DEMOS.has(str(k)))
		if not known.is_empty():
			return known
	return ORDER


func _show_menu() -> void:
	_teardown_demo(true)
	state = State.MENU
	menu_box.visible = true
	hud_box.visible = false
	over_box.visible = false
	for c in grid.get_children():
		c.queue_free()
	for k in _enabled():
		var d: Dictionary = DEMOS[k]
		var b := Button.new()
		var best := GameState.best_for(k)
		b.text = "%s\n%s%s" % [d["title"], d["era"],
			("\nBEST %d" % best) if best > 0 else ""]
		b.add_theme_font_size_override("font_size", 24)
		b.custom_minimum_size = Vector2(330, 108)
		b.pressed.connect(_start_demo.bind(str(k)))
		grid.add_child(b)


func _start_demo(key: String) -> void:
	_teardown_demo(false)
	current_key = key
	state = State.PLAYING
	menu_box.visible = false
	over_box.visible = false
	hud_box.visible = true
	title_label.text = str(DEMOS[key]["title"])
	score_label.text = "0"
	demo = (DEMOS[key]["script"] as GDScript).new()
	add_child(demo)
	demo.score_changed.connect(func(s): score_label.text = str(s))
	demo.demo_over.connect(_on_demo_over)
	demo.start()
	Analytics.track("demo_start", {"demo": key})


func _teardown_demo(submit_endless: bool) -> void:
	if demo == null:
		return
	if submit_endless and demo.running and demo.score > 0:
		# Endless demos submit on exit.
		GameState.report_score(demo.score, current_key)
		Backend.submit_score(demo.score, current_key)
		Analytics.track("demo_over", {"demo": current_key, "score": demo.score, "endless": true})
	demo.queue_free()
	demo = null


func _on_demo_over(score: int) -> void:
	state = State.OVER
	_over_at = Time.get_ticks_msec() / 1000.0
	GameState.register_death()
	var improved := GameState.report_score(score, current_key)
	Analytics.track("demo_over", {"demo": current_key, "score": score})
	Analytics.flush()
	Ads.maybe_show_interstitial()
	await Ads.interstitial_closed
	over_box.visible = true
	over_score.text = str(score)
	over_best.text = "NEW BEST!" if improved else "BEST %d" % GameState.best_for(current_key)
	_populate_leaderboard(score)


func _populate_leaderboard(score: int) -> void:
	lb_title.text = ""
	for c in lb_box.get_children():
		c.queue_free()
	if not Backend.online:
		return
	await Backend.submit_score(score, current_key)
	var lb: Dictionary = await Backend.get_leaderboard(5, current_key)
	if state != State.OVER:
		return
	var entries: Array = lb.get("entries", [])
	if entries.is_empty():
		return
	lb_title.text = "— TOP · %s —" % str(DEMOS[current_key]["title"])
	for e in entries:
		var row := Label.new()
		row.text = "%d. %s   %d" % [e.get("rank", 0), e.get("name", "?"), e.get("score", 0)]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 28)
		if e.get("you", false):
			row.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		lb_box.add_child(row)


func _back_to_menu() -> void:
	_show_menu()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch and event.pressed):
		return
	if state == State.OVER and Time.get_ticks_msec() / 1000.0 - _over_at > 0.9:
		var key := current_key
		over_box.visible = false
		_start_demo(key)


func _process(_delta: float) -> void:
	offline_label.visible = not Backend.online
