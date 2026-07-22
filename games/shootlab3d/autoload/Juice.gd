extends Node
## Shared JUICE toolkit. Template file: copy unchanged to every game
## (tools/sync_autoloads.py does this for you).
##
## Screen flash, hit-stop, floating popups, particle bursts, camera shake,
## haptics, and SYNTHESIZED sound effects — zero asset files, so every game
## gets audio+feel for free. Intensity is a remote-config dial:
##   "juice_level": 0 = off · 1 = minimal · 2 = full (default) · 3 = extra
## That makes juice an A/B experiment like everything else: ship the same
## game at different juice levels and compare retention.

var _flash_rect: ColorRect
var _popup_layer: CanvasLayer
var _sounds := {}
var _players: Array = []


func _lv() -> int:
	return clampi(int(Backend.cfg("juice_level", 2)), 0, 3)


func _ready() -> void:
	var fl := CanvasLayer.new()
	fl.layer = 90
	add_child(fl)
	_flash_rect = ColorRect.new()
	_flash_rect.color = Color(1, 1, 1, 0)
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fl.add_child(_flash_rect)
	_popup_layer = CanvasLayer.new()
	_popup_layer.layer = 91
	add_child(_popup_layer)

	_sounds["chime"] = _tone([1318.5, 1760.0], 0.09)   # perfect / success
	_sounds["coin"] = _tone([987.8, 1318.5], 0.07)     # pickup / reward
	_sounds["tick"] = _tone([660.0], 0.035)            # UI / step
	_sounds["thud"] = _noise(0.09)                     # placement / hit
	_sounds["boom"] = _noise(0.35)                     # death / explosion
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


# ---------- sound (synthesized, no files) ----------

func sfx(name: String, pitch := 1.0) -> void:
	if _lv() == 0 or not _sounds.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _sounds[name]
			p.pitch_scale = pitch * randf_range(0.94, 1.06)
			p.play()
			return


func _tone(freqs: Array, dur_each: float) -> AudioStreamWAV:
	var rate := 22050
	var n_each := int(dur_each * rate)
	var total := n_each * freqs.size()
	var data := PackedByteArray()
	data.resize(total * 2)
	for fi in freqs.size():
		var freq: float = freqs[fi]
		for i in n_each:
			var env := exp(-5.0 * float(i) / float(n_each))
			var s := sin(TAU * freq * float(i) / float(rate)) * env * 0.38
			data.encode_s16((fi * n_each + i) * 2, int(s * 32767.0))
	return _wav(data, rate)


func _noise(dur: float) -> AudioStreamWAV:
	var rate := 22050
	var n := int(dur * rate)
	var data := PackedByteArray()
	data.resize(n * 2)
	var v := 0.0
	for i in n:
		v = v * 0.86 + randf_range(-1.0, 1.0) * 0.5
		var env := exp(-6.0 * float(i) / float(n))
		data.encode_s16(i * 2, int(clampf(v * env * 0.8, -1.0, 1.0) * 32767.0))
	return _wav(data, rate)


func _wav(data: PackedByteArray, rate: int) -> AudioStreamWAV:
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = data
	return wav


# ---------- feel ----------

func haptic(ms := 30) -> void:
	if _lv() >= 1 and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)


func flash(col := Color(1, 1, 1), strength := 0.25) -> void:
	if _lv() == 0:
		return
	_flash_rect.color = Color(col.r, col.g, col.b, strength * (1.4 if _lv() == 3 else 1.0))
	var t := create_tween()
	t.tween_property(_flash_rect, "color:a", 0.0, 0.25)


func hitstop(msec := 60) -> void:
	## Freeze the whole game for a few real-time milliseconds — the classic
	## "impact" trick. Fire-and-forget (async).
	if _lv() < 2:
		return
	Engine.time_scale = 0.05
	await get_tree().create_timer(msec / 1000.0, true, false, true).timeout
	Engine.time_scale = 1.0


func popup(text: String, screen_pos: Vector2, col := Color(1, 0.9, 0.4), font_size := 42) -> void:
	if _lv() == 0:
		return
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", col)
	l.position = screen_pos - Vector2(200, 24)
	l.size = Vector2(400, 60)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_popup_layer.add_child(l)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(l, "position:y", l.position.y - 90.0, 0.6).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "modulate:a", 0.0, 0.55).set_delay(0.2)
	t.chain().tween_callback(l.queue_free)


func shake2d(cam: Camera2D, amount := 8.0) -> void:
	if _lv() == 0 or cam == null:
		return
	var amt := amount * [0.0, 0.5, 1.0, 1.5][_lv()]
	var t := create_tween()
	t.tween_method(func(v: float):
		cam.offset = Vector2(randf_range(-v, v), randf_range(-v, v)), amt, 0.0, 0.3)
	t.tween_callback(func(): cam.offset = Vector2.ZERO)


func burst(parent: Node2D, pos: Vector2, col: Color, n := 16) -> void:
	if _lv() < 2 or parent == null:
		return
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = n * (2 if _lv() == 3 else 1)
	p.lifetime = 0.5
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 260.0
	p.gravity = Vector2(0, 600)
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = col
	p.position = pos
	parent.add_child(p)
	p.emitting = true
	p.finished.connect(p.queue_free)
