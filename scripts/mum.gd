extends CharacterBody2D

signal create_grapple
signal player_take_damage(int)
signal player_defeated

@onready var tongue_attack_origin = $TonguePathRoot/TonguePathOrigin
@onready var tongue_root = $TonguePathRoot
@onready var tongue_line = $TonguePathRoot/Line2D
@onready var tongue_path = $TonguePathRoot/TonguePathOrigin/TonguePath
@onready var tongue_attack = $TonguePathRoot/TonguePathOrigin/TonguePath/TonguePathFollower
@onready var tongue_remote_transform = $TonguePathRoot/TonguePathOrigin/TonguePath/TonguePathFollower/RemoteTransform2D
@onready var mum_tongue = $TonguePathRoot/TonguePathOrigin/TonguePath/TonguePathFollower/MumTongue
@onready var anim = $AnimatedSprite2D
@onready var stamina_bar = $UI/StaminaBar

@export var debug_stamina = false

@export var SPEED = 300.0
@export var CLIMB_SPEED = 100.0
@export var JUMP_VELOCITY = -600.0

# for some reason, when I try to use GRAVITY * delta, it gives me
# an error, but when I use get_gravity() * delta, there's no error.
# perhaps this can be discarded since its not used anywhere?
@onready var GRAVITY = get_gravity().y

@export var KNOCKBACK = -600
@export var DEACCEL = 300.0

@export var effective_size = Vector2(64, 64)
@export var debug = true

var stamina: float = 100.0
var empty_stamina: bool = false
var full_stamina: bool = true
var grapple_path: Path2D = null
var grapple_path_follower: PathFollow2D = null
var eating: bool = false
var prev_vel = Vector2.ZERO
var health = 3
var invulnerable: bool = false

# currently retracting tongue
var retracting: bool = false

# keeps track of what state the player was in last
var prev_state := 0
var prev_surface := 0

# Locks the animation while attacking, to avoid weirdness
var anim_lock = ""

# So the player can climb up onto the ground from the wall, without having a seziure
var ledge_catch = 0

var deaccel_factor = 1.0

var time = 0	
	
# Possible states for the player
enum STATE {
	NORMAL,  # Walk and Jump State
	GRAPPLE, # Grappling State
	CLIMB,   # Climbing State
	ATTACK,  # Attacking State
	HIT,     # Hit State
	DEFEAT   # Defeated State
}

enum SURFACE {
	FLOOR,
	LEFT,
	RIGHT,
	CEILING,
	AIR
}

# Controls the state of the player and exports it to the inspector
# When adding a new state, make sure to iterate the second argument!
@export_range(0, 5, 1, "suffix:state") var state = STATE.NORMAL

func _physics_process(delta: float) -> void:
	GRAVITY = get_gravity().y
	#print("Gravity:", get_gravity(), "Velocity:", velocity)
	if debug:
		if on_wall():
			$AnimatedSprite2D.modulate = Color.RED 
		elif is_ceiling_climbing():
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
		STATE.GRAPPLE:
			grapple_state(delta)
		STATE.HIT:
			hit_state(delta)
	
	animate()
	
	# Better ways to do this; I'm too tired to care
	tongue_root.visible = state in [STATE.ATTACK, STATE.GRAPPLE]
	var rotation = -tongue_root.global_rotation
	if not on_wall():
		rotation = 0
	tongue_line.set_point_position(0, ((mum_tongue.global_position - global_position) * anim.scale).rotated(rotation))
	#tongue_line.set_point_position(1, (tongue_attack_origin.global_position - global_position) * anim.scale)
	
	# Last
	prev_vel = velocity
	prev_surface = get_surface()
	for i in get_slide_collision_count():
		var collision = get_slide_collision(i)
	

func get_surface():
	if is_on_ceiling():
		return SURFACE.CEILING
	
	# Prioritize walls, unless we're somehow touching BOTH walls
	# Not that it'd come up in the current state of the game
	# But if it did, it may be good to change it. Like to take input into account.
	var side = 0
	if len($RightTerrainDetector.get_overlapping_bodies()) > 0:
		side += 1
	if len($LeftTerrainDetector.get_overlapping_bodies()) > 0:
		side -= 1
	
	if side == 1:
		return SURFACE.RIGHT
	elif side == -1:
		return SURFACE.LEFT
	else:
		if is_on_floor():
			return SURFACE.FLOOR
		return SURFACE.AIR
	
	

# Not to be confused with is_on_wall(). They're a little different, and I hope this one works better.
func on_wall():
	return get_surface() in [SURFACE.RIGHT, SURFACE.LEFT] && stamina > 0

func is_climbing():
	return get_surface() in [SURFACE.RIGHT, SURFACE.LEFT, SURFACE.CEILING] && stamina > 0
	
