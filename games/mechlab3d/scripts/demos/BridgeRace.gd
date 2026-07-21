extends MechDemo3D
## BRIDGE RACE — auto-run forward; grab planks, and they auto-build across the
## gaps. Reach a gap with no planks and you fall. Score = distance. Desktop:
## A/D or drag to steer, to line up plank pickups.

var player: MeshInstance3D
var px := 0.0
var pz := 0.0
var speed := 8.0
var planks := 3
var falling := false
var segs: Array = []    # {z0, z1, gap:bool, bridged:bool}
var pickups: Array = []  # {z, x, node, dead}
var next_z := 0.0
var plank_label: Label3D


func start() -> void:
	super.start()
	setup_world(Color(0.45, 0.6, 0.8))
	player = mesh_box(Vector3(0.9, 1.2, 0.9), Vector3(0, 0.6, 0), Color(0.4, 0.85, 1.0))
	plank_label = label3d("3", Vector3(0, 2, 0), 40, Color.WHITE)
	px = 0.0
	pz = 0.0
	speed = 8.0
	planks = 3
	falling = false
	segs.clear()
	pickups.clear()
	next_z = -6.0
	for i in 8:
		_extend()
	make_camera(Vector3(0, 5, -8), Vector3(0, 0, 6))


func _extend() -> void:
	var solid := randf() > 0.4 or segs.is_empty()
	var length := randf_range(6.0, 10.0) if solid else randf_range(3.0, 6.0)
	var z0 := next_z
	var z1 := z0 + length
	if solid:
		mesh_box(Vector3(6, 0.5, length), Vector3(0, -0.25, (z0 + z1) * 0.5), Color(0.35, 0.45, 0.4))
		var np := 1 + randi() % 3
		for i in np:
			var pxp := randf_range(-2.4, 2.4)
			var pzp := randf_range(z0 + 1.0, z1 - 1.0)
			var node := mesh_box(Vector3(0.6, 0.25, 1.0), Vector3(pxp, 0.3, pzp), Color(0.85, 0.65, 0.3))
			pickups.append({"z": pzp, "x": pxp, "node": node, "dead": false})
	segs.append({"z0": z0, "z1": z1, "gap": not solid, "bridged": false})
	next_z = z1


func _cur_seg() -> Dictionary:
	for s in segs:
		if pz >= s.z0 and pz <= s.z1:
			return s
	return {}


func _unhandled_input(event: InputEvent) -> void:
	if running and event is InputEventScreenDrag:
		px = clampf(px + event.relative.x * 0.03, -2.6, 2.6)


func _process(delta: float) -> void:
	if falling:
		player.position.y -= 12.0 * delta
		if player.position.y < -6.0:
			end_demo()
		return
	if not running:
		return
	speed = minf(14.0, speed + delta * 0.2)
	pz += speed * delta
	px = clampf(px + key_axis_x() * 6.0 * delta, -2.6, 2.6)
	set_score(int(pz))

	while next_z < pz + 50.0:
		_extend()

	var s := _cur_seg()
	if s.get("gap", false) and not s.get("bridged", false):
		if planks > 0:
			s.bridged = true
			planks -= 1
			plank_label.text = str(planks)
			var mid := (s.z0 + s.z1) * 0.5
			mesh_box(Vector3(3.0, 0.2, s.z1 - s.z0), Vector3(0, -0.1, mid), Color(0.8, 0.6, 0.3))
			Juice.sfx("thud")
		else:
			falling = true
			Juice.haptic(40)
			return

	for p in pickups.duplicate():
		if p.dead:
			continue
		if p.z < pz - 4.0:
			p.node.queue_free()
			pickups.erase(p)
			continue
		if absf(p.z - pz) < 0.9 and absf(p.x - px) < 0.9:
			p.dead = true
			p.node.queue_free()
			planks += 1
			plank_label.text = str(planks)
			Juice.sfx("coin")

	player.position = Vector3(px, 0.6, pz)
	plank_label.position = Vector3(px, 2.0, pz)
	cam.position = Vector3(px * 0.4, 5, pz - 8)
	cam.look_at(Vector3(0, 0, pz + 6), Vector3.UP)
