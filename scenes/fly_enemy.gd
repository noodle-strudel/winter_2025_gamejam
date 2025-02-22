extends Enemy

# think about making flying enemy class
# do some pathfinding stuff
# Return to original flying position
var returning = false

var flying_bounds: int = 200
var start_offset: int = 0
var starting_pos: Vector2 = Vector2.ZERO
var angle: float = 0.00

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	direction = choose([Vector2.LEFT, Vector2.RIGHT])
	starting_pos = global_position

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	move()
	handle_animation(delta)
	move_and_slide()
	

func move():
	if not dead:
		if not is_chasing_player and not returning:
			velocity.y = wobble() * speed
			velocity.x = direction.x * speed
			start_offset += 1
			if start_offset > flying_bounds or is_on_wall():
				direction = Vector2.LEFT if direction == Vector2.RIGHT else Vector2.RIGHT
				start_offset = 0
		elif not is_chasing_player and returning:
			var dir_to_start = position.direction_to(starting_pos) * speed
			velocity.x = move_toward(velocity.x, dir_to_start.x, 5)
			velocity.y = move_toward(velocity.y, dir_to_start.y, 5)
			if position.distance_to(starting_pos) <= 1:
				returning = false
		elif is_chasing_player and not taking_damage:
			var dir_to_player = position.direction_to(player.position) * speed
			velocity.x = move_toward(velocity.x, dir_to_player.x, 5)
			velocity.y = move_toward(velocity.y, dir_to_player.y, 5)
			returning = true
		else:
			var knockback_dir = position.direction_to(player.position) * knockback_force
			velocity.x = knockback_dir.x
		is_moving = true

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

func handle_animation(delta):
	if not dead and not taking_damage and not is_attacking:
		# Play walking animation dependent on direction
		pass
	elif not dead and taking_damage and not is_attacking:
		# Play hurt animation
		await get_tree().create_timer(1).timeout
		taking_damage = false
	elif dead and is_moving:
		is_moving = false
		# death animation
		defeat()

func defeat():
	set_collision_layer_value(2, false)
	$EdibleBox.monitorable = true

func _on_entity_detector_body_entered(body: Node2D) -> void:
	if body.name == "Mum":
		player = body
		is_chasing_player = true

func _on_entity_detector_body_exited(body: Node2D) -> void:
	if body.name == "Mum":
		is_chasing_player = false

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.name == "MumTongue":
		take_damage()
