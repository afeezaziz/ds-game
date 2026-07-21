class_name OpenPlayer
extends CharacterBody3D
## Third-person on-foot controller. Main.gd feeds it a camera-relative
## desired direction each frame; this script handles gravity, jumping,
## movement and facing. Gray-box body: capsule + head cube.

const GRAVITY := 22.0
const JUMP_V := 8.5

var desired_dir := Vector3.ZERO  # world-space, normalized-ish, set by Main
var want_jump := false
var run_speed := 6.0

var _mesh_root: Node3D


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	shape.shape = cap
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)

	_mesh_root = Node3D.new()
	add_child(_mesh_root)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.35
	cm.height = 1.6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.95, 0.95, 1.0)
	cm.material = mat
	body.mesh = cm
	body.position = Vector3(0, 0.8, 0)
	_mesh_root.add_child(body)
	var head := MeshInstance3D.new()
	var hb := BoxMesh.new()
	hb.size = Vector3(0.3, 0.3, 0.3)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(1.0, 0.8, 0.6)
	hb.material = hmat
	head.mesh = hb
	head.position = Vector3(0, 1.75, 0)
	_mesh_root.add_child(head)


func _physics_process(delta: float) -> void:
	if not visible:
		return  # parked while riding a vehicle
	velocity.y -= GRAVITY * delta
	if want_jump and is_on_floor():
		velocity.y = JUMP_V
	want_jump = false

	var flat := Vector3(desired_dir.x, 0, desired_dir.z)
	if flat.length() > 1.0:
		flat = flat.normalized()
	velocity.x = flat.x * run_speed
	velocity.z = flat.z * run_speed
	move_and_slide()

	if flat.length() > 0.1:
		var target_yaw := atan2(flat.x, flat.z)
		_mesh_root.rotation.y = lerp_angle(_mesh_root.rotation.y, target_yaw, 10.0 * delta)
