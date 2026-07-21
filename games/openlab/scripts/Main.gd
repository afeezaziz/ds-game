extends Node3D
## OpenLab — open-world mechanics gray-box. Everything is a system to feel:
## third-person movement + orbit camera, car & horse (enter/exit), hitscan
## shooting, crowd AI, wanted level + police + BUSTED loop, procedural
## missions, day/night, minimap. Desktop: WASD + mouse (right-drag = camera,
## left-click = shoot, E = enter/exit, Space = jump). Touch: left half =
## move stick, right half = camera drag, on-screen JUMP / ACT / FIRE.

enum State { MENU, PLAYING, BUSTED }

const BOUNDS := 45.0
const GRID := 14.0

var state: State = State.MENU
var player: OpenPlayer
var car: OpenVehicle
var horse: OpenVehicle
var mounted: OpenVehicle = null
var npcs: Array = []
var missions: MissionManager
var cam: Camera3D
var sun: DirectionalLight3D
var env: Environment

var yaw := 0.0
var pitch := 0.5
var score := 0
var wanted := 0
var wanted_t := 0.0
var day_t := 0.35
var day_length := 150.0
var npc_count := 14

# touch state
var _stick_id := -1
var _stick_origin := Vector2.ZERO
var _stick_vec := Vector2.ZERO
var _busted_t := 0.0

# UI
var menu_box: Control
var hud_box: Control
var busted_box: Control
var score_label: Label
var wanted_label: Label
var objective_label: Label
var prompt_label: Label
var best_label: Label
var lb_box: VBoxContainer
var offline_label: Label
var crosshair: Label
var minimap: MiniMap
var flash_rect: ColorRect


func _ready() -> void:
	day_length = float(Backend.cfg("day_length_s", day_length))
	npc_count = int(Backend.cfg("npc_count", npc_count))
	_build_world()
	_build_ui()
	_show_menu()


# ---------------- world ----------------

func _build_world() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.7, 0.95)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.75
	we.environment = env
	add_child(we)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -35, 0)
	sun.light_energy = 1.1
	add_child(sun)

	# Ground
	var ground := StaticBody3D.new()
	var gshape := CollisionShape3D.new()
	var gbox := BoxShape3D.new()
	gbox.size = Vector3(2.0 * BOUNDS + 30.0, 1.0, 2.0 * BOUNDS + 30.0)
	gshape.shape = gbox
	gshape.position = Vector3(0, -0.5, 0)
	ground.add_child(gshape)
	var gmesh := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = gbox.size
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.25, 0.27, 0.3)
	gmat.roughness = 1.0
	gm.material = gmat
	gmesh.mesh = gm
	gmesh.position = Vector3(0, -0.5, 0)
	ground.add_child(gmesh)
	add_child(ground)

	# City blocks (roads are the gaps in the grid)
	for gx in range(-3, 4):
		for gz in range(-3, 4):
			if absi(gx) <= 0 and absi(gz) <= 0:
				continue  # plaza at spawn
			var h := randf_range(5.0, 18.0)
			var w := randf_range(7.0, 9.5)
			var d := randf_range(7.0, 9.5)
			var b := StaticBody3D.new()
			b.position = Vector3(gx * GRID, h * 0.5, gz * GRID)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(w, h, d)
			cs.shape = bs
			b.add_child(cs)
			var mi := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = bs.size
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color.from_hsv(randf_range(0.5, 0.7), 0.15, randf_range(0.45, 0.7))
			mat.roughness = 0.95
			bm.material = mat
			mi.mesh = bm
			b.add_child(mi)
			add_child(b)

	player = OpenPlayer.new()
	player.position = Vector3(0, 1.0, 3.0)
	add_child(player)

	car = OpenVehicle.new()
	car.setup("car")
	car.position = Vector3(5.0, 1.0, 7.0)
	add_child(car)

	horse = OpenVehicle.new()
	horse.setup("horse")
	horse.position = Vector3(-5.0, 1.0, 7.0)
	add_child(horse)

	missions = MissionManager.new()
	add_child(missions)
	missions.mission_text.connect(_on_mission_text)
	missions.mission_reward.connect(_on_mission_reward)

	for i in npc_count:
		_spawn_npc(false)

	cam = Camera3D.new()
	cam.fov = 70.0
	add_child(cam)
	cam.make_current()
	cam.position = Vector3(0, 4, 12)


