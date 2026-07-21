extends MechDemo
## SNAKE — grow-and-avoid grid movement. Tap left half = turn left,
## right half = turn right (relative steering, the Nokia way).

const CS := 45.0
const COLS := 16
const ROWS := 24
const OY := 140.0

var body: Array = []
var dir := Vector2i(1, 0)
var food := Vector2i(4, 4)
var step_t := 0.0


func start() -> void:
	super.start()
	body = [Vector2i(8, 12), Vector2i(7, 12), Vector2i(6, 12)]
	dir = Vector2i(1, 0)
	step_t = 0.0
	_place_food()
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not running or not (event is InputEventScreenTouch and event.pressed):
		return
	if event.position.x < W * 0.5:
		dir = Vector2i(dir.y, -dir.x)   # turn left
	else:
		dir = Vector2i(-dir.y, dir.x)   # turn right


func _process(delta: float) -> void:
	if not running:
		return
	step_t += delta
	if step_t >= 0.14:
		step_t = 0.0
		_step()
	queue_redraw()


func _step() -> void:
	var head: Vector2i = body[0] + dir
	if head.x < 0 or head.x >= COLS or head.y < 0 or head.y >= ROWS or body.has(head):
		end_demo()
		return
	body.push_front(head)
	if head == food:
		add_points(5)
		_place_food()
	else:
		body.pop_back()


func _place_food() -> void:
	while true:
		food = Vector2i(randi() % COLS, randi() % ROWS)
		if not body.has(food):
			return


func _draw() -> void:
	draw_rect(Rect2(0, OY, COLS * CS, ROWS * CS), Color(0.09, 0.12, 0.09))
	draw_rect(Rect2(food.x * CS + 6, OY + food.y * CS + 6, CS - 12, CS - 12), Color(0.95, 0.3, 0.25))
	for i in body.size():
		var c: Vector2i = body[i]
		var col := Color(0.5, 0.95, 0.4) if i == 0 else Color(0.35, 0.75, 0.3)
		draw_rect(Rect2(c.x * CS + 3, OY + c.y * CS + 3, CS - 6, CS - 6), col)
	draw_string(f(), Vector2(20, OY + ROWS * CS + 40),
		"tap LEFT/RIGHT half to turn", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1, 1, 1, 0.5))
