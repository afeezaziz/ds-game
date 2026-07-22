extends MechDemo3D
## COLONY SIM — allocate labour, survive (Rimworld). Assign your colonists across
## CHOP (wood), FARM (food) and GUARD (defence); each button pulls a worker from the
## busiest other job. Food feeds the colony; raids test your guards. Starve or get
## overrun and colonists die — lose them all and it's over. Score = days survived.

var colonists: Array = []     # {node, job}
var wood := 10.0
var food := 20.0
var day := 1
var day_t := 0.0
var raid_t := 18.0
var raid_warn := 0.0
var tc: TouchControls
var hud: Label3D
var zones := {}


func start() -> void:
	super.start()
	setup_world(Color(0.45, 0.55, 0.6), 0.85, Vector3(-55, -25, 0))
	static_box(Vector3(46, 1, 34), Vector3(0, -0.5, -2), Color(0.35, 0.42, 0.3))
	zones = {
		"chop": Vector3(-12, 0, -6),
		"farm": Vector3(0, 0, -9),
		"guard": Vector3(12, 0, -6),
	}
	mesh_box(Vector3(3, 4, 3), Vector3(-12, 2, -10), Color(0.4, 0.55, 0.3))   # forest
	mesh_box(Vector3(6, 0.4, 4), Vector3(0, 0.2, -12), Color(0.5, 0.6, 0.25)) # field
	mesh_box(Vector3(3, 3, 3), Vector3(12, 1.5, -10), Color(0.5, 0.4, 0.35))  # wall
	mesh_box(Vector3(4, 3, 4), Vector3(0, 1.5, 6), Color(0.6, 0.5, 0.4))      # base
	colonists = []
	var jobs := ["farm", "farm", "chop", "guard"]
	for i in 4:
		var node := Node3D.new()
		add_child(node)
		mesh_box(Vector3(0.9, 1.6, 0.9), Vector3(0, 0.8, 0), hue_col(i * 0.2, 0.5, 0.9), node)
		colonists.append({"node": node, "job": jobs[i]})
	wood = 10.0
	food = 20.0
	day = 1
	raid_t = 18.0
	make_camera(Vector3(0, 20, 20), Vector3.ZERO, 55.0)
	hud = label3d("", Vector3(0, 12, 0), 32, Color.WHITE)
	tc = add_touch_controls([
		{"id": "chop", "label": "CHOP", "col": Color(0.6, 0.45, 0.35)},
		{"id": "farm", "label": "FARM", "col": Color(0.6, 0.8, 0.4)},
		{"id": "guard", "label": "GUARD", "col": Color(0.5, 0.7, 0.95)},
	], false, false)
	tc.action.connect(func(id): _assign(id))


func _count(job: String) -> int:
	var n := 0
	for c in colonists:
		if c.job == job:
			n += 1
	return n


func _assign(job: String) -> void:
	# pull one colonist from the most-staffed OTHER job
	var others := ["chop", "farm", "guard"].filter(func(j): return j != job)
	var biggest := ""
	var bn := 0
	for j in others:
		if _count(j) > bn:
			bn = _count(j)
			biggest = j
	if biggest == "":
		return
	for c in colonists:
		if c.job == biggest:
			c.job = job
			Juice.sfx("tick")
			return


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_J: _assign("chop")
		elif event.keycode == KEY_K: _assign("farm")
		elif event.keycode == KEY_L: _assign("guard")


func _process(delta: float) -> void:
	if not running:
		return
	var pop := colonists.size()
	wood += _count("chop") * 1.2 * delta
	food += _count("farm") * 1.4 * delta - pop * 0.5 * delta
	if food <= 0.0:
		food = 0.0
		# starvation: lose a colonist every few seconds
		if fmod(day_t, 4.0) < delta and pop > 0:
			_kill("STARVED")

	day_t += delta
	if day_t >= 12.0:
		day_t = 0.0
		day += 1
		add_points(1)

	raid_t -= delta
	raid_warn = maxf(0.0, raid_warn - delta)
	if raid_t < 4.0 and raid_warn <= 0.0:
		raid_warn = 1.0
		Juice.popup("RAID INCOMING", Vector2(W * 0.5, H * 0.34), Color(1, 0.5, 0.3))
	if raid_t <= 0.0:
		raid_t = maxf(10.0, 20.0 - day * 0.5)
		_raid()

	# position colonists near their job zone (bobbing)
	var idx := {"chop": 0, "farm": 0, "guard": 0}
	for c in colonists:
		var base: Vector3 = zones[c.job]
		var off: int = idx[c.job]
		idx[c.job] = off + 1
		var target := base + Vector3((off % 3 - 1) * 1.4, 0, (off / 3) * 1.4)
		c.node.position = c.node.position.move_toward(target, 5.0 * delta)

	cam.look_at(Vector3(0, 0, -2), Vector3.UP)
	hud.text = "DAY %d   pop %d   WOOD %d   FOOD %d\nchop %d  farm %d  guard %d   next raid %ds" % [
		day, colonists.size(), int(wood), int(food),
		_count("chop"), _count("farm"), _count("guard"), int(raid_t)]
	hud.position = Vector3(0, 12, 0)


func _raid() -> void:
	var force := 1 + day / 2
	var defense := _count("guard") + int(wood / 20.0)   # walls from stockpiled wood help
	wood = maxf(0.0, wood - 20.0)
	if defense >= force:
		add_points(2)
		Juice.sfx("chime")
		Juice.flash(Color(0.6, 0.9, 1.0), 0.25)
		Juice.popup("RAID REPELLED", Vector2(W * 0.5, H * 0.36), Color(0.7, 1, 0.8))
	else:
		var losses := force - defense
		Juice.sfx("boom")
		Juice.flash(Color(1, 0.3, 0.3), 0.35)
		for i in losses:
			_kill("RAIDED")


func _kill(reason: String) -> void:
	if colonists.is_empty():
		return
	var c = colonists.pop_back()
	c.node.queue_free()
	Juice.haptic(30)
	Juice.popup("COLONIST LOST (%s)" % reason, Vector2(W * 0.5, H * 0.42), Color(1, 0.5, 0.4))
	if colonists.is_empty():
		end_demo()