func _spawn_npc(cop: bool) -> void:
	var npc := OpenNPC.new()
	add_child(npc)
	npc.setup(cop, player, BOUNDS)
	npc.position = Vector3(randf_range(-BOUNDS, BOUNDS), 1.0, randf_range(-BOUNDS, BOUNDS))
	npc.downed.connect(_on_npc_downed)
	npcs.append(npc)


# ---------------- UI ----------------

func _build_ui() -> void:
	var ui_layer := CanvasLayer.new()
	ui_layer.layer = 1
	add_child(ui_layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_layer.add_child(root)

	# menu
	menu_box = Control.new()
	menu_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(menu_box)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_box.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_box.add_child(cc)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	cc.add_child(box)
	_lbl(box, "OPENLAB", 82, Color.WHITE)
	_lbl(box, "open-world mechanics gray-box", 26, Color(1, 1, 1, 0.55))
	best_label = _lbl(box, "BEST 0", 34, Color(1, 1, 1, 0.75))
	_sp(box, 16)
	var start := Button.new()
	start.text = "ENTER CITY"
	start.add_theme_font_size_override("font_size", 36)
	start.custom_minimum_size = Vector2(340, 84)
	start.pressed.connect(_start_game)
	box.add_child(start)
	_sp(box, 10)
	_lbl(box, "WASD move · right-drag camera · E enter/exit\nleft-click shoot · Space jump · missions = yellow pillars",
		22, Color(1, 1, 1, 0.5))
	_sp(box, 12)
	lb_box = VBoxContainer.new()
	lb_box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(lb_box)

	# HUD
	hud_box = Control.new()
	hud_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud_box)
	score_label = Label.new()
	score_label.add_theme_font_size_override("font_size", 44)
	score_label.position = Vector2(24, 20)
	score_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(score_label)
	wanted_label = Label.new()
	wanted_label.add_theme_font_size_override("font_size", 38)
	wanted_label.add_theme_color_override("font_color", Color(1, 0.35, 0.3))
	wanted_label.position = Vector2(24, 74)
	wanted_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(wanted_label)
	objective_label = Label.new()
	objective_label.add_theme_font_size_override("font_size", 28)
	objective_label.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	objective_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	objective_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	objective_label.position = Vector2(-330, 130)
	objective_label.size = Vector2(660, 70)
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	objective_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(objective_label)
	prompt_label = Label.new()
	prompt_label.add_theme_font_size_override("font_size", 30)
	prompt_label.add_theme_color_override("font_color", Color(0.7, 1, 0.7))
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.position = Vector2(-250, -320)
	prompt_label.size = Vector2(500, 40)
	prompt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(prompt_label)
	crosshair = Label.new()
	crosshair.text = "+"
	crosshair.add_theme_font_size_override("font_size", 40)
	crosshair.set_anchors_preset(Control.PRESET_CENTER)
	crosshair.position = Vector2(-12, -26)
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(crosshair)

	minimap = MiniMap.new()
	minimap.main = self
	minimap.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	minimap.position = Vector2(-180, 20)
	minimap.size = Vector2(160, 160)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud_box.add_child(minimap)

	# touch buttons
	var act := Button.new()
	act.text = "ACT"
	act.add_theme_font_size_override("font_size", 28)
	act.custom_minimum_size = Vector2(120, 84)
	act.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	act.position = Vector2(-150, -240)
	act.pressed.connect(_interact)
	hud_box.add_child(act)
	var jump := Button.new()
	jump.text = "JUMP"
	jump.add_theme_font_size_override("font_size", 28)
	jump.custom_minimum_size = Vector2(120, 84)
	jump.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	jump.position = Vector2(-150, -140)
	jump.pressed.connect(func(): player.want_jump = true)
	hud_box.add_child(jump)
	var fire := Button.new()
	fire.text = "FIRE"
	fire.add_theme_font_size_override("font_size", 28)
	fire.custom_minimum_size = Vector2(120, 84)
	fire.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	fire.position = Vector2(-290, -140)
	fire.pressed.connect(_shoot)
	hud_box.add_child(fire)

	# busted overlay
	busted_box = Control.new()
	busted_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	busted_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(busted_box)
	var bdim := ColorRect.new()
	bdim.color = Color(0.4, 0, 0, 0.55)
	bdim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bdim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busted_box.add_child(bdim)
	var bcc := CenterContainer.new()
	bcc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bcc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	busted_box.add_child(bcc)
	var bl := Label.new()
	bl.text = "BUSTED"
	bl.add_theme_font_size_override("font_size", 110)
	bl.add_theme_color_override("font_color", Color(1, 1, 1))
	bcc.add_child(bl)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(flash_rect)
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


