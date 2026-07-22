# FlagLab-style 3D demo — build contract (read before writing a demo)

You are writing ONE self-contained Godot 4.3 GDScript demo that `extends MechDemo3D`.
Gray-box only (primitive meshes, no external assets). It ships to real Android/iOS
phones AND desktop, so touch controls must be VISIBLE. It MUST pass `gdparse`.

## Base class API (MechDemo3D — already exists, DO NOT redefine)
- Override `func start() -> void:` and call `super.start()` FIRST (sets running=true,
  score=0). Guard `_process(delta)` and `_unhandled_input(event)` with `if not running: return`.
- Score: `add_points(d: int)`, `set_score(s: int)`, and call `end_demo()` EXACTLY once
  when the run dies (endless demos submit on exit automatically). Never emit signals yourself.
- Constants: `W` (720.0), `H` (1280.0) — the portrait design space.
- `setup_world(bg: Color, ambient := 0.8, sun_angle := Vector3(-55,-40,0))` — call once in start().
- `make_camera(pos := Vector3(0,6,10), look := Vector3.ZERO, fov := 65.0) -> Camera3D` — sets
  member `cam` and makes it current. Reposition `cam` each frame in _process as needed
  (cam.position = ...; cam.look_at(target, Vector3.UP)).
- Primitives (all return the node; `parent` defaults to self):
  `mesh_box(size: Vector3, pos: Vector3, col: Color, parent=null) -> MeshInstance3D`
  `mesh_sphere(radius: float, pos: Vector3, col: Color, parent=null) -> MeshInstance3D`
  `mesh_cyl(radius: float, height: float, pos: Vector3, col: Color, parent=null) -> MeshInstance3D`
  `static_box(size, pos, col) -> StaticBody3D`  (visual + collider; usually just decoration)
  `label3d(text: String, pos: Vector3, size := 48, col := Color.WHITE, parent=null) -> Label3D`
  `hue_col(i: float, s := 0.5, v := 0.9) -> Color`
- Keyboard (poll in _process): `key_axis_x()` (A/D → -1..1), `key_axis_y()` (W/S → +1 forward).

## Touch overlay (REQUIRED — visible controls, no invisible tap zones)
Declare `var tc: TouchControls`. In start(), AFTER make_camera:
```
tc = add_touch_controls([
    {"id": "fire", "label": "FIRE", "col": Color(0.9,0.4,0.35)},
    # up to ~4 buttons
], want_look, want_stick)     # want_look/want_stick are bools
```
- `want_stick` (default true): left-side floating joystick. Read `tc.move` (Vector2:
  x=-1..1 right, y=-1..1 DOWN on screen). Standard world mapping:
  `Vector3(tc.move.x + key_axis_x(), 0, tc.move.y - key_axis_y())`.
- `want_look` (default false): right-side look-drag region. `tc.look.connect(_on_look)`
  where `func _on_look(rel: Vector2)` maps rel.x/rel.y to camera yaw/pitch.
- Buttons: `tc.action.connect(...)`, press-id string. Hold: `tc.held("id") -> bool` (poll).
  Release of a held button: `tc.released.connect(...)`.
- LAMBDA GOTCHA (causes gdparse failure): a SINGLE-LINE lambda cannot contain an `if`
  statement. For one button use `func(_id): do_thing()`. For several use MULTI-LINE:
  ```
  tc.action.connect(func(id):
      if id == "a": _a()
      elif id == "b": _b())
  ```
- If a demo needs to tap the 3D WORLD (place/select), set want_stick=false so the left
  half isn't consumed, and handle un-consumed touches in your own `_unhandled_input`
  (TouchControls only consumes its buttons/stick/look; a ground raycast:
  `var from := cam.project_ray_origin(sp); var dir := cam.project_ray_normal(sp)
   var hit = Plane(Vector3.UP, 0.0).intersects_ray(from, dir)`).

## Juice autoload (feel) — EXACT signatures, do not guess
- `Juice.sfx(name: String, pitch := 1.0)` — names: "chime","coin","thud","boom","tick".
- `Juice.flash(col := Color(1,1,1), strength := 0.25)`
- `Juice.hitstop(msec := 60)`
- `Juice.haptic(ms := 30)`
- `Juice.popup(text: String, screen_pos: Vector2, col := Color(1,0.9,0.4), font_size := 42)`
  — screen_pos is a Vector2 (e.g. Vector2(360, 500)); ALWAYS pass it.
- DO NOT call `Juice.shake2d` or `Juice.burst` — they need a Camera2D/Node2D and will
  ERROR in a 3D scene. For screen shake, add your own: a member `var _shake := 0.0`,
  add `_shake` to `cam.position` with random offset each frame and decay it.
- Vocabulary: success=chime, big success=coin, hit=thud, death=boom.

## Hard rules
- SCRIPTED movement/physics ONLY. Never use RigidBody3D, CharacterBody3D, PhysicsBody
  motion, or `move_and_slide`. Integrate your own velocity/gravity by setting `.position`
  and `.rotation`. This keeps demos deterministic and guaranteed to run.
- No external files/assets. Build everything from primitives + code.
- Typed GDScript, tabs, snake_case, portrait 720x1280.
- Keep KEYBOARD working in parallel (key_axis + discrete keys in _unhandled_input) for desktop.
- Start the file with `extends MechDemo3D` then a `## ...` docstring (2-4 lines: the
  mechanic AND the controls, touch + desktop keys).
- Make the DEEP SYSTEM real — the interlocking loop that makes the genre retain, not
  just the surface verb. ~150-230 lines is fine.
- Camera: each demo owns its own camera (make_camera) and repositions it per frame.
- Avoid undeclared identifiers (gdparse won't catch them but Godot fails to load).
  Cast typed mesh access (e.g. `(mi.mesh as CylinderMesh).height`). Don't mutate an
  array/dict while iterating it — iterate `.duplicate()` when removing.

## Before returning
RUN: `cd /home/claude/ds/game-client && gdparse <your file path>` and FIX until it
prints nothing (success). Return ONLY: "DONE <File>.gd — gdparse: OK" plus 1-2
sentences naming the deep system and the control scheme. If it still fails, return
"GDPARSE FAILED" and paste the error.
