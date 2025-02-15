extends Enemy

var flying_bounds: int = 200
var start_offset: int = 0
var starting_pos: int = 0
var angle: float = 0.00

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	direction = choose([Vector2.LEFT, Vector2.RIGHT])
	starting_pos = global_position.x

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	move()
	move_and_slide()
	

func move():
	if not dead:
		if not is_chasing_player:
			velocity.y = wobble() * speed
			velocity.x = direction.x * speed
			start_offset += 1
			if start_offset > flying_bounds:
				direction = Vector2.LEFT if direction == Vector2.RIGHT else Vector2.RIGHT
				start_offset = 0
		else:
			var dir_to_player = position.direction_to(player.position) * speed
			velocity.x = move_toward(velocity.x, dir_to_player.x, 5)
			velocity.y = move_toward(velocity.y, dir_to_player.y, 5) + wobble()
			

# 
func wobble():
	angle += 0.1
	
	# clamping angle to 2 pi
	if angle > 2 * PI:
		angle = 0
	return sin(angle)

func choose(array: Array):
	array.shuffle()
	return array.front()


func _on_entity_detector_body_entered(body: Node2D) -> void:
	if body.name == "Mum":
		player = body
		is_chasing_player = true

func _on_entity_detector_body_exited(body: Node2D) -> void:
	if body.name == "Mum":
		player = null
		is_chasing_player = false