func _sp(box: Control, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(s)


# ---------------- state flow ----------------

func _show_menu() -> void:
	state = State.MENU
	menu_box.visible = true
	hud_box.visible = false
	busted_box.visible = false
	best_label.text = "BEST %d" % GameState.best_score
	missions.stop()
	_fill_menu_leaderboard()


func _fill_menu_leaderboard() -> void:
	for c in lb_box.get_children():
		c.queue_free()
	if not Backend.online:
		return
	var lb: Dictionary = await Backend.get_leaderboard(5)
	if state != State.MENU:
		return
	var entries: Array = lb.get("entries", [])
	for e in entries:
		var row := Label.new()
		row.text = "%d. %s   %d" % [e.get("rank", 0), e.get("name", "?"), e.get("score", 0)]
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_theme_font_size_override("font_size", 26)
		if e.get("you", false):
			row.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
		lb_box.add_child(row)


func _start_game() -> void:
	state = State.PLAYING
	menu_box.visible = false
	hud_box.visible = true
	busted_box.visible = false
	score = 0
	wanted = 0
	_dismount(false)
	player.position = Vector3(0, 1.0, 3.0)
	_update_hud()
	missions.begin()
	Analytics.track("game_start", {})


func _on_mission_text(text: String) -> void:
	objective_label.text = text


func _on_mission_reward(points: int, done: bool) -> void:
	score += points
	_update_hud()
	_flash(0.15)
	if done:
		var improved := GameState.report_score(score)
		Backend.submit_score(score)
		if improved:
			objective_label.text += "  (NEW BEST!)"


func _on_npc_downed(npc) -> void:
	npcs.erase(npc)
	_raise_wanted()
	for other in npcs:
		if is_instance_valid(other) and other.position.distance_to(npc.position) < 12.0:
			other.alert_flee()
	# keep the city populated
	_spawn_npc(false)


func _raise_wanted() -> void:
	wanted = mini(5, wanted + 1)
	wanted_t = float(Backend.cfg("wanted_decay_s", 18.0))
	Analytics.track("wanted", {"level": wanted})
	if wanted == 1:
		_spawn_npc(true)
		_spawn_npc(true)
	for npc in npcs:
		if is_instance_valid(npc) and npc.is_cop:
			npc.set_chasing(true)
	_update_hud()


func _busted() -> void:
	state = State.BUSTED
	_busted_t = 1.6
	busted_box.visible = true
	wanted = 0
	score = maxi(0, score - int(Backend.cfg("busted_penalty", 50)))
	GameState.register_death()
	Analytics.track("busted", {"score": score})
	Analytics.flush()
	for npc in npcs:
		if is_instance_valid(npc) and npc.is_cop:
			npc.set_chasing(false)
	_dismount(false)
	player.position = Vector3(0, 1.0, 3.0)
	_update_hud()


func _update_hud() -> void:
	score_label.text = "SCORE %d" % score
	wanted_label.text = "*".repeat(wanted)


# ---------------- interaction / combat ----------------

func _active_body() -> Node3D:
	return mounted if mounted != null else player


func _interact() -> void:
	if state != State.PLAYING:
		return
	if mounted != null:
		_dismount(true)
		return
	if player.position.distance_to(car.position) < 3.0:
		_mount(car)
	elif player.position.distance_to(horse.position) < 3.0:
		_mount(horse)


func _mount(v: OpenVehicle) -> void:
	mounted = v
	v.occupied = true
	player.visible = false
	player.position = v.position + Vector3(0, 0.5, 0)
	Analytics.track("mount", {"kind": v.kind})


func _dismount(track: bool) -> void:
	if mounted == null:
		return
	mounted.occupied = false
	player.position = mounted.position + Vector3(2.0, 1.0, 0)
	player.visible = true
	if track:
		Analytics.track("dismount", {"kind": mounted.kind})
	mounted = null


var _shoot_requested := false


func _shoot() -> void:
	if state != State.PLAYING or mounted != null:
		return
	_flash(0.06)
	Analytics.track("shot", {})
	_shoot_requested = true


func _physics_process(_delta: float) -> void:
	# Raycasts must run inside the physics step in Godot 4.
	if not _shoot_requested:
		return
	_shoot_requested = false
	var from := cam.global_position
	var dir := -cam.global_transform.basis.z
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 70.0)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return
	var collider: Object = hit.get("collider")
	if collider is OpenNPC:
		(collider as OpenNPC).hit()
	else:
		# a warning shot near civilians still scatters them
		for npc in npcs:
			if is_instance_valid(npc) and npc.position.distance_to(hit.get("position", Vector3.ZERO)) < 6.0:
				npc.alert_flee()


