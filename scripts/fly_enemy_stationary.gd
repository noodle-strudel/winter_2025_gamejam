extends FlyEnemy

func move():
	#print(direction, " start_offset: ", start_offset)
	#print(direction, " start_offset: ", start_offset)
	if not dead:
		if not is_chasing_player and not returning:
			# Idle state
			#velocity.y = wobble() * speed
			#velocity.x = direction.x * speed
			start_offset += 1
			
			# turn around
			if start_offset > flying_bounds or is_on_wall():
				direction = Vector2.LEFT if direction == Vector2.RIGHT else Vector2.RIGHT
				start_offset = 0
			
		elif not is_chasing_player and returning:
			# returning after chasing player
			var dir_to_start = position.direction_to(starting_pos) * speed
			#velocity.x = move_toward(velocity.x, dir_to_start.x, 5)
			#velocity.y = move_toward(velocity.y, dir_to_start.y, 5)
			direction = Vector2(abs(velocity.x)/velocity.x, 0)
			if position.distance_to(starting_pos) <= 1:
				returning = false
			
		elif is_chasing_player and not taking_damage:
			# actively chasing the player
			var dir_to_player = position.direction_to(player.position) * speed
			#velocity.x = move_toward(velocity.x, dir_to_player.x, 5)
			#velocity.y = move_toward(velocity.y, dir_to_player.y, 5)
			direction = Vector2(abs(velocity.x)/velocity.x, 0)
			returning = true
		else:
			# taking damage, add knockback
			var knockback_dir = position.direction_to(player.position) * knockback_force
			velocity.x = knockback_dir.x
		is_moving = true
	return
		
func _on_entity_detector_body_entered(body: Node2D) -> void:
	if body.name == "Mum":
		player = body
		is_chasing_player = false	#Disabling so that it stays Stationary

func _on_entity_detector_body_exited(body: Node2D) -> void:
	if body.name == "Mum":
		is_chasing_player = false	#Disabling so that it stays Stationary
	return
