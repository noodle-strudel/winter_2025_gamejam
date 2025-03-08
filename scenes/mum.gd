extends CharacterBody2D

@export var SPEED = 300.0
@export var CLIMB_SPEED = 100.0
@export var JUMP_VELOCITY = -600.0
@export var GRAVITY = 1500

@onready var tongue_attack = $TonguePath/TonguePathFollower
@onready var stamina_bar = $UI/StaminaBar
@onready var anim = $AnimatedSprite2D
var eating: bool = false

var stamina: float = 100.0
var empty_stamina: bool = false
var full_stamina: bool = true

@export var effective_size = Vector2(64, 64)
@export var debug = true

var prev_vel = Vector2.ZERO

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
	if debug:
		if is_on_wall_only():
			$AnimatedSprite2D.modulate = Color.RED 
		elif is_on_ceiling_only():
			$AnimatedSprite2D.modulate = Color.BLUE
		else: 
			$AnimatedSprite2D.modulate = Color.WHITE
	
	manage_stamina()
	match state:
		STATE.NORMAL:
			normal_state(delta)
		STATE.ATTACK:
			attack_state(delta)
		STATE.CLIMB:
			climb_state(delta)
	
	animate()
	
	# Last
	prev_vel = velocity

func normal_state(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		$TonguePath/TonguePathFollower/MumTongue.monitorable = true
		$TongueSound.play()
		state = STATE.ATTACK
		return
	
	if is_on_wall_only() and not empty_stamina:
		state = STATE.CLIMB
		return
		
	# Add the gravity.
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
		
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		
	move_and_slide()

func attack_state(delta: float) -> void:
	if is_on_wall_only() and not empty_stamina:
		tongue_attack.progress_ratio = 0
		state = STATE.CLIMB
		tongue_attack.visible = false
		return
		
	tongue_attack.visible = true
	
	# Add the gravity.
	if not is_on_floor() and not is_on_wall():
		velocity += get_gravity() * delta
	
	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
	
	tongue_attack.progress_ratio = clamp(tongue_attack.progress_ratio + 0.03, 0, 1)
	
	if tongue_attack.progress_ratio == 1:
		tongue_attack.progress_ratio = 0
		tongue_attack.visible = false
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

func climb_state(_delta: float) -> void:
	if (not is_on_wall() and not is_on_ceiling()) or empty_stamina:
		state = STATE.NORMAL
		
		return
		
	var direction := Vector2(int(Input.get_axis("left", "right")), int(Input.get_axis("up", "down")))
	if direction:
		velocity = direction * CLIMB_SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)
	move_and_slide()
	
	# Handle jump. (make sure to add a directional aspect, so user jumps OFF of wall)
	if Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
		state = STATE.NORMAL
		
		return
		
	

# Manages stamina and stanima bar
func manage_stamina():
	if state == STATE.CLIMB:
		stamina -= 0
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

# There's certainly many better ways to do animation
# For example, using a tree
# Or putting the logic within the state functions (that's probably what I SHOULD do)
# But I'm doing it this way for some reason
# Feel free to change it if you feel the need
func animate() -> void:
	# Goodness did this turn out janky
	# Definitely should have separated the logic into the different states
	# Might refactor all the state stuff at some point, we'll see
	var surface = "floor"
	if is_on_ceiling():
		surface = "ceiling"
	if is_on_wall():
		surface = "wall"
	
	# Fix weird (literal) edge cases
	var vel = Vector2.ZERO
	vel.x = min(velocity.x, prev_vel.x)
	vel.y = min(velocity.y, prev_vel.y)
	
	var relevant_vel = vel.y if surface == "wall" else vel.x
	
	### Play the animations
	var vertical_threshold = 50
	if is_on_floor() or is_on_ceiling() or is_on_wall():
		if relevant_vel == 0:
			anim.play("idle")
		else:
			anim.play("walk")
	else:
		# In the air
		if velocity.y > vertical_threshold:
			anim.play("fall")
		elif velocity.y < -vertical_threshold:
			anim.play("jump")
		else:
			anim.play("air_neutral")
	
	### Orient the sprite properly
	var right_wall = false
	if len($RightTerrainDetector.get_overlapping_bodies()) > 0 and surface == "wall":
		right_wall = true
	if surface == "wall":
		if right_wall:
			anim.rotation_degrees = -90
		else:
			anim.rotation_degrees = 90
	else:
		anim.rotation_degrees = 0
		
	if vel:
		var s = 1
		if relevant_vel < 0:
			s = -1
		if right_wall:
			s *= -1
		for child in get_children():
			if child is Node2D and not child.is_in_group("noflip"):
				child.scale.x = abs(child.scale.x) * s
		
		var s2 = -1 if surface == "ceiling" else 1
		for child in get_children():
			if child is Node2D and child.name != "TonguePath" and not child.is_in_group("noflip"):
				child.scale.y = abs(child.scale.y) * s2