# ---------------- input ----------------

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		yaw -= event.relative.x * 0.008
		pitch = clampf(pitch + event.relative.y * 0.006, 0.12, 1.25)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if state == State.PLAYING:
			_shoot()
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_interact()
			KEY_SPACE:
				player.want_jump = true
	elif event is InputEventScreenTouch:
		if event.pressed and event.position.x < 360.0 and _stick_id == -1:
			_stick_id = event.index
			_stick_origin = event.position
			_stick_vec = Vector2.ZERO
		elif not event.pressed and event.index == _stick_id:
			_stick_id = -1
			_stick_vec = Vector2.ZERO
	elif event is InputEventScreenDrag:
		if event.index == _stick_id:
			_stick_vec = (event.position - _stick_origin) / 90.0
			_stick_vec = _stick_vec.limit_length(1.0)
		else:
			yaw -= event.relative.x * 0.008
			pitch = clampf(pitch + event.relative.y * 0.006, 0.12, 1.25)


func _move_input() -> Vector2:
	var v := Vector2.ZERO
	if Input.is_key_pressed(KEY_W):
		v.y += 1.0
	if Input.is_key_pressed(KEY_S):
		v.y -= 1.0
	if Input.is_key_pressed(KEY_D):
		v.x += 1.0
	if Input.is_key_pressed(KEY_A):
		v.x -= 1.0
	v += Vector2(_stick_vec.x, -_stick_vec.y)
	return v.limit_length(1.0)


# ---------------- per-frame ----------------

