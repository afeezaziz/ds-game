class_name MechDemo3D
extends Node3D
## Base class for every 3D / 2.5D mechanic demo.
## Contract: override start(); guard on `running`; add_points() for score;
## end_demo() exactly once when the run dies (endless demos submit on exit).
## Helpers below build the world, camera and primitives so each demo file
## stays short. All gray-box: primitive meshes only, no external assets.

signal score_changed(score: int)
signal demo_over(score: int)

var score := 0
var running := false
var cam: Camera3D


func start() -> void:
	score = 0
	running = true


func add_points(d: int) -> void:
	score += d
	score_changed.emit(score)


func set_score(s: int) -> void:
	if s == score:
		return
	score = s
	score_changed.emit(score)


func end_demo() -> void:
	if not running:
		return
	running = false
	demo_over.emit(score)


# ---------- world helpers ----------

func setup_world(bg: Color, ambient := 0.8, sun_angle := Vector3(-55, -40, 0)) -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = bg
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = ambient
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = sun_angle
	sun.light_energy = 1.1
	add_child(sun)


func make_camera(pos := Vector3(0, 6, 10), look := Vector3.ZERO, fov := 65.0) -> Camera3D:
	cam = Camera3D.new()
	cam.fov = fov
	cam.position = pos
	add_child(cam)
	cam.make_current()
	cam.look_at(look, Vector3.UP)
	return cam


func mesh_box(size: Vector3, pos: Vector3, col: Color, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	mi.material_override = _mat(col)
	(parent if parent else self).add_child(mi)
	return mi


func mesh_sphere(radius: float, pos: Vector3, col: Color, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	mi.mesh = sm
	mi.position = pos
	mi.material_override = _mat(col)
	(parent if parent else self).add_child(mi)
	return mi


func mesh_cyl(radius: float, height: float, pos: Vector3, col: Color, parent: Node = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = height
	mi.mesh = cm
	mi.position = pos
	mi.material_override = _mat(col)
	(parent if parent else self).add_child(mi)
	return mi


func static_box(size: Vector3, pos: Vector3, col: Color) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.position = pos
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	body.add_child(cs)
	body.add_child(mesh_box(size, Vector3.ZERO, col))
	add_child(body)
	return body


func label3d(text: String, pos: Vector3, size := 48, col := Color.WHITE, parent: Node = null) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.modulate = col
	l.position = pos
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	(parent if parent else self).add_child(l)
	return l


func hue_col(i: float, s := 0.5, v := 0.9) -> Color:
	return Color.from_hsv(fmod(0.55 + i * 0.04, 1.0), s, v)


func _mat(col: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.roughness = 0.85
	return mat


# ---------- input helpers ----------

func key_axis_x() -> float:
	## Desktop steering: A/D or Left/Right. Demos add touch on top.
	var v := 0.0
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		v -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		v += 1.0
	return v


func key_axis_y() -> float:
	var v := 0.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		v += 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		v -= 1.0
	return v
