class_name TouchControls
extends Control
## Shared on-screen touch overlay for the 3D labs. Renders a VISIBLE floating
## joystick on the left, a cluster of labeled action buttons bottom-right, and an
## optional right-side look region — so the mechanic is playable on a phone, not
## just with a keyboard. Owns its own multitouch (one finger per role, tracked by
## event.index) and consumes only the touches it uses, so the shell's MENU button
## and retry-tap still work. Desktop mouse works too (the project emulates touch
## from the mouse); each demo's key_axis_* keyboard movement runs in parallel.
##
## Layout is computed from the LIVE viewport size every frame, so buttons stay
## pinned to the real screen edges under the mobile "expand" stretch and rotation
## (never assumes the 720x1280 design box is the device's actual pixel box).
##
## Usage from a demo's start():
##   var tc := add_touch_controls([
##       {"id": "fire", "label": "FIRE", "col": Color(0.85, 0.4, 0.35)},
##   ], true)                          # 2nd arg true = enable look region
##   tc.action.connect(_on_action)     # id string, on press
##   tc.look.connect(_on_look)         # Vector2 relative, look demos only
##   # then read tc.move (Vector2, -1..1) as the movement stick, and
##   # tc.held("fire") for hold-to-act buttons.

signal action(id: String)      # a button went down this frame
signal released(id: String)    # a held button was let go
signal look(rel: Vector2)      # look-region drag delta (only if want_look)

var move := Vector2.ZERO       # current joystick vector, length 0..1
var show_stick := true
var use_look := false

const BASE := 96.0             # joystick radius
const KNOB := 50.0
const BTN := 148.0             # action button side
const GAP := 22.0
const MARGIN := 40.0
const LOOK_TOP := 150.0        # leave the shell's top bar free for the MENU button

var _demo: MechDemo3D = null
var _defs: Array = []          # [{id,label,col}]  (rects computed live)
var _held := {}                # id -> true while pressed
var _stick_i := -1
var _home := Vector2.ZERO
var _look_i := -1
var _btn_i := {}               # touch index -> button id


func _ready() -> void:
	# the first layout can report size 0; redraw when it (or a rotation) settles
	resized.connect(queue_redraw)


func setup(demo: MechDemo3D, buttons: Array, want_look := false, want_stick := true) -> void:
	_demo = demo
	use_look = want_look
	show_stick = want_stick
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_defs = []
	for b in buttons:
		_defs.append({
			"id": str(b.get("id", "")),
			"label": str(b.get("label", "?")),
			"col": b.get("col", Color(0.85, 0.85, 0.92)),
		})
	queue_redraw()


func held(id: String) -> bool:
	return _held.get(id, false)


func _vp() -> Vector2:
	var s := size
	return s if s.x > 1.0 and s.y > 1.0 else Vector2(720, 1280)


func _btn_rect(i: int) -> Rect2:
	var vp := _vp()
	var col: int = i % 2
	var row: int = i >> 1
	var x := vp.x - MARGIN - BTN - col * (BTN + GAP)
	var y := vp.y - (MARGIN + 20.0) - BTN - row * (BTN + GAP)
	return Rect2(x, y, BTN, BTN)


func _active() -> bool:
	return visible and _demo != null and _demo.running


func _input(event: InputEvent) -> void:
	if not _active():
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			var p: Vector2 = event.position
			for i in _defs.size():
				if _btn_rect(i).has_point(p):
					var id: String = _defs[i].id
					_btn_i[event.index] = id
					_held[id] = true
					action.emit(id)
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
			if show_stick and p.x < _vp().x * 0.5 and _stick_i == -1:
				_stick_i = event.index
				_home = p
				move = Vector2.ZERO
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif use_look and p.x >= _vp().x * 0.5 and p.y > LOOK_TOP and _look_i == -1:
				_look_i = event.index
				get_viewport().set_input_as_handled()
		else:
			if _btn_i.has(event.index):
				var id: String = _btn_i[event.index]
				_held.erase(id)
				_btn_i.erase(event.index)
				released.emit(id)
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif event.index == _stick_i:
				_stick_i = -1
				move = Vector2.ZERO
				queue_redraw()
				get_viewport().set_input_as_handled()
			elif event.index == _look_i:
				_look_i = -1
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == _stick_i:
			move = ((event.position - _home) / BASE).limit_length(1.0)
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif event.index == _look_i:
			look.emit(event.relative)
			get_viewport().set_input_as_handled()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	var vp := _vp()
	# joystick
	if show_stick:
		if _stick_i != -1:
			draw_circle(_home, BASE, Color(1, 1, 1, 0.08))
			draw_arc(_home, BASE, 0, TAU, 48, Color(1, 1, 1, 0.35), 3.0, true)
			draw_circle(_home + move * BASE, KNOB, Color(1, 1, 1, 0.28))
			draw_arc(_home + move * BASE, KNOB, 0, TAU, 32, Color(1, 1, 1, 0.5), 2.0, true)
		else:
			var hint := Vector2(160, vp.y - 210)
			draw_arc(hint, BASE, 0, TAU, 48, Color(1, 1, 1, 0.14), 3.0, true)
			draw_circle(hint, KNOB * 0.8, Color(1, 1, 1, 0.08))
	if use_look:
		draw_string(font, Vector2(vp.x - 250, LOOK_TOP + 30), "drag to look",
			HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.22))
	# buttons
	for i in _defs.size():
		var r := _btn_rect(i)
		var d: Dictionary = _defs[i]
		var fill: Color = d.col
		fill.a = 0.8 if _held.get(d.id, false) else 0.42
		draw_rect(r, fill, true)
		draw_rect(r, Color(1, 1, 1, 0.55), false, 2.0)
		var tw := font.get_string_size(d.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30).x
		draw_string(font, r.position + Vector2((r.size.x - tw) * 0.5, r.size.y * 0.5 + 11),
			d.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color.WHITE)