func is_ceiling_climbing():
	return state == STATE.CLIMB and get_surface() == SURFACE.CEILING

# Returns whether the player is looking away from their surface
func looking_up():
	var looking_up = false
	var surf = get_surface()
	if surf == SURFACE.FLOOR && Input.is_action_pressed("up"):
		looking_up = true
	elif surf == SURFACE.LEFT && Input.is_action_pressed("right"):
		looking_up = true
	elif surf == SURFACE.RIGHT && Input.is_action_pressed("left"):
		looking_up = true
	elif surf == SURFACE.CEILING && Input.is_action_pressed("down"):
		looking_up = true
	return looking_up

func normal_state(delta: float) -> void:
	if deaccel_factor < 1.0:
		deaccel_factor = min(deaccel_factor + delta, 1.0)
	
	if ledge_catch:
		position.y -= ledge_catch
		position.x += ledge_catch
		ledge_catch = 0
	
	
	if Input.is_action_just_pressed("attack"):
		mum_tongue.monitorable = true
		mum_tongue.monitoring = true
		$TongueSound.play()
		prev_state = state
		state = STATE.ATTACK
		return
	
	if on_wall() and not empty_stamina:
		prev_state = state
		state = STATE.CLIMB
		return
		
	# Add the gravity. check if the gravity is pointing upwards, meaning the frog is in water!
	if get_surface() != SURFACE.FLOOR or sign(get_gravity().y) == -1:
		velocity += get_gravity() * delta
	else: # otherwise, the frog is on land
		ledge_catch = 0

	# Handle jump.
	if Input.is_action_just_pressed("jump") and get_surface() == SURFACE.FLOOR:
		velocity.y = JUMP_VELOCITY
		$JumpAudio.play()
		
	# moves the tongue 45 degrees up
	if looking_up():
		tongue_attack_origin.rotation_degrees = -45 
	else:
		tongue_attack_origin.rotation_degrees = 0
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		if get_gravity().x:
			# check if direction is opposite of gravity
			if sign(direction) != sign(get_gravity().x):
				velocity.x = move_toward(velocity.x, direction * SPEED, DEACCEL * 0.1)
				
			else: # otherwise add direction to gravity
				velocity.x = move_toward(velocity.x, (direction * SPEED) + get_gravity().x, DEACCEL * 0.1)
		else:
			velocity.x = direction * SPEED
	else:
		# if there's gravity in the x direction
		if (get_gravity().x):
			# move toward the gravity
			velocity.x = move_toward(velocity.x, get_gravity().x, DEACCEL * 0.1)
		else: # otherwise go to 0
			velocity.x = move_toward(velocity.x, 0, DEACCEL * deaccel_factor)

	flip(velocity.x)
	move_and_slide()

func eat_food() -> void:
	if eating:
		eating = false
		var food = get_node(tongue_remote_transform.remote_path)
		food.handle_death()

func extend_tongue() -> void:
	time += 1
	if retracting:
		tongue_attack.progress_ratio = clamp(tongue_attack.progress_ratio - 0.04, 0, 1)
		mum_tongue.monitorable = false
		mum_tongue.monitoring = false
	else:
		tongue_attack.progress_ratio = clamp(tongue_attack.progress_ratio + 0.04, 0, 1)
		
	if tongue_attack.progress_ratio <= 0 or tongue_attack.progress_ratio >= 1:
		time = 0
		if tongue_attack.progress_ratio >= 1:
			eat_food()
			tongue_attack.progress_ratio = 0
		else:
			retracting = false
		mum_tongue.monitorable = false
		mum_tongue.monitoring = false
		tongue_attack.visible = false
		
		state = prev_state
		
	
func attack_state(delta: float) -> void:
	#if on_wall() and not empty_stamina:
		#tongue_attack.progress_ratio = 0
		#tongue_attack.visible = false
		#eat_food()
		#prev_state = state
		#state = STATE.CLIMB
		#return
		
	tongue_attack.visible = true
	
	# Add the gravity.
	if get_surface() == SURFACE.AIR:
		velocity.y += GRAVITY * delta
	
	# Handle jump.
	# No need to jump while attacking, I figure?
	#if Input.is_action_just_pressed("jump") and get_surface() == SURFACE.FLOOR:
	#	velocity.y = JUMP_VELOCITY
	
	extend_tongue()
	
	
	#var direction := Input.get_axis("left", "right")
	#if direction:
		#velocity.x = direction * SPEED
	#else:
		#velocity.x = move_toward(velocity.x, 0, DEACCEL)
	velocity.x = move_toward(velocity.x, 0, DEACCEL)
		
	#flip(velocity.x)
	move_and_slide()

