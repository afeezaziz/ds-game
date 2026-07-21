class_name OpenVehicle
extends CharacterBody3D
## One arcade vehicle class, two personalities: "car" (fast, wide turns)
## and "horse" (slower, tight turns, gallop bob). Forward is -Z.
## Main.gd calls drive(throttle, steer, delta) while the player is mounted.

const GRAVITY := 22.0

var kind := "car"
var top_speed := 16.0
var reverse_speed := 6.0
var accel := 14.0
var brake := 24.0
var coast := 8.0
var turn_rate := 1.6

var occupied := false
var speed_cur := 0.0

var _mesh_root: Node3D
var _t := 0.0


func setup(vehicle_kind: String) -> void:
	kind = vehicle_kind
	_mesh_root = Node3D.new()
	add_child(_mesh_root)

	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()

	if kind == "car":
		top_speed = 16.0
		turn_rate = 1.6
		box.size = Vector3(1.9, 1.0, 3.6)
		shape.position = Vector3(0, 0.5, 0)
		_add_box(Vector3(1.9, 0.7, 3.6), Vector3(0, 0.45, 0), Color(0.9, 0.25, 0.25))
		_add_box(Vector3(1.5, 0.55, 1.7), Vector3(0, 1.05, 0.2), Color(0.15, 0.15, 0.2))
		for sx in [-0.85, 0.85]:
			for sz in [-1.25, 1.25]:
				_add_box(Vector3(0.25, 0.5, 0.5), Vector3(sx, 0.25, sz), Color(0.05, 0.05, 0.05))
	else:
		top_speed = 11.0
		turn_rate = 2.6
		accel = 10.0
		box.size = Vector3(0.8, 1.2, 2.2)
		shape.position = Vector3(0, 0.9, 0)
		_add_box(Vector3(0.7, 0.7, 1.8), Vector3(0, 1.15, 0), Color(0.45, 0.3, 0.18))
		_add_box(Vector3(0.35, 0.5, 0.5), Vector3(0, 1.7, -1.0), Color(0.45, 0.3, 0.18))  # head
		for sx in [-0.25, 0.25]:
			for sz in [-0.7, 0.7]:
				_add_box(Vector3(0.18, 0.85, 0.18), Vector3(sx, 0.42, sz), Color(0.3, 0.2, 0.12))

	shape.shape = box
	add_child(shape)


func _add_box(size: Vector3, pos: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.6
	bm.material = mat
	mi.mesh = bm
	mi.position = pos
	_mesh_root.add_child(mi)


func drive(throttle: float, steer: float, delta: float) -> void:
	_t += delta
	var target := throttle * (top_speed if throttle >= 0.0 else reverse_speed)
	if absf(target) > absf(speed_cur):
		speed_cur = move_toward(speed_cur, target, accel * delta)
	else:
		speed_cur = move_toward(speed_cur, target, brake * delta)
	if absf(throttle) < 0.05:
		speed_cur = move_toward(speed_cur, 0.0, coast * delta)

	if absf(speed_cur) > 0.5:
		rotation.y -= steer * turn_rate * delta * signf(speed_cur)

	if kind == "horse" and absf(speed_cur) > 1.0:
		_mesh_root.position.y = absf(sin(_t * 9.0)) * 0.12 * (absf(speed_cur) / top_speed)
	else:
		_mesh_root.position.y = 0.0


func _physics_process(delta: float) -> void:
	velocity.y -= GRAVITY * delta
	var fwd := -transform.basis.z
	velocity.x = fwd.x * speed_cur
	velocity.z = fwd.z * speed_cur
	move_and_slide()
	if not occupied:
		speed_cur = move_toward(speed_cur, 0.0, coast * delta)
