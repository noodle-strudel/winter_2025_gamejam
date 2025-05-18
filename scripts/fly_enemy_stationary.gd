extends FlyEnemy

func move():
	##print(direction, " start_offset: ", start_offset)
	if not dead:
		if taking_damage:
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
