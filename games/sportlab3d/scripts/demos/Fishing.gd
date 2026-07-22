extends MechDemo3D
## FISHING — cast, hook, reel. HOLD CAST to build distance and release to drop the
## bobber; wait for the strike and tap HOOK inside the window; then HOLD REEL to
## bring it in — but the fish RUNS and the line tension climbs, so ease off when it
## bolts or the line snaps. Land fish by size. Desktop: SPACE cast, H hook, R reel.

enum St { AIM, WAIT, BITE, REEL, SNAP }
var st: St = St.AIM
var power := 0.0
var charging := false
var bobber: Node3D
var bpos := Vector3(0, 0.1, -6)
var wait_t := 0.0
var bite_t := 0.0
var progress := 0.0
var tension := 0.0
var run_t := 0.0
var fish_size := 0
var caught := 0
var misses := 0
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.55, 0.72, 0.9), 0.95)
	static_box(Vector3(60, 1, 60), Vector3(0, -0.7, -20), Color(0.2, 0.45, 0.7))
	static_box(Vector3(8, 0.6, 4), Vector3(0, 0.1, 4), Color(0.5, 0.4, 0.3))  # dock
	bobber = mesh_sphere(0.35, Vector3(0, 0.1, -6), Color(1, 0.3, 0.3))
	st = St.AIM
	caught = 0
	misses = 0
	make_camera(Vector3(0, 5, 9), Vector3(0, 0, -8), 60.0)
	hud = label3d("", Vector3(0, 5, -2), 34, Color.WHITE)
	tc = add_touch_controls([
		{"id": "cast", "label": "CAST", "col": Color(0.5, 0.8, 0.6)},
		{"id": "hook", "label": "HOOK", "col": Color(0.95, 0.8, 0.3)},
		{"id": "reel", "label": "REEL", "col": Color(0.5, 0.65, 0.95)},
	], false, false)
	tc.action.connect(func(id):
		if id == "cast": charging = true
		elif id == "hook": _hook())
	tc.released.connect(func(id):
		if id == "cast": _cast())


func _cast() -> void:
	if st != St.AIM or not charging:
		charging = false
		return
	charging = false
	bpos = Vector3(0, 0.1, -4.0 - power * 22.0)
	power = 0.0
	st = St.WAIT
	wait_t = randf_range(1.5, 4.0)
	Juice.sfx("tick")


func _hook() -> void:
	if st != St.BITE:
		return
	# hooked! size determines the fight
	fish_size = randi_range(1, 5)
	progress = 0.0
	tension = 0.2
	run_t = randf_range(0.6, 1.4)
	st = St.REEL
	Juice.sfx("thud")
	Juice.haptic(20)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and not event.echo:
		if event.keycode == KEY_SPACE:
			if event.pressed:
				charging = true
			else:
				_cast()
		elif event.pressed and event.keycode == KEY_H:
			_hook()


func _reeling() -> bool:
	return tc.held("reel") or Input.is_key_pressed(KEY_R)


func _process(delta: float) -> void:
	if not running:
		return
	if charging:
		power = min(1.0, power + delta * 0.7)
	bobber.position = bpos + Vector3(0, sin(Time.get_ticks_msec() * 0.004) * 0.1, 0)

	match st:
		St.WAIT:
			wait_t -= delta
			if wait_t <= 0.0:
				st = St.BITE
				bite_t = 0.9
				Juice.sfx("tick")
				Juice.haptic(15)
		St.BITE:
			bite_t -= delta
			bobber.position += Vector3(0, -0.25, 0)   # dip
			if bite_t <= 0.0:
				st = St.AIM                              # missed the bite
				misses += 1
				Juice.popup("...it got away", Vector2(W * 0.5, H * 0.4), Color(0.8, 0.8, 0.9))
				if misses >= 5:
					end_demo()
					return
		St.REEL:
			run_t -= delta
			var running_now := _reeling()
			if run_t <= 0.0:
				# the fish makes a run: tension spikes if you keep reeling
				run_t = randf_range(0.7, 1.6)
			var fish_running := run_t < 0.5
			if running_now:
				progress += (0.10 + fish_size * 0.008) * delta * 60.0 * delta
				tension += (0.9 if fish_running else 0.35) * delta
			else:
				tension -= 0.7 * delta
			tension = clampf(tension, 0.0, 1.0)
			if tension >= 1.0:
				st = St.AIM
				misses += 1
				Juice.sfx("boom")
				Juice.flash(Color(1, 0.4, 0.3), 0.3)
				Juice.popup("LINE SNAPPED", Vector2(W * 0.5, H * 0.4), Color(1, 0.5, 0.4))
				if misses >= 5:
					end_demo()
					return
			elif progress >= 1.0:
				caught += 1
				add_points(fish_size)
				st = St.AIM
				Juice.sfx("coin")
				Juice.flash(Color(0.5, 1, 0.6), 0.25)
				Juice.popup("LANDED! size %d +%d" % [fish_size, fish_size], Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))

	cam.look_at(bpos + Vector3(0, 0, -2), Vector3.UP)
	var line := ""
	match st:
		St.AIM: line = "HOLD CAST  power %d%%" % int(power * 100)
		St.WAIT: line = "waiting for a bite..."
		St.BITE: line = "!! HOOK NOW !!"
		St.REEL: line = "REEL  fish %d  progress %d%%  TENSION %d%%" % [fish_size, int(progress * 100), int(tension * 100)]
		St.SNAP: line = ""
	hud.text = "%s\ncaught %d   misses %d/5" % [line, caught, misses]