func climb_state(_delta: float) -> void:
	var surf = get_surface()
	
	# moves the tongue 45 degrees up
	if looking_up():
		if surf == SURFACE.RIGHT:
			tongue_attack_origin.global_rotation_degrees = 180
		elif surf == SURFACE.LEFT:
			tongue_attack_origin.global_rotation_degrees = 0
	else:
		tongue_attack_origin.global_rotation_degrees = anim.global_rotation_degrees
	
	if Input.is_action_just_pressed("attack"):
		mum_tongue.monitorable = true
		mum_tongue.monitoring = true
		$TongueSound.play()
		prev_state = state
		state = STATE.ATTACK
		return
	
	
	if (not is_climbing()) or empty_stamina:
		if prev_state == STATE.HIT:
			anim.global_rotation_degrees = 0
			tongue_root.rotation_degrees = 0
			prev_state = STATE.CLIMB
			state = STATE.HIT
		else:
			prev_state = state
			anim.global_rotation_degrees = 0
			tongue_root.rotation_degrees = 0
			state = STATE.NORMAL
		flip_vert(1)
		return
	
	# Handle jump. (make sure to add a directional aspect, so user jumps OFF of wall)
	if Input.is_action_just_pressed("jump"):
		$JumpAudio.play()
	# Handle jump
	var jump = Input.is_action_just_pressed("jump")
	
	# Y'know what, only jump if the player actually presses the button
	#if Input.is_action_just_pressed("right") and surf == SURFACE.LEFT:
		#jump = true
	#if Input.is_action_just_pressed("left") and surf == SURFACE.RIGHT:
		#jump = true
	#if Input.is_action_just_pressed("down") and surf == SURFACE.CEILING:
		#jump = true
	
	if jump:
		prev_state = state
		anim.global_rotation_degrees = 0
		tongue_root.rotation_degrees = 0
		if prev_state == STATE.HIT:
			state = STATE.HIT
		else:
			state = STATE.NORMAL
		# Apply jump force
		match surf:
			SURFACE.LEFT:
				velocity.x = -JUMP_VELOCITY
				velocity.y = JUMP_VELOCITY
				deaccel_factor = 0.1
			SURFACE.RIGHT:
				velocity.x = JUMP_VELOCITY
				velocity.y = JUMP_VELOCITY
				deaccel_factor = 0.1
			SURFACE.CEILING:
				velocity.y = -JUMP_VELOCITY / 2
		flip_vert(1)
		move_and_slide()
		return
	
	var direction := Vector2()
	if not on_wall():
		direction.x = int(Input.get_axis("left", "right"))
	if not is_on_ceiling():
		direction.y = int(Input.get_axis("up", "down"))
	#var direction := Vector2(int(Input.get_axis("left", "right")), int(Input.get_axis("up", "down")))
	if direction:
		velocity = direction * CLIMB_SPEED
		if surf == SURFACE.RIGHT and not direction.x < 0:
			ledge_catch = 5
		elif surf == SURFACE.LEFT and not direction.x > 0:
			ledge_catch = -5
		else:
			ledge_catch = 0
	else:
		ledge_catch = 0
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.y = move_toward(velocity.y, 0, SPEED)
	
	match surf:
		SURFACE.CEILING:
			anim.global_rotation_degrees = 0
			tongue_root.rotation_degrees = 0
			flip(velocity.x)
			flip_vert(-1)
		SURFACE.RIGHT:
			#anim.rotation_degrees = -90
			anim.global_rotation_degrees = -90
			tongue_root.rotation_degrees = -90
			flip(-velocity.y)
		SURFACE.LEFT:
			#anim.rotation_degrees = 90
			anim.global_rotation_degrees = 90
			tongue_root.rotation_degrees = 90
			flip(velocity.y)
		_:
			anim.global_rotation_degrees = 0
			tongue_root.rotation_degrees = 0
	
	
	move_and_slide()
	

# Manages stamina and stanima bar
func manage_stamina():
	if state == STATE.CLIMB:
		if not debug_stamina:
			stamina -= 0.3
		full_stamina = false
		if stamina <= 0:
			empty_stamina = true
			$StaminaCooldown.start()
			
	elif state == STATE.NORMAL and not full_stamina and not empty_stamina:
		stamina += 0.5
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
		
		path_curve.add_point(tongue_path.global_position - Vector2(0, 32))
		path_curve.add_point(tongue_attack.global_position)
		grapple_path.curve = path_curve
		grapple_path_follower.rotates = false
		grapple_path_follower.loop = false

		#grapple_path.scale.x = $TonguePath.scale.x
		remote_transform.remote_path = get_path()
		
		grapple_path.add_child(grapple_path_follower)
		grapple_path_follower.add_child(remote_transform)
		get_parent().add_child(grapple_path)
	
	grapple_path_follower.progress += 7
	
	if on_wall() or get_surface() == SURFACE.CEILING:
		grapple_path.call_deferred("queue_free")
		tongue_attack.progress_ratio = 0
		prev_state = state
		state = STATE.CLIMB
	
	if grapple_path_follower.progress_ratio == 1:
		grapple_path.call_deferred("queue_free")
		tongue_attack.progress_ratio = 0
		
		# add some jump velocity as a test
		velocity.y = JUMP_VELOCITY
		prev_state = state
		state = STATE.NORMAL
	
	flip(velocity.x)
	move_and_slide()

