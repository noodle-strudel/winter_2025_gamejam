extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Possible states for the player
enum STATE {
	NORMAL,  # Walk and Jump State
	GRAPPLE, # Grappling State
	HIT,     # Hit State
	DEFEAT   # Defeated State
}

# Controls the state of the player and exports it to the inspector
# When adding a new state, make sure to iterate the second argument!
@export_range(0, 3, 1, "suffix:state") var state = STATE.NORMAL

func _physics_process(delta: float) -> void:
	match state:
		STATE.NORMAL:
			normal_state(delta)

func normal_state(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	$Sprite2D.modulate = Color.RED if is_on_wall_only() else Color.WHITE

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
		# Flip the player horizontally
		var s = 1 if direction > 0 else -1
		for child in get_children():
			if child is Node2D:
				child.scale.x = abs(child.scale.x) * s
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
