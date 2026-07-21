extends MechDemo3D
## ACTION RPG — third-person melee (Diablo / Genshin combat core). Drag/WASD to
## move; tap ATTACK to swing an arc at foes in front. Kills grant XP; level up
## for more damage and health. Waves escalate. Score = kills. HP 0 = over.

var player: Node3D
var ppos := Vector3.ZERO
var facing := Vector3(0, 0, -1)
var hp := 100.0
var maxhp := 100.0
var dmg := 12.0
var xp := 0
var need := 4
var level := 1
var inv := 0.0
var atk_flash := 0.0
var enemies: Array = []
var spawn_t := 0.0
var t := 0.0
var tc: TouchControls
var hud: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.14, 0.13, 0.18), 0.9, Vector3(-60, -30, 0))
	static_box(Vector3(60, 1, 60), Vector3(0, -0.5, 0), Color(0.25, 0.27, 0.3))
	player = Node3D.new()
	add_child(player)
	mesh_box(Vector3(0.9, 1.6, 0.9), Vector3(0, 0.8, 0), Color(0.5, 0.85, 1.0), player)
	mesh_box(Vector3(0.2, 0.2, 1.3), Vector3(0.5, 1.0, 0.6), Color(0.95, 0.95, 1.0), player)
	ppos = Vector3.ZERO
	hp = 100.0
	maxhp = 100.0
	dmg = 12.0
	xp = 0
	need = 4
	level = 1
	enemies = []
	spawn_t = 0.5
	t = 0.0
	hud = label3d("", Vector3(0, 3, 0), 40, Color.WHITE)
	make_camera(Vector3(0, 13, 10), Vector3.ZERO, 55.0)
	tc = add_touch_controls([{"id": "attack", "label": "ATTACK", "col": Color(0.9, 0.5, 0.4)}])
	tc.action.connect(func(_id): attack())


func attack() -> void:
	atk_flash = 0.15
	Juice.sfx("thud")
	for e in enemies.duplicate():
		var to: Vector3 = e.node.position - ppos
		if to.length() < 3.4 and facing.dot(to.normalized()) > 0.35:
			e.hp -= dmg
			if e.hp <= 0:
				e.node.queue_free()
				enemies.erase(e)
				_gain_xp()


func _gain_xp() -> void:
	add_points(1)
	xp += 1
	if xp >= need:
		xp = 0
		level += 1
		need = 3 + level * 2
		dmg += 4
		maxhp += 20
		hp = maxhp
		Juice.sfx("chime")
		Juice.flash(Color(0.6, 0.9, 1.0), 0.2)


func _unhandled_input(event: InputEvent) -> void:
	if not running:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		attack()


func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	inv -= delta
	atk_flash = maxf(0.0, atk_flash - delta)
	var mv := Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())
	if mv.length() > 1.0:
		mv = mv.normalized()
	ppos += mv * 8.0 * delta
	ppos.x = clampf(ppos.x, -28, 28)
	ppos.z = clampf(ppos.z, -28, 28)
	if mv.length() > 0.1:
		facing = mv.normalized()
		player.rotation.y = atan2(mv.x, mv.z)
	player.position = ppos

	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = maxf(0.5, 1.8 - t * 0.02)
		var a := randf() * TAU
		var p := ppos + Vector3(cos(a), 0, sin(a)) * 24.0
		var node := mesh_box(Vector3(0.9, 1.4, 0.9), p + Vector3(0, 0.7, 0), Color(0.85, 0.35, 0.35))
		enemies.append({"node": node, "hp": 6.0 + level * 3.0})

	for e in enemies:
		var to: Vector3 = ppos - e.node.position
		to.y = 0
		e.node.position += to.normalized() * (2.8 + level * 0.1) * delta
		if inv <= 0.0 and to.length() < 1.3:
			hp -= 8.0
			inv = 0.7
			Juice.flash(Color(1, 0.3, 0.3), 0.2)
			Juice.haptic(25)
			if hp <= 0.0:
				end_demo()
				return

	cam.position = ppos + Vector3(0, 13, 10)
	cam.look_at(ppos, Vector3.UP)
	hud.text = "HP %d/%d   Lv%d   (%d/%d xp)" % [int(max(0, hp)), int(maxhp), level, xp, need]
	hud.position = ppos + Vector3(0, 3, 0)
