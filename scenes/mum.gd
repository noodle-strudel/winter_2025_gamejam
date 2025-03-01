extends CharacterBody2D

const SPEED = 300.0
const CLIMB_SPEED = 100.0
const JUMP_VELOCITY = -400.0

@onready var tongue_attack = $TonguePath/TonguePathFollower
@onready var stamina_bar = $UI/StaminaBar
var eating: bool = false

var stamina: float = 100.0
var empty_stamina: bool = false
var full_stamina: bool = true

@export var effective_size = Vector2(64, 64)

# Possible states for the player
enum STATE {
	NORMAL,  # Walk and Jump State
	GRAPPLE, # Grappling State
	CLIMB,   # Climbing State
	ATTACK,  # Attacking State
	HIT,     # Hit State
	DEFEAT   # Defeated State
}

# Controls the state of the player and exports it to the inspector
# When adding a new state, make sure to iterate the second argument!
@export_range(0, 4, 1, "suffix:state") var state = STATE.NORMAL

func _physics_process(delta: float) -> void:
	if is_on_wall_only():
		$Sprite2D.modulate = Color.RED 
	elif is_on_ceiling_only():
		$Sprite2D.modulate = Color.BLUE
	else: 
		$Sprite2D.modulate = Color.WHITE
	
	manage_stamina()
	match state:
		STATE.NORMAL:
			normal_state(delta)
		STATE.ATTACK:
			attack_state(delta)
		STATE.CLIMB:
			climb_state(delta)

func normal_state(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		$TonguePath/TonguePathFollower/MumTongue.monitorable = true
		state = STATE.ATTACK
		return
	
	if is_on_wall_only() and not empty_stamina:
		state = STATE.CLIMB
		return
		
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
		# Flip the player horizontally
		var s = 1
		if direction < 0:
			s = -1
		for child in get_children():
			if child is Node2D:
				child.scale.x = abs(child.scale.x) * s
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	move_and_slide()

func attack_state(delta: float) -> void:
	if is_on_wall_only() and not empty_stamina:
		tongue_attack.progress_ratio = 0
		state = STATE.CLIMB
		return
		
	# Add the gravity.
	if not is_on_floor() and not is_on_wall():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	tongue_attack.progress_ratio = clamp(tongue_attack.progress_ratio + 0.03, 0, 1)
	
	if tongue_attack.progress_ratio == 1:
		tongue_attack.progress_ratio = 0
		$TonguePath/TonguePathFollower/MumTongue.monitorable = false
		if eating:
			eating = false
			var food = get_node($TonguePath/TonguePathFollower/RemoteTransform2D.remote_path)
			food.handle_death()
		state = STATE.NORMAL
	
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	move_and_slide()

func climb_state(delta: float) -> void:
	if (not is_on_wall() and not is_on_ceiling()) or empty_stamina:
		state = STATE.NORMAL
		for child in get_children():
			if child is Node2D:
				child.scale.y = abs(child.scale.y)
		return
		
	var direction := Vector2(int(Input.get_axis("left", "right")), int(Input.get_axis("up", "down")))
	if direction:
		velocity.x = direction.x * CLIMB_SPEED
		velocity.y = direction.y * CLIMB_SPEED
		if direction.x:
			var s = 1
			if direction.x < 0:
				s = -1
			for child in get_children():
				if child is Node2D:
					child.scale.x = abs(child.scale.x) * s
		if direction.y and is_on_ceiling():
			var s = 1
			if direction.y < 0:
				s = -1
			for child in get_children():
				if child is Node2D and child.name != "TonguePath":
					child.scale.y = abs(child.scale.y) * s
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)
	move_and_slide()

# Manages stamina and stanima bar
func manage_stamina():
	if state == STATE.CLIMB:
		stamina -= 0.3
		full_stamina = false
		if stamina <= 0:
			empty_stamina = true
			$StaminaCooldown.start()
			
	elif state == STATE.NORMAL and not full_stamina and not empty_stamina:
		stamina += 0.2
		if stamina >= 100:
			full_stamina = true
	
	stamina_bar.value = stamina

func _on_mum_tongue_area_entered(area: Area2D) -> void:
	if area.name == "EdibleBox" and state == STATE.ATTACK:
		$TonguePath/TonguePathFollower/RemoteTransform2D.remote_path = area.get_parent().get_path()
		eating = true


func _on_stamina_cooldown_timeout() -> void:
	empty_stamina = false
