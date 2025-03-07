extends CharacterBody2D

signal create_grapple

const SPEED = 300.0
const CLIMB_SPEED = 100.0
const JUMP_VELOCITY = -400.0

@onready var tongue_attack = $TonguePath/TonguePathFollower
@onready var stamina_bar = $UI/StaminaBar
@onready var tongue_remote_transform = $TonguePath/TonguePathFollower/RemoteTransform2D
@onready var mum_tongue = $TonguePath/TonguePathFollower/MumTongue
var eating: bool = false

var stamina: float = 100.0
var empty_stamina: bool = false
var full_stamina: bool = true
var grapple_path: Path2D = null
var grapple_path_follower: PathFollow2D = null

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
	print(position)
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
		STATE.GRAPPLE:
			grapple_state(delta)

func normal_state(delta: float) -> void:
	if Input.is_action_just_pressed("attack"):
		mum_tongue.monitorable = true
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
		mum_tongue.monitorable = false
		if eating:
			eating = false
			var food = get_node(tongue_remote_transform.remote_path)
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
		if direction.y:
			var s = 1
			if is_on_ceiling():
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

func grapple_state(delta: float) -> void:
	if grapple_path == null:
		grapple_path = Path2D.new()
		grapple_path.name = "GrapplePath"
		
		var path_curve = Curve2D.new()
		grapple_path_follower = PathFollow2D.new()
		grapple_path_follower.name = "PathFollower"
		
		var remote_transform = RemoteTransform2D.new()
		remote_transform.name = "GrappleTransform"
		
		path_curve.add_point($TonguePath.global_position)
		path_curve.add_point(tongue_attack.global_position + Vector2(0, 32))
		grapple_path.curve = path_curve
		grapple_path_follower.rotates = false
		grapple_path_follower.loop = false

		#grapple_path.scale.x = $TonguePath.scale.x
		remote_transform.remote_path = get_path()
		
		grapple_path.add_child(grapple_path_follower)
		grapple_path_follower.add_child(remote_transform)
		get_parent().add_child(grapple_path)
	
	grapple_path_follower.progress += 5
	
	if is_on_wall():
		grapple_path.queue_free()
		tongue_attack.progress_ratio = 0
		state = STATE.CLIMB
	
	move_and_slide()
	
	
func _on_mum_tongue_area_entered(area: Area2D) -> void:
	if area.name == "EdibleBox" and state == STATE.ATTACK:
		tongue_remote_transform.remote_path = area.get_parent().get_path()
		eating = true


func _on_stamina_cooldown_timeout() -> void:
	empty_stamina = false


func _on_mum_tongue_body_entered(body: Node2D) -> void:
	if body is TileMapLayer and not eating:
		state = STATE.GRAPPLE