# Hit state, cant attack and can only run, jump and climb
func hit_state(delta):
	print("hit!")
	if on_wall() and not empty_stamina:
		prev_state = state
		state = STATE.CLIMB
		return
		
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY
		
	# moves the tongue 45 degrees up
	if looking_up():
		tongue_attack_origin.rotation_degrees = -45
	else:
		tongue_attack_origin.rotation_degrees = 0
	
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var direction := Input.get_axis("left", "right")
	if direction:
		velocity.x = direction * SPEED
		
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
	
	flip(velocity.x)
	move_and_slide()

func _on_mum_tongue_area_entered(area: Area2D) -> void:
	if STATE.ATTACK:
		if area.name == "EdibleBox":
			tongue_remote_transform.remote_path = area.get_parent().get_path()
			eating = true
		elif area.name == "UnstickableBarrier":
			retracting = true


func _on_stamina_cooldown_timeout() -> void:
	empty_stamina = false


func _on_mum_tongue_body_entered(body: Node2D) -> void:
	if (body is TileMapLayer or body.name == "GrapplePoint") and not eating:
		mum_tongue.set_deferred("monitorable", false)
		mum_tongue.set_deferred("monitoring", false)
		state = STATE.GRAPPLE

# There's certainly many better ways to do animation
# For example, using a tree
# Or putting the logic within the state functions (that's probably what I SHOULD do)
# But I'm doing it this way for some reason
# Feel free to change it if you feel the need
func animate() -> void:
	# Goodness did this turn out janky
	# Definitely should have separated the logic into the different states
	# Might refactor all the state stuff at some point, we'll see
	
	var surf = get_surface()
	
	# Fix weird (literal) edge cases
	var vel = Vector2.ZERO
	vel.x = min(velocity.x, prev_vel.x)
	vel.y = min(velocity.y, prev_vel.y)
	
	var relevant_vel = vel.y if on_wall() else vel.x
	
	# Are we looking "up" ?
	var looking_up = looking_up()
	
	### Play the animations
	if state in [STATE.GRAPPLE, STATE.ATTACK]:
		if anim_lock != "":
			anim.play(anim_lock)
			return
		if is_climbing():
			anim.play("wall_tongue")
		else:
			if looking_up:
				anim.play("tongue_up")
			else:
				anim.play("tongue")
		anim_lock = anim.animation
		return
	anim_lock = ""
	var vertical_threshold = 50
	# INTRODUCING: Nightmare hellscape of nested if statements
	if surf != SURFACE.AIR:
		if relevant_vel == 0:
			if looking_up:
				if is_climbing():
					anim.play("wall_look_up")
				else:
					anim.play("look_up")
			else:
				if is_climbing():
					anim.play("wall_idle")
				else:
					anim.play("idle")
		else:
			if is_climbing():
				anim.play("wall_walk")
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

func flip(vel):
	if vel == 0:
		return
	# Gives 1 or 0
	var s = sign(vel)
	
	for child in get_children():
		if child is Node2D and not child.is_in_group("noflip"):
			child.scale.x = abs(child.scale.x) * s

func flip_vert(factor):
	for child in get_children():
		if child is Node2D and child.name != "TonguePath" and not child.is_in_group("noflip"):
			child.scale.y = abs(child.scale.y) * factor


func take_damage(dmg):
	health -= dmg
	if health <= 0:
		emit_signal("player_defeated")
	emit_signal("player_take_damage", dmg)
	$HurtCooldown.start()
	invulnerable = true


func _on_hurt_box_body_entered(body: Node2D) -> void:
	if not invulnerable:
		var knockback_direction = (body.global_position - global_position).normalized()
		velocity += knockback_direction * KNOCKBACK
		#set_collision_mask_value(2, false)
		take_damage(1)
		state = STATE.HIT
		$AnimatedSprite2D.modulate = Color.RED 


func _on_hurt_cooldown_timeout() -> void:
	invulnerable = false
	state = STATE.NORMAL
	#set_collision_mask_value(2, true)
	$AnimatedSprite2D.modulate = Color.WHITE
