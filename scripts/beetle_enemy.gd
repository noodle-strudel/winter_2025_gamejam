extends Enemy

# Sets default moving direction
func _ready() -> void:
	direction = Vector2.LEFT
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	
	if not is_on_floor():
		velocity += get_gravity() * delta
		velocity.x = 0
	else:
		move(delta)
		
	move_and_slide()

func move(delta) -> void:
	if not dead:
		if not is_chasing_player:
			# Shoots rays under its feet to determind when to turn around
			var space_state = get_world_2d().direct_space_state
			var query
			if direction == Vector2.LEFT:
				query = PhysicsRayQueryParameters2D.create($PlatformGuideL.global_position, $PlatformGuideL.global_position + Vector2.DOWN * 5)
				query.exclude = [self]
			else:
				query = PhysicsRayQueryParameters2D.create($PlatformGuideR.global_position, $PlatformGuideR.global_position + Vector2.DOWN * 5)
				query.exclude = [self]
			var result = space_state.intersect_ray(query)
			
			if not result:
				direction = Vector2.LEFT if direction == Vector2.RIGHT else Vector2.RIGHT
			velocity.x = move_toward(velocity.x, speed * direction.x, 5)
			
		elif is_chasing_player and not taking_damage:
			var dir_to_player = position.direction_to(player.position) * speed
			direction = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
			velocity.x = move_toward(velocity.x, dir_to_player.x, 1 )
		is_moving = true
	else:
		velocity.x = 0


func _on_entity_detector_body_entered(body: Node2D) -> void:
	if body.name == "Mum":
		player = body
		is_chasing_player = true


func _on_entity_detector_body_exited(body: Node2D) -> void:
	if body.name == "Mum":
		player = null
		is_chasing_player = false