func _process(delta: float) -> void:
	offline_label.visible = not Backend.online
	_day_night(delta)

	if state == State.BUSTED:
		_busted_t -= delta
		if _busted_t <= 0.0:
			busted_box.visible = false
			state = State.PLAYING
			Ads.maybe_show_interstitial()
		return
	if state != State.PLAYING:
		return

	var input := _move_input()
	if mounted != null:
		mounted.drive(input.y, input.x, delta)
		player.position = mounted.position + Vector3(0, 0.5, 0)
	else:
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(-fwd.z, 0, fwd.x)
		player.desired_dir = fwd * input.y + right * input.x

	missions.tick(_active_body().position, delta)

	# wanted decay + cop pursuit
	if wanted > 0:
		wanted_t -= delta
		if wanted_t <= 0.0:
			wanted = 0
			for npc in npcs:
				if is_instance_valid(npc) and npc.is_cop:
					npc.set_chasing(false)
			_update_hud()
		else:
			for npc in npcs:
				if is_instance_valid(npc) and npc.is_cop \
						and npc.position.distance_to(player.position) < 1.5 and mounted == null:
					_busted()
					return

	# camera orbit
	var target: Vector3 = _active_body().position + Vector3(0, 1.7, 0)
	var dist := 10.0 if mounted != null else 6.0
	var offset := Vector3(
		dist * sin(yaw) * cos(pitch),
		dist * sin(pitch),
		dist * cos(yaw) * cos(pitch))
	cam.position = cam.position.lerp(target + offset, 1.0 - pow(0.0005, delta))
	cam.look_at(target, Vector3.UP)

	crosshair.visible = mounted == null
	prompt_label.text = ""
	if mounted != null:
		prompt_label.text = "E / ACT — get off" if mounted.kind == "horse" else "E / ACT — get out"
	elif player.position.distance_to(car.position) < 3.0:
		prompt_label.text = "E / ACT — enter car"
	elif player.position.distance_to(horse.position) < 3.0:
		prompt_label.text = "E / ACT — mount horse"

	minimap.queue_redraw()


func _day_night(delta: float) -> void:
	day_t = fmod(day_t + delta / day_length, 1.0)
	var sun_angle := day_t * TAU
	sun.rotation_degrees = Vector3(-20.0 - 120.0 * absf(sin(sun_angle * 0.5)), -35, 0)
	var daylight := clampf(0.25 + 0.75 * maxf(0.0, sin(sun_angle)), 0.25, 1.0)
	sun.light_energy = 0.15 + 1.0 * daylight
	env.background_color = Color(0.5 * daylight, 0.7 * daylight, 0.95 * daylight)
	env.ambient_light_energy = 0.3 + 0.5 * daylight


func _flash(strength: float) -> void:
	flash_rect.color = Color(1, 1, 1, strength)
	var t := create_tween()
	t.tween_property(flash_rect, "color:a", 0.0, 0.2)


# ---------------- minimap ----------------

class MiniMap extends Control:
	var main: Node3D

	func _draw() -> void:
		if main == null:
			return
		var half := size * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.5))
		var center: Vector3 = main._active_body().position
		var s := 1.6  # px per world unit
		for npc in main.npcs:
			if not is_instance_valid(npc):
				continue
			var rel := Vector2(npc.position.x - center.x, npc.position.z - center.z) * s
			if rel.length() < half.x - 4.0:
				draw_circle(half + rel, 3.0, Color(0.3, 0.4, 1.0) if npc.is_cop else Color(0.7, 0.7, 0.7))
		for v in [main.car, main.horse]:
			var relv := Vector2(v.position.x - center.x, v.position.z - center.z) * s
			if relv.length() < half.x - 4.0:
				draw_circle(half + relv, 4.0, Color(0.3, 0.9, 0.9))
		if main.missions.active():
			var mp: Vector3 = main.missions.marker_pos()
			var relm := Vector2(mp.x - center.x, mp.z - center.z) * s
			relm = relm.limit_length(half.x - 6.0)
			draw_circle(half + relm, 5.0, Color(1, 0.85, 0.2))
		draw_circle(half, 4.0, Color.WHITE)
