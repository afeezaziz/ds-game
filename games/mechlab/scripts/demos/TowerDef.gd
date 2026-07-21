extends MechDemo
## TOWER DEFENSE — creeps walk the road; tap open ground to build towers
## (40 gold) that auto-shoot. Classic Bloons/Kingdom Rush loop.

const PATH := [Vector2(0, 260), Vector2(560, 260), Vector2(560, 640),
	Vector2(160, 640), Vector2(160, 1020), Vector2(720, 1020)]
const TOWER_COST := 40
const RANGE := 235.0

var creeps: Array = []
var towers: Array = []
var beams: Array = []
var gold := 60
var lives := 10
var wave := 0
var to_spawn := 0
var spawn_t := 0.0
var wave_t := 2.0


func start() -> void:
	super.start()
	creeps.clear()
	towers.clear()
	beams.clear()
	gold = 60
	lives = 10
	wave = 0
	to_spawn = 0
	wave_t = 2.0
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	var p: Vector2 = event.position
	if p.y < 140.0 or gold < TOWER_COST:
		return
	if _dist_to_path(p) < 75.0:
		return
	for t in towers:
		if t.pos.distance_to(p) < 60.0:
			return
	towers.append({"pos": p, "cd": 0.0})
	gold -= TOWER_COST
	queue_redraw()


func _dist_to_path(p: Vector2) -> float:
	var best := 99999.0
	for i in range(PATH.size() - 1):
		var q := Geometry2D.get_closest_point_to_segment(p, PATH[i], PATH[i + 1])
		best = minf(best, p.distance_to(q))
	return best


func _process(delta: float) -> void:
	if not running:
		return
	# waves
	if to_spawn > 0:
		spawn_t -= delta
		if spawn_t <= 0.0:
			spawn_t = 0.8
			to_spawn -= 1
			creeps.append({"seg": 0, "d": 0.0, "hp": 3 + wave, "maxhp": 3 + wave,
				"pos": PATH[0]})
	elif creeps.is_empty():
		wave_t -= delta
		if wave_t <= 0.0:
			wave += 1
			to_spawn = 3 + wave
			spawn_t = 0.0
			wave_t = 3.0
			if wave > 1:
				add_points(10 * (wave - 1))
				gold += 15 + wave * 5

	# creeps walk
	var speed := 90.0 + wave * 4.0
	for c in creeps.duplicate():
		c.d += speed * delta
		var seg_len: float = PATH[c.seg].distance_to(PATH[c.seg + 1])
		while c.d >= seg_len:
			c.d -= seg_len
			c.seg += 1
			if c.seg >= PATH.size() - 1:
				break
			seg_len = PATH[c.seg].distance_to(PATH[c.seg + 1])
		if c.seg >= PATH.size() - 1:
			creeps.erase(c)
			lives -= 1
			if lives <= 0:
				end_demo()
				return
			continue
		c.pos = PATH[c.seg].lerp(PATH[c.seg + 1], c.d / seg_len)

	# towers shoot
	for t in towers:
		t.cd -= delta
		if t.cd > 0.0:
			continue
		var best = null
		var best_d := RANGE
		for c in creeps:
			var d: float = t.pos.distance_to(c.pos)
			if d < best_d:
				best = c
				best_d = d
		if best != null:
			t.cd = 0.5
			best.hp -= 1
			beams.append({"a": t.pos, "b": best.pos, "t": 0.12})
			if best.hp <= 0:
				creeps.erase(best)
				gold += 4
				add_points(5)

	for b in beams.duplicate():
		b.t -= delta
		if b.t <= 0.0:
			beams.erase(b)
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(0, 130, W, H - 130), Color(0.1, 0.13, 0.1))
	draw_polyline(PackedVector2Array(PATH), Color(0.35, 0.3, 0.25), 56.0)
	for t in towers:
		draw_circle(t.pos, RANGE, Color(1, 1, 1, 0.03))
		draw_circle(t.pos, 24.0, Color(0.4, 0.6, 0.95))
		draw_circle(t.pos, 12.0, Color(0.2, 0.3, 0.6))
	for c in creeps:
		draw_rect(Rect2(c.pos.x - 18, c.pos.y - 18, 36, 36), Color(0.85, 0.3, 0.3))
		var frac: float = float(c.hp) / float(c.maxhp)
		draw_rect(Rect2(c.pos.x - 20, c.pos.y - 30, 40.0 * frac, 6.0), Color(0.3, 0.9, 0.4))
	for b in beams:
		draw_line(b.a, b.b, Color(1, 1, 0.6, b.t * 7.0), 3.0)
	draw_string(f(), Vector2(20, 165), "GOLD %d   LIVES %d   WAVE %d" % [gold, lives, wave],
		HORIZONTAL_ALIGNMENT_LEFT, -1, 28, Color(1, 1, 1, 0.85))
	draw_string(f(), Vector2(20, H - 16), "tap open ground to build (40g)",
		HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
