extends Area2D



func _on_body_entered(body: Node2D) -> void:
	if body.name == "Mum":
		body.take_damage(999999)
