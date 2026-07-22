extends MechDemo3D
## RHYTHM — four-lane beat game (Guitar Hero / Beat Saber). Notes stream toward the
## strike line; tap the matching lane the instant a note crosses it. Tight timing
## builds a combo multiplier; misses drain the bar. Tempo ramps up. Miss out the
## bar and the set ends. Desktop: D F J K per lane.

const LANES := 4
const LANE_X := [-4.5, -1.5, 1.5, 4.5]
const HIT_Z := 6.0
const SPAWN_Z := -40.0
const LANE_COL := [Color(0.9, 0.4, 0.4), Color(0.9, 0.85, 0.35), Color(0.4, 0.8, 0.95), Color(0.6, 0.85, 0.5)]

var notes: Array = []         # {lane,z,node,hit}
var beat_t := 0.0
var beat_gap := 0.7
var speed := 26.0
var health := 100.0
var combo := 0
var best_combo := 0
var pads: Array = []
var tc: TouchControls
var hud: Label3D
var t := 0.0


func start() -> void:
	super.start()
	setup_world(Color(0.06, 0.05, 0.12), 0.75, Vector3(-60, 0, 0))
	static_box(Vector3(16, 1, 60), Vector3(0, -0.5, -14), Color(0.1, 0.1, 0.18))
	for i in LANES:
		# lane guide + strike pad
		mesh_box(Vector3(2.4, 0.05, 50), Vector3(LANE_X[i], 0.02, -18), Color(LANE_COL[i], 0.12))
		var pad := mesh_box(Vector3(2.6, 0.2, 2.0), Vector3(LANE_X[i], 0.1, HIT_Z), Color(LANE_COL[i]) * 0.6)
		pads.append(pad)
	notes = []
	beat_t = 0.5
	beat_gap = 0.7
	speed = 26.0
	health = 100.0
	combo = 0
	best_combo = 0
	t = 0.0
	make_camera(Vector3(0, 9, 16), Vector3(0, 0, -6), 62.0)
	hud = label3d("", Vector3(0, 8, 6), 34, Color.WHITE)
	tc = add_touch_controls([
		{"id": "0", "label": "◆", "col": LANE_COL[0]},
		{"id": "1", "label": "◆", "col": LANE_COL[1]},
		{"id": "2", "label": "◆", "col": LANE_COL[2]},
		{"id": "3", "label": "◆", "col": LANE_COL[3]},
	], false, false)
	tc.action.connect(func(id): _strike(int(id)))


func _strike(lane: int) -> void:
	if lane < 0 or lane >= LANES:
		return
	pads[lane].position.y = 0.4
	var best = null
	var bd := 2.2
	for n in notes:
		if n.lane == lane and not n.hit:
			var d: float = absf(n.z - HIT_Z)
			if d < bd:
				bd = d
				best = n
	if best != null:
		best.hit = true
		best.node.queue_free()
		notes.erase(best)
		combo += 1
		best_combo = maxi(best_combo, combo)
		var pts := 1 + combo / 10
		add_points(pts)
		health = minf(100.0, health + 1.0)
		if bd < 0.7:
			Juice.sfx("coin")
			Juice.popup("PERFECT x%d" % combo, Vector2(W * 0.5, H * 0.36), Color(1, 0.9, 0.4))
		else:
			Juice.sfx("tick")
	else:
		combo = 0                     # swung at nothing


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_D: _strike(0)
			KEY_F: _strike(1)
			KEY_J: _strike(2)
			KEY_K: _strike(3)


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	for i in pads.size():
		pads[i].position.y = move_toward(pads[i].position.y, 0.1, delta * 2.0)

	beat_gap = maxf(0.28, 0.7 - t * 0.004)
	speed = 26.0 + t * 0.25
	beat_t -= delta
	if beat_t <= 0.0:
		beat_t = beat_gap
		var lane := randi() % LANES
		var node := mesh_box(Vector3(2.2, 0.5, 1.4), Vector3(LANE_X[lane], 0.4, SPAWN_Z), LANE_COL[lane])
		notes.append({"lane": lane, "z": SPAWN_Z, "node": node, "hit": false})

	for n in notes.duplicate():
		n.z += speed * delta
		n.node.position.z = n.z
		if n.z > HIT_Z + 2.2 and not n.hit:
			n.node.queue_free()
			notes.erase(n)
			combo = 0
			health -= 9.0
			Juice.flash(Color(1, 0.3, 0.3), 0.15)
			Juice.haptic(15)
			if health <= 0.0:
				end_demo()
				return

	hud.text = "SCORE %d   COMBO x%d   HEALTH %d%%" % [score, combo, int(health)]
	hud.position = Vector3(0, 8, 6)
