extends Enemy

var charge_speed = 300
# Sets default moving direction

var charging_at_player = false

func _ready() -> void:
	direction = Vector2.LEFT
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
		velocity.x = 0
	elif not edible:
		move(delta)
	else:
		defeat(delta)
	
	handle_animation(delta)
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
			
			if not result or is_on_wall():
				direction = Vector2.LEFT if direction == Vector2.RIGHT else Vector2.RIGHT
			
			velocity.x = move_toward(velocity.x, speed * direction.x, 5)
		
		elif is_chasing_player and not charging_at_player:
			var dir_to_player = position.direction_to(player.position) * speed
			direction = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
			velocity.x = move_toward(velocity.x, dir_to_player.x, 2)
			
		elif charging_at_player:
			var dir_to_player = position.direction_to(player.position) * charge_speed
			direction = Vector2.LEFT if direction.x < 0 else Vector2.RIGHT
			velocity.x = move_toward(velocity.x, dir_to_player.x, 5)
		else:
			var knockback_dir = position.direction_to(player.position) * knockback_force
			velocity.x = knockback_dir.x
			velocity.y += -600
		is_moving = true
	else:
		velocity.x = 0

func defeat(delta):
	set_collision_layer_value(2, false)
	$UnstickableBarrier.monitorable = false
	$EdibleBox.monitorable = true
	# for debugging purposes
	$EdibleBox.show()

func handle_animation(delta):
	if velocity.x:
		var flip = ["Beetle", "EntityDetector", "UnstickableBarrier"]
		for node in flip:
			get_node(node).scale.x = abs(get_node(node).scale.x) * (-1 if velocity.x > 0 else 1)
	if not dead and not taking_damage and not is_attacking:
		$AnimationPlayer.play("walk")
	elif not dead and taking_damage and not is_attacking:
		$AnimationPlayer.play("hurt")
		var flip = ["Beetle", "EntityDetector", "UnstickableBarrier"]
		for node in flip:
			get_node(node).scale.x = abs(get_node(node).scale.x) * -1
		await get_tree().create_timer(1).timeout
		taking_damage = false
	elif dead and is_moving:
		is_moving = false
		$AnimationPlayer.play("die")
		await get_tree().create_timer(0.5).timeout
		edible = true


func _on_entity_detector_body_entered(body: Node2D) -> void: 
	charging_at_player = true
		

func _on_entity_detector_body_exited(body: Node2D) -> void:
	charging_at_player = false
		

func _on_hurtbox_area_entered(area: Area2D) -> void:
	if area.name == "MumTongue":
		take_damage()


func _on_player_sensor_body_entered(body: Node2D) -> void:
	if body.name == "Mum":
		player = body 
		is_chasing_player = true


func _on_player_sensor_body_exited(body: Node2D) -> void:
	if body.name == "Mum":
		player = null
		is_chasing_player = false
